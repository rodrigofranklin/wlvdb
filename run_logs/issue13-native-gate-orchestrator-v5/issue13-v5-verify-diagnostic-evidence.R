# Verifies one freshly captured calculate or full-recalculation run before it
# can enter an external diagnostic evidence index.

wlv13_v5d_verify_evidence_main <- function(arguments = commandArgs(TRUE)) {
  if (!length(arguments) %in% c(5L, 8L)) {
    stop(paste0(
      "Usage: Rscript issue13-v5-verify-diagnostic-evidence.R ",
      "<harness-dir> <controller-dir> <project-root> <run-root> <method> ",
      "[<mode> <expected-parent-run-id-or-dash> <expected-stage-or-dash>]"
    ), call. = FALSE)
  }
  harness_dir <- normalizePath(arguments[[1L]], winslash = "/",
    mustWork = TRUE
  )
  controller_dir <- normalizePath(arguments[[2L]], winslash = "/",
    mustWork = TRUE
  )
  project_root <- normalizePath(arguments[[3L]], winslash = "/",
    mustWork = TRUE
  )
  run_root <- normalizePath(arguments[[4L]], winslash = "/",
    mustWork = TRUE
  )
  method <- enc2utf8(arguments[[5L]])
  expected_mode <- if (length(arguments) == 8L) {
    enc2utf8(arguments[[6L]])
  } else {
    "calculate"
  }
  expected_parent <- if (length(arguments) == 8L &&
      !identical(arguments[[7L]], "-")) {
    enc2utf8(arguments[[7L]])
  } else {
    ""
  }
  expected_stage <- if (length(arguments) == 8L &&
      !identical(arguments[[8L]], "-")) {
    enc2utf8(arguments[[8L]])
  } else {
    ""
  }
  if (!expected_mode %in% c("calculate", "recalculate") ||
      (identical(expected_mode, "calculate") &&
        (nzchar(expected_parent) || nzchar(expected_stage))) ||
      (identical(expected_mode, "recalculate") &&
        (!grepl("^run-[0-9A-Za-z-]+$", expected_parent) ||
          !expected_stage %in% c("1", "4", "5")))) {
    stop("Invalid expected diagnostic evidence execution.", call. = FALSE)
  }
  script_dir <<- controller_dir
  source(file.path(harness_dir, "issue13-lib.R"))
  source(file.path(dirname(harness_dir), "issue13-prep-paper-lib.R"))
  source(file.path(harness_dir, "issue13-compare-lib.R"))
  source(file.path(controller_dir, "issue13-v5-compare-override.R"))
  source(file.path(controller_dir, "issue13-v5-diagnostics-override.R"))
  source(file.path(controller_dir,
    "issue13-v5-build-diagnostic-bridges.R"
  ))
  value <- wlv13_v5d_bridge_authenticate_run(
    project_root, run_root, method, expected_mode
  )
  execution_valid <- identical(value$execution$mode, expected_mode) &&
    identical(value$execution$at_stage, expected_stage) &&
    identical(value$execution$sea_vars, character()) &&
    identical(value$execution$workers, 1L) &&
    identical(if (is.null(value$parent_run_id)) "" else
      value$parent_run_id, expected_parent)
  if (!execution_valid) {
    stop("Diagnostic evidence execution differs from its sealed request.",
      call. = FALSE
    )
  }
  optional_sha256 <- function(artifact) {
    if (is.null(artifact)) "" else artifact$sha256
  }
  cat(paste(c(
    "evidence_record",
    paste0("method=", method),
    paste0("mode=", value$execution$mode),
    paste0("at_stage=", value$execution$at_stage),
    paste0("scenario_id=", value$execution$scenario_id),
    paste0("run_id=", value$run_id),
    paste0("parent_run_id=", expected_parent),
    paste0("commit=", value$commit),
    paste0("tree=", value$tree),
    paste0("request_sha256=", value$execution$request_sha256),
    paste0("source_sha256=", value$source_sha256),
    paste0("run_manifest_sha256=", value$run_manifest_sha256),
    paste0("run_inventory_sha256=", value$run_inventory_sha256),
    paste0("anomalies_sha256=", value$anomalies$sha256),
    paste0("unit_sha256=", optional_sha256(value$unit)),
    paste0("nonfinite_sha256=", optional_sha256(value$nonfinite))
  ), collapse = ";"), "\n", sep = "")
  invisible(value)
}

if (sys.nframe() == 0L) {
  wlv13_v5d_verify_evidence_main()
}
