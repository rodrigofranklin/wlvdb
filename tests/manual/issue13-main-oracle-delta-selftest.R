# JSON-only regression checks for the reduced oracle architecture profile.
# No scientific payload, run, or publication directory is opened or modified.
arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 3L) {
  stop("Expected <harness-root> <state.json> <output.json>.", call. = FALSE)
}
harness_root <- normalizePath(arguments[[1L]], winslash = "/", mustWork = TRUE)
state_path <- normalizePath(arguments[[2L]], winslash = "/", mustWork = TRUE)
output_path <- normalizePath(arguments[[3L]], winslash = "/", mustWork = FALSE)
if (file.exists(output_path)) stop("Selftest output already exists.", call. = FALSE)
script_argument <- grep("^--file=", commandArgs(FALSE), value = TRUE)
if (length(script_argument) != 1L) stop("Run this selftest with Rscript.")
script_path <- normalizePath(sub("^--file=", "", script_argument),
  winslash = "/", mustWork = TRUE)
wrapper_path <- file.path(dirname(script_path), "issue13-main-oracle-delta.R")

sha_file <- function(path) {
  connection <- file(path, open = "rb")
  on.exit(close(connection), add = TRUE)
  paste0(tolower(as.character(openssl::sha256(connection))), collapse = "")
}
read_json <- function(path) jsonlite::read_json(path, simplifyVector = FALSE)
assert_hash <- function(path, expected) {
  if (!is.character(expected) || length(expected) != 1L || is.na(expected) ||
      !grepl("^[0-9a-f]{64}$", expected) || !identical(sha_file(path), expected)) {
    stop(sprintf("Authenticated JSON/tooling input changed: %s.", path), call. = FALSE)
  }
  invisible(TRUE)
}
state_sha <- sha_file(state_path)
state <- read_json(state_path)
if (!identical(state$schema, "wlv-issue13-main-state/1")) stop("Invalid scientific state.")
assert_hash(state$config_path, state$config_sha256)
assert_hash(state$tooling_binding_path, state$tooling_binding_sha256)
binding <- read_json(state$tooling_binding_path)
namespace <- new.env(parent = baseenv())
library_records <- lapply(c("issue13-lib.R", "issue13-v5-aggregate-hardening.R"), function(name) {
  matches <- Filter(function(record) identical(record$name, name), binding$harness_records)
  if (length(matches) != 1L) stop("Frozen library coverage differs.")
  record <- matches[[1L]]
  path <- normalizePath(file.path(harness_root, name), winslash = "/", mustWork = TRUE)
  if (!identical(path, normalizePath(record$path, winslash = "/", mustWork = TRUE))) {
    stop("The requested harness does not own the frozen library.")
  }
  assert_hash(path, record$sha256)
  sys.source(path, envir = namespace)
  list(path = path, sha256 = record$sha256)
})
original_projection <- namespace$wlv13_v5_oracle_delta_projection
original_artifact_delta <- namespace$wlv13_v5_oracle_artifact_delta
untouched_names <- c("wlv13_v5_compare_oracle_deltas", "wlv13_v5_oracle_delta_sha256",
  "wlv13_v5_canonical_json",
  "wlv13_v5_source_provenance_architecture_proof")
untouched <- lapply(untouched_names, function(name) get(name, namespace))
names(untouched) <- untouched_names
wrapper_sha <- sha_file(wrapper_path)
expressions <- parse(wrapper_path, keep.source = FALSE)
for (name in c("wlv13_main_oracle_architecture_proof", "wlv13_main_oracle_artifact_delta",
    "wlv13_main_oracle_delta_projection")) {
  definitions <- Filter(function(value) is.call(value) && length(value) == 3L &&
      identical(value[[1L]], as.name("<-")) && identical(value[[2L]], as.name(name)) &&
      is.call(value[[3L]]) && identical(value[[3L]][[1L]], as.name("function")),
    as.list(expressions))
  if (length(definitions) != 1L) stop(sprintf("Expected one definition of %s.", name))
  eval(definitions[[1L]], envir = namespace)
}
namespace$wlv13_v5_oracle_architecture_proof <- namespace$wlv13_main_oracle_architecture_proof
namespace$wlv13_v5_oracle_artifact_delta <- namespace$wlv13_main_oracle_artifact_delta
namespace$wlv13_v5_oracle_delta_projection <-
  namespace$wlv13_main_oracle_delta_projection(original_projection)

