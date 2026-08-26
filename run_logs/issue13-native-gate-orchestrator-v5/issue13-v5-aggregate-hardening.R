# Terminal V5 aggregation checks for Issue #13.
#
# This file is sourced by the sealed evidence harness. It contains only
# fail-closed validators: it neither executes the scientific engines nor writes
# evidence.

wlv13_v5_recompute_peak_rss <- function(metrics, expected_path) {
  expected_columns <- c(
    "sample_at_utc", "pid", "parent_pid", "name", "created_at_utc",
    "working_set_bytes", "private_bytes", "cpu_seconds"
  )
  recorded_path <- wlv13_scalar_text(
    metrics$samples_path, "recorded process samples path"
  )
  recorded_normalized <- gsub("\\\\", "/", recorded_path)
  path <- normalizePath(
    expected_path, winslash = "/", mustWork = TRUE
  )
  if (!identical(basename(recorded_normalized), "process-samples.csv") ||
      !identical(basename(path), "process-samples.csv")) {
    stop("Process samples are not the canonical sibling evidence file.",
      call. = FALSE
    )
  }
  expected_sha256 <- wlv13_scalar_text(
    metrics$samples_sha256,
    "process samples sha256",
    "^[0-9a-f]{64}$"
  )
  if (!identical(wlv13_sha256_file(path), expected_sha256)) {
    stop("Process samples differ from their authenticated hash.", call. = FALSE)
  }
  samples <- utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = "character",
    na.strings = NULL,
    fileEncoding = "UTF-8"
  )
  rownames(samples) <- NULL
  if (!identical(names(samples), expected_columns) || !nrow(samples)) {
    stop("Process samples have an invalid schema or no observations.",
      call. = FALSE
    )
  }
  samples[] <- lapply(samples, enc2utf8)
  if (any(!nzchar(samples$sample_at_utc)) ||
      any(!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T.+Z$", samples$sample_at_utc)) ||
      any(!grepl("^[0-9]+$", samples$pid)) ||
      any(!grepl("^$|^[0-9]+$", samples$parent_pid)) ||
      any(!nzchar(samples$name)) || any(!nzchar(samples$created_at_utc)) ||
      any(!grepl("^[0-9]+$", samples$working_set_bytes)) ||
      any(!grepl("^[0-9]+$", samples$private_bytes))) {
    stop("Process samples contain invalid identity or memory fields.",
      call. = FALSE
    )
  }
  working_set <- suppressWarnings(as.numeric(samples$working_set_bytes))
  private <- suppressWarnings(as.numeric(samples$private_bytes))
  cpu <- suppressWarnings(as.numeric(samples$cpu_seconds))
  if (anyNA(working_set) || any(!is.finite(working_set)) ||
      any(working_set < 0) || anyNA(private) || any(!is.finite(private)) ||
      any(private < 0) || anyNA(cpu) || any(!is.finite(cpu)) || any(cpu < 0)) {
    stop("Process samples contain invalid numeric observations.", call. = FALSE)
  }
  generations <- paste(samples$sample_at_utc, samples$pid, sep = "|")
  if (anyDuplicated(generations)) {
    stop("A process generation is duplicated within one sample.", call. = FALSE)
  }
  sample_order <- unique(samples$sample_at_utc)
  if (!identical(rle(samples$sample_at_utc)$values, sample_order) ||
      !identical(sample_order, sort(sample_order, method = "radix"))) {
    stop("Process sample timestamps are not contiguous and ordered.",
      call. = FALSE
    )
  }
  totals <- vapply(sample_order, function(timestamp) {
    sum(working_set[samples$sample_at_utc == timestamp])
  }, numeric(1L))
  recomputed <- max(totals)
  reported <- suppressWarnings(as.numeric(metrics$peak_rss_bytes))
  reported_samples_raw <- metrics$samples
  reported_samples <- suppressWarnings(as.numeric(reported_samples_raw))
  if (length(reported) != 1L || is.na(reported) || !is.finite(reported) ||
      reported <= 0 || length(reported_samples) != 1L ||
      !is.numeric(reported_samples_raw) || is.na(reported_samples) ||
      !is.finite(reported_samples) || reported_samples <= 0L ||
      reported_samples != floor(reported_samples) ||
      !reported_samples %in% c(length(sample_order), length(sample_order) + 1L) ||
      !identical(reported, recomputed) || recomputed <= 0) {
    stop("Reported peak RSS is not the positive peak recomputed from samples.",
      call. = FALSE
    )
  }
  list(
    passed = TRUE,
    peak_rss_bytes = recomputed,
    reported_peak_rss_bytes = reported,
    sample_count = length(sample_order),
    row_count = nrow(samples),
    samples_sha256 = expected_sha256
  )
}

