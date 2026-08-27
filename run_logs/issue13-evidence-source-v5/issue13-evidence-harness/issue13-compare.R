script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_argument)) {
  stop("Run issue13-compare.R with Rscript.", call. = FALSE)
}
script_path <- normalizePath(sub("^--file=", "", script_argument[[1L]]),
  winslash = "/", mustWork = TRUE
)
script_dir <- dirname(script_path)
sys.source(file.path(script_dir, "issue13-lib.R"), envir = environment())
sys.source(file.path(dirname(script_dir), "issue13-prep-paper-lib.R"),
  envir = environment()
)
sys.source(file.path(script_dir, "issue13-compare-lib.R"), envir = environment())

options <- wlv13_parse_cli(commandArgs(trailingOnly = TRUE))
wlv13_cli_required(options, c(
  "candidate_kind", "candidate", "baseline_kind", "baseline", "output",
  "scenario_id"
))
chunk_rows <- if ("chunk_rows" %in% names(options)) {
  suppressWarnings(as.numeric(options$chunk_rows))
} else {
  1000000
}
chunk_rows <- wlv13_integer(chunk_rows, "chunk_rows", 1L)
comparison_mode <- if ("comparison_mode" %in% names(options)) {
  match.arg(options$comparison_mode, c("strict", "cross_engine_run_v3"))
} else {
  "strict"
}
output <- wlv13_ensure_dir(options$output, "comparison output directory")

report <- NULL
status <- 1L
tryCatch(
  {
    candidate <- wlv13_inventory(options$candidate_kind, options$candidate)
    baseline <- wlv13_inventory(options$baseline_kind, options$baseline)
    if (wlv13_is_within(output, candidate$root) ||
        wlv13_is_within(output, baseline$root)) {
      stop("Comparison evidence must be outside both artifact roots.",
        call. = FALSE
      )
    }
    report <- wlv13_compare_inventories(
      candidate,
      baseline,
      chunk_rows = chunk_rows,
      scenario_id = options$scenario_id,
      comparison_mode = comparison_mode
    )
    wlv13_recheck_inventory(candidate)
    wlv13_recheck_inventory(baseline)
    wlv13_write_comparison_outputs(report, output)
    status <- if (isTRUE(report$passed)) 0L else 1L
  },
  error = function(error) {
    report <<- list(
      schema = wlv13_schema$comparison,
      scenario_id = wlv13_id(options$scenario_id, "scenario_id"),
      status = "failed",
      passed = FALSE,
      compared_at = wlv13_now(),
      comparison_mode = comparison_mode,
      error = conditionMessage(error),
      artifacts = list(),
      transitions = data.frame(),
      indicator_differences = data.frame(),
      policy_exceptions = list()
    )
    final_names <- c(
      "artifact-summary.csv",
      "state-transitions.csv",
      "indicator-differences.csv",
      "comparison.json"
    )
    final_paths <- file.path(output, final_names)
    final_exists <- file.exists(final_paths) | dir.exists(final_paths)
    if (!any(final_exists)) {
      tryCatch(
        wlv13_write_comparison_outputs(report, output),
        error = function(publication_error) {
          message(sprintf(
            "Cannot publish comparison failure evidence: %s",
            conditionMessage(publication_error)
          ))
        }
      )
    } else if (!isTRUE(final_exists[[match("comparison.json", final_names)]])) {
      message(paste0(
        "Comparison publication is partial; refusing to retry over existing ",
        "final output(s): ",
        paste(final_names[final_exists], collapse = ", "),
        "."
      ))
    }
    message(conditionMessage(error))
    status <<- 1L
  }
)
quit(save = "no", status = status, runLast = FALSE)
