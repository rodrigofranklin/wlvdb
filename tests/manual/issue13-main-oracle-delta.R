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
paths <- vapply(arguments[2:5], normalizePath, character(1L),
  winslash = "/", mustWork = TRUE
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
  inputs = Map(function(path, role) {
    list(role = role, path = path, sha256 = wlv13_sha256_file(path))
  }, paths, c("baseline-oracle", "candidate-oracle", "child-parity", "full-parity"))
)
wlv13_json_write(result, arguments[[7L]])
quit(save = "no", status = if (isTRUE(result$passed)) 0L else 1L,
  runLast = FALSE
)
