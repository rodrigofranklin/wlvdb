# V5 cross-engine allowance for the candidate's authenticated runtime sidecar.
#
# The sidecar has no legacy equivalent. It is accepted only after the
# candidate runtime itself validates its complete envelope, artifact hashes,
# semantic-state coordinates and state-binding hashes against the immutable run.

sys.source(
  file.path(script_dir, "issue13-v5-preparation-equivalence.R"),
  envir = environment(),
  chdir = FALSE
)

wlv13_v5_original_validate_nonfinite <-
  wlv13_cross_engine_validate_nonfinite
wlv13_v5_original_compare_config <- wlv13_cross_engine_compare_config
wlv13_v5_original_cross_engine_schema <- wlv13_cross_engine_schema

wlv13_cross_engine_run_rules <- function() {
  list(
    normalized = c(
      "file:_anomalies.csv",
      "file:_method_assumptions.csv",
      "file:_method_matrices.csv",
      "file:_method_solutions.csv",
      "file:_scientific_checks.csv",
      "file:_source_provenance.csv",
      "file:_unit_contract.csv"
    ),
    candidate_only = c(
      "file:_nonfinite_resolution_diagnostics.csv",
      "file:_runtime_resources.rds"
    )
  )
}

wlv13_v5_runtime_snapshot_interface <- function(runtime, expected_generation) {
  if (!is.environment(runtime) && !is.list(runtime)) {
    stop("Candidate runtime snapshot interface is missing.", call. = FALSE)
  }
  expected_generation <- unname(unclass(as.character(expected_generation)))
  if (!is.character(expected_generation) || length(expected_generation) != 1L ||
      is.na(expected_generation) ||
      !grepl("^[0-9a-f]{64}$", expected_generation)) {
    stop("Expected runtime snapshot generation is invalid.", call. = FALSE)
  }
  expected_reader_formals <- c(
    "result_dir", "method", "source", "partitions", "expected_sha256"
  )
  reader <- runtime$wlv_runtime_snapshot_read_envelope
  if (!is.function(reader) ||
      !identical(names(formals(reader)), expected_reader_formals)) {
    stop("Runtime snapshot envelope reader signature changed.", call. = FALSE)
  }
  version <- runtime$wlv_runtime_snapshot_version
  snapshot_version <- "wlv-runtime-resources/1.1.0"
  if (!is.function(version) || length(formals(version)) ||
      !identical(version(), snapshot_version)) {
    stop("Candidate runtime snapshot contract changed.", call. = FALSE)
  }
  authenticator <- runtime$wlv_runtime_snapshot_authenticate_bound_files
  authenticate_formals <- if (is.function(authenticator)) {
    formals(authenticator)
  } else {
    NULL
  }
  if (is.null(authenticate_formals) || !identical(
      names(authenticate_formals),
      c("snapshot", "root", "validate_snapshot")
    ) || !identical(authenticate_formals$validate_snapshot, TRUE)) {
    stop("Runtime snapshot authenticator signature changed.", call. = FALSE)
  }
  generation_accessor <- runtime$.wlv_runtime_compatibility_generation
  if (!is.function(generation_accessor) || length(formals(generation_accessor))) {
    stop("Runtime snapshot generation accessor changed.", call. = FALSE)
  }
  runtime_generation <- unname(unclass(as.character(generation_accessor())))
  if (!is.character(runtime_generation) || length(runtime_generation) != 1L ||
      is.na(runtime_generation) ||
      !grepl("^[0-9a-f]{64}$", runtime_generation) ||
      !identical(runtime_generation, expected_generation)) {
    stop("Runtime snapshot generation differs from metadata derivation.",
      call. = FALSE
    )
  }
  list(
    snapshot_version = snapshot_version,
    runtime_generation = runtime_generation
  )
}

wlv13_v5_validate_runtime_snapshot <- function(descriptor, method) {
  if (!identical(descriptor$relative, "_runtime_resources.rds") ||
      !identical(descriptor$type, "rds") ||
      !identical(descriptor$role, "metadata")) {
    return(list(
      passed = FALSE,
      reason = "runtime-snapshot-descriptor-mismatch",
      architecture_difference = TRUE
    ))
  }
  validation <- tryCatch({
    context <- wlv13_v5_metadata_context(descriptor, "candidate", method)
    profile <- wlv13_v5_metadata_profile(
      method, "_method_assumptions.csv"
    )
    loaded <- wlv_gate_load_runtime(context$project_root)
    if (!identical(loaded$kind, "candidate")) {
      stop("The runtime sidecar can only be validated by the candidate runtime.",
        call. = FALSE
      )
    }
    interface <- wlv13_v5_runtime_snapshot_interface(
      loaded$runtime,
      profile$manifest$candidate_runtime_generation_sha256
    )
    expected_snapshot_version <- interface$snapshot_version
    runtime_generation <- interface$runtime_generation
    snapshot <- loaded$runtime$wlv_runtime_snapshot_read_envelope(
      context$run_root,
      method = method,
      source = profile$source,
      partitions = profile$partition,
      expected_sha256 = descriptor$sha256
    )
    snapshot_generation <- unname(unclass(as.character(
      snapshot$compatibility$runtime_generation_sha256
    )))
    if (!identical(snapshot_generation, runtime_generation)) {
      stop("Runtime snapshot is bound to another runtime generation.",
        call. = FALSE
      )
    }
    bound_artifacts <-
      loaded$runtime$wlv_runtime_snapshot_authenticate_bound_files(
        snapshot, context$run_root, validate_snapshot = TRUE
      )
    if (!is.list(bound_artifacts) || !length(bound_artifacts) ||
        anyDuplicated(names(bound_artifacts))) {
      stop("Runtime snapshot bound-artifact proof is incomplete.",
        call. = FALSE
      )
    }
    loaded$runtime$wlv_assert_loaded_runtime_unchanged()
    if (!identical(snapshot$version, expected_snapshot_version) ||
        !identical(snapshot$method, method) ||
        !identical(snapshot$source, profile$source) ||
        !identical(snapshot$partitions, profile$partition)) {
      stop("The runtime sidecar envelope is not the Issue #13 contract.",
        call. = FALSE
      )
    }
    list(
      passed = TRUE,
      reason = "candidate-runtime-envelope-and-bound-files-validated",
      snapshot_version = snapshot$version,
      partition_count = length(snapshot$partitions),
      resource_count = length(snapshot$resources),
      state_binding_count = nrow(snapshot$state_bindings),
      bound_artifact_count = length(bound_artifacts),
      input_binding_sha256 = context$input_binding_sha256,
      architecture_difference = TRUE
    )
  }, error = function(error) {
    list(
      passed = FALSE,
      reason = paste0(
        "candidate-runtime-snapshot-invalid: ",
        conditionMessage(error)
      ),
      architecture_difference = TRUE
    )
  })
  validation
}

