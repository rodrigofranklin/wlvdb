# Compare fresh baseline and candidate preparation generations semantically.

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_argument)) {
  stop("Run this harness with Rscript.", call. = FALSE)
}
script_path <- normalizePath(
  sub("^--file=", "", script_argument[[1L]]),
  winslash = "/",
  mustWork = TRUE
)
sys.source(
  file.path(dirname(script_path), "issue13-prep-paper-lib.R"),
  envir = environment(),
  chdir = FALSE
)
sys.source(
  file.path(dirname(script_path), "issue13-evidence-harness", "issue13-lib.R"),
  envir = environment(),
  chdir = FALSE
)
sys.source(
  file.path(dirname(script_path), "issue13-evidence-harness", "issue13-matrix.R"),
  envir = environment(),
  chdir = FALSE
)
sys.source(
  file.path(dirname(script_path), "issue13-preparation-auth-lib.R"),
  envir = environment(),
  chdir = FALSE
)

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 12L) {
  stop(
    paste(
      "Expected: <baseline-root> <candidate-root> <report-dir>",
      "<baseline-commit> <candidate-commit> <chunk-rows>",
      "<baseline-metrics.json> <candidate-metrics.json>",
      "<baseline-execution.json> <candidate-execution.json>",
      "<dependency-library> <prep-fault-plan.json>."
    ),
    call. = FALSE
  )
}

baseline_root <- wlv_gate_normalize_path(arguments[[1L]], "baseline_root")
candidate_root <- wlv_gate_normalize_path(arguments[[2L]], "candidate_root")
report_dir <- arguments[[3L]]
baseline_commit <- arguments[[4L]]
candidate_commit <- arguments[[5L]]
chunk_rows <- suppressWarnings(as.integer(arguments[[6L]]))
baseline_metrics_path <- wlv_gate_normalize_path(
  arguments[[7L]], "baseline_metrics_path"
)
candidate_metrics_path <- wlv_gate_normalize_path(
  arguments[[8L]], "candidate_metrics_path"
)
baseline_execution_path <- wlv_gate_normalize_path(
  arguments[[9L]], "baseline_execution_path"
)
candidate_execution_path <- wlv_gate_normalize_path(
  arguments[[10L]], "candidate_execution_path"
)
dependency_library <- wlv_gate_normalize_path(
  arguments[[11L]], "dependency_library"
)
plan_path <- wlv_gate_normalize_path(arguments[[12L]], "plan_path")
wlv_gate_use_library(dependency_library)
wlv_gate_require_namespaces(c("jsonlite", "openssl", "fst"))

report_dir <- wlv_gate_claim_empty_directory(
  report_dir,
  "preparation comparison report directory"
)
if (wlv_gate_path_within(report_dir, baseline_root) ||
    wlv_gate_path_within(report_dir, candidate_root)) {
  stop("The comparison report directory must be outside both worktrees.",
    call. = FALSE)
}
report_path <- file.path(report_dir, "issue13-preparation-comparison.json")
rule_matrix_path <- normalizePath(
  file.path(dirname(script_path), "issue13-preparation-rule-matrix.json"),
  winslash = "/",
  mustWork = TRUE
)
helper_path <- normalizePath(
  file.path(dirname(script_path), "issue13-prep-paper-lib.R"),
  winslash = "/",
  mustWork = TRUE
)
request <- list(
  schema = "wlv-issue13-preparation-comparison-request/1",
  baseline = list(
    root = baseline_root,
    commit = baseline_commit,
    metrics_path = baseline_metrics_path,
    metrics_sha256 = wlv_gate_sha256(baseline_metrics_path),
    execution_path = baseline_execution_path,
    execution_sha256 = wlv_gate_sha256(baseline_execution_path)
  ),
  candidate = list(
    root = candidate_root,
    commit = candidate_commit,
    metrics_path = candidate_metrics_path,
    metrics_sha256 = wlv_gate_sha256(candidate_metrics_path),
    execution_path = candidate_execution_path,
    execution_sha256 = wlv_gate_sha256(candidate_execution_path)
  ),
  chunk_rows = chunk_rows,
  dependency_library = dependency_library,
  plan_path = plan_path,
  plan_sha256 = wlv_gate_sha256(plan_path),
  rule_matrix_path = rule_matrix_path,
  rule_matrix_sha256 = wlv_gate_sha256(rule_matrix_path),
  producer_path = script_path,
  producer_sha256 = wlv_gate_sha256(script_path),
  helper_path = helper_path,
  helper_sha256 = wlv_gate_sha256(helper_path)
)

