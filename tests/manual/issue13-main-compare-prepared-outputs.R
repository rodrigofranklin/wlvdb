# Narrow comparison entrypoint for the three prepared outputs in campaign 054.
#
# The sealed V5 run diagnostics replace the generic `_unit_contract.csv`
# comparator with a run-context comparator. Prepared source inventories do not
# have run contexts. For cross-engine source comparisons only, this entrypoint
# restores the original source comparator for the exact two selected unit
# contract descriptors. Every other comparison function remains the sealed
# upstream implementation.

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE),
  value = TRUE
)
if (!length(script_argument)) stop("Run with Rscript.", call. = FALSE)
wrapper_path <- normalizePath(
  sub("^--file=", "", script_argument[[1L]]),
  winslash = "/", mustWork = TRUE
)

wlv13_main_bootstrap_options <- function(arguments) {
  result <- list()
  index <- 1L
  while (index <= length(arguments)) {
    argument <- arguments[[index]]
    if (!startsWith(argument, "--")) {
      stop(sprintf("Unexpected positional argument: %s.", argument),
        call. = FALSE
      )
    }
    payload <- substring(argument, 3L)
    if (grepl("=", payload, fixed = TRUE)) {
      pieces <- strsplit(payload, "=", fixed = TRUE)[[1L]]
      key <- pieces[[1L]]
      value <- paste(pieces[-1L], collapse = "=")
    } else {
      key <- payload
      index <- index + 1L
      if (index > length(arguments) || startsWith(arguments[[index]], "--")) {
        stop(sprintf("--%s requires a value.", key), call. = FALSE)
      }
      value <- arguments[[index]]
    }
    key <- chartr("-", "_", key)
    if (!nzchar(key) || key %in% names(result)) {
      stop(sprintf("Invalid or duplicate option: --%s.", payload),
        call. = FALSE
      )
    }
    result[[key]] <- value
    index <- index + 1L
  }
  result
}

bootstrap <- wlv13_main_bootstrap_options(commandArgs(trailingOnly = TRUE))
if (!"upstream_path" %in% names(bootstrap)) {
  stop("Missing option: --upstream-path.", call. = FALSE)
}
upstream_path <- normalizePath(
  bootstrap$upstream_path, winslash = "/", mustWork = TRUE
)
if (!identical(basename(upstream_path), "issue13-compare-results.R")) {
  stop("The upstream comparison entrypoint has an unexpected name.",
    call. = FALSE
  )
}
script_dir <- dirname(upstream_path)

sys.source(file.path(script_dir, "issue13-lib.R"), envir = environment())
sys.source(file.path(dirname(script_dir), "issue13-prep-paper-lib.R"),
  envir = environment()
)
sys.source(file.path(script_dir, "issue13-compare-lib.R"),
  envir = environment()
)
sys.source(file.path(script_dir, "issue13-v5-difference-fingerprint.R"),
  envir = environment()
)
sys.source(file.path(script_dir, "issue13-v5-compare-override.R"),
  envir = environment()
)
sys.source(file.path(script_dir, "issue13-v5-diagnostics-override.R"),
  envir = environment()
)

expected_upstream_sha256 <-
  "ce55e0dfe1dfc4ed921cac36cb51a672bdd7cdcc91fae2428ca85b5f354ac922"
expected_primary_sha256 <-
  "ce4da65b3dc9bce57b030aed2328674853b2aa2383b7f745ef991d43c10c5754"
upstream_sha256 <- wlv13_sha256_file(upstream_path)
if (!identical(upstream_sha256, expected_upstream_sha256)) {
  stop("The upstream comparison entrypoint differs from the sealed input.",
    call. = FALSE
  )
}

# Reuse the two selection/context definitions from the exact authenticated
# upstream AST instead of maintaining copies of them here.
upstream_ast <- parse(upstream_path, keep.source = FALSE)
wlv13_main_assignment_name <- function(expression) {
  if (is.call(expression) && identical(expression[[1L]], as.name("<-")) &&
      is.symbol(expression[[2L]])) {
    return(as.character(expression[[2L]]))
  }
  ""
}
assignment_names <- vapply(upstream_ast, wlv13_main_assignment_name,
  character(1L)
)
for (name in c("wlv13_v5_validate_run_context", "select_output")) {
  selected <- which(assignment_names == name)
  if (length(selected) != 1L) {
    stop(sprintf("The sealed upstream AST lacks one `%s` definition.", name),
      call. = FALSE
    )
  }
  eval(upstream_ast[[selected]], envir = environment())
}

