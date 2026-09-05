wlv13_main_oracle_architecture_proof <- function(report, inventory_sha256,
                                                identity) {
  # The two stable profiles are nonfinite_none_v1 (reject, expected_count=0).
  # Only the runtime snapshot is candidate-only in their authenticated outputs.
  # Keep the frozen source proof and exact nonempty-delta fingerprints.
  if (!is.list(identity) ||
      !(identical(identity$method, "wiodr13") ||
        identical(identity$method, "wiodr16"))) {
    stop("Main oracle architecture proof requires a supported stable method.",
      call. = FALSE)
  }
  architecture_keys <- "file:_runtime_resources.rds"
  source_provenance_key <- "file:_source_provenance.csv"
  required_architecture_keys <- c(architecture_keys, source_provenance_key)
  if (!is.list(report) || !isTRUE(report$passed) ||
      !identical(report$status, "passed") ||
      !identical(report$comparison_mode, "cross_engine_run_v3") ||
      !is.list(report$candidate) ||
      !identical(report$candidate$kind, "run") ||
      !identical(report$candidate$inventory_sha256, inventory_sha256) ||
      !identical(
        wlv13_v5_oracle_identity_core(
          report$candidate$identity, "architecture candidate"
        ), identity
      ) || !isTRUE(report$identity$passed) ||
      length(report$missing_candidate_artifacts) ||
      length(report$extra_candidate_artifacts) ||
      !identical(
        sort(unlist(report$allowed_candidate_only_artifacts,
          use.names = FALSE), method = "radix"),
        architecture_keys
      ) ||
      !is.list(report$architecture_differences) ||
      length(report$policy_exceptions) || !is.list(report$artifacts)) {
    stop("Candidate architecture proof is invalid or misbound.",
      call. = FALSE)
  }
  keys <- vapply(report$artifacts, function(artifact) {
    if (is.list(artifact) && is.character(artifact$key) &&
        length(artifact$key) == 1L) artifact$key else ""
  }, character(1L))
  if (anyDuplicated(keys) ||
      "file:_nonfinite_resolution_diagnostics.csv" %in% keys) {
    stop("Main oracle architecture proof has duplicate or out-of-profile keys.",
      call. = FALSE)
  }
  architecture_universe <- c(
    "file:_anomalies.csv",
    "file:_method_assumptions.csv",
    "file:_method_matrices.csv",
    "file:_method_solutions.csv",
    "file:_scientific_checks.csv",
    "file:_source_provenance.csv",
    "file:_unit_contract.csv",
    architecture_keys
  )
  reported_architecture <- sort(unlist(report$architecture_differences,
    use.names = FALSE), method = "radix")
  derived_architecture <- sort(keys[vapply(report$artifacts, function(value) {
    is.list(value) && isTRUE(value$architecture_difference)
  }, logical(1L))], method = "radix")
  if (anyDuplicated(reported_architecture) ||
      !identical(reported_architecture, derived_architecture) ||
      length(setdiff(reported_architecture, architecture_universe)) ||
      length(setdiff(required_architecture_keys, reported_architecture))) {
    stop("Cross-engine architecture differences are not closed or derived.",
      call. = FALSE)
  }
  artifact <- report$artifacts[[match(architecture_keys, keys)]]
  if (!is.list(artifact) || !identical(artifact$type, "rds") ||
      !isTRUE(artifact$passed) || !isTRUE(artifact$role_match) ||
      !isTRUE(artifact$architecture_difference) ||
      !identical(artifact$candidate_path, "_runtime_resources.rds") ||
      !identical(artifact$baseline_path, "")) {
    stop("Candidate architecture proof for the runtime snapshot failed.",
      call. = FALSE)
  }
  source_provenance <- report$artifacts[[match(source_provenance_key, keys)]]
  wlv13_v5_source_provenance_architecture_proof(
    source_provenance, identity,
    wlv13_scalar_text(report$candidate$manifest_sha256,
      "source provenance candidate run manifest sha256", "^[0-9a-f]{64}$"),
    wlv13_scalar_text(report$baseline$manifest_sha256,
      "source provenance baseline run manifest sha256", "^[0-9a-f]{64}$")
  )
  reported_architecture
}

wlv13_main_oracle_artifact_delta <- function(artifact) {
  fst <- artifact$type %in% c("fst_array", "fst_table")
  if (fst) {
    hash <- artifact$difference_sha256
    if (!is.character(hash) || length(hash) != 1L || is.na(hash) ||
        !grepl("^[0-9a-f]{64}$", hash)) {
      stop("Scientific oracle artifact lacks an exact fingerprint.",
        call. = FALSE)
    }
    if (!is.logical(artifact$passed) || length(artifact$passed) != 1L ||
        is.na(artifact$passed)) {
      stop("Scientific oracle artifact has an invalid verdict.", call. = FALSE)
    }
    if (isTRUE(artifact$passed)) {
      structural <- if (identical(artifact$type, "fst_array")) {
        c("same_dimensions", "same_dimnames", "same_payload_schema")
      } else c("same_rows", "same_columns", "same_types")
      count <- artifact$mismatch_count
      if (!all(vapply(artifact[structural], identical, logical(1L), TRUE)) ||
          !identical(artifact$role_match, TRUE) ||
          (!is.null(artifact$meta_role_match) &&
            !identical(artifact$meta_role_match, TRUE)) ||
          !is.numeric(count) || length(count) != 1L || is.na(count) ||
          !is.finite(count) || count != 0 ||
          !identical(artifact$first_mismatch_coordinate, "")) {
        stop("Passed scientific oracle artifact has a nonempty delta.",
          call. = FALSE)
      }
      if (identical(artifact$type, "fst_array")) {
        empty_fields <- c("first_candidate_state", "first_baseline_state",
          "first_candidate_value", "first_baseline_value")
        maximum <- suppressWarnings(as.numeric(
          artifact$maximum_absolute_difference
        ))
        if (!all(vapply(artifact[empty_fields], identical, logical(1L), "")) ||
            length(maximum) != 1L || is.na(maximum) ||
            !is.finite(maximum) || maximum != 0) {
          stop("Passed array oracle artifact has a nonempty semantic delta.",
            call. = FALSE)
        }
      }
    }
  }
  result <- list(key = artifact$key, type = artifact$type,
    passed = artifact$passed, role_match = artifact$role_match)
  if (!is.null(artifact$meta_role_match)) {
    result$meta_role_match <- artifact$meta_role_match
  }
  # A zero delta is independent of the two endpoint storage fingerprints.
  # Failed artifacts retain the complete original difference fingerprint.
  if (!is.null(artifact$difference_sha256) &&
      !(fst && isTRUE(artifact$passed))) {
    result$difference_sha256 <- artifact$difference_sha256
  }
  result
}