wlv13_cross_engine_validate_nonfinite <- function(descriptor, method) {
  if (identical(descriptor$relative, "_runtime_resources.rds")) {
    return(wlv13_v5_validate_runtime_snapshot(descriptor, method))
  }
  wlv13_v5_original_validate_nonfinite(descriptor, method)
}

# The legacy and native engines intentionally publish different identifiers for
# their method composition. Cross-engine parity therefore uses an exhaustive,
# versioned bridge: every cell of both sidecars is sealed per method/artifact,
# and each side is independently reconstructed from its pinned engine plan.
# No category, wildcard, tolerance or unordered projection is accepted here.

wlv13_v5_metadata_artifacts <- c(
  "_method_assumptions.csv",
  "_method_matrices.csv",
  "_method_solutions.csv"
)
wlv13_v5_source_provenance_columns <- c(
  "schema_version", "source", "source_generation_id", "contract_id",
  "contract_version", "contract_sha256", "manifest_sha256"
)
wlv13_cross_engine_schema <- function(name) {
  if (identical(name, "_source_provenance.csv")) {
    return(wlv13_v5_source_provenance_columns)
  }
  wlv13_v5_original_cross_engine_schema(name)
}
wlv13_v5_metadata_cache <- new.env(parent = emptyenv())
wlv13_v5_metadata_manifest_cache <- NULL

wlv13_v5_metadata_manifest <- function() {
  if (!is.null(wlv13_v5_metadata_manifest_cache)) {
    return(wlv13_v5_metadata_manifest_cache)
  }
  path <- file.path(script_dir, "issue13-v5-metadata-equivalence.json")
  value <- wlv13_json_read(path, simplify = FALSE)
  methods <- c(
    "wiodr13", "wiodr16", "alternative_1", "alternative_2", "norow_w13",
    "ochoa_1", "ochoa_2", "petrovic", "wiodr13v09", "wiodr16v09",
    "zerodep_1", "zerodep_2"
  )
  valid <- is.list(value) &&
    identical(value$schema, "wlv-issue13-metadata-equivalence/1") &&
    identical(
      value$baseline_commit,
      "cc2c86189a06676bcb9f0e05e08033d710a92509"
    ) &&
    identical(
      value$candidate_commit_at_derivation,
      "899f6379daffeb5697c08a605260c64dea750ec7"
    ) &&
    identical(
      value$derivation,
      paste0(
        "Exact engine-reconstructed sidecars paired by method and artifact; ",
        "no category, wildcard, tolerance or row-order projection."
      )
    ) &&
    is.character(value$candidate_runtime_generation_sha256) &&
    length(value$candidate_runtime_generation_sha256) == 1L &&
    grepl("^[0-9a-f]{64}$", value$candidate_runtime_generation_sha256) &&
    identical(unlist(value$methods, use.names = FALSE), methods) &&
    identical(
      unlist(value$artifacts, use.names = FALSE),
      wlv13_v5_metadata_artifacts
    ) &&
    is.list(value$profiles) && length(value$profiles) == length(methods) &&
    identical(
      vapply(value$profiles, `[[`, character(1L), "method"),
      methods
    ) &&
    all(vapply(value$profiles, function(profile) {
      is.list(profile) &&
        identical(names(profile), c("method", "source", "partition", "artifacts")) &&
        is.list(profile$artifacts) &&
        identical(
          vapply(profile$artifacts, `[[`, character(1L), "artifact"),
          wlv13_v5_metadata_artifacts
        )
    }, logical(1L)))
  if (!valid) {
    stop("The exhaustive metadata equivalence manifest is invalid.",
      call. = FALSE
    )
  }
  assign(
    "wlv13_v5_metadata_manifest_cache",
    value,
    envir = environment(wlv13_v5_metadata_manifest)
  )
  value
}

wlv13_v5_metadata_profile <- function(method, artifact) {
  manifest <- wlv13_v5_metadata_manifest()
  profile_index <- match(method, vapply(
    manifest$profiles, `[[`, character(1L), "method"
  ))
  if (is.na(profile_index)) {
    stop(sprintf("No exhaustive metadata profile exists for `%s`.", method),
      call. = FALSE
    )
  }
  profile <- manifest$profiles[[profile_index]]
  if (!is.character(profile$source) || length(profile$source) != 1L ||
      !profile$source %in% c("wiodr13", "wiodr16") ||
      !is.character(profile$partition) || length(profile$partition) != 1L ||
      !profile$partition %in% c("1995-2009", "2000-2014") ||
      !is.list(profile$artifacts) ||
      length(profile$artifacts) != length(wlv13_v5_metadata_artifacts)) {
    stop(sprintf("Metadata profile `%s` has an invalid envelope.", method),
      call. = FALSE
    )
  }
  artifact_index <- match(artifact, vapply(
    profile$artifacts, `[[`, character(1L), "artifact"
  ))
  if (is.na(artifact_index)) {
    stop(sprintf(
      "No exhaustive metadata profile exists for `%s`/`%s`.",
      method, artifact
    ), call. = FALSE)
  }
  list(
    method = method,
    source = profile$source,
    partition = profile$partition,
    artifact = profile$artifacts[[artifact_index]],
    manifest = manifest
  )
}