checks <- list()
check <- function(id, action, negative = FALSE) {
  failure <- NULL
  value <- tryCatch(action(), error = function(error) {
    failure <<- conditionMessage(error)
    NULL
  })
  passed <- if (negative) !is.null(failure) ||
    (is.list(value) && identical(value$passed, FALSE)) else
    is.null(failure) && isTRUE(value)
  checks[[length(checks) + 1L]] <<- list(id = id, passed = passed,
    expected = if (negative) "rejected-or-delta-mismatch" else "passed",
    error = failure)
  invisible(passed)
}

# Independently constrain the factory to the single architecture_spec literal.
old_spec <- quote(list(
  `file:_nonfinite_resolution_diagnostics.csv` = list(type = "csv", role = "diagnostic",
    comparison_mode = "unordered-row-multiset"),
  `file:_runtime_resources.rds` = list(type = "rds", role = "metadata", comparison_mode = NULL)
))
new_spec <- quote(list(
  `file:_runtime_resources.rds` = list(type = "rds", role = "metadata", comparison_mode = NULL)
))
replace_spec <- function(expression, expected, replacement) {
  count <- 0L
  visit <- function(value) {
    if (!is.call(value)) return(value)
    if (length(value) == 3L && identical(value[[1L]], as.name("<-")) &&
        identical(value[[2L]], as.name("architecture_spec"))) {
      if (!identical(value[[3L]], expected)) stop("Unexpected architecture_spec literal.")
      count <<- count + 1L
      value[[3L]] <- replacement
      return(value)
    }
    # Preserve literal NULL slots (including nested function source slots):
    # assigning NULL through [[<- deletes the slot and changes the reference AST.
    for (index in seq_along(value)) value[index] <- list(visit(value[[index]]))
    value
  }
  result <- visit(expression)
  if (count != 1L) stop("architecture_spec must have exactly one assignment.")
  result
}
reference_projection <- original_projection
body(reference_projection) <- replace_spec(body(original_projection), old_spec, new_spec)
check("factory-changes-only-the-architecture-spec-literal", function() {
  factory_environment <- environment(namespace$wlv13_v5_oracle_delta_projection)
  candidates <- mget(ls(factory_environment, all.names = TRUE), factory_environment,
    inherits = FALSE)
  matches <- Filter(function(value) is.function(value) &&
      identical(formals(value), formals(original_projection)) &&
      identical(body(value), body(reference_projection)) &&
      identical(environment(value), environment(original_projection)), candidates)
  length(matches) == 1L
})
check("factory-rejects-an-already-reduced-projection", function() {
  namespace$wlv13_main_oracle_delta_projection(reference_projection)
}, negative = TRUE)
check("factory-rejects-duplicate-spec-assignments", function() {
  duplicate <- original_projection
  body(duplicate) <- as.call(c(as.list(body(duplicate)),
    list(call("<-", as.name("architecture_spec"), old_spec))))
  namespace$wlv13_main_oracle_delta_projection(duplicate)
}, negative = TRUE)