report <- list(
  schema = "wlv-issue13-preparation-comparison/2",
  baseline_root = baseline_root,
  candidate_root = candidate_root,
  baseline_commit = baseline_commit,
  candidate_commit = candidate_commit,
  chunk_rows = chunk_rows,
  started_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3%z"),
  status = "running",
  request = request,
  request_sha256 = wlv_gate_json_sha256(request)
)

metric_comparison <- function() {
  baseline <- wlv_gate_prep_authenticate_metrics(
    baseline_metrics_path,
    "baseline",
    baseline_root,
    baseline_commit,
    dependency_library,
    report$plan$records$baseline
  )
  candidate <- wlv_gate_prep_authenticate_metrics(
    candidate_metrics_path,
    "candidate",
    candidate_root,
    candidate_commit,
    dependency_library,
    report$plan$records$candidate
  )
  baseline_identity <- isTRUE(baseline$passed)
  candidate_identity <- isTRUE(candidate$passed)
  baseline_elapsed <- as.double(baseline$elapsed_seconds)
  candidate_elapsed <- as.double(candidate$elapsed_seconds)
  baseline_rss <- as.double(baseline$peak_rss_bytes)
  candidate_rss <- as.double(candidate$peak_rss_bytes)
  elapsed_limit <- baseline_elapsed * 1.2
  rss_allowance <- max(baseline_rss * 0.1, 512 * 1024^2)
  rss_limit <- baseline_rss + rss_allowance
  valid_numbers <- all(is.finite(c(
    baseline_elapsed, candidate_elapsed, baseline_rss, candidate_rss
  ))) && all(c(
    baseline_elapsed, candidate_elapsed, baseline_rss, candidate_rss
  ) >= 0)
  list(
    passed = baseline_identity && candidate_identity && valid_numbers &&
      isTRUE(candidate_elapsed <= elapsed_limit) &&
      isTRUE(candidate_rss <= rss_limit),
    baseline_metrics_path = baseline_metrics_path,
    candidate_metrics_path = candidate_metrics_path,
    baseline_authentication = baseline,
    candidate_authentication = candidate,
    baseline_identity_passed = baseline_identity,
    candidate_identity_passed = candidate_identity,
    numeric_metrics_valid = valid_numbers,
    baseline_elapsed_seconds = baseline_elapsed,
    candidate_elapsed_seconds = candidate_elapsed,
    elapsed_limit_seconds = elapsed_limit,
    elapsed_passed = candidate_elapsed <= elapsed_limit,
    baseline_peak_rss_bytes = baseline_rss,
    candidate_peak_rss_bytes = candidate_rss,
    rss_allowance_bytes = rss_allowance,
    rss_limit_bytes = rss_limit,
    rss_passed = candidate_rss <= rss_limit
  )
}

execution_comparison <- function() {
  baseline <- wlv_gate_prep_authenticate_execution(
    baseline_execution_path,
    "baseline",
    baseline_root,
    baseline_commit,
    report$plan$records$baseline
  )
  candidate <- wlv_gate_prep_authenticate_execution(
    candidate_execution_path,
    "candidate",
    candidate_root,
    candidate_commit,
    report$plan$records$candidate
  )
  baseline_ok <- isTRUE(baseline$passed)
  candidate_ok <- isTRUE(candidate$passed)
  list(
    passed = baseline_ok && candidate_ok,
    baseline_execution_path = baseline_execution_path,
    candidate_execution_path = candidate_execution_path,
    baseline_passed = baseline_ok,
    candidate_passed = candidate_ok,
    baseline_authentication = baseline,
    candidate_authentication = candidate
  )
}