wlv13_v5_metadata_table <- function(value, artifact, arm) {
  expected_columns <- wlv13_cross_engine_schema(artifact)
  columns <- if (is.list(value)) unlist(value$columns, use.names = FALSE) else
    character()
  rows <- if (is.list(value) && is.list(value$rows)) value$rows else NULL
  if (!identical(columns, expected_columns) || is.null(rows)) {
    stop(sprintf("Metadata manifest table `%s`/%s has an invalid schema.",
      artifact, arm
    ), call. = FALSE)
  }
  if (!length(rows)) {
    result <- as.data.frame(
      stats::setNames(replicate(
        length(columns), character(), simplify = FALSE
      ), columns),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    rownames(result) <- NULL
    return(result)
  }
  valid_rows <- vapply(rows, function(row) {
    is.list(row) && length(row) == length(columns) &&
      all(vapply(row, function(cell) {
        is.character(cell) && length(cell) == 1L && !is.na(cell)
      }, logical(1L)))
  }, logical(1L))
  if (any(!valid_rows)) {
    stop(sprintf("Metadata manifest table `%s`/%s has an invalid row.",
      artifact, arm
    ), call. = FALSE)
  }
  result <- as.data.frame(
    stats::setNames(lapply(seq_along(columns), function(column) {
      vapply(rows, `[[`, character(1L), column)
    }), columns),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  rownames(result) <- NULL
  result
}

wlv13_v5_metadata_normalize <- function(value, columns) {
  if (!is.data.frame(value) || !identical(names(value), columns)) {
    return(NULL)
  }
  result <- as.data.frame(lapply(value, function(column) {
    column <- as.character(column)
    column[is.na(column)] <- ""
    enc2utf8(column)
  }), stringsAsFactors = FALSE, check.names = FALSE)
  rownames(result) <- NULL
  result
}

wlv13_v5_metadata_context <- function(descriptor, expected_arm, method) {
  path <- normalizePath(descriptor$path, winslash = "/", mustWork = TRUE)
  run_root <- dirname(path)
  scope <- environment(wlv13_v5_metadata_context)
  if (!exists("wlv13_v5_comparison_context", envir = scope, inherits = TRUE)) {
    stop(
      "Cross-engine metadata comparison lacks sealed run contexts.",
      call. = FALSE
    )
  }
  contexts <- get(
    "wlv13_v5_comparison_context", envir = scope, inherits = TRUE
  )
  context <- if (is.list(contexts)) contexts[[expected_arm]] else NULL
  project_root <- if (is.list(context)) normalizePath(
    context$project_root, winslash = "/", mustWork = TRUE
  ) else ""
  context_run_root <- if (is.list(context)) normalizePath(
    context$run_root, winslash = "/", mustWork = TRUE
  ) else ""
  expected_commit <- if (is.list(context)) context$expected_commit else NULL
  observed_commit <- if (is.list(context)) context$observed_commit else NULL
  input_records <- if (is.list(context) && is.list(context$inputs)) {
    tryCatch(vapply(context$inputs, function(input) {
      relative <- wlv13_scalar_text(input$path, "sealed input path")
      sha256 <- wlv13_scalar_text(
        input$sha256, "sealed input sha256", "^[0-9a-f]{64}$"
      )
      paste(relative, sha256, sep = "|")
    }, character(1L)), error = function(error) character())
  } else {
    character()
  }
  input_paths <- sub("[|].*$", "", input_records)
  input_binding_valid <- length(input_records) > 0L &&
    !anyDuplicated(input_paths) &&
    identical(
      wlv13_sha256_text(paste(input_records, collapse = "\n")),
      context$input_binding_sha256
    )
  valid <- is.list(context) &&
    identical(context$arm, expected_arm) &&
    identical(context$method, method) &&
    identical(run_root, context_run_root) &&
    identical(expected_commit, observed_commit) &&
    is.character(expected_commit) && length(expected_commit) == 1L &&
    grepl("^[0-9a-f]{40}$", expected_commit) &&
    is.numeric(context$input_count) && length(context$input_count) == 1L &&
    !is.na(context$input_count) && context$input_count > 0L &&
    is.character(context$input_binding_sha256) &&
    length(context$input_binding_sha256) == 1L &&
    grepl("^[0-9a-f]{64}$", context$input_binding_sha256) &&
    is.list(context$inputs) &&
    length(context$inputs) == context$input_count &&
    input_binding_valid &&
    identical(wlv13_git_commit(project_root), expected_commit) &&
    isTRUE(wlv13_git_runtime_clean(project_root))
  if (!valid) {
    stop(sprintf(
      "Metadata artifact is outside the sealed %s engine context.",
      expected_arm
    ), call. = FALSE)
  }
  context
}

wlv13_v5_baseline_sidecars <- function(plan, method) {
  configuration <- plan$configuration[[method]]
  assumptions <- configuration$assumptions[
    order(configuration$assumptions$order), , drop = FALSE
  ]
  matrices <- configuration$matrices[
    order(configuration$matrices$order), , drop = FALSE
  ]
  solutions <- configuration$solutions[
    order(configuration$solutions$order), , drop = FALSE
  ]
  solutions <- solutions[order(solutions$stage), , drop = FALSE]
  list(
    `_method_assumptions.csv` = assumptions,
    `_method_matrices.csv` = matrices,
    `_method_solutions.csv` = solutions
  )
}

wlv13_v5_reconstructed_metadata <- function(context, profile) {
  cache_key <- paste(
    context$arm, context$project_root, context$method,
    context$expected_commit, context$input_binding_sha256,
    profile$source, profile$partition,
    sep = "\034"
  )
  if (exists(cache_key, envir = wlv13_v5_metadata_cache, inherits = FALSE)) {
    return(get(cache_key, envir = wlv13_v5_metadata_cache, inherits = FALSE))
  }
  loaded <- wlv_gate_load_runtime(context$project_root)
  if (!identical(loaded$kind, context$arm)) {
    stop("Metadata reconstruction loaded the wrong engine generation.",
      call. = FALSE
    )
  }
  expected_formals <- c(
    "methods", "repeat_pp", "papern", "prepaper", "workers", "channel",
    "mode", "at_stage", "sea_vars", "root", "allow_experimental",
    "requested_operations", "catalog"
  )
  if (!identical(
      names(formals(loaded$runtime$wlv_validate_request)), expected_formals
  )) {
    stop("Metadata reconstruction received an unexpected planner signature.",
      call. = FALSE
    )
  }
  plan <- loaded$runtime$wlv_validate_request(
    methods = context$method,
    repeat_pp = FALSE,
    papern = 0L,
    prepaper = FALSE,
    workers = 1L,
    channel = "stable",
    mode = "calculate",
    at_stage = 1L,
    sea_vars = NULL,
    root = context$project_root,
    allow_experimental = TRUE,
    requested_operations = "calculate",
    catalog = NULL
  )
  if (!inherits(plan, "wlv_run_plan") ||
      !identical(
        normalizePath(plan$root, winslash = "/", mustWork = TRUE),
        context$project_root
      ) ||
      !identical(plan$mode, "calculate") ||
      !identical(plan$requested_operations, "calculate") ||
      !identical(plan$method_names, context$method) ||
      !identical(plan$allow_experimental, TRUE)) {
    stop("Metadata reconstruction produced an unexpected run plan.",
      call. = FALSE
    )
  }
  expected_inputs <- if (identical(context$arm, "candidate")) {
    loaded$runtime$wlv_assert_plan_publication_inputs_unchanged(
      plan, context$method
    )
    loaded$runtime$wlv_plan_publication_input_inventory(plan, context$method)
  } else {
    first <- loaded$runtime$wlv_publication_input_inventory(
      plan, context$method
    )
    second <- loaded$runtime$wlv_publication_input_inventory(
      plan, context$method
    )
    if (!identical(first, second)) {
      stop("Baseline publication inputs changed during reconstruction.",
        call. = FALSE
      )
    }
    first
  }
  if (!identical(expected_inputs, context$inputs)) {
    stop("Reconstructed plan inputs differ from sealed run provenance.",
      call. = FALSE
    )
  }
  observed_source <- if (identical(context$arm, "candidate")) {
    plan$methods$source[[1L]]
  } else {
    plan$methods$parameter_set[[1L]]
  }
  if (!identical(observed_source, profile$source)) {
    stop("Reconstructed metadata source differs from the sealed profile.",
      call. = FALSE
    )
  }
  sidecars <- if (identical(context$arm, "candidate")) {
    generation <- unname(unclass(as.character(
      loaded$runtime$.wlv_runtime_compatibility_generation()
    )))
    if (!is.character(generation) || length(generation) != 1L ||
        is.na(generation) || !grepl("^[0-9a-f]{64}$", generation)) {
      stop("Candidate runtime generation is invalid.", call. = FALSE)
    }
    if (!identical(
        generation,
        profile$manifest$candidate_runtime_generation_sha256
    )) {
      stop("Candidate runtime generation differs from metadata derivation.",
        call. = FALSE
      )
    }
    native <- loaded$runtime$wlv_native_configuration_sidecars(
      plan,
      context$method,
      list(partitions = profile$partition)
    )
    loaded$runtime$wlv_assert_loaded_runtime_unchanged()
    list(
      `_method_assumptions.csv` = native$assumptions,
      `_method_matrices.csv` = native$matrices,
      `_method_solutions.csv` = native$solutions
    )
  } else {
    wlv13_v5_baseline_sidecars(plan, context$method)
  }
  if (identical(context$arm, "candidate")) {
    loaded$runtime$wlv_assert_plan_publication_inputs_unchanged(
      plan, context$method
    )
  } else if (!identical(
      loaded$runtime$wlv_publication_input_inventory(plan, context$method),
      context$inputs
  )) {
    stop("Baseline publication inputs changed after reconstruction.",
      call. = FALSE
    )
  }
  normalized <- lapply(names(sidecars), function(artifact) {
    value <- wlv13_v5_metadata_normalize(
      sidecars[[artifact]], wlv13_cross_engine_schema(artifact)
    )
    if (is.null(value)) {
      stop(sprintf("Reconstructed `%s` has an invalid schema.", artifact),
        call. = FALSE
      )
    }
    value
  })
  names(normalized) <- names(sidecars)
  assign(cache_key, normalized, envir = wlv13_v5_metadata_cache)
  normalized
}

wlv13_v5_exact_metadata_equal <- function(observed, expected) {
  is.data.frame(observed) && is.data.frame(expected) && identical(observed, expected)
}

wlv13_v5_json_rows <- function(value, columns, label, allow_empty = FALSE) {
  if (!is.list(value) || (!length(value) && !isTRUE(allow_empty))) {
    stop(sprintf("%s has no rows.", label), call. = FALSE)
  }
  if (!is.character(columns) || !length(columns) || anyNA(columns) ||
      any(!nzchar(columns)) || anyDuplicated(columns)) {
    stop(sprintf("%s has an invalid expected schema.", label), call. = FALSE)
  }
  rows <- lapply(value, function(row) {
    row_names <- names(row)
    if (!is.list(row) || is.null(row_names) || anyDuplicated(row_names) ||
        !setequal(row_names, columns)) {
      stop(sprintf("%s has an invalid row schema.", label), call. = FALSE)
    }
    row <- row[columns]
    unname(vapply(row, function(cell) {
      if (is.null(cell) || is.list(cell) || length(cell) != 1L ||
          is.na(cell)) {
        stop(sprintf("%s has an invalid cell.", label), call. = FALSE)
      }
      enc2utf8(as.character(cell))
    }, character(1L)))
  })
  result <- as.data.frame(stats::setNames(
    lapply(seq_along(columns), function(index) {
      vapply(rows, `[[`, character(1L), index)
    }),
    columns
  ), stringsAsFactors = FALSE, check.names = FALSE)
  rownames(result) <- NULL
  result
}

wlv13_v5_source_provenance_expected <- function(context, source, arm) {
  run <- wlv13_run_inventory(context$run_root)
  if (!identical(run$root, context$run_root) ||
      !identical(run$identity$method, context$method)) {
    stop("Source provenance belongs to another sealed run.", call. = FALSE)
  }
  source_value <- run$manifest$result$provenance$source
  if (!is.list(source_value) || !identical(
      names(source_value),
      c("additional_inputs", "manifest", "summary")
    )) {
    stop("Sealed run source provenance has an invalid envelope.",
      call. = FALSE
    )
  }
  manifest <- wlv13_v5_json_rows(
    source_value$manifest,
    wlv13_source_manifest_columns,
    paste0(arm, " source manifest")
  )
  summary <- wlv13_v5_json_rows(
    source_value$summary,
    wlv13_v5_source_provenance_columns,
    paste0(arm, " source summary")
  )
  additional <- wlv13_v5_json_rows(
    source_value$additional_inputs,
    c("path", "sha256", "size_bytes"),
    paste0(arm, " additional source inputs"),
    allow_empty = TRUE
  )
  if (nrow(summary) != 1L || anyDuplicated(manifest$artifact) ||
      anyDuplicated(additional$path) || !identical(
        manifest$artifact,
        sort(manifest$artifact, method = "radix")
      ) || any(!grepl("^[0-9a-f]{64}$", c(
        manifest$sha256,
        additional$sha256,
        summary$source_generation_id,
        summary$contract_sha256,
        summary$manifest_sha256
      ))) || any(!grepl("^(0|[1-9][0-9]*)$", additional$size_bytes))) {
    stop("Sealed run source provenance is not canonical.", call. = FALSE)
  }

  source_root <- normalizePath(
    file.path(context$project_root, "source_data", source, "normalized"),
    winslash = "/",
    mustWork = TRUE
  )
  physical <- wlv13_source_inventory(source_root)
  if (!identical(physical$manifest, manifest)) {
    stop("Sealed source manifest differs from physical normalized data.",
      call. = FALSE
    )
  }
  preparation_path <- file.path(
    script_dir,
    "issue13-v5-preparation-equivalence.json"
  )
  preparation <- wlv13_v5p_manifest(preparation_path)
  profile_index <- match(source, vapply(
    preparation$profiles,
    `[[`,
    character(1L),
    "source"
  ))
  if (is.na(profile_index)) {
    stop("No sealed preparation profile exists for source provenance.",
      call. = FALSE
    )
  }
  profile <- preparation$profiles[[profile_index]]
  arm_profile <- profile[[arm]]
  manifest_profile <- wlv13_v5p_artifact_profile(
    profile,
    arm,
    "_source_manifest.csv"
  )
  manifest_binding <- wlv13_v5p_compare_artifact(
    physical$manifest_path,
    manifest,
    manifest_profile,
    paste(source, arm, "run-source-manifest", sep = "/")
  )
  if (!isTRUE(manifest_binding$passed)) {
    stop("Run source manifest differs from its exhaustive preparation profile.",
      call. = FALSE
    )
  }

  loaded <- wlv_gate_load_runtime(context$project_root)
  source_formals <- list(
    wlv_resolve_source_artifacts = c("plan", "method", "needs_io"),
    wlv_validate_method_source_manifest = c("plan", "method", "artifacts"),
    wlv_publication_source_input_inventory = c("root", "paths"),
    wlv_source_effective_manifest_sha256 = c("manifest", "additional_paths")
  )
  source_signatures_valid <- all(vapply(names(source_formals), function(name) {
    is.function(loaded$runtime[[name]]) && identical(
      names(formals(loaded$runtime[[name]])),
      source_formals[[name]]
    )
  }, logical(1L)))
  expected_plan_formals <- c(
    "methods", "repeat_pp", "papern", "prepaper", "workers", "channel",
    "mode", "at_stage", "sea_vars", "root", "allow_experimental",
    "requested_operations", "catalog"
  )
  if (!identical(loaded$kind, arm) || !source_signatures_valid ||
      !identical(
        names(formals(loaded$runtime$wlv_validate_request)),
        expected_plan_formals
      )) {
    stop("Source provenance loaded an incompatible engine.", call. = FALSE)
  }
  plan <- loaded$runtime$wlv_validate_request(
    methods = context$method,
    repeat_pp = FALSE,
    papern = 0L,
    prepaper = FALSE,
    workers = 1L,
    channel = "stable",
    mode = "calculate",
    at_stage = 1L,
    sea_vars = NULL,
    root = context$project_root,
    allow_experimental = TRUE,
    requested_operations = "calculate",
    catalog = NULL
  )
  if (!inherits(plan, "wlv_run_plan") ||
      !identical(
        normalizePath(plan$root, winslash = "/", mustWork = TRUE),
        context$project_root
      ) || !identical(plan$mode, "calculate") ||
      !identical(plan$requested_operations, "calculate") ||
      !identical(plan$method_names, context$method) ||
      !identical(plan$allow_experimental, TRUE) ||
      !is.data.frame(plan$methods) || nrow(plan$methods) != 1L) {
    stop("Source provenance reconstructed an unexpected run plan.",
      call. = FALSE
    )
  }
  expected_inputs <- if (identical(arm, "candidate")) {
    loaded$runtime$wlv_assert_plan_publication_inputs_unchanged(
      plan, context$method
    )
    loaded$runtime$wlv_plan_publication_input_inventory(plan, context$method)
  } else {
    first <- loaded$runtime$wlv_publication_input_inventory(
      plan, context$method
    )
    second <- loaded$runtime$wlv_publication_input_inventory(
      plan, context$method
    )
    if (!identical(first, second)) {
      stop("Baseline publication inputs changed during source validation.",
        call. = FALSE
      )
    }
    first
  }
  if (!identical(expected_inputs, context$inputs)) {
    stop("Source plan inputs differ from sealed run provenance.", call. = FALSE)
  }
  observed_source <- if (identical(arm, "candidate")) {
    plan$methods$source[[1L]]
  } else {
    plan$methods$parameter_set[[1L]]
  }
  if (!identical(observed_source, source)) {
    stop("Source plan differs from the sealed metadata profile.", call. = FALSE)
  }
  artifacts <- loaded$runtime$wlv_resolve_source_artifacts(
    plan, plan$methods, TRUE
  )
  validated_source <- loaded$runtime$wlv_validate_method_source_manifest(
    plan, plan$methods, artifacts
  )
  validated_root <- normalizePath(
    validated_source$normalized_root,
    winslash = "/",
    mustWork = TRUE
  )
  validated_manifest_path <- normalizePath(
    artifacts$manifest,
    winslash = "/",
    mustWork = TRUE
  )
  if (!identical(validated_root, source_root) ||
      !identical(validated_manifest_path, physical$manifest_path) ||
      !identical(validated_source$manifest, manifest)) {
    stop("Runtime source validation differs from the sealed physical source.",
      call. = FALSE
    )
  }

  relative <- vapply(
    additional$path,
    wlv13_safe_relative_path,
    character(1L),
    name = "additional source input path"
  )
  additional_paths <- normalizePath(
    file.path(context$project_root, relative),
    winslash = "/",
    mustWork = TRUE
  )
  if (any(!vapply(
      additional_paths,
      wlv13_is_within,
      logical(1L),
      parent = context$project_root
    ))) {
    stop("Additional source inputs escape the engine worktree.", call. = FALSE)
  }
  runtime_additional_raw <-
    loaded$runtime$wlv_publication_source_input_inventory(
      context$project_root,
      additional_paths
    )
  if (identical(arm, "baseline") && !identical(
      runtime_additional_raw,
      loaded$runtime$wlv_publication_source_input_inventory(
        context$project_root,
        additional_paths
      )
    )) {
    stop("Baseline source input inventory changed during validation.",
      call. = FALSE
    )
  }
  runtime_additional <- wlv13_v5_json_rows(
    runtime_additional_raw,
    c("path", "sha256", "size_bytes"),
    paste0(arm, " reconstructed additional source inputs"),
    allow_empty = TRUE
  )
  if (!identical(runtime_additional, additional)) {
    stop("Additional source inputs differ from their physical inventory.",
      call. = FALSE
    )
  }
  effective_sha256 <- loaded$runtime$wlv_source_effective_manifest_sha256(
    validated_source$manifest,
    additional_paths
  )
  if (identical(arm, "candidate")) {
    loaded$runtime$wlv_assert_plan_publication_inputs_unchanged(
      plan, context$method
    )
    loaded$runtime$wlv_assert_loaded_runtime_unchanged()
  }
  effective_sha256 <- unname(unclass(as.character(effective_sha256)))
  if (!is.character(effective_sha256) || length(effective_sha256) != 1L ||
      is.na(effective_sha256) || !grepl("^[0-9a-f]{64}$", effective_sha256)) {
    stop("Effective source manifest hash is invalid.", call. = FALSE)
  }
  expected <- data.frame(
    schema_version = "1",
    source = source,
    source_generation_id = arm_profile$source_generation_id,
    contract_id = arm_profile$contract_id,
    contract_version = arm_profile$contract_version,
    contract_sha256 = arm_profile$contract_sha256,
    manifest_sha256 = effective_sha256,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  rownames(expected) <- NULL
  if (!identical(summary, expected)) {
    stop("Run source summary differs from its authenticated inputs.",
      call. = FALSE
    )
  }
  list(
    expected = expected,
    preparation_profile_sha256 = wlv13_sha256_file(preparation_path),
    run_manifest_sha256 = run$manifest_sha256,
    source_manifest_sha256 = physical$manifest_sha256,
    additional_inputs = additional,
    additional_inputs_sha256 = unname(unclass(as.character(
      wlv13_v5p_table_sha256(additional)
    ))),
    additional_input_count = nrow(additional)
  )
}

wlv13_v5_compare_source_provenance <- function(left, right, name) {
  left_parsed <- wlv13_cross_engine_read(left, name)
  right_parsed <- wlv13_cross_engine_read(right, name)
  method <- basename(dirname(dirname(left$path)))
  if (!identical(method, basename(dirname(dirname(right$path))))) {
    stop("Cross-engine source provenance methods differ.", call. = FALSE)
  }
  metadata <- wlv13_v5_metadata_profile(
    method,
    "_method_assumptions.csv"
  )
  candidate_context <- wlv13_v5_metadata_context(left, "candidate", method)
  baseline_context <- wlv13_v5_metadata_context(right, "baseline", method)
  candidate <- wlv13_v5_source_provenance_expected(
    candidate_context,
    metadata$source,
    "candidate"
  )
  baseline <- wlv13_v5_source_provenance_expected(
    baseline_context,
    metadata$source,
    "baseline"
  )
  candidate_exact <- left_parsed$schema_valid && identical(
    left_parsed$value,
    candidate$expected
  )
  baseline_exact <- right_parsed$schema_valid && identical(
    right_parsed$value,
    baseline$expected
  )
  additional_inputs_exact <- identical(
    candidate$additional_inputs,
    baseline$additional_inputs
  ) && identical(
    candidate$additional_inputs_sha256,
    baseline$additional_inputs_sha256
  )
  preparation_profile_exact <- identical(
    candidate$preparation_profile_sha256,
    baseline$preparation_profile_sha256
  )
  passed <- candidate_exact && baseline_exact && additional_inputs_exact &&
    preparation_profile_exact
  list(
    summary = list(
      passed = passed,
      comparison_mode = "sealed-source-provenance-by-arm",
      method = method,
      source = metadata$source,
      candidate_schema_valid = left_parsed$schema_valid,
      baseline_schema_valid = right_parsed$schema_valid,
      candidate_exact = candidate_exact,
      baseline_exact = baseline_exact,
      candidate_run_manifest_sha256 = candidate$run_manifest_sha256,
      baseline_run_manifest_sha256 = baseline$run_manifest_sha256,
      candidate_source_manifest_sha256 = candidate$source_manifest_sha256,
      baseline_source_manifest_sha256 = baseline$source_manifest_sha256,
      preparation_profile_sha256 = candidate$preparation_profile_sha256,
      preparation_profile_exact = preparation_profile_exact,
      candidate_additional_inputs_sha256 =
        candidate$additional_inputs_sha256,
      baseline_additional_inputs_sha256 = baseline$additional_inputs_sha256,
      additional_inputs_exact = additional_inputs_exact,
      candidate_additional_input_count = candidate$additional_input_count,
      baseline_additional_input_count = baseline$additional_input_count,
      raw_semantic_equal = identical(
        left_parsed$value,
        right_parsed$value
      ),
      architecture_difference = TRUE
    ),
    transitions = data.frame(),
    indicators = data.frame()
  )
}

wlv13_v5_compare_metadata <- function(left, right, name) {
  left_parsed <- wlv13_cross_engine_read(left, name)
  right_parsed <- wlv13_cross_engine_read(right, name)
  candidate <- left_parsed$value
  baseline <- right_parsed$value
  method <- basename(dirname(dirname(left$path)))
  if (!identical(method, basename(dirname(dirname(right$path))))) {
    stop("Cross-engine metadata methods differ.", call. = FALSE)
  }
  profile <- wlv13_v5_metadata_profile(method, name)
  candidate_expected <- wlv13_v5_metadata_table(
    profile$artifact$candidate, name, "candidate"
  )
  baseline_expected <- wlv13_v5_metadata_table(
    profile$artifact$baseline, name, "baseline"
  )
  candidate_context <- wlv13_v5_metadata_context(left, "candidate", method)
  baseline_context <- wlv13_v5_metadata_context(right, "baseline", method)
  candidate_reconstructed <- wlv13_v5_reconstructed_metadata(
    candidate_context, profile
  )[[name]]
  baseline_reconstructed <- wlv13_v5_reconstructed_metadata(
    baseline_context, profile
  )[[name]]
  candidate_manifest_exact <- left_parsed$schema_valid &&
    wlv13_v5_exact_metadata_equal(candidate, candidate_expected)
  baseline_manifest_exact <- right_parsed$schema_valid &&
    wlv13_v5_exact_metadata_equal(baseline, baseline_expected)
  candidate_engine_exact <- wlv13_v5_exact_metadata_equal(
    candidate_reconstructed, candidate_expected
  )
  baseline_engine_exact <- wlv13_v5_exact_metadata_equal(
    baseline_reconstructed, baseline_expected
  )
  valid <- candidate_manifest_exact && baseline_manifest_exact &&
    candidate_engine_exact && baseline_engine_exact
  list(
    summary = list(
      passed = valid,
      comparison_mode = "sealed-exhaustive-engine-reconstruction",
      manifest_schema = profile$manifest$schema,
      method = method,
      source = profile$source,
      partition = profile$partition,
      candidate_schema_valid = left_parsed$schema_valid,
      baseline_schema_valid = right_parsed$schema_valid,
      candidate_rows = nrow(candidate),
      baseline_rows = nrow(baseline),
      candidate_manifest_exact = candidate_manifest_exact,
      baseline_manifest_exact = baseline_manifest_exact,
      candidate_engine_exact = candidate_engine_exact,
      baseline_engine_exact = baseline_engine_exact,
      raw_semantic_equal = identical(candidate, baseline),
      architecture_difference = !identical(candidate, baseline)
    ),
    transitions = data.frame(),
    indicators = data.frame()
  )
}

wlv13_cross_engine_compare_config <- function(left, right, name) {
  if (identical(name, "_source_provenance.csv")) {
    return(wlv13_v5_compare_source_provenance(left, right, name))
  }
  if (name %in% wlv13_v5_metadata_artifacts) {
    return(wlv13_v5_compare_metadata(left, right, name))
  }
  wlv13_v5_original_compare_config(left, right, name)
}

wlv13_v5_metadata_selftest <- function() {
  manifest <- wlv13_v5_metadata_manifest()
  assertions <- 0L
  assert_false <- function(value, label) {
    if (isTRUE(value)) {
      stop(sprintf("Exhaustive metadata self-test accepted `%s`.", label),
        call. = FALSE
      )
    }
    assertions <<- assertions + 1L
  }
  assert_true <- function(value, label) {
    if (!isTRUE(value)) {
      stop(sprintf("Exhaustive metadata self-test rejected `%s`.", label),
        call. = FALSE
      )
    }
    assertions <<- assertions + 1L
  }
  assert_error <- function(expression, label) {
    rejected <- tryCatch({
      force(expression)
      FALSE
    }, error = function(error) TRUE)
    if (!rejected) {
      stop(sprintf("Exhaustive metadata self-test accepted `%s`.", label),
        call. = FALSE
      )
    }
    assertions <<- assertions + 1L
  }

  expected_generation <-
    manifest$candidate_runtime_generation_sha256
  valid_runtime <- list(
    wlv_runtime_snapshot_read_envelope = function(
        result_dir, method, source, partitions, expected_sha256) NULL,
    wlv_runtime_snapshot_version = function() {
      "wlv-runtime-resources/1.1.0"
    },
    wlv_runtime_snapshot_authenticate_bound_files = function(
        snapshot, root, validate_snapshot = TRUE) NULL,
    .wlv_runtime_compatibility_generation = function() expected_generation
  )
  valid_interface <- wlv13_v5_runtime_snapshot_interface(
    valid_runtime, expected_generation
  )
  assert_true(
    identical(valid_interface$snapshot_version,
      "wlv-runtime-resources/1.1.0") &&
      identical(valid_interface$runtime_generation, expected_generation),
    "runtime-snapshot-interface"
  )
  classed_runtime <- valid_runtime
  classed_runtime$.wlv_runtime_compatibility_generation <- function() {
    structure(expected_generation, class = c("hash", "sha256"))
  }
  assert_true(
    identical(
      wlv13_v5_runtime_snapshot_interface(
        classed_runtime, expected_generation
      )$runtime_generation,
      expected_generation
    ),
    "classed-runtime-generation-normalization"
  )
  old_version <- valid_runtime
  old_version$wlv_runtime_snapshot_version <- function() {
    "wlv-runtime-resources/1.0.0"
  }
  assert_error(
    wlv13_v5_runtime_snapshot_interface(old_version, expected_generation),
    "old-runtime-snapshot-version"
  )
  version_argument <- valid_runtime
  version_argument$wlv_runtime_snapshot_version <- function(unused) {
    "wlv-runtime-resources/1.1.0"
  }
  assert_error(
    wlv13_v5_runtime_snapshot_interface(version_argument, expected_generation),
    "runtime-snapshot-version-argument"
  )
  reader_signature <- valid_runtime
  reader_signature$wlv_runtime_snapshot_read_envelope <- function(
      result_dir, method, source, partitions) NULL
  assert_error(
    wlv13_v5_runtime_snapshot_interface(reader_signature, expected_generation),
    "runtime-snapshot-reader-signature"
  )
  old_authenticator <- valid_runtime
  old_authenticator$wlv_runtime_snapshot_authenticate_bound_files <- function(
      snapshot, root) NULL
  assert_error(
    wlv13_v5_runtime_snapshot_interface(old_authenticator, expected_generation),
    "runtime-snapshot-authenticator-signature"
  )
  false_authenticator <- valid_runtime
  false_authenticator$wlv_runtime_snapshot_authenticate_bound_files <- function(
      snapshot, root, validate_snapshot = FALSE) NULL
  assert_error(
    wlv13_v5_runtime_snapshot_interface(
      false_authenticator, expected_generation
    ),
    "runtime-snapshot-authenticator-default"
  )
  wrong_generation <- valid_runtime
  wrong_generation$.wlv_runtime_compatibility_generation <- function() {
    paste(rep("0", 64L), collapse = "")
  }
  assert_error(
    wlv13_v5_runtime_snapshot_interface(
      wrong_generation, expected_generation
    ),
    "runtime-snapshot-generation-mismatch"
  )

  source_columns <- wlv13_v5_source_provenance_columns
  source_row <- stats::setNames(as.list(c(
    "1", "wiodr13", paste(rep("1", 64L), collapse = ""),
    "wiodr13_units_v2", "2", paste(rep("2", 64L), collapse = ""),
    paste(rep("3", 64L), collapse = "")
  )), source_columns)
  expected_source_row <- as.data.frame(source_row,
    stringsAsFactors = FALSE, check.names = FALSE
  )
  rownames(expected_source_row) <- NULL
  reordered_source_row <- source_row[rev(source_columns)]
  assert_true(
    identical(
      wlv13_v5_json_rows(
        list(reordered_source_row), source_columns, "reordered source row"
      ),
      expected_source_row
    ),
    "source-provenance-json-key-order"
  )
  assert_true(
    identical(
      wlv13_cross_engine_schema("_source_provenance.csv"),
      source_columns
    ),
    "source-provenance-schema-dispatch"
  )
  assert_true(
    identical(
      wlv13_cross_engine_schema("_method_assumptions.csv"),
      c("names", "computation", "order")
    ),
    "legacy-schema-dispatch"
  )
  missing_source_cell <- reordered_source_row[-1L]
  assert_error(
    wlv13_v5_json_rows(
      list(missing_source_cell), source_columns, "missing source cell"
    ),
    "source-provenance-missing-cell"
  )
  extra_source_cell <- c(reordered_source_row, unexpected = "value")
  assert_error(
    wlv13_v5_json_rows(
      list(extra_source_cell), source_columns, "extra source cell"
    ),
    "source-provenance-extra-cell"
  )
  duplicate_source_cell <- reordered_source_row
  names(duplicate_source_cell)[[2L]] <- names(duplicate_source_cell)[[1L]]
  assert_error(
    wlv13_v5_json_rows(
      list(duplicate_source_cell), source_columns, "duplicate source cell"
    ),
    "source-provenance-duplicate-cell"
  )
  list_source_cell <- reordered_source_row
  list_source_cell$source <- list("wiodr13")
  assert_error(
    wlv13_v5_json_rows(
      list(list_source_cell), source_columns, "list source cell"
    ),
    "source-provenance-list-cell"
  )
  assert_error(
    wlv13_v5_json_rows(list(), source_columns, "empty source rows"),
    "source-provenance-empty-required"
  )
  empty_source_rows <- wlv13_v5_json_rows(
    list(), source_columns, "empty optional source rows", allow_empty = TRUE
  )
  assert_true(
    is.data.frame(empty_source_rows) && !nrow(empty_source_rows) &&
      identical(names(empty_source_rows), source_columns),
    "source-provenance-empty-optional"
  )
  additional_inputs <- data.frame(
    path = "contracts/units/wiodr13_v2-units.csv",
    sha256 = paste(rep("4", 64L), collapse = ""),
    size_bytes = "1",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  mutated_additional_path <- additional_inputs
  mutated_additional_path$path[[1L]] <-
    "contracts/units/wiodr16_v2-units.csv"
  assert_false(
    wlv13_v5_exact_metadata_equal(
      mutated_additional_path, additional_inputs
    ),
    "source-additional-input-path"
  )
  mutated_additional_hash <- additional_inputs
  mutated_additional_hash$sha256[[1L]] <-
    paste(rep("5", 64L), collapse = "")
  assert_false(
    wlv13_v5_exact_metadata_equal(
      mutated_additional_hash, additional_inputs
    ),
    "source-additional-input-hash"
  )
  for (profile in manifest$profiles) {
    for (artifact in profile$artifacts) {
      for (arm in c("baseline", "candidate")) {
        expected <- wlv13_v5_metadata_table(
          artifact[[arm]], artifact$artifact, arm
        )
        if (!wlv13_v5_exact_metadata_equal(expected, expected)) {
          stop("Exhaustive metadata self-test rejected its sealed table.",
            call. = FALSE
          )
        }
        assertions <- assertions + 1L
        if (nrow(expected)) {
          for (column in names(expected)) {
            mutated <- expected
            mutated[[column]][[1L]] <- paste0(mutated[[column]][[1L]], "#mutation")
            assert_false(
              wlv13_v5_exact_metadata_equal(mutated, expected),
              paste(profile$method, artifact$artifact, arm, column)
            )
          }
          removed <- expected[-1L, , drop = FALSE]
          rownames(removed) <- NULL
          assert_false(wlv13_v5_exact_metadata_equal(removed, expected),
            paste(profile$method, artifact$artifact, arm, "missing-row")
          )
          added <- rbind(expected, expected[1L, , drop = FALSE])
          rownames(added) <- NULL
          assert_false(wlv13_v5_exact_metadata_equal(added, expected),
            paste(profile$method, artifact$artifact, arm, "duplicate-row")
          )
          extra <- expected[1L, , drop = FALSE]
          extra[[1L]][[1L]] <- paste0(extra[[1L]][[1L]], "#extra")
          extra <- rbind(expected, extra)
          rownames(extra) <- NULL
          assert_false(wlv13_v5_exact_metadata_equal(extra, expected),
            paste(profile$method, artifact$artifact, arm, "extra-row")
          )
          if (nrow(expected) > 1L) {
            tail_rows <- if (nrow(expected) > 2L) {
              seq.int(3L, nrow(expected))
            } else {
              integer()
            }
            reordered <- expected[c(2L, 1L, tail_rows), ,
              drop = FALSE
            ]
            rownames(reordered) <- NULL
            assert_false(wlv13_v5_exact_metadata_equal(reordered, expected),
              paste(profile$method, artifact$artifact, arm, "row-order")
            )
          }
        }
      }
    }
  }
  solution_profiles <- lapply(manifest$profiles, function(profile) {
    artifact <- profile$artifacts[[match(
      "_method_solutions.csv",
      vapply(profile$artifacts, `[[`, character(1L), "artifact")
    )]]
    list(method = profile$method, artifact = artifact)
  })
  custom_tested <- FALSE
  for (profile in solution_profiles) {
    for (arm in c("baseline", "candidate")) {
      expected <- wlv13_v5_metadata_table(
        profile$artifact[[arm]], "_method_solutions.csv", arm
      )
      custom <- which(!expected$country_solution %in% c(
        "", "sum", "mean", "weighted_mean", "ratio_of_sums", "not_applicable"
      ))
      if (length(custom)) {
        mutated <- expected
        mutated$country_solution[[custom[[1L]]]] <- "aggregation.changed_formula"
        assert_false(wlv13_v5_exact_metadata_equal(mutated, expected),
          paste(profile$method, arm, "custom-formula")
        )
        custom_tested <- TRUE
        break
      }
    }
    if (custom_tested) break
  }
  if (!custom_tested) {
    stop("Exhaustive metadata self-test found no custom formula row.",
      call. = FALSE
    )
  }
  assumptions <- lapply(manifest$profiles, function(profile) {
    artifact <- profile$artifacts[[match(
      "_method_assumptions.csv",
      vapply(profile$artifacts, `[[`, character(1L), "artifact")
    )]]
    wlv13_v5_metadata_table(
      artifact$candidate, "_method_assumptions.csv", "candidate"
    )
  })
  different <- NULL
  for (left_index in seq_along(assumptions)) {
    for (right_index in seq_along(assumptions)) {
      if (!identical(assumptions[[left_index]], assumptions[[right_index]])) {
        different <- c(left_index, right_index)
        break
      }
    }
    if (!is.null(different)) break
  }
  if (is.null(different)) {
    stop("Exhaustive metadata self-test cannot exercise method swapping.",
      call. = FALSE
    )
  }
  assert_false(
    wlv13_v5_exact_metadata_equal(
      assumptions[[different[[1L]]]], assumptions[[different[[2L]]]]
    ),
    "method-swap"
  )
  invisible(assertions)
}