wlv13_main_new_source_dispatch <- function(original, candidate, baseline) {
  if (!is.function(original) || !is.list(candidate) || !is.list(baseline)) {
    stop("Cannot construct the prepared-source comparison dispatch.",
      call. = FALSE
    )
  }
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  dispatch <- function(left, right, name) {
    valid <- identical(name, "_unit_contract.csv") &&
      identical(left, candidate) && identical(right, baseline)
    if (!valid) {
      stop(
        "Prepared-source dispatch received an unbound artifact or direction.",
        call. = FALSE
      )
    }
    state$calls <- state$calls + 1L
    original(left, right, name)
  }
  list(dispatch = dispatch, state = state)
}

wlv13_main_dispatch_selftest <- function() {
  calls <- 0L
  original <- function(left, right, name) {
    calls <<- calls + 1L
    list(summary = list(passed = TRUE, name = name))
  }
  candidate <- list(relative = "_unit_contract.csv", type = "csv",
    role = "contract", path = "C:/candidate/_unit_contract.csv",
    sha256 = paste(rep("a", 64L), collapse = ""))
  baseline <- list(relative = "_unit_contract.csv", type = "csv",
    role = "contract", path = "C:/baseline/_unit_contract.csv",
    sha256 = paste(rep("b", 64L), collapse = ""))
  installed <- wlv13_main_new_source_dispatch(original, candidate, baseline)
  checks <- 0L
  expect_true <- function(value, label) {
    if (!isTRUE(value)) stop(paste("Dispatch self-test failed:", label),
      call. = FALSE
    )
    checks <<- checks + 1L
  }
  expect_error <- function(expression, label) {
    rejected <- tryCatch({
      force(expression)
      FALSE
    }, error = function(error) TRUE)
    expect_true(rejected, label)
  }
  expect_true(isTRUE(installed$dispatch(
    candidate, baseline, "_unit_contract.csv"
  )$summary$passed), "exact descriptors")
  changed <- candidate
  changed$sha256 <- paste(rep("c", 64L), collapse = "")
  expect_error(installed$dispatch(changed, baseline, "_unit_contract.csv"),
    "candidate SHA mutation"
  )
  changed <- candidate
  changed$path <- "C:/other/_unit_contract.csv"
  expect_error(installed$dispatch(changed, baseline, "_unit_contract.csv"),
    "candidate path mutation"
  )
  expect_error(installed$dispatch(baseline, candidate, "_unit_contract.csv"),
    "arm reversal"
  )
  expect_error(installed$dispatch(candidate, baseline, "_scientific_checks.csv"),
    "artifact-name mutation"
  )
  expect_true(identical(installed$state$calls, 1L) && identical(calls, 1L),
    "rejected calls did not reach upstream"
  )
  list(schema = "wlv-issue13-main-prepared-dispatch-selftest/1",
    passed = TRUE, checks = checks)
}

options <- wlv13_parse_cli(commandArgs(trailingOnly = TRUE))
if ("selftest" %in% names(options)) {
  if (!identical(options$selftest, "true")) {
    stop("--selftest accepts only `true`.", call. = FALSE)
  }
  cat(as.character(jsonlite::toJSON(wlv13_main_dispatch_selftest(),
    auto_unbox = TRUE, pretty = TRUE, digits = NA, null = "null"
  )), "\n")
  quit(save = "no", status = 0L, runLast = FALSE)
}

wlv13_cli_required(options, c(
  "upstream_path", "primary_preparation_report_path",
  "candidate_result", "candidate_selector", "baseline_result",
  "baseline_selector", "output", "scenario_id"
))
primary_path <- normalizePath(options$primary_preparation_report_path,
  winslash = "/", mustWork = TRUE
)
primary_sha256 <- wlv13_sha256_file(primary_path)
if (!identical(primary_sha256, expected_primary_sha256)) {
  stop("The primary preparation report differs from its approved proof.",
    call. = FALSE
  )
}
primary <- wlv13_json_read(primary_path, simplify = FALSE)
primary_valid <- is.list(primary) &&
  identical(primary$schema, "wlv-issue13-preparation-comparison/2") &&
  identical(primary$status, "passed") &&
  identical(primary$actual_baseline_commit,
    "e2f4d6dae9a6d35c966b305fabac52e489faa3e7") &&
  identical(primary$actual_candidate_commit,
    "654959715f9484adb15e16946c27ddbc9648ffa2") &&
  identical(primary$raw_caches$identical, TRUE) &&
  identical(primary$inventory$baseline$passed, TRUE) &&
  identical(primary$inventory$candidate$passed, TRUE) &&
  identical(primary$executions$passed, TRUE) &&
  identical(primary$performance$elapsed_passed, TRUE)
