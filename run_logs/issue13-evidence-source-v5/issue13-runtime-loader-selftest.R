# Lightweight dual-loader preflight for the cc2 baseline and native candidate.

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_argument)) stop("Run with Rscript.", call. = FALSE)
script_path <- normalizePath(
  sub("^--file=", "", script_argument[[1L]]),
  winslash = "/",
  mustWork = TRUE
)
script_dir <- dirname(script_path)
sys.source(file.path(script_dir, "issue13-prep-paper-lib.R"),
  envir = environment()
)
sys.source(file.path(script_dir, "issue13-evidence-harness", "issue13-lib.R"),
  envir = environment()
)

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 5L) {
  stop(paste(
    "Expected <baseline-root> <baseline-commit> <candidate-root>",
    "<candidate-commit> <dependency-library>."
  ), call. = FALSE)
}
wlv_gate_use_library(arguments[[5L]])
arms <- list(
  baseline = list(root = arguments[[1L]], commit = arguments[[2L]]),
  candidate = list(root = arguments[[3L]], commit = arguments[[4L]])
)
expected_api <- list(
  prepare_wlv = c("methods", "allow_experimental"),
  get_wlv = c(
    "methods", "repeat_pp", "papern", "prepaper", "workers", "channel",
    "allow_experimental"
  ),
  recalc_wlv = c(
    "methods", "at_stage", "sea_vars", "papern", "prepaper", "workers",
    "channel", "allow_experimental"
  )
)
checks <- lapply(names(arms), function(engine) {
  root <- wlv_gate_normalize_path(arms[[engine]]$root, paste(engine, "root"))
  commit <- arms[[engine]]$commit
  if (!identical(wlv13_git_commit(root), commit) ||
      !wlv13_git_runtime_clean(root)) {
    stop(sprintf("%s worktree is not pinned/runtime-clean.", engine),
      call. = FALSE
    )
  }
  wlv_gate_assert_fresh_preparation_root(root)
  working_directory <- getwd()
  search_path <- search()
  loaded <- wlv_gate_load_runtime(root)
  runtime <- loaded$runtime
  signatures <- vapply(names(expected_api), function(name) {
    exists(name, envir = runtime, mode = "function", inherits = FALSE) &&
      identical(names(formals(get(name, envir = runtime, inherits = FALSE))),
        expected_api[[name]]
      )
  }, logical(1L))
  catalog <- if (exists("wlv_runtime_catalog", envir = runtime,
      mode = "function", inherits = FALSE)) {
    runtime$wlv_runtime_catalog()
  } else {
    runtime$method_catalog
  }
  sources <- vapply(c("wiodr13", "wiodr16"), function(method) {
    runtime$wlv_catalog_method(catalog, method)$source[[1L]]
  }, character(1L))
  publication_absent <- is.null(runtime$wlv_read_current_release(
    root,
    channel = "issue13-loader-selftest",
    required = FALSE
  ))
  if (identical(engine, "candidate")) {
    runtime$wlv_assert_loaded_runtime_unchanged()
  }
  passed <- identical(loaded$kind, engine) && all(signatures) &&
    identical(sources, c(wiodr13 = "wiodr13", wiodr16 = "wiodr16")) &&
    publication_absent &&
    identical(getwd(), working_directory) && identical(search(), search_path) &&
    identical(wlv13_git_commit(root), commit) && wlv13_git_runtime_clean(root)
  if (!passed) stop(sprintf("Dual loader self-test failed for `%s`.", engine),
    call. = FALSE
  )
  list(
    engine = engine,
    root = root,
    commit = commit,
    loader_kind = loaded$kind,
    api_signatures = as.list(signatures),
    preparation_sources = as.list(sources),
    publication_probe_absent = publication_absent,
    working_directory_unchanged = TRUE,
    search_path_unchanged = TRUE,
    runtime_clean = TRUE,
    passed = TRUE
  )
})
names(checks) <- names(arms)
report <- list(
  schema = "wlv-issue13-runtime-loader-selftest/1",
  executed_at = wlv13_now(),
  passed = all(vapply(checks, `[[`, logical(1L), "passed")),
  checks = checks
)
report_path <- file.path(script_dir, "issue13-runtime-loader-selftest.json")
wlv_gate_write_json(report, report_path)
cat("Issue #13 dual runtime loader self-test: PASS\n")
cat("  report:", report_path, "\n")
