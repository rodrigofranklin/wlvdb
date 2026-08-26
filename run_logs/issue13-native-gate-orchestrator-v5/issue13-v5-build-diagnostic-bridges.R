# Build the closed diagnostic-module bridge manifest from authenticated
# calculate evidence.  The generated manifest is data, not an inference rule:
# every changed owner is bound to one method, artifact context, evidence run,
# request, commit, artifact hash and exact evidence row count.

wlv13_v5d_bridge_empty_row <- function() {
  as.data.frame(stats::setNames(
    as.list(rep("", length(wlv13_v5d_bridge_columns))),
    wlv13_v5d_bridge_columns
  ), stringsAsFactors = FALSE, check.names = FALSE)
}

wlv13_v5d_json_rows <- function(value, columns, label) {
  if (!is.list(value) || !length(value)) {
    stop(sprintf("%s is empty.", label), call. = FALSE)
  }
  rows <- lapply(value, function(row) {
    if (!is.list(row) || !setequal(names(row), columns)) {
      stop(sprintf("%s has an invalid schema.", label), call. = FALSE)
    }
    as.data.frame(stats::setNames(lapply(columns, function(column) {
      field <- row[[column]]
      if (is.null(field) || length(field) != 1L || is.na(field)) {
        stop(sprintf("%s contains an invalid field.", label),
          call. = FALSE
        )
      }
      enc2utf8(as.character(field))
    }), columns), stringsAsFactors = FALSE, check.names = FALSE)
  })
  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result
}

wlv13_v5d_source_table_payload <- function(value, columns, domain) {
  if (!is.data.frame(value) || !identical(names(value), columns) ||
      any(!vapply(value, is.character, logical(1L)))) {
    stop(sprintf("Invalid %s source table.", domain), call. = FALSE)
  }
  fields <- c(
    domain, as.character(length(columns)), columns, as.character(nrow(value)),
    unlist(lapply(seq_len(nrow(value)), function(index) {
      as.character(value[index, columns, drop = TRUE])
    }), use.names = FALSE)
  )
  charToRaw(enc2utf8(paste0(vapply(fields, function(field) {
    field <- enc2utf8(as.character(field))
    paste0(nchar(field, type = "bytes"), ":", field)
  }, character(1L)), collapse = "")))
}