compare_source <- function(source) {
  baseline <- file.path(baseline_root, "source_data", source, "normalized")
  candidate <- file.path(candidate_root, "source_data", source, "normalized")
  baseline_manifest <- wlv_gate_verify_source_manifest(baseline)
  candidate_manifest <- wlv_gate_verify_source_manifest(candidate)
  baseline_manifest_table <- baseline_manifest$table
  candidate_manifest_table <- candidate_manifest$table
  baseline_manifest$table <- NULL
  candidate_manifest$table <- NULL

  csv_names <- c(
    "_normalization_contract.csv",
    "_source_manifest.csv",
    "_unit_contract.csv",
    "countries.csv",
    "demand.csv",
    "sectors.csv"
  )
  csv <- lapply(csv_names, function(name) {
    wlv_gate_compare_csv(
      file.path(baseline, name),
      file.path(candidate, name),
      paste0(source, "/normalized/", name)
    )
  })
  names(csv) <- csv_names
  arrays <- lapply(c("m_io.fst", "sea.fst"), function(name) {
    wlv_gate_compare_fst_array(
      file.path(baseline, name),
      file.path(candidate, name),
      paste0(source, "/normalized/", name),
      chunk_rows = chunk_rows
    )
  })
  names(arrays) <- c("m_io.fst", "sea.fst")
  gfcf <- wlv_gate_compare_rds(
    file.path(baseline, "_gfcf_canonical.rds"),
    file.path(candidate, "_gfcf_canonical.rds"),
    paste0(source, "/normalized/_gfcf_canonical.rds")
  )
  root_labels <- lapply(c("countries.csv", "demand.csv", "sectors.csv"),
    function(name) {
      cross <- wlv_gate_compare_csv(
        file.path(baseline_root, "source_data", source, name),
        file.path(candidate_root, "source_data", source, name),
        paste0(source, "/", name)
      )
      baseline_matches_normalized <- identical(
        wlv_gate_read_character_csv(file.path(
          baseline_root, "source_data", source, name
        )),
        wlv_gate_read_character_csv(file.path(baseline, name))
      )
      candidate_matches_normalized <- identical(
        wlv_gate_read_character_csv(file.path(
          candidate_root, "source_data", source, name
        )),
        wlv_gate_read_character_csv(file.path(candidate, name))
      )
      cross$baseline_matches_normalized <- baseline_matches_normalized
      cross$candidate_matches_normalized <- candidate_matches_normalized
      cross$passed <- isTRUE(cross$passed) && baseline_matches_normalized &&
        candidate_matches_normalized
      cross
    })
  names(root_labels) <- c("countries.csv", "demand.csv", "sectors.csv")

  manifest_tables_identical <- identical(
    baseline_manifest_table,
    candidate_manifest_table
  )
  passed <- isTRUE(baseline_manifest$passed) &&
    isTRUE(candidate_manifest$passed) && manifest_tables_identical &&
    all(vapply(csv, `[[`, logical(1L), "passed")) &&
    all(vapply(arrays, `[[`, logical(1L), "passed")) &&
    isTRUE(gfcf$passed) &&
    all(vapply(root_labels, `[[`, logical(1L), "passed"))
  list(
    source = source,
    passed = passed,
    baseline_manifest = baseline_manifest,
    candidate_manifest = candidate_manifest,
    manifest_tables_identical = manifest_tables_identical,
    csv = csv,
    arrays = arrays,
    gfcf = gfcf,
    root_labels = root_labels
  )
}