if (!primary_valid) {
  stop("The primary preparation report is not an approved exact proof.",
    call. = FALSE
  )
}

for (arm in c("candidate", "baseline")) {
  option_name <- paste0(arm, "_result")
  requested <- normalizePath(options[[option_name]],
    winslash = "/", mustWork = TRUE
  )
  expected <- normalizePath(primary$request[[arm]]$execution_path,
    winslash = "/", mustWork = TRUE
  )
  if (!identical(requested, expected) || !identical(
      wlv13_sha256_file(requested), primary$request[[arm]]$execution_sha256
    )) {
    stop(sprintf("The %s scenario input differs from the primary proof.", arm),
      call. = FALSE
    )
  }
}

allowed <- list(
  `parity/prepare/wiodr13` = c(
    selector = "source:wiodr13", mode = "cross_engine_source_v1"
  ),
  `parity/prepare/wiodr16` = c(
    selector = "source:wiodr16", mode = "cross_engine_source_v1"
  ),
  `parity/prepare/euklems` = c(
    selector = "snapshot:euklems", mode = "strict"
  )
)
comparison_mode <- if ("comparison_mode" %in% names(options)) {
  match.arg(options$comparison_mode, c(
    "strict", "cross_engine_run_v3", "cross_engine_source_v1"
  ))
} else {
  "strict"
}
contract <- allowed[[options$scenario_id]]
if (is.null(contract) ||
    !identical(options$candidate_selector, unname(contract[["selector"]])) ||
    !identical(options$baseline_selector, unname(contract[["selector"]])) ||
    !identical(comparison_mode, unname(contract[["mode"]]))) {
  stop("The prepared-output comparison request is outside its three cases.",
    call. = FALSE
  )
}
chunk_rows <- wlv13_integer(if ("chunk_rows" %in% names(options)) {
  suppressWarnings(as.numeric(options$chunk_rows))
} else {
  1000000
}, "chunk_rows", 1L)

candidate <- select_output(options$candidate_result, options$candidate_selector)
baseline <- select_output(options$baseline_result, options$baseline_selector)
wlv13_v5_comparison_context <- list(
  candidate = candidate$v5_engine_context,
  baseline = baseline$v5_engine_context
)
dispatch_state <- NULL
dispatch_identity <- "strict-unmodified"
if (identical(comparison_mode, "cross_engine_source_v1")) {
  candidate_descriptor <- wlv13_artifact_descriptors(candidate)[[
    "file:_unit_contract.csv"
  ]]
  baseline_descriptor <- wlv13_artifact_descriptors(baseline)[[
    "file:_unit_contract.csv"
  ]]
  if (is.null(candidate_descriptor) || is.null(baseline_descriptor)) {
    stop("A selected source lacks its unit-contract descriptor.", call. = FALSE)
  }
  installed <- wlv13_main_new_source_dispatch(
    wlv13_v5_original_compare_config,
    candidate_descriptor,
    baseline_descriptor
  )
  wlv13_cross_engine_compare_config <- installed$dispatch
  dispatch_state <- installed$state
  dispatch_identity <- "authenticated-source-unit-contract-original-dispatch"
}

output <- wlv13_ensure_dir(options$output, "comparison output")
if (wlv13_is_within(output, candidate$root) ||
    wlv13_is_within(output, baseline$root)) {
  stop("Comparison output must be outside both artifact roots.", call. = FALSE)
}
report <- wlv13_compare_inventories(candidate, baseline, chunk_rows,
  options$scenario_id, comparison_mode = comparison_mode
)
if (!is.null(dispatch_state) && !identical(dispatch_state$calls, 1L)) {
  stop("Prepared-source unit-contract dispatch count changed.", call. = FALSE)
}
wlv13_recheck_inventory(candidate)
wlv13_recheck_inventory(baseline)
report$prepared_outputs_binding <- list(
  schema = "wlv-issue13-main-prepared-outputs-binding/1",
  wrapper_path = wrapper_path,
  wrapper_sha256 = wlv13_sha256_file(wrapper_path),
  upstream_path = upstream_path,
  upstream_sha256 = upstream_sha256,
  primary_preparation_report_path = primary_path,
  primary_preparation_report_sha256 = primary_sha256,
  baseline_execution_sha256 = primary$request$baseline$execution_sha256,
  candidate_execution_sha256 = primary$request$candidate$execution_sha256,
  dispatch = dispatch_identity
)
wlv13_write_comparison_outputs(report, output)
quit(save = "no", status = if (report$passed) 0L else 1L, runLast = FALSE)