authenticated <- list()
read_comparison <- function(id, parity) {
  matches <- Filter(function(record) identical(record$id, id), state$comparisons)
  if (length(matches) != 1L) stop(sprintf("Missing comparison: %s.", id))
  record <- matches[[1L]]
  attempts <- Filter(function(attempt) identical(attempt$status, "passed"), record$attempts)
  if (!identical(record$status, "passed") || length(attempts) != 1L) {
    stop(sprintf("Comparison is not an unambiguous completed proof: %s.", id))
  }
  attempt <- attempts[[1L]]
  assert_hash(attempt$job_path, attempt$job_sha256)
  assert_hash(attempt$result_path, attempt$result_sha256)
  job <- read_json(attempt$job_path)
  outcome <- read_json(attempt$result_path)
  path <- file.path(record$output_directory, "comparison.json")
  assert_hash(path, record$comparison_sha256)
  report <- read_json(path)
  expected_mode <- if (parity) "cross_engine_run_v3" else "strict"
  if (!identical(job$comparison_id, id) || !identical(outcome$comparison_id, id) ||
      !identical(outcome$status, "passed") || !identical(outcome$passed, TRUE) ||
      !identical(outcome$job_sha256, attempt$job_sha256) ||
      !identical(outcome$comparison_sha256, record$comparison_sha256) ||
      !identical(report$schema, "wlv-issue13-artifact-comparison/1") ||
      !identical(report$scenario_id, id) || !identical(report$comparison_mode, expected_mode) ||
      !identical(job$mode, expected_mode) || !identical(job$allow_difference, !parity) ||
      !identical(report$passed, record$passed) ||
      !identical(report$passed, outcome$comparison_passed) ||
      (parity && !identical(report$passed, TRUE))) {
    stop(sprintf("Comparison envelope is not authenticated: %s.", id))
  }
  authenticated[[id]] <<- list(id = id, path = path, sha256 = record$comparison_sha256,
    job_path = attempt$job_path, job_sha256 = attempt$job_sha256,
    outcome_path = attempt$result_path, outcome_sha256 = attempt$result_sha256)
  report
}
phases <- unlist(lapply(c("wiodr13", "wiodr16"), function(method) paste0(
  "recalculate/", method, "/", c("stage1/full", "stage4/full", "stage5/full",
    "stage4/select-gross-output-mv", "stage5/select-gross-output-du")
)), use.names = FALSE)
quartets <- lapply(phases, function(phase) {
  method <- strsplit(phase, "/", fixed = TRUE)[[1L]][[2L]]
  list(baseline = read_comparison(paste0("oracle/baseline/", phase), FALSE),
    candidate = read_comparison(paste0("oracle/candidate/", phase), FALSE),
    child = read_comparison(paste0("parity/", phase), TRUE),
    full = read_comparison(paste0("parity/calculate/", method, "/workers1"), TRUE))
})
names(quartets) <- phases
run_delta <- function(quartet) namespace$wlv13_v5_compare_oracle_deltas(
  quartet$baseline, quartet$candidate, quartet[c("child", "full")])
positive_results <- list()
for (phase in phases) {
  quartet <- quartets[[phase]]
  check(paste0("real-quartet/", phase), function() {
    delta <- run_delta(quartet)
    proofs <- quartet[c("child", "full")]
    keys <- sort(unique(unlist(lapply(c("child", "full"), function(side) {
      endpoint <- if (side == "child") quartet$candidate$candidate else quartet$candidate$baseline
      namespace$wlv13_main_oracle_architecture_proof(proofs[[side]], endpoint$inventory_sha256,
        namespace$wlv13_v5_oracle_identity_core(endpoint$identity, side))
    }), use.names = FALSE)), method = "radix")
    baseline <- reference_projection(quartet$baseline, "baseline", projected_keys = keys)
    candidate <- reference_projection(quartet$candidate, "candidate", proofs, keys)
    exact <- identical(delta$passed, TRUE) && identical(baseline, candidate) &&
      identical(delta$baseline_sha256, namespace$wlv13_v5_oracle_delta_sha256(baseline)) &&
      identical(delta$candidate_sha256, namespace$wlv13_v5_oracle_delta_sha256(candidate))
    positive_results[[phase]] <<- list(phase = phase, passed = exact, delta = delta,
      classification = if (!isTRUE(delta$passed)) "oracle-mismatch" else
        if (isTRUE(delta$baseline_passed)) "exact-to-full" else "baseline-known-divergence")
    exact
  })
}