main <- function() {
  rule_matrix <- wlv13_json_read(rule_matrix_path, simplify = FALSE)
  expected_modes <- c("preparation_cross_engine", "fault_within_engine")
  if (!identical(rule_matrix$schema,
      "wlv-issue13-preparation-rule-matrix/1") ||
      !identical(names(rule_matrix$comparison_modes), expected_modes) ||
      length(rule_matrix$comparison_modes$preparation_cross_engine$ignored_artifacts) ||
      length(rule_matrix$comparison_modes$fault_within_engine$ignored_artifacts) ||
      !identical(
        rule_matrix$comparison_modes$preparation_cross_engine$numeric_tolerance,
        "none-bitwise"
      )) {
    stop("Preparation/fault rule matrix is incomplete or permissive.",
      call. = FALSE)
  }
  report$rule_matrix <<- list(
    path = rule_matrix_path,
    sha256 = wlv13_sha256_file(rule_matrix_path),
    schema = rule_matrix$schema,
    preparation_rule_ids = vapply(
      rule_matrix$comparison_modes$preparation_cross_engine$rules,
      `[[`, character(1L), "id"
    ),
    fault_rule_ids = vapply(
      rule_matrix$comparison_modes$fault_within_engine$rules,
      `[[`, character(1L), "id"
    )
  )
  report$actual_baseline_commit <<- wlv_gate_assert_commit(
    baseline_root,
    baseline_commit
  )
  report$actual_candidate_commit <<- wlv_gate_assert_commit(
    candidate_root,
    candidate_commit
  )
  report$plan <<- wlv_gate_prep_load_plan(
    plan_path,
    baseline_root,
    candidate_root,
    baseline_commit,
    candidate_commit
  )
  baseline_cache <- wlv_gate_verify_raw_caches(baseline_root)
  candidate_cache <- wlv_gate_verify_raw_caches(candidate_root)
  report$raw_caches <<- list(
    baseline = baseline_cache,
    candidate = candidate_cache,
    identical = identical(baseline_cache$records, candidate_cache$records)
  )
  if (!isTRUE(baseline_cache$passed) || !isTRUE(candidate_cache$passed) ||
      !isTRUE(report$raw_caches$identical)) {
    stop("Official raw cache evidence is incomplete or differs.", call. = FALSE)
  }

  baseline_inventory <- wlv_gate_preparation_inventory(baseline_root)
  candidate_inventory <- wlv_gate_preparation_inventory(candidate_root)
  report$inventory <<- list(
    baseline = baseline_inventory,
    candidate = candidate_inventory,
    identical = identical(baseline_inventory, candidate_inventory)
  )
  if (!isTRUE(baseline_inventory$passed) ||
      !isTRUE(candidate_inventory$passed) ||
      !isTRUE(report$inventory$identical)) {
    stop("Prepared artifact inventory is incomplete, opaque, or different.",
      call. = FALSE)
  }
  report$transaction_state <<- list(
    baseline = wlv_gate_prep_transaction_state(baseline_root),
    candidate = wlv_gate_prep_transaction_state(candidate_root)
  )
  report$transaction_state$passed <<- all(vapply(
    report$transaction_state[c("baseline", "candidate")],
    `[[`, logical(1L), "passed"
  ))
  if (!isTRUE(report$transaction_state$passed)) {
    stop("Preparation left staging entries or locks behind.", call. = FALSE)
  }

  sources <- lapply(c("wiodr13", "wiodr16"), compare_source)
  names(sources) <- c("wiodr13", "wiodr16")
  report$sources <<- sources

  euklems_names <- sort(setdiff(
    wlv_gate_expected_euklems_artifacts(),
    c("Statistical_Capital.rds", "Statistical_National-Accounts.rds")
  ), method = "radix")
  euklems <- lapply(euklems_names, function(name) {
    wlv_gate_compare_fst_table(
      file.path(baseline_root, "source_data", "euklems", name),
      file.path(candidate_root, "source_data", "euklems", name),
      paste0("euklems/", name)
    )
  })
  names(euklems) <- euklems_names
  report$euklems <<- list(
    expected_years = 1995:2015,
    expected_series = c("ekk", "ekdeprate"),
    artifact_count = length(euklems),
    passed = all(vapply(euklems, `[[`, logical(1L), "passed")),
    artifacts = euklems
  )
  report$executions <<- execution_comparison()
  report$performance <<- metric_comparison()
  report$finished_at <<- format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3%z")
  report$status <<- if (
    all(vapply(sources, `[[`, logical(1L), "passed")) &&
    isTRUE(report$euklems$passed) &&
    isTRUE(report$transaction_state$passed) &&
    isTRUE(report$executions$passed) &&
    isTRUE(report$performance$passed)
  ) "passed" else "failed"
  if (!identical(report$status, "passed")) {
    report$error <<- "Preparation parity or performance gate failed."
  }
  wlv_gate_write_json(report, report_path)
  if (!identical(report$status, "passed")) {
    stop(report$error, call. = FALSE)
  }
  invisible(report)
}

tryCatch(
  main(),
  error = function(error) {
    report$status <<- "failed"
    report$finished_at <<- format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3%z")
    report$error <<- conditionMessage(error)
    if (!file.exists(report_path) && !dir.exists(report_path)) {
      try(wlv_gate_write_json(report, report_path), silent = TRUE)
    }
    stop(error)
  }
)

cat("Preparation comparison passed:", report_path, "\n")
