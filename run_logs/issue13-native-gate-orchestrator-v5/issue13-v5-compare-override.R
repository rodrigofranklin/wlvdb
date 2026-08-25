# V5 cross-engine allowance for the candidate's authenticated runtime sidecar.
#
# The sidecar has no legacy equivalent. It is accepted only after the
# candidate runtime itself validates its complete envelope, artifact hashes,
# semantic-state coordinates and state-binding hashes against the immutable run.

wlv13_v5_original_validate_nonfinite <-
  wlv13_cross_engine_validate_nonfinite

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
    snapshot_path <- normalizePath(
      descriptor$path,
      winslash = "/",
      mustWork = TRUE
    )
    run_root <- dirname(snapshot_path)
    method_root <- dirname(run_root)
    runs_root <- dirname(method_root)
    results_root <- dirname(runs_root)
    project_root <- dirname(results_root)
    expected_structure <-
      identical(basename(results_root), "results") &&
      identical(basename(runs_root), "runs") &&
      identical(basename(method_root), method) &&
      nzchar(basename(run_root)) &&
      file.exists(file.path(project_root, "R", "bootstrap.R"))
    if (!expected_structure) {
      stop(
        "The runtime sidecar is outside results/runs/<method>/<run_id>.",
        call. = FALSE
      )
    }
    loaded <- wlv_gate_load_runtime(project_root)
    if (!identical(loaded$kind, "candidate")) {
      stop("The runtime sidecar can only be validated by the candidate runtime.",
        call. = FALSE
      )
    }
    snapshot <- loaded$runtime$wlv_runtime_snapshot_read(
      run_root,
      method = method
    )
    loaded$runtime$wlv_assert_loaded_runtime_unchanged()
    if (!identical(snapshot$version, "wlv-runtime-resources/1.0.0")) {
      stop("The runtime sidecar version is not the Issue #13 contract.",
        call. = FALSE
      )
    }
    list(
      passed = TRUE,
      reason = "candidate-runtime-snapshot-validated",
      snapshot_version = snapshot$version,
      partition_count = length(snapshot$partitions),
      resource_count = length(snapshot$resources),
      state_binding_count = nrow(snapshot$state_bindings),
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