wlv13_v5_canonical_json <- function(value) {
  if (is.list(value)) {
    if (!is.null(names(value))) {
      value <- value[order(names(value), method = "radix")]
    }
    return(lapply(value, wlv13_v5_canonical_json))
  }
  if (is.character(value)) enc2utf8(value) else value
}

wlv13_v5_oracle_identity_core <- function(value, label) {
  contract <- list(id = "wlvpanel-output", version = "1.0.0")
  if (!is.list(value) ||
      !is.character(value$method) || length(value$method) != 1L ||
      is.na(value$method) || !nzchar(value$method) ||
      !identical(value$output_contract, contract)) {
    stop(sprintf("Recalculation oracle has an invalid %s identity.", label),
      call. = FALSE
    )
  }
  list(method = enc2utf8(value$method), output_contract = contract)
}

wlv13_v5_oracle_artifact_delta <- function(artifact) {
  result <- list(
    key = artifact$key,
    type = artifact$type,
    passed = artifact$passed,
    role_match = artifact$role_match
  )
  if (!is.null(artifact$meta_role_match)) {
    result$meta_role_match <- artifact$meta_role_match
  }
  if (!is.null(artifact$difference_sha256)) {
    result$difference_sha256 <- artifact$difference_sha256
  }
  result
}

wlv13_v5_oracle_architecture_proof <- function(report, inventory_sha256,
                                                identity) {
  architecture_keys <- c(
    "file:_nonfinite_resolution_diagnostics.csv",
    "file:_runtime_resources.rds"
  )
  if (!is.list(report) || !isTRUE(report$passed) ||
      !identical(report$status, "passed") ||
      !identical(report$comparison_mode, "cross_engine_run_v3") ||
      !is.list(report$candidate) ||
      !identical(report$candidate$kind, "run") ||
      !identical(report$candidate$inventory_sha256, inventory_sha256) ||
      !identical(
        wlv13_v5_oracle_identity_core(
          report$candidate$identity, "architecture candidate"
        ),
        identity
      ) || !isTRUE(report$identity$passed) ||
      length(report$missing_candidate_artifacts) ||
      length(report$extra_candidate_artifacts) ||
      !identical(
        sort(unlist(
          report$allowed_candidate_only_artifacts, use.names = FALSE
        ), method = "radix"),
        sort(architecture_keys, method = "radix")
      ) ||
      !is.list(report$architecture_differences) ||
      length(report$policy_exceptions) || !is.list(report$artifacts)) {
    stop("Candidate architecture proof is invalid or misbound.",
      call. = FALSE
    )
  }
  keys <- vapply(report$artifacts, function(artifact) {
    if (is.list(artifact) && is.character(artifact$key) &&
        length(artifact$key) == 1L) artifact$key else ""
  }, character(1L))
  if (anyDuplicated(keys)) {
    stop("Candidate architecture proof has duplicate artifact keys.",
      call. = FALSE
    )
  }
  architecture_universe <- c(
    "file:_anomalies.csv",
    "file:_method_assumptions.csv",
    "file:_method_matrices.csv",
    "file:_method_solutions.csv",
    "file:_scientific_checks.csv",
    "file:_unit_contract.csv",
    architecture_keys
  )
  reported_architecture <- sort(unlist(
    report$architecture_differences, use.names = FALSE
  ), method = "radix")
  derived_architecture <- sort(keys[vapply(report$artifacts, function(value) {
    is.list(value) && isTRUE(value$architecture_difference)
  }, logical(1L))], method = "radix")
  if (anyDuplicated(reported_architecture) ||
      !identical(reported_architecture, derived_architecture) ||
      length(setdiff(reported_architecture, architecture_universe)) ||
      length(setdiff(architecture_keys, reported_architecture))) {
    stop("Cross-engine architecture differences are not closed or derived.",
      call. = FALSE
    )
  }
  expected <- list(
    `file:_nonfinite_resolution_diagnostics.csv` = list(
      type = "csv", role = "diagnostic"
    ),
    `file:_runtime_resources.rds` = list(type = "rds", role = "metadata")
  )
  for (key in architecture_keys) {
    artifact <- report$artifacts[[match(key, keys)]]
    spec <- expected[[key]]
    if (!is.list(artifact) || !identical(artifact$type, spec$type) ||
        !isTRUE(artifact$passed) || !isTRUE(artifact$role_match) ||
        !isTRUE(artifact$architecture_difference) ||
        !identical(artifact$candidate_path, sub("^file:", "", key)) ||
        !identical(artifact$baseline_path, "")) {
      stop(sprintf("Candidate architecture proof for `%s` failed.", key),
        call. = FALSE
      )
    }
  }
  reported_architecture
}

