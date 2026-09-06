# Real-data public-API recalculation gate. Run from the main repository with
# TEMP, TMP and TMPDIR set to the campaign scratch directory before R starts.
# Usage: Rscript tests/manual/issue28-recalculation.R <isolated-root> <method>
#   <calculate|recalculate> <stage> <workers> <all|indicator[,indicator]>
#   <report.json> [full-calculation-report.json]
# The root must be a campaign copy with normalized sources and no user channel.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) %in% c(7L, 8L))
root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
repo <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
stopifnot(startsWith(tolower(root), paste0(tolower(repo), "/temp/")))
method <- args[[2L]]
mode <- args[[3L]]
stage <- as.integer(args[[4L]])
workers <- as.integer(args[[5L]])
selection <- if (identical(args[[6L]], "all")) NULL else {
  strsplit(args[[6L]], ",", fixed = TRUE)[[1L]]
}
report_path <- args[[7L]]
stopifnot(!file.exists(report_path), method %in% c("wiodr13", "wiodr16"),
  mode %in% c("calculate", "recalculate"), workers %in% c(1L, 2L))
bootstrap <- new.env(parent = baseenv())
sys.source(file.path(root, "R", "bootstrap.R"), envir = bootstrap)
runtime <- bootstrap$wlv_load_runtime(root)
channel <- Sys.getenv("WLV_ISSUE28_CHANNEL", "validation/issue28")
current <- function() runtime$wlv_resolve_method_run_reference(root, method,
  runtime$wlv_read_current_release(root, channel, required = TRUE))
parent <- if (mode == "recalculate") current() else NULL
started <- format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3%z")
elapsed <- system.time({
  if (mode == "calculate") {
    runtime$get_wlv(method, workers = workers, channel = channel)
  } else {
    runtime$recalc_wlv(method, at_stage = stage, sea_vars = selection,
      workers = workers, channel = channel)
  }
})[["elapsed"]]
published <- current()
stopifnot(identical(published$manifest$result$request$mode, mode))
if (!is.null(parent)) {
  stopifnot(identical(published$manifest$parent_run_id, parent$run_id))
}
hash <- runtime$wlv_publication_file_sha256
checks <- list(publication_authenticated = TRUE,
  lineage = is.null(parent) || identical(published$manifest$parent_run_id, parent$run_id))
baseline <- if (length(args) == 8L) {
  jsonlite::read_json(args[[8L]], simplifyVector = FALSE)$run_path
} else NULL
comparison <- list()
if (!is.null(baseline)) {
  for (name in c("sea_sectors", "sea_countries")) {
    expected <- runtime$read_fst_array(file.path(baseline, paste0(name, ".fst")))
    observed <- runtime$read_fst_array(file.path(published$path, paste0(name, ".fst")))
    same <- identical(observed, expected)
    comparison[[name]] <- list(identical = same,
      dimensions = dim(observed), labels_identical = identical(dimnames(observed), dimnames(expected)),
      finite_mismatches = sum(is.finite(expected) & is.finite(observed) & expected != observed),
      na_identical = identical(is.na(expected), is.na(observed)),
      nan_identical = identical(is.nan(expected), is.nan(observed)))
    stopifnot(same)
    if (!is.null(selection)) {
      inherited <- runtime$read_fst_array(file.path(parent$path, paste0(name, ".fst")))
      unselected <- setdiff(dimnames(observed)[[2L]], selection)
      before <- if (length(dim(observed)) == 4L) inherited[, unselected, , , drop = FALSE] else inherited[, unselected, , drop = FALSE]
      after <- if (length(dim(observed)) == 4L) observed[, unselected, , , drop = FALSE] else observed[, unselected, , drop = FALSE]
      stopifnot(identical(before, after))
      comparison[[name]]$unselected_identical <- TRUE
    }
  }
  for (name in c("meta_indicators.RDS", "_unit_contract.csv", "_source_provenance.csv",
      "_parameters.csv", "_leontief_diagnostics.csv",
      "_gfcf_negative_cells.csv", "_gfcf_negative_summary.csv")) {
    stopifnot(identical(hash(file.path(published$path, name)), hash(file.path(baseline, name))))
    checks[[name]] <- TRUE
  }
  inherited_io <- list.files(baseline, "^m_(io|countries).*[.]fst([.]meta)?$", full.names = FALSE)
  stopifnot(length(inherited_io) >= 4L)
  checks$matrices_identical <- all(vapply(inherited_io, function(name) {
    identical(hash(file.path(published$path, name)), hash(file.path(baseline, name)))
  }, logical(1L)))
  stopifnot(checks$matrices_identical)
  expected_snapshot <- readRDS(file.path(baseline, "_runtime_resources.rds"))
  observed_snapshot <- readRDS(file.path(published$path, "_runtime_resources.rds"))
  checks$semantic_states_identical <- identical(
    observed_snapshot$panel_states, expected_snapshot$panel_states)
  stopifnot(checks$semantic_states_identical)
}
report <- list(schema = "wlv-issue28-recalculation/1", passed = TRUE,
  method = method, mode = mode, at_stage = stage, workers = workers,
  selection = selection, started_at = started, elapsed_seconds = unname(elapsed),
  finished_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3%z"), root = root,
  channel = channel, run_path = published$path, run_id = published$run_id,
  result_id = published$result_id, parent_run_id = if (is.null(parent)) NULL else parent$run_id,
  manifest_sha256 = hash(published$manifest_path), checks = checks,
  comparison = comparison,
  runtime_compatibility = published$manifest$result$provenance$runtime_compatibility,
  inputs = published$manifest$result$provenance$inputs)
jsonlite::write_json(report, report_path, pretty = TRUE, auto_unbox = TRUE, null = "null")
message("PASS ", method, " ", mode, " stage=", stage, " workers=", workers,
  " run=", published$run_id, " elapsed=", elapsed)