mutate <- function(id, target, change, phase = phases[[1L]]) {
  check(id, function() {
    quartet <- quartets[[phase]]
    quartet[[target]] <- change(quartet[[target]])
    run_delta(quartet)
  }, negative = TRUE)
}
artifact_index <- function(report, key = "array:m_countries") {
  matches <- which(vapply(report$artifacts, function(value) identical(value$key, key), logical(1L)))
  if (length(matches) != 1L) stop("Synthetic mutation target is absent or duplicated.")
  matches[[1L]]
}
mutate("wrong-endpoint-inventory", "child", function(x) {
  x$candidate$inventory_sha256 <- strrep("0", 64L); x
})
mutate("wrong-endpoint-identity", "child", function(x) {
  x$candidate$identity$method <- "wiodr16"; x
})
mutate("invalid-output-contract", "candidate", function(x) {
  x$candidate$identity$output_contract$version <- "9.0.0"; x
})
mutate("unexpected-oracle-envelope-field", "candidate", function(x) { x$unexpected <- TRUE; x })
mutate("invalid-oracle-passed-type", "candidate", function(x) { x$passed <- "false"; x })
mutate("missing-scientific-artifact", "candidate", function(x) {
  x$artifacts <- x$artifacts[-artifact_index(x)]; x$artifact_count <- length(x$artifacts); x
})
mutate("duplicate-scientific-key", "candidate", function(x) {
  x$artifacts <- c(x$artifacts, x$artifacts[artifact_index(x)]); x$artifact_count <- length(x$artifacts); x
})
mutate("invalid-scientific-key", "candidate", function(x) {
  x$artifacts[[artifact_index(x)]]$key <- ""; x
})
mutate("scientific-artifact-mismatch", "candidate", function(x) {
  x$artifacts[[artifact_index(x)]]$passed <- FALSE; x$passed <- FALSE; x$status <- "failed"; x
})
check("empty-delta-ignores-only-valid-endpoint-fingerprint-differences", function() {
  quartet <- quartets[[1L]]
  index <- artifact_index(quartet$candidate)
  artifact <- quartet$candidate$artifacts[[index]]
  if (!identical(artifact$passed, TRUE)) stop("Expected a real empty array delta.")
  changed <- artifact
  changed$difference_sha256 <- if (identical(artifact$difference_sha256, strrep("0", 64L)))
    strrep("1", 64L) else strrep("0", 64L)
  quartet$candidate$artifacts[[index]] <- changed
  original <- original_artifact_delta(artifact)
  expected <- original; expected$difference_sha256 <- NULL
  identical(namespace$wlv13_v5_oracle_artifact_delta(artifact), expected) &&
    identical(namespace$wlv13_v5_oracle_artifact_delta(changed), expected) &&
    identical(run_delta(quartet)$passed, TRUE)
})
mutate("missing-scientific-fingerprint", "candidate", function(x) {
  x$artifacts[[artifact_index(x)]]$difference_sha256 <- NULL; x
})
mutate("extra-declared-architecture", "child", function(x) {
  key <- "array:m_countries"; x$artifacts[[artifact_index(x, key)]]$architecture_difference <- TRUE
  x$architecture_differences <- c(x$architecture_differences, list(key)); x
})
mutate("removed-runtime-architecture", "child", function(x) {
  key <- "file:_runtime_resources.rds"; x$artifacts <- x$artifacts[-artifact_index(x, key)]
  x$artifact_count <- length(x$artifacts); x
})
mutate("missing-source-architecture-declaration", "child", function(x) {
  x$architecture_differences <- Filter(function(key) key != "file:_source_provenance.csv",
    x$architecture_differences); x
})
mutate("wrong-source-provenance-binding", "child", function(x) {
  x$artifacts[[artifact_index(x, "file:_source_provenance.csv")]]$candidate_run_manifest_sha256 <- strrep("0", 64L); x
})
add_nonfinite <- function(x) {
  value <- x$artifacts[[artifact_index(x, "file:_runtime_resources.rds")]]
  value$key <- "file:_nonfinite_resolution_diagnostics.csv"; value$type <- "csv"
  value$candidate_path <- "_nonfinite_resolution_diagnostics.csv"
  x$artifacts <- c(x$artifacts, list(value)); x$artifact_count <- length(x$artifacts); x
}
mutate("unexpected-nonfinite-in-endpoint", "child", add_nonfinite)
mutate("unexpected-nonfinite-in-oracle", "candidate", add_nonfinite)
check("unsupported-experimental-method", function() {
  quartet <- quartets[[1L]]; identity <- quartet$candidate$candidate$identity
  identity$method <- "alternative_1"; quartet$child$candidate$identity$method <- identity$method
  namespace$wlv13_main_oracle_architecture_proof(quartet$child,
    quartet$child$candidate$inventory_sha256,
    namespace$wlv13_v5_oracle_identity_core(identity, "unsupported"))
}, negative = TRUE)
check("invalid-architecture-endpoint-keys", function() {
  quartet <- quartets[[1L]]
  namespace$wlv13_v5_compare_oracle_deltas(quartet$baseline, quartet$candidate,
    c(quartet[c("child", "full")], list(unexpected = quartet$full)))
}, negative = TRUE)