wlv13_v5d_authenticate_source <- function(project_root, provenance) {
  source_value <- provenance$source
  manifest_columns <- wlv13_source_manifest_columns
  summary_columns <- c(
    "schema_version", "source", "source_generation_id", "contract_id",
    "contract_version", "contract_sha256", "manifest_sha256"
  )
  additional_columns <- c("path", "sha256", "size_bytes")
  if (!is.list(source_value)) {
    stop("Bridge evidence lacks source provenance.", call. = FALSE)
  }
  manifest <- wlv13_v5d_json_rows(
    source_value$manifest, manifest_columns,
    "Bridge evidence source manifest"
  )
  summary <- wlv13_v5d_json_rows(
    source_value$summary, summary_columns,
    "Bridge evidence source summary"
  )
  additional <- wlv13_v5d_json_rows(
    source_value$additional_inputs, additional_columns,
    "Bridge evidence additional source inputs"
  )
  if (nrow(summary) != 1L || anyDuplicated(manifest$artifact) ||
      anyDuplicated(additional$path) ||
      !identical(order(manifest$artifact, method = "radix"),
        seq_len(nrow(manifest))) ||
      any(!grepl("^[0-9a-f]{64}$", c(
        manifest$sha256, additional$sha256, summary$contract_sha256,
        summary$manifest_sha256
      )))) {
    stop("Bridge evidence source provenance is not canonical.",
      call. = FALSE
    )
  }
  source_root <- file.path(
    project_root, "source_data", summary$source[[1L]], "normalized"
  )
  inventory <- wlv13_source_inventory(source_root)
  if (!identical(inventory$manifest, manifest)) {
    stop("Bridge evidence source manifest differs from physical data.",
      call. = FALSE
    )
  }
  generation_payload <- manifest[setdiff(
    manifest_columns, "source_generation_id"
  )]
  generation_sha256 <- wlv13_sha256_raw(wlv13_v5d_source_table_payload(
    generation_payload, names(generation_payload),
    "wlv-source-generation-v1"
  ))
  manifest_sha256 <- wlv13_sha256_raw(wlv13_v5d_source_table_payload(
    manifest, manifest_columns, "wlv-source-manifest-v1"
  ))
  parsed_sizes <- suppressWarnings(as.numeric(additional$size_bytes))
  additional_paths <- vapply(additional$path, function(relative) {
    relative <- wlv13_v5d_scalar(
      relative, "additional source input path"
    )
    if (grepl("^([A-Za-z]:|[/\\\\])", relative) ||
        grepl("(^|[/\\\\])[.][.]($|[/\\\\])", relative)) {
      stop("Unsafe additional source input path.", call. = FALSE)
    }
    normalizePath(file.path(project_root, relative),
      winslash = "/", mustWork = TRUE
    )
  }, character(1L))
  physical_valid <- !anyNA(parsed_sizes) &&
    identical(as.character(parsed_sizes), additional$size_bytes) &&
    all(vapply(seq_along(additional_paths), function(index) {
      path <- additional_paths[[index]]
      !isTRUE(file.info(path)$isdir) &&
        identical(as.numeric(file.info(path)$size), parsed_sizes[[index]]) &&
        identical(wlv13_sha256_file(path), additional$sha256[[index]])
    }, logical(1L)))
  labels <- basename(additional_paths)
  if (anyDuplicated(labels)) labels <- additional_paths
  effective <- data.frame(
    input = c("source_manifest", labels),
    sha256 = c(manifest_sha256, additional$sha256),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  effective <- effective[order(effective$input, method = "radix"), ,
    drop = FALSE
  ]
  row.names(effective) <- NULL
  effective_sha256 <- wlv13_sha256_raw(wlv13_v5d_source_table_payload(
    effective, names(effective), "wlv-effective-source-provenance-v1"
  ))
  identity_valid <- physical_valid &&
    identical(generation_sha256, unique(manifest$source_generation_id)) &&
    identical(summary$schema_version[[1L]], "1") &&
    identical(summary$source_generation_id[[1L]],
      unique(manifest$source_generation_id)) &&
    identical(summary$contract_id[[1L]], unique(manifest$contract_id)) &&
    identical(summary$contract_version[[1L]],
      unique(manifest$contract_version)) &&
    identical(summary$contract_sha256[[1L]],
      unique(manifest$contract_sha256)) &&
    identical(summary$manifest_sha256[[1L]], effective_sha256)
  if (!identity_valid) {
    stop("Bridge evidence source provenance failed physical authentication.",
      call. = FALSE
    )
  }
  records <- c(
    vapply(seq_len(nrow(summary)), function(index) {
      wlv13_v5d_length_record(wlv13_v5d_raw_row_keys(summary[index, ]))
    }, character(1L)),
    vapply(seq_len(nrow(manifest)), function(index) {
      wlv13_v5d_length_record(wlv13_v5d_raw_row_keys(manifest[index, ]))
    }, character(1L)),
    vapply(seq_len(nrow(additional)), function(index) {
      wlv13_v5d_length_record(wlv13_v5d_raw_row_keys(additional[index, ]))
    }, character(1L))
  )
  wlv13_v5d_sha256_text(paste(records, collapse = "\n"))
}

wlv13_v5d_bridge_authenticate_run <- function(
    project_root, run_root, method, expected_mode = "calculate") {
  if (!expected_mode %in% c("calculate", "recalculate")) {
    stop("Invalid bridge evidence run mode.", call. = FALSE)
  }
  project_root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  run_root <- normalizePath(run_root, winslash = "/", mustWork = TRUE)
  expected_prefix <- normalizePath(file.path(
    project_root, "results", "runs", method
  ), winslash = "/", mustWork = TRUE)
  if (!wlv13_is_within(run_root, expected_prefix) ||
      !identical(dirname(run_root), expected_prefix)) {
    stop("Bridge evidence run is not a direct canonical method run.",
      call. = FALSE
    )
  }
  git_value <- function(arguments, label) {
    value <- tryCatch(system2(
      "git", c("-C", shQuote(project_root), arguments),
      stdout = TRUE, stderr = FALSE
    ), error = function(error) structure(character(), status = 1L))
    status <- attr(value, "status")
    if ((!is.null(status) && status != 0L) || length(value) != 1L ||
        !nzchar(value[[1L]])) {
      stop(sprintf("Cannot authenticate bridge evidence %s.", label),
        call. = FALSE
      )
    }
    enc2utf8(value[[1L]])
  }
  inventory <- wlv13_run_inventory(run_root)
  manifest <- inventory$manifest
  provenance <- if (is.list(manifest$result)) {
    manifest$result$provenance
  } else {
    NULL
  }
  inputs <- if (is.list(provenance)) provenance$inputs else NULL
  evidence_tree <- if (is.list(provenance) && is.list(provenance$git) &&
      is.character(provenance$git$commit) &&
      length(provenance$git$commit) == 1L &&
      grepl("^[0-9a-f]{40}$", provenance$git$commit)) {
    git_value(c(
      "rev-parse", shQuote(paste0(provenance$git$commit, "^{tree}"))
    ), "tree")
  } else {
    ""
  }
  valid <- identical(manifest$method, method) &&
    identical(manifest$run_id, basename(run_root)) &&
    ((identical(expected_mode, "calculate") &&
        is.null(manifest$parent_run_id)) ||
      (identical(expected_mode, "recalculate") &&
        is.character(manifest$parent_run_id) &&
        length(manifest$parent_run_id) == 1L &&
        grepl("^run-[0-9A-Za-z-]+$", manifest$parent_run_id))) &&
    is.list(provenance) && isTRUE(provenance$complete) &&
    is.list(provenance$git) &&
    is.character(provenance$git$commit) &&
    length(provenance$git$commit) == 1L &&
    grepl("^[0-9a-f]{40}$", provenance$git$commit) &&
    grepl("^[0-9a-f]{40}$", evidence_tree) &&
    identical(provenance$git$dirty, FALSE) &&
    is.list(inputs) && length(inputs) > 0L
  input_error <- ""
  input_records <- if (valid) tryCatch(vapply(inputs, function(input) {
    relative <- wlv13_v5d_scalar(input$path, "bridge evidence input path")
    expected_sha256 <- wlv13_v5d_scalar(
      input$sha256, "bridge evidence input hash", "^[0-9a-f]{64}$"
    )
    if (grepl("^([A-Za-z]:|[/\\\\])", relative) ||
        grepl("(^|[/\\\\])[.][.]($|[/\\\\])", relative)) {
      stop("Unsafe bridge evidence input path.", call. = FALSE)
    }
    blob_path <- tempfile("wlv13-v5d-blob-")
    status <- tryCatch(system2(
      "git",
      c(
        "-C", shQuote(project_root), "cat-file", "--filters",
        shQuote(paste0("--path=", relative)),
        shQuote(paste0(provenance$git$commit, ":", relative))
      ),
      stdout = blob_path, stderr = FALSE
    ), error = function(error) 1L)
    blob_valid <- identical(as.integer(status), 0L) &&
      file.exists(blob_path) &&
      identical(wlv13_sha256_file(blob_path), expected_sha256)
    unlink(blob_path, force = TRUE)
    if (!blob_valid) {
      stop(sprintf(
        "Bridge evidence provenance input `%s` differs from its commit.",
        relative
      ), call. = FALSE)
    }
    wlv13_v5d_length_record(relative, expected_sha256)
  }, character(1L)), error = function(error) {
    input_error <<- conditionMessage(error)
    character()
  }) else character()
  if (!valid || length(input_records) != length(inputs) ||
      anyDuplicated(input_records)) {
    stop(sprintf(
      "Bridge evidence run is not authenticated%s.",
      if (nzchar(input_error)) paste0(": ", input_error) else ""
    ), call. = FALSE)
  }
  source_sha256 <- wlv13_v5d_authenticate_source(project_root, provenance)
  context <- list(
    arm = "evidence", project_root = project_root,
    expected_commit = provenance$git$commit,
    observed_commit = provenance$git$commit, method = method,
    run_root = run_root
  )
  execution <- wlv13_v5d_run_request(context)
  if (!identical(execution$mode, expected_mode)) {
    stop(sprintf("Bridge evidence must be a %s run.", expected_mode),
      call. = FALSE
    )
  }
  artifact <- function(relative, required = TRUE) {
    row <- inventory$records[
      inventory$records$path == relative, , drop = FALSE
    ]
    if (nrow(row) != as.integer(required)) {
      stop(sprintf("Bridge evidence artifact `%s` has invalid presence.",
        relative
      ), call. = FALSE)
    }
    if (!nrow(row)) return(NULL)
    list(
      path = normalizePath(file.path(run_root, relative),
        winslash = "/", mustWork = TRUE
      ),
      sha256 = row$sha256[[1L]]
    )
  }
  list(
    project_root = project_root,
    run_root = run_root,
    run_id = manifest$run_id,
    parent_run_id = manifest$parent_run_id,
    commit = provenance$git$commit,
    tree = evidence_tree,
    context = context,
    execution = execution,
    source_sha256 = source_sha256,
    run_manifest_sha256 = inventory$manifest_sha256,
    run_inventory_sha256 = wlv13_inventory_signature(inventory),
    anomalies = artifact("_anomalies.csv"),
    unit = artifact("_unit_contract.csv"),
    nonfinite = artifact(
      "_nonfinite_resolution_diagnostics.csv", required = FALSE
    )
  )
}

wlv13_v5d_bridge_common_fields <- function(
    row, artifact_name, method, source, baseline, candidate,
    baseline_sha256, candidate_sha256, baseline_rows, candidate_rows) {
  row$schema_version <- wlv13_v5d_bridge_schema
  row$artifact_name <- artifact_name
  row$method <- method
  row$source <- source
  row$evidence_baseline_run_id <- baseline$run_id
  row$evidence_baseline_artifact_sha256 <- baseline_sha256
  row$evidence_baseline_request_sha256 <-
    baseline$execution$request_sha256
  row$evidence_baseline_source_sha256 <- baseline$source_sha256
  row$evidence_baseline_commit <- baseline$commit
  row$evidence_baseline_tree <- baseline$tree
  row$evidence_candidate_run_id <- candidate$run_id
  row$evidence_candidate_artifact_sha256 <- candidate_sha256
  row$evidence_candidate_request_sha256 <-
    candidate$execution$request_sha256
  row$evidence_candidate_source_sha256 <- candidate$source_sha256
  row$evidence_candidate_commit <- candidate$commit
  row$evidence_candidate_tree <- candidate$tree
  row$expected_baseline_evidence_rows <- as.character(baseline_rows)
  row$expected_candidate_evidence_rows <- as.character(candidate_rows)
  row$derivation_sha256 <- wlv13_v5d_bridge_derivation(row)
  row$bridge_id <- paste0(
    "bridge-", substr(row$derivation_sha256, 1L, 24L)
  )
  row
}

wlv13_v5d_derive_unit_bridges <- function(
    method, source, baseline, candidate) {
  columns <- wlv13_cross_engine_schema("_unit_contract.csv")
  baseline_value <- wlv13_v5d_normalize_table(
    wlv13_read_csv_semantic(baseline$unit$path), columns,
    "Baseline bridge unit evidence"
  )
  candidate_value <- wlv13_v5d_normalize_table(
    wlv13_read_csv_semantic(candidate$unit$path), columns,
    "Candidate bridge unit evidence"
  )
  nonmodule <- setdiff(columns, "module")
  if (!identical(baseline_value[nonmodule], candidate_value[nonmodule]) ||
      !all(baseline_value$source == source) ||
      !all(candidate_value$source == source)) {
    stop("Unit bridge evidence differs outside the module field.",
      call. = FALSE
    )
  }
  changed <- baseline_value$module != candidate_value$module
  if (!any(changed) || any(!nzchar(baseline_value$module[changed])) ||
      any(!nzchar(candidate_value$module[changed]))) {
    stop("Unit bridge evidence has invalid changed module rows.",
      call. = FALSE
    )
  }
  changed_value <- data.frame(
    source = baseline_value$source[changed],
    indicator = baseline_value$indicator[changed],
    strategy = baseline_value$strategy[changed],
    level = baseline_value$level[changed],
    baseline_module = baseline_value$module[changed],
    candidate_module = candidate_value$module[changed],
    stringsAsFactors = FALSE, check.names = FALSE
  )
  pair_columns <- setdiff(names(changed_value), "level")
  pair_key <- wlv13_v5d_raw_row_keys(changed_value[pair_columns])
  groups <- split(seq_len(nrow(changed_value)), pair_key)
  rows <- lapply(groups, function(index) {
    levels <- sort(unique(changed_value$level[index]), method = "radix")
    if (!identical(levels, sort(c(
        "country_to_world", "sector_to_country"
      ), method = "radix"))) {
      stop("A unit bridge does not cover its two exact aggregation levels.",
        call. = FALSE
      )
    }
    first <- index[[1L]]
    row <- wlv13_v5d_bridge_empty_row()
    row$indicator <- changed_value$indicator[[first]]
    row$strategy <- changed_value$strategy[[first]]
    row$baseline_module <- changed_value$baseline_module[[first]]
    row$candidate_module <- changed_value$candidate_module[[first]]
    wlv13_v5d_bridge_common_fields(
      row, "_unit_contract.csv", method, source, baseline, candidate,
      baseline$unit$sha256, candidate$unit$sha256,
      length(index), length(index)
    )
  })
  do.call(rbind, rows)
}

wlv13_v5d_derive_anomaly_bridges <- function(
    method, profile, baseline, candidate) {
  columns <- wlv13_cross_engine_schema("_anomalies.csv")
  baseline_value <- wlv13_v5d_normalize_table(
    wlv13_read_csv_semantic(baseline$anomalies$path), columns,
    "Baseline bridge anomaly evidence"
  )
  candidate_value <- wlv13_v5d_normalize_table(
    wlv13_read_csv_semantic(candidate$anomalies$path), columns,
    "Candidate bridge anomaly evidence"
  )
  resolution <- if (profile$expected_count > 0L) {
    if (is.null(candidate$nonfinite)) {
      stop("Candidate bridge evidence lacks non-finite diagnostics.",
        call. = FALSE
      )
    }
    diagnostic <- wlv13_v5d_normalize_table(
      wlv13_read_csv_semantic(candidate$nonfinite$path),
      wlv13_cross_engine_schema("_nonfinite_resolution_diagnostics.csv"),
      "Candidate bridge non-finite evidence"
    )
    wlv13_v5d_validate_nonfinite_value(
      diagnostic, method, profile, candidate_value
    )
  } else {
    list(
      passed = is.null(candidate$nonfinite),
      resolution_mask = rep(FALSE, nrow(candidate_value))
    )
  }
  if (!isTRUE(resolution$passed)) {
    stop("Candidate bridge non-finite evidence is invalid.", call. = FALSE)
  }
  candidate_keep <- if (identical(profile$action, "replace_nan_with_zero")) {
    rep(TRUE, nrow(candidate_value))
  } else {
    !resolution$resolution_mask
  }
  candidate_core <- candidate_value[candidate_keep, , drop = FALSE]
  row.names(candidate_core) <- NULL
  baseline_resolution <- wlv13_v5d_bridge_baseline_nonfinite(
    baseline_value, profile
  )
  if (!isTRUE(baseline_resolution$passed)) {
    stop("Baseline bridge non-finite evidence is invalid.", call. = FALSE)
  }
  baseline_core <- wlv13_v5d_normalize_baseline_anomaly_policy(
    baseline_resolution$value, profile
  )$value
  nonmodule <- setdiff(columns, "module")
  baseline_semantic <- wlv13_v5d_raw_row_keys(baseline_core[nonmodule])
  candidate_semantic <- wlv13_v5d_raw_row_keys(candidate_core[nonmodule])
  baseline_order <- order(baseline_semantic, method = "radix")
  candidate_order <- order(candidate_semantic, method = "radix")
  if (!identical(
      baseline_semantic[baseline_order], candidate_semantic[candidate_order]
    )) {
    stop("Anomaly bridge evidence differs outside the module field.",
      call. = FALSE
    )
  }
  baseline_sorted <- baseline_core[baseline_order, , drop = FALSE]
  candidate_sorted <- candidate_core[candidate_order, , drop = FALSE]
  changed <- baseline_sorted$module != candidate_sorted$module
  if (!any(changed)) {
    stop("Anomaly bridge evidence contains no owner migration.",
      call. = FALSE
    )
  }
  context <- wlv13_v5d_bridge_context_columns("_anomalies.csv")
  changed_value <- data.frame(
    baseline_sorted[changed, context, drop = FALSE],
    baseline_module = baseline_sorted$module[changed],
    candidate_module = candidate_sorted$module[changed],
    stringsAsFactors = FALSE, check.names = FALSE
  )
  key <- wlv13_v5d_raw_row_keys(changed_value)
  groups <- split(seq_len(nrow(changed_value)), key)
  rows <- lapply(groups, function(index) {
    first <- index[[1L]]
    row <- wlv13_v5d_bridge_empty_row()
    for (column in context) {
      row[[column]] <- changed_value[[column]][[first]]
    }
    row$baseline_module <- changed_value$baseline_module[[first]]
    row$candidate_module <- changed_value$candidate_module[[first]]
    wlv13_v5d_bridge_common_fields(
      row, "_anomalies.csv", method, profile$source,
      baseline, candidate, baseline$anomalies$sha256,
      candidate$anomalies$sha256, length(index), length(index)
    )
  })
  do.call(rbind, rows)
}

wlv13_v5d_bind_anomaly_owner_contract <- function(value, owner_contract) {
  if (!is.data.frame(value) || !nrow(value) || !is.list(owner_contract) ||
      !is.data.frame(owner_contract$anomaly_targets)) {
    stop("Invalid anomaly owner-contract binding request.", call. = FALSE)
  }
  targets <- owner_contract$anomaly_targets
  for (index in seq_len(nrow(value))) {
    matches <- targets$artifact == value$artifact[[index]] &
      targets$indicator == value$indicator[[index]] &
      targets$stage == value$stage[[index]] &
      (targets$module == value$candidate_module[[index]] |
        targets$producer_id == value$candidate_module[[index]])
    if (sum(matches) != 1L) {
      stop("An anomaly bridge lacks one exact candidate DAG owner.",
        call. = FALSE
      )
    }
    target <- targets[which(matches), , drop = FALSE]
    value$candidate_producer_id[[index]] <- target$producer_id[[1L]]
    value$candidate_write_action[[index]] <- target$action[[1L]]
    value$derivation_sha256[[index]] <- wlv13_v5d_bridge_derivation(
      value[index, , drop = FALSE]
    )
    value$bridge_id[[index]] <- paste0(
      "bridge-", substr(value$derivation_sha256[[index]], 1L, 24L)
    )
  }
  value
}

wlv13_v5d_generate_bridge_manifest <- function(
    evidence, contract_project_root, output_path) {
  required <- c(
    "method", "candidate_project_root", "candidate_run_root",
    "baseline_project_root", "baseline_run_root"
  )
  if (!is.data.frame(evidence) || !identical(names(evidence), required) ||
      !identical(sort(evidence$method, method = "radix"),
        sort(wlv13_v5d_methods, method = "radix")) ||
      anyDuplicated(evidence$method) || file.exists(output_path)) {
    stop("Invalid bridge evidence index or pre-existing output path.",
      call. = FALSE
    )
  }
  contract_project_root <- normalizePath(
    contract_project_root, winslash = "/", mustWork = TRUE
  )
  results <- vector("list", nrow(evidence) * 2L)
  for (index in seq_len(nrow(evidence))) {
    method <- evidence$method[[index]]
    candidate <- tryCatch(wlv13_v5d_bridge_authenticate_run(
      evidence$candidate_project_root[[index]],
      evidence$candidate_run_root[[index]], method
    ), error = function(error) stop(sprintf(
      "Candidate bridge evidence for `%s` failed: %s",
      method, conditionMessage(error)
    ), call. = FALSE))
    baseline <- tryCatch(wlv13_v5d_bridge_authenticate_run(
      evidence$baseline_project_root[[index]],
      evidence$baseline_run_root[[index]], method
    ), error = function(error) stop(sprintf(
      "Baseline bridge evidence for `%s` failed: %s",
      method, conditionMessage(error)
    ), call. = FALSE))
    if (!identical(
        candidate$execution[setdiff(names(candidate$execution), c(
          "run_id", "run_manifest_sha256"
        ))],
        baseline$execution[setdiff(names(baseline$execution), c(
          "run_id", "run_manifest_sha256"
        ))]
      ) || !identical(candidate$execution$mode, "calculate") ||
        !identical(candidate$execution$at_stage, "") ||
        !identical(candidate$execution$sea_vars, character()) ||
        !identical(candidate$execution$workers, 1L)) {
      stop("Bridge evidence calculate requests differ across engines.",
        call. = FALSE
      )
    }
    profile <- wlv13_v5d_scientific_profile(
      candidate$project_root, method
    )
    if (!identical(profile, wlv13_v5d_scientific_profile(
        contract_project_root, method
      ))) {
      stop("Historical and current scientific profiles differ.",
        call. = FALSE
      )
    }
    results[[index * 2L - 1L]] <- wlv13_v5d_derive_unit_bridges(
      method, profile$source, baseline, candidate
    )
    results[[index * 2L]] <- wlv13_v5d_bind_anomaly_owner_contract(
      wlv13_v5d_derive_anomaly_bridges(
      method, profile, baseline, candidate
      ),
      wlv13_v5d_candidate_owner_contract(contract_project_root, method)
    )
  }
  value <- do.call(rbind, results)
  order_index <- wlv13_v5d_bridge_order(value)
  value <- value[order_index, wlv13_v5d_bridge_columns, drop = FALSE]
  row.names(value) <- NULL
  value <- wlv13_v5d_validate_bridge_manifest(value)
  output_directory <- normalizePath(dirname(output_path), winslash = "/",
    mustWork = TRUE
  )
  staging_path <- tempfile(
    pattern = "issue13-v5-diagnostic-bridges-", tmpdir = output_directory,
    fileext = ".csv"
  )
  on.exit(unlink(staging_path, force = TRUE), add = TRUE)
  utils::write.table(
    value, file = staging_path, sep = ";", row.names = FALSE,
    col.names = TRUE, quote = TRUE, qmethod = "double",
    fileEncoding = "UTF-8", eol = "\n"
  )
  reread <- wlv13_v5d_validate_bridge_manifest(
    wlv13_read_csv_semantic(staging_path)
  )
  if (!identical(value, reread)) {
    stop("Generated diagnostic bridge manifest failed its UTF-8 round trip.",
      call. = FALSE
    )
  }
  if (!file.rename(staging_path, output_path) || !file.exists(output_path)) {
    stop("Could not atomically promote the diagnostic bridge manifest.",
      call. = FALSE
    )
  }
  invisible(value)
}

wlv13_v5d_bridge_generator_main <- function(arguments = commandArgs(TRUE)) {
  if (!length(arguments)) return(invisible(NULL))
  if (length(arguments) != 4L) {
    stop(paste0(
      "Usage: Rscript issue13-v5-build-diagnostic-bridges.R ",
      "<harness-dir> <candidate-contract-root> ",
      "<evidence-index.csv> <new-output.csv>"
    ), call. = FALSE)
  }
  harness_dir <- normalizePath(arguments[[1L]], winslash = "/", mustWork = TRUE)
  contract_project_root <- normalizePath(
    arguments[[2L]], winslash = "/", mustWork = TRUE
  )
  evidence_path <- normalizePath(arguments[[3L]], winslash = "/", mustWork = TRUE)
  script_path <- sub("^--file=", "", grep(
    "^--file=", commandArgs(FALSE), value = TRUE
  )[[1L]])
  script_dir <<- normalizePath(dirname(script_path),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(harness_dir, "issue13-lib.R"))
  source(file.path(dirname(harness_dir), "issue13-prep-paper-lib.R"))
  source(file.path(harness_dir, "issue13-compare-lib.R"))
  source(file.path(script_dir, "issue13-v5-compare-override.R"))
  source(file.path(script_dir, "issue13-v5-diagnostics-override.R"))
  evidence <- wlv13_v5d_normalize_table(
    wlv13_read_csv_semantic(evidence_path),
    c(
      "method", "candidate_project_root", "candidate_run_root",
      "baseline_project_root", "baseline_run_root"
    ),
    "Diagnostic bridge evidence index"
  )
  value <- wlv13_v5d_generate_bridge_manifest(
    evidence, contract_project_root, arguments[[4L]]
  )
  cat(sprintf(
    "generated_rows=%d manifest_sha256=%s\n",
    nrow(value), wlv13_sha256_file(arguments[[4L]])
  ))
  invisible(value)
}

if (sys.nframe() == 0L) {
  wlv13_v5d_bridge_generator_main()
}
