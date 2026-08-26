# V5 cross-engine allowance for the candidate's authenticated runtime sidecar.
#
# The sidecar has no legacy equivalent. It is accepted only after the
# candidate runtime itself validates its complete envelope, artifact hashes,
# semantic-state coordinates and state-binding hashes against the immutable run.

wlv13_v5_original_validate_nonfinite <-
  wlv13_cross_engine_validate_nonfinite
wlv13_v5_original_compare_config <- wlv13_cross_engine_compare_config

wlv13_cross_engine_run_rules <- function() {
  list(
    normalized = c(
      "file:_anomalies.csv",
      "file:_method_assumptions.csv",
      "file:_method_matrices.csv",
      "file:_method_solutions.csv",
      "file:_scientific_checks.csv",
      "file:_unit_contract.csv"
    ),
    candidate_only = c(
      "file:_nonfinite_resolution_diagnostics.csv",
      "file:_runtime_resources.rds"
    )
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
    expected_formals <- c(
      "result_dir", "method", "source", "partitions", "expected_sha256"
    )
    if (!identical(
        names(formals(loaded$runtime$wlv_runtime_snapshot_read_envelope)),
        expected_formals
    )) {
      stop("Runtime snapshot envelope reader signature changed.", call. = FALSE)
    }
    snapshot <- loaded$runtime$wlv_runtime_snapshot_read_envelope(
      context$run_root,
      method = method,
      source = profile$source,
      partitions = profile$partition,
      expected_sha256 = descriptor$sha256
    )
    bound_artifacts <-
      loaded$runtime$wlv_runtime_snapshot_authenticate_bound_files(
        snapshot, context$run_root
      )
    if (!is.list(bound_artifacts) || !length(bound_artifacts) ||
        anyDuplicated(names(bound_artifacts))) {
      stop("Runtime snapshot bound-artifact proof is incomplete.",
        call. = FALSE
      )
    }
    loaded$runtime$wlv_assert_loaded_runtime_unchanged()
    if (!identical(snapshot$version, "wlv-runtime-resources/1.0.0") ||
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
      "a70cef8ef7ec19b329dd60cc2a10f49bf0c9533b"
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
    generation <- loaded$runtime$.wlv_runtime_compatibility_generation()
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