scientific_phase <- "recalculate/wiodr13/stage4/full"
for (key in c("array:sea_countries", "array:sea_sectors")) {
  check(paste0("failed-fst-fingerprint-preserved/", key), function() {
    artifact <- quartets[[scientific_phase]]$candidate$artifacts[[
      artifact_index(quartets[[scientific_phase]]$candidate, key)]]
    identical(artifact$passed, FALSE) &&
      identical(namespace$wlv13_v5_oracle_artifact_delta(artifact), original_artifact_delta(artifact))
  })
  mutate(paste0("changed-failed-scientific-fingerprint/", key), "candidate", function(x) {
    index <- artifact_index(x, key)
    x$artifacts[[index]]$difference_sha256 <- if (
      identical(x$artifacts[[index]]$difference_sha256, strrep("0", 64L)))
      strrep("1", 64L) else strrep("0", 64L)
    x
  }, scientific_phase)
}
empty_array <- quartets[[1L]]$candidate$artifacts[[artifact_index(quartets[[1L]]$candidate)]]
bad_fields <- list(
  invalid_fingerprint = list(difference_sha256 = "not-a-sha256"),
  missing_fingerprint = list(difference_sha256 = NULL),
  invalid_verdict = list(passed = "true"),
  false_dimensions = list(same_dimensions = FALSE),
  false_dimnames = list(same_dimnames = FALSE),
  false_payload_schema = list(same_payload_schema = FALSE),
  nonboolean_structure = list(same_dimnames = "true"),
  false_role = list(role_match = FALSE),
  false_metadata_role = list(meta_role_match = FALSE),
  missing_count = list(mismatch_count = NULL),
  nonnumeric_count = list(mismatch_count = "0"),
  nonzero_count_without_tolerance = list(mismatch_count = 1e-20),
  NA_count = list(mismatch_count = NA_real_),
  NaN_count = list(mismatch_count = NaN),
  infinite_count = list(mismatch_count = Inf),
  mismatch_coordinate = list(first_mismatch_coordinate = "1,1"),
  candidate_state = list(first_candidate_state = "NA"),
  baseline_state = list(first_baseline_state = "NaN"),
  candidate_value = list(first_candidate_value = "0"),
  baseline_value = list(first_baseline_value = "1"),
  nonzero_maximum_without_tolerance = list(maximum_absolute_difference = 1e-20),
  NA_maximum = list(maximum_absolute_difference = NA_real_),
  infinite_maximum = list(maximum_absolute_difference = Inf)
)
for (id in names(bad_fields)) {
  check(paste0("passed-fst-array-rejects/", id), function() {
    artifact <- empty_array
    for (field in names(bad_fields[[id]])) artifact[field] <- bad_fields[[id]][field]
    namespace$wlv13_v5_oracle_artifact_delta(artifact)
  }, negative = TRUE)
}
# A descriptor-only table exercises the other FST branch without reading a payload.
empty_table <- list(key = "file:synthetic.fst", type = "fst_table", passed = TRUE,
  role_match = TRUE, same_rows = TRUE, same_columns = TRUE, same_types = TRUE,
  mismatch_count = 0, first_mismatch_coordinate = "", difference_sha256 = strrep("0", 64L))
check("passed-fst-table-omits-only-its-empty-delta-fingerprint", function() {
  expected <- original_artifact_delta(empty_table); expected$difference_sha256 <- NULL
  identical(namespace$wlv13_v5_oracle_artifact_delta(empty_table), expected)
})
for (field in c("same_rows", "same_columns", "same_types")) {
  check(paste0("passed-fst-table-rejects/", field), function() {
    artifact <- empty_table; artifact[[field]] <- FALSE
    namespace$wlv13_v5_oracle_artifact_delta(artifact)
  }, negative = TRUE)
}
check("non-fst-artifact-projections-remain-identical", function() {
  artifacts <- unlist(lapply(quartets, function(quartet) {
    Filter(function(artifact) !(artifact$type %in% c("fst_array", "fst_table")),
      quartet$candidate$artifacts)
  }), recursive = FALSE)
  length(artifacts) > 0L && all(vapply(artifacts, function(artifact) {
    identical(namespace$wlv13_v5_oracle_artifact_delta(artifact), original_artifact_delta(artifact))
  }, logical(1L)))
})
na_rows <- which(vapply(quartets[[scientific_phase]]$candidate$transitions,
  function(row) identical(row$candidate_state, "NA"), logical(1L)))
