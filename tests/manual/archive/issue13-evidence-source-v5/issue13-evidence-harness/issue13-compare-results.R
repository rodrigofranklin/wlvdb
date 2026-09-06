script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_argument)) stop("Run with Rscript.", call. = FALSE)
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
  "candidate_result", "candidate_selector", "baseline_result",
  "baseline_selector", "output", "scenario_id"
))
chunk_rows <- wlv13_integer(if ("chunk_rows" %in% names(options)) {
  suppressWarnings(as.numeric(options$chunk_rows))
} else {
  1000000
}, "chunk_rows", 1L)
comparison_mode <- if ("comparison_mode" %in% names(options)) {
  match.arg(options$comparison_mode, c("strict", "cross_engine_run_v3"))
} else {
  "strict"
}

select_output <- function(path, selector) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  report <- wlv13_json_read(path, simplify = FALSE)
  if (!is.list(report) || !identical(report$schema, wlv13_schema$scenario) ||
      !isTRUE(report$passed) || !is.list(report$outputs)) {
    stop(sprintf("Scenario result is not passed evidence: %s.", path),
      call. = FALSE
    )
  }
  pieces <- strsplit(selector, ":", fixed = TRUE)[[1L]]
  kind <- match.arg(pieces[[1L]], c("run", "source", "snapshot", "release"))
  qualifier <- if (length(pieces) == 2L && nzchar(pieces[[2L]])) {
    pieces[[2L]]
  } else {
    NULL
  }
  if (length(pieces) > 2L || (kind %in% c("run", "source", "snapshot") &&
      is.null(qualifier))) {
    stop(sprintf("Invalid output selector: %s.", selector), call. = FALSE)
  }
  matches <- vapply(report$outputs, function(output) {
    if (!is.list(output) || !identical(output$kind, kind)) return(FALSE)
    if (is.null(qualifier)) return(TRUE)
    identical(output$method, qualifier) || identical(output$source, qualifier)
  }, logical(1L))
  if (sum(matches) != 1L) {
    stop(sprintf("Selector `%s` did not match exactly one output.", selector),
      call. = FALSE
    )
  }
  output <- report$outputs[[which(matches)]]
  inventory <- wlv13_inventory(kind, if (identical(kind, "snapshot")) {
    output$manifest_path
  } else {
    output$root
  })
  if (!identical(wlv13_inventory_signature(inventory),
      output$inventory_sha256) ||
      !identical(inventory$manifest_sha256, output$manifest_sha256)) {
    stop("Selected output differs from its scenario evidence.", call. = FALSE)
  }
  inventory
}

candidate <- select_output(options$candidate_result, options$candidate_selector)
baseline <- select_output(options$baseline_result, options$baseline_selector)
output <- wlv13_ensure_dir(options$output, "comparison output")
if (wlv13_is_within(output, candidate$root) ||
    wlv13_is_within(output, baseline$root)) {
  stop("Comparison output must be outside both artifact roots.", call. = FALSE)
}
report <- wlv13_compare_inventories(candidate, baseline, chunk_rows,
  options$scenario_id, comparison_mode = comparison_mode
)
wlv13_recheck_inventory(candidate)
wlv13_recheck_inventory(baseline)
wlv13_write_comparison_outputs(report, output)
quit(save = "no", status = if (report$passed) 0L else 1L, runLast = FALSE)