wlv13_v5_oracle_delta_projection <- function(report,
                                              arm = c("baseline", "candidate"),
                                              architecture_proofs = NULL,
                                              projected_keys = character()) {
  arm <- match.arg(arm)
  architecture_universe <- c(
    "file:_anomalies.csv",
    "file:_method_assumptions.csv",
    "file:_method_matrices.csv",
    "file:_method_solutions.csv",
    "file:_scientific_checks.csv",
    "file:_unit_contract.csv",
    "file:_nonfinite_resolution_diagnostics.csv",
    "file:_runtime_resources.rds"
  )
  if (!is.character(projected_keys) || anyNA(projected_keys) ||
      any(!nzchar(projected_keys)) || anyDuplicated(projected_keys) ||
      !identical(projected_keys,
        sort(projected_keys, method = "radix")) ||
      length(setdiff(projected_keys, architecture_universe))) {
    stop("Recalculation oracle projection keys are not closed and exact.",
      call. = FALSE
    )
  }
  required_names <- c(
    "schema", "scenario_id", "status", "passed", "compared_at",
    "chunk_rows", "comparison_mode", "candidate", "baseline", "identity",
    "missing_candidate_artifacts", "extra_candidate_artifacts",
    "allowed_candidate_only_artifacts", "architecture_differences",
    "artifact_count", "artifacts", "transitions", "indicator_differences",
    "policy_exceptions"
  )
  if (!is.list(report) || !identical(sort(names(report), method = "radix"),
      sort(required_names, method = "radix")) ||
      !identical(report$schema, wlv13_schema$comparison) ||
      !identical(report$comparison_mode, "strict") ||
      !is.numeric(report$chunk_rows) || length(report$chunk_rows) != 1L ||
      is.na(report$chunk_rows) || report$chunk_rows < 1L ||
      !is.list(report$candidate) || !is.list(report$baseline) ||
      !identical(report$candidate$kind, "run") ||
      !identical(report$baseline$kind, "run") ||
      !is.logical(report$passed) || length(report$passed) != 1L ||
      is.na(report$passed) ||
      !identical(
        report$status,
        if (isTRUE(report$passed)) "passed" else "failed"
      ) ||
      !isTRUE(report$identity$passed) ||
      length(report$missing_candidate_artifacts) ||
      length(report$extra_candidate_artifacts) ||
      length(report$allowed_candidate_only_artifacts) ||
      length(report$architecture_differences) ||
      length(report$policy_exceptions) ||
      !is.list(report$artifacts) || !length(report$artifacts) ||
      !identical(as.integer(report$artifact_count), length(report$artifacts))) {
    stop("Recalculation oracle lacks a complete strict comparison envelope.",
      call. = FALSE
    )
  }
  candidate_identity <- wlv13_v5_oracle_identity_core(
    report$candidate$identity, "candidate"
  )
  baseline_identity <- wlv13_v5_oracle_identity_core(
    report$baseline$identity, "baseline"
  )
  expected_identity_names <- c(
    "passed", "candidate_method", "baseline_method",
    "candidate_output_contract", "baseline_output_contract"
  )
  if (!identical(
      sort(names(report$identity), method = "radix"),
      sort(expected_identity_names, method = "radix")
    ) ||
      !identical(report$identity$candidate_method,
        candidate_identity$method
      ) ||
      !identical(report$identity$baseline_method,
        baseline_identity$method
      ) ||
      !identical(report$identity$candidate_output_contract,
        candidate_identity$output_contract
      ) ||
      !identical(report$identity$baseline_output_contract,
        baseline_identity$output_contract
      )) {
    stop("Recalculation oracle identity summary is inconsistent.",
      call. = FALSE
    )
  }
  artifact_keys <- vapply(report$artifacts, function(artifact) {
    if (!is.list(artifact) || !is.character(artifact$key) ||
        length(artifact$key) != 1L || !nzchar(artifact$key) ||
        !is.character(artifact$type) || length(artifact$type) != 1L ||
        !nzchar(artifact$type) || !is.logical(artifact$passed) ||
        length(artifact$passed) != 1L || is.na(artifact$passed) ||
        !isTRUE(artifact$role_match)) {
      stop("Recalculation oracle contains an incomplete artifact summary.",
        call. = FALSE
      )
    }
    if (artifact$type %in% c("fst_array", "fst_table")) {
      if (!is.character(artifact$difference_sha256) ||
          length(artifact$difference_sha256) != 1L ||
          !grepl("^[0-9a-f]{64}$", artifact$difference_sha256)) {
        stop("A scientific artifact lacks its complete difference fingerprint.",
          call. = FALSE
        )
      }
    } else if (!isTRUE(artifact$passed) &&
        (!is.character(artifact$difference_sha256) ||
          length(artifact$difference_sha256) != 1L ||
          !grepl("^[0-9a-f]{64}$", artifact$difference_sha256))) {
      stop("A failed non-FST artifact lacks a complete delta proof.",
        call. = FALSE
      )
    }
    artifact$key
  }, character(1L))
  if (anyDuplicated(artifact_keys) ||
      !identical(report$passed,
        isTRUE(report$identity$passed) &&
          all(vapply(report$artifacts, function(value) {
            isTRUE(value$passed)
          }, logical(1L))))) {
    stop("Recalculation oracle status is inconsistent with its artifacts.",
      call. = FALSE
    )
  }
  architecture_spec <- list(
    `file:_nonfinite_resolution_diagnostics.csv` = list(
      type = "csv", role = "diagnostic",
      comparison_mode = "unordered-row-multiset"
    ),
    `file:_runtime_resources.rds` = list(
      type = "rds", role = "metadata", comparison_mode = NULL
    )
  )
  architecture_keys <- names(architecture_spec)
  present_architecture <- intersect(artifact_keys, architecture_keys)
  if (identical(arm, "baseline") && length(present_architecture)) {
    stop("Baseline oracle unexpectedly contains candidate-only artifacts.",
      call. = FALSE
    )
  }
  if (identical(arm, "candidate") &&
      !identical(sort(present_architecture, method = "radix"),
        sort(architecture_keys, method = "radix"))) {
    stop("Candidate oracle lacks its exact architecture-only artifacts.",
      call. = FALSE
    )
  }
  for (key in present_architecture) {
    artifact <- report$artifacts[[match(key, artifact_keys)]]
    spec <- architecture_spec[[key]]
    valid <- identical(artifact$type, spec$type) &&
      isTRUE(artifact$role_match) &&
      identical(artifact$candidate_path, sub("^file:", "", key)) &&
      identical(artifact$baseline_path, sub("^file:", "", key))
    if (!valid) {
      stop(sprintf("Candidate-only artifact `%s` is not exact.", key),
        call. = FALSE
      )
    }
  }
  if (identical(arm, "candidate")) {
    if (!is.list(architecture_proofs) ||
        !identical(sort(names(architecture_proofs), method = "radix"),
          c("child", "full"))) {
      stop("Candidate oracle lacks child/full architecture proofs.",
        call. = FALSE
      )
    }
    child_projected <- wlv13_v5_oracle_architecture_proof(
      architecture_proofs$child,
      report$candidate$inventory_sha256,
      candidate_identity
    )
    full_projected <- wlv13_v5_oracle_architecture_proof(
      architecture_proofs$full,
      report$baseline$inventory_sha256,
      baseline_identity
    )
    authenticated_projection <- sort(unique(c(
      child_projected, full_projected
    )), method = "radix")
    if (!identical(projected_keys, authenticated_projection)) {
      stop("Recalculation projection differs from authenticated endpoints.",
        call. = FALSE
      )
    }
  }
  scientific_artifacts <- report$artifacts[
    !artifact_keys %in% projected_keys
  ]
  scientific_keys <- artifact_keys[!artifact_keys %in% projected_keys]
  scientific_artifacts <- scientific_artifacts[
    order(scientific_keys, method = "radix")
  ]
  scientific_passed <- isTRUE(report$identity$passed) &&
    all(vapply(scientific_artifacts, function(value) {
      isTRUE(value$passed)
    }, logical(1L)))
  projection <- list(
    schema = report$schema,
    status = if (scientific_passed) "passed" else "failed",
    passed = scientific_passed,
    chunk_rows = report$chunk_rows,
    comparison_mode = report$comparison_mode,
    candidate = list(
      kind = report$candidate$kind,
      identity = candidate_identity
    ),
    baseline = list(
      kind = report$baseline$kind,
      identity = baseline_identity
    ),
    identity = list(
      passed = TRUE,
      candidate = candidate_identity,
      baseline = baseline_identity
    ),
    missing_candidate_artifacts = report$missing_candidate_artifacts,
    extra_candidate_artifacts = report$extra_candidate_artifacts,
    allowed_candidate_only_artifacts = report$allowed_candidate_only_artifacts,
    architecture_differences = report$architecture_differences,
    projected_architecture_artifacts = as.list(projected_keys),
    artifact_count = length(scientific_artifacts),
    artifacts = lapply(
      scientific_artifacts, wlv13_v5_oracle_artifact_delta
    ),
    transitions = report$transitions,
    indicator_differences = report$indicator_differences,
    policy_exceptions = report$policy_exceptions
  )
  wlv13_v5_canonical_json(projection)
}