wlv13_main_oracle_delta_projection <- function(projection) {
  # Parameterize only the frozen candidate-only artifact declaration.
  # No scientific projection, comparison, canonicalization or hash changes.
  expected <- quote(architecture_spec <- list(
    `file:_nonfinite_resolution_diagnostics.csv` = list(
      type = "csv", role = "diagnostic",
      comparison_mode = "unordered-row-multiset"
    ),
    `file:_runtime_resources.rds` = list(
      type = "rds", role = "metadata", comparison_mode = NULL
    )
  ))
  statements <- as.list(body(projection))
  declarations <- which(vapply(statements, function(value) {
    is.call(value) && length(value) == 3L &&
      identical(value[[1L]], as.name("<-")) &&
      identical(value[[2L]], as.name("architecture_spec"))
  }, logical(1L)))
  if (length(declarations) != 1L ||
      !identical(statements[[declarations]], expected)) {
    stop("Frozen oracle artifact declaration is not the reviewed version.",
      call. = FALSE)
  }
  body(projection)[[declarations]] <- quote(architecture_spec <- list(
    `file:_runtime_resources.rds` = list(
      type = "rds", role = "metadata", comparison_mode = NULL
    )
  ))
  function(report, arm = c("baseline", "candidate"),
           architecture_proofs = NULL, projected_keys = character()) {
    method <- report$candidate$identity$method
    keys <- vapply(report$artifacts, function(value) {
      if (is.list(value) && is.character(value$key) &&
          length(value$key) == 1L) value$key else ""
    }, character(1L))
    if (!(identical(method, "wiodr13") || identical(method, "wiodr16")) ||
        "file:_nonfinite_resolution_diagnostics.csv" %in% keys) {
      stop("Main oracle projection requires the exact stable artifact profile.",
        call. = FALSE)
    }
    projection(report, arm, architecture_proofs, projected_keys)
  }
}

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_argument)) stop("Run with Rscript.", call. = FALSE)
arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 7L) {
  stop(paste(
    "Expected <harness-root> <baseline-oracle.json> <candidate-oracle.json>",
    "<child-parity.json> <full-parity.json> <id> <output.json>."
  ), call. = FALSE)
}
harness_root <- normalizePath(arguments[[1L]], winslash = "/", mustWork = TRUE)
sys.source(file.path(harness_root, "issue13-lib.R"), envir = environment())
sys.source(file.path(harness_root, "issue13-v5-aggregate-hardening.R"),
  envir = environment()
)
wlv13_v5_oracle_architecture_proof <- wlv13_main_oracle_architecture_proof
wlv13_v5_oracle_artifact_delta <- wlv13_main_oracle_artifact_delta
wlv13_v5_oracle_delta_projection <- wlv13_main_oracle_delta_projection(
  wlv13_v5_oracle_delta_projection
)
paths <- vapply(arguments[2:5], normalizePath, character(1L),
  winslash = "/", mustWork = TRUE, USE.NAMES = FALSE
)
documents <- lapply(paths, wlv13_json_read, simplify = FALSE)
if (any(!vapply(documents, function(value) {
  is.list(value) && identical(value$schema,
    "wlv-issue13-artifact-comparison/1"
  )
}, logical(1L)))) {
  stop("Oracle delta input is not comparison evidence.", call. = FALSE)
}
delta <- wlv13_v5_compare_oracle_deltas(
  documents[[1L]], documents[[2L]],
  list(child = documents[[3L]], full = documents[[4L]])
)
result <- list(
  schema = "wlv-issue13-main-oracle-delta/1",
  id = arguments[[6L]],
  passed = isTRUE(delta$passed),
  classification = if (!isTRUE(delta$passed)) {
    "oracle-mismatch"
  } else if (isTRUE(delta$baseline_passed)) {
    "exact-to-full"
  } else {
    "baseline-known-divergence"
  },
  delta = delta,
  inputs = unname(Map(function(path, role) {
    list(role = role, path = path, sha256 = wlv13_sha256_file(path))
  }, paths, c("baseline-oracle", "candidate-oracle", "child-parity", "full-parity")))
)
wlv13_json_write(result, arguments[[7L]])
quit(save = "no", status = if (isTRUE(result$passed)) 0L else 1L,
  runLast = FALSE
)
