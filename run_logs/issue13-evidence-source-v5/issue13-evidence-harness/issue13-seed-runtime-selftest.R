# Focused positive/negative checks for the seeder's fail-closed dual loader.

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
sys.source(file.path(script_dir, "issue13-seed-runtime-lib.R"),
  envir = environment()
)

arguments <- commandArgs(trailingOnly = TRUE)
if (!length(arguments) %in% c(4L, 5L)) {
  stop(paste(
    "Expected <baseline-root> <baseline-commit> <candidate-root>",
    "<candidate-commit> [dependency-library]."
  ), call. = FALSE)
}
if (length(arguments) == 5L) wlv_gate_use_library(arguments[[5L]])

expect_error <- function(expression, pattern) {
  observed <- tryCatch({
    force(expression)
    NULL
  }, error = conditionMessage)
  if (is.null(observed) || !grepl(pattern, observed, perl = TRUE)) {
    stop(sprintf("Expected error /%s/, observed: %s.", pattern,
      if (is.null(observed)) "<none>" else observed
    ), call. = FALSE)
  }
  invisible(observed)
}

baseline_root <- wlv13_normalize_existing_dir(arguments[[1L]], "baseline root")
baseline_commit <- wlv13_scalar_text(arguments[[2L]], "baseline commit",
  "^[0-9a-f]{40}$"
)
candidate_root <- wlv13_normalize_existing_dir(arguments[[3L]], "candidate root")
candidate_commit <- wlv13_scalar_text(arguments[[4L]], "candidate commit",
  "^[0-9a-f]{40}$"
)

working_directory <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
search_path <- search()
baseline <- wlv13_load_seed_runtime(baseline_root, baseline_commit)
candidate <- wlv13_load_seed_runtime(candidate_root, candidate_commit)
if (!identical(baseline$kind, "baseline") ||
    !identical(candidate$kind, "candidate")) {
  stop("Positive dual-loader classification failed.", call. = FALSE)
}
baseline$assert_unchanged()
candidate$assert_unchanged()

mutable_name <- wlv13_seed_runtime_required_bindings[[1L]]
original_binding <- get(mutable_name, envir = baseline$runtime, inherits = FALSE)
assign(mutable_name, function(...) NULL, envir = baseline$runtime)
expect_error(baseline$assert_unchanged(), "bindings changed")
assign(mutable_name, original_binding, envir = baseline$runtime)
baseline$assert_unchanged()

temporary_directory <- tempfile("wlv13-seed-loader-cwd-")
if (!dir.create(temporary_directory)) {
  stop("Cannot create loader CWD fixture.", call. = FALSE)
}
previous <- setwd(temporary_directory)
expect_error(baseline$assert_unchanged(), "working directory")
setwd(previous)
baseline$assert_unchanged()

incomplete_root <- tempfile("wlv13-seed-loader-layout-")
if (!dir.create(file.path(incomplete_root, "R", "lib"), recursive = TRUE)) {
  stop("Cannot create incomplete loader fixture.", call. = FALSE)
}
if (!file.create(file.path(incomplete_root, "R", "lib", "functions.R"))) {
  stop("Cannot create incomplete loader definition.", call. = FALSE)
}
expect_error(wlv13_seed_runtime_layout(incomplete_root), "layout is unsupported")

seed_scenario_id <- "baseline/calculate/wiodr13/workers1"
native_seed_report <- list(
  schema = wlv13_schema$scenario,
  scenario_id = seed_scenario_id,
  status = "passed",
  passed = TRUE,
  expected_commit = baseline_commit,
  observed_commit = baseline_commit,
  project_root = baseline_root,
  error = NULL,
  outputs = list(run = list())
)
wlv13_validate_native_seed_report(
  native_seed_report, seed_scenario_id, baseline_root, baseline_commit
)

forbidden_modes <- list(
  imported = "authenticated_import",
  unknown = "historical_copy",
  null = NULL
)
for (name in names(forbidden_modes)) {
  invalid <- native_seed_report
  invalid["execution_mode"] <- list(forbidden_modes[[name]])
  expect_error(
    wlv13_validate_native_seed_report(
      invalid, seed_scenario_id, baseline_root, baseline_commit
    ),
    "forbids imported seed evidence"
  )
}
invalid <- native_seed_report
invalid$authentication <- list(schema = "forbidden-selftest")
expect_error(
  wlv13_validate_native_seed_report(
    invalid, seed_scenario_id, baseline_root, baseline_commit
  ),
  "forbids imported seed evidence"
)
expect_error(
  wlv13_validate_native_seed_report(
    native_seed_report, seed_scenario_id, candidate_root, baseline_commit
  ),
  "belongs to another project root"
)
alternate_commit <- paste0(
  if (substr(baseline_commit, 1L, 1L) == "0") "1" else "0",
  substring(baseline_commit, 2L)
)
expect_error(
  wlv13_validate_native_seed_report(
    native_seed_report, seed_scenario_id, baseline_root, alternate_commit
  ),
  "seed evidence is invalid"
)

if (!wlv13_seed_same_path(getwd(), working_directory) ||
    !identical(search(), search_path)) {
  stop("Loader self-test leaked CWD or search-path state.", call. = FALSE)
}
baseline$assert_unchanged()
candidate$assert_unchanged()
cat("issue13 seed dual-loader self-test: PASS\n")