wlv13_v5_oracle_delta_sha256 <- function(projection) {
  wlv13_require("jsonlite")
  encoded <- jsonlite::toJSON(
    projection,
    auto_unbox = TRUE,
    digits = NA,
    null = "null",
    na = "string"
  )
  wlv13_sha256_text(as.character(encoded))
}

wlv13_v5_compare_oracle_deltas <- function(baseline, candidate,
                                            candidate_architecture) {
  if (!is.list(candidate) || !is.list(candidate$candidate) ||
      !is.list(candidate$baseline) ||
      !is.list(candidate$candidate$identity) ||
      !is.list(candidate$baseline$identity) ||
      !is.list(candidate_architecture) ||
      !identical(sort(names(candidate_architecture), method = "radix"),
        c("child", "full"))) {
    stop("Recalculation oracle lacks authenticated architecture endpoints.",
      call. = FALSE
    )
  }
  candidate_identity <- wlv13_v5_oracle_identity_core(
    candidate$candidate$identity, "candidate"
  )
  baseline_identity <- wlv13_v5_oracle_identity_core(
    candidate$baseline$identity, "baseline"
  )
  child_projected <- wlv13_v5_oracle_architecture_proof(
    candidate_architecture$child,
    candidate$candidate$inventory_sha256,
    candidate_identity
  )
  full_projected <- wlv13_v5_oracle_architecture_proof(
    candidate_architecture$full,
    candidate$baseline$inventory_sha256,
    baseline_identity
  )
  projected_keys <- sort(unique(c(
    child_projected, full_projected
  )), method = "radix")
  baseline_projection <- wlv13_v5_oracle_delta_projection(
    baseline, "baseline", projected_keys = projected_keys
  )
  candidate_projection <- wlv13_v5_oracle_delta_projection(
    candidate, "candidate", candidate_architecture, projected_keys
  )
  baseline_sha256 <- wlv13_v5_oracle_delta_sha256(baseline_projection)
  candidate_sha256 <- wlv13_v5_oracle_delta_sha256(candidate_projection)
  list(
    passed = identical(baseline_projection, candidate_projection) &&
      identical(baseline_sha256, candidate_sha256),
    baseline_sha256 = baseline_sha256,
    candidate_sha256 = candidate_sha256,
    baseline_passed = isTRUE(baseline_projection$passed),
    candidate_passed = isTRUE(candidate_projection$passed),
    schema = "wlv-issue13-complete-recalculation-delta/1"
  )
}