if (length(na_rows)) {
  mutate("NA-to-NaN-transition-mismatch", "candidate", function(x) {
    x$transitions[[na_rows[[1L]]]]$candidate_state <- "NaN"; x
  }, scientific_phase)
  mutate("missingness-count-mismatch", "candidate", function(x) {
    x$transitions[[na_rows[[1L]]]]$count <- x$transitions[[na_rows[[1L]]]]$count + 1; x
  }, scientific_phase)
}
if (length(quartets[[scientific_phase]]$candidate$indicator_differences)) {
  mutate("indicator-difference-mismatch", "candidate", function(x) {
    x$indicator_differences[[1L]]$mismatch_count <- x$indicator_differences[[1L]]$mismatch_count + 1; x
  }, scientific_phase)
}
check("scientific-projection-fingerprint-functions-unchanged", function() {
  all(vapply(untouched_names, function(name) {
    identical(get(name, namespace), untouched[[name]])
  }, logical(1L)))
})
check("real-wrapper-cli-emits-four-array-inputs", function() {
  phase <- phases[[1L]]
  ids <- c(paste0("oracle/baseline/", phase), paste0("oracle/candidate/", phase),
    paste0("parity/", phase), "parity/calculate/wiodr13/workers1")
  paths <- vapply(ids, function(id) authenticated[[id]]$path, character(1L),
    USE.NAMES = FALSE)
  cli_output <- file.path(dirname(output_path), "wrapper-cli.json")
  rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows")
    "Rscript.exe" else "Rscript")
  status <- system2(rscript,
    c("--vanilla", shQuote(c(wrapper_path, harness_root, paths,
      "oracle-delta/selftest-cli", cli_output))),
    stdout = file.path(dirname(output_path), "wrapper-cli.stdout.log"),
    stderr = file.path(dirname(output_path), "wrapper-cli.stderr.log"), timeout = 60)
  if (status != 0L || !file.exists(cli_output)) stop("Oracle wrapper CLI failed.")
  value <- read_json(cli_output)
  roles <- c("baseline-oracle", "candidate-oracle", "child-parity", "full-parity")
  identical(value$schema, "wlv-issue13-main-oracle-delta/1") &&
    identical(value$id, "oracle-delta/selftest-cli") && identical(value$passed, TRUE) &&
    is.list(value$inputs) && length(value$inputs) == 4L && is.null(names(value$inputs)) &&
    all(vapply(seq_along(paths), function(index) {
      input <- value$inputs[[index]]
      identical(input$role, roles[[index]]) &&
        identical(input$path, normalizePath(paths[[index]], winslash = "/")) &&
        identical(input$sha256, authenticated[[ids[[index]]]]$sha256)
    }, logical(1L)))
})
check("all-input-json-and-library-hashes-remain-unchanged", function() {
  assert_hash(state_path, state_sha); assert_hash(wrapper_path, wrapper_sha)
  for (record in library_records) assert_hash(record$path, record$sha256)
  for (record in authenticated) {
    assert_hash(record$path, record$sha256); assert_hash(record$job_path, record$job_sha256)
    assert_hash(record$outcome_path, record$outcome_sha256)
  }
  TRUE
})
passed <- all(vapply(checks, `[[`, logical(1L), "passed")) && length(positive_results) == 10L
result <- list(schema = "wlv-issue13-main-oracle-delta-selftest/1", passed = passed,
  status = if (passed) "passed" else "failed", payloads_opened = 0L,
  scientific_runs_executed = 0L, source_state = list(path = state_path, sha256 = state_sha),
  wrapper = list(path = wrapper_path, sha256 = wrapper_sha), libraries = library_records,
  authenticated_comparisons = unname(authenticated), real_quartets = unname(positive_results),
  represented_missingness_checks = length(na_rows) > 0L,
  represented_indicator_checks = length(quartets[[scientific_phase]]$candidate$indicator_differences) > 0L,
  checks = checks)
namespace$wlv13_json_write(result, output_path)
cat(sprintf("oracle-delta-selftest=%s\npassed=%s\nchecks=%d\n",
  output_path, passed, length(checks)))
quit(save = "no", status = if (passed) 0L else 1L, runLast = FALSE)
