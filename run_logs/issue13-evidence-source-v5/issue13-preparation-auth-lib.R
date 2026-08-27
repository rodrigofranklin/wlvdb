# Authentication and transactional-cleanliness checks for issue #13 preparation.
# Source issue13-prep-paper-lib.R and issue13-evidence-harness/issue13-lib.R first.

wlv_gate_prep_text <- function(value) {
  if (is.null(value)) return(character())
  enc2utf8(as.character(unlist(value, use.names = FALSE)))
}

wlv_gate_prep_require <- function(condition, message) {
  if (!isTRUE(condition)) stop(message, call. = FALSE)
  invisible(TRUE)
}

wlv_gate_prep_same_path <- function(left, right, must_work = TRUE) {
  identical(
    normalizePath(left, winslash = "/", mustWork = must_work),
    normalizePath(right, winslash = "/", mustWork = must_work)
  )
}

wlv_gate_prep_transaction_state <- function(root) {
  source_root <- file.path(root, "source_data")
  staging_root <- file.path(source_root, ".preparation-staging")
  staging <- if (dir.exists(staging_root)) {
    sort(list.files(
      staging_root,
      all.files = TRUE,
      no.. = TRUE,
      recursive = TRUE,
      include.dirs = TRUE,
      full.names = FALSE
    ), method = "radix")
  } else {
    character()
  }
  locks <- if (dir.exists(source_root)) {
    sort(list.files(
      source_root,
      pattern = "^[.]prepare-lock-",
      all.files = TRUE,
      no.. = TRUE,
      include.dirs = TRUE,
      full.names = FALSE
    ), method = "radix")
  } else {
    character()
  }
  list(
    passed = !length(staging) && !length(locks),
    staging_root = normalizePath(staging_root, winslash = "/", mustWork = FALSE),
    staging_entries = as.list(staging),
    locks = as.list(locks)
  )
}

wlv_gate_prep_load_plan <- function(
    plan_path,
    baseline_root,
    candidate_root,
    baseline_commit,
    candidate_commit) {
  plan_path <- normalizePath(plan_path, winslash = "/", mustWork = TRUE)
  audit_path <- normalizePath(
    file.path(dirname(plan_path), "plan-audit.json"),
    winslash = "/",
    mustWork = TRUE
  )
  plan <- wlv13_json_read(plan_path, simplify = FALSE)
  audit <- wlv13_json_read(audit_path, simplify = FALSE)
  expected_ids <- c(
    "baseline/prepare/all",
    "candidate/prepare/all",
    paste0("candidate/fault/", wlv13_fault_names)
  )
  wlv_gate_prep_require(
    is.list(plan) &&
      identical(plan$schema, "wlv-issue13-prep-fault-plan/2") &&
      identical(plan$execution_started, FALSE) &&
      identical(as.integer(plan$preparation_scenario_count), 2L) &&
      identical(as.integer(plan$fault_scenario_count), 10L) &&
      length(plan$records) == 12L &&
      identical(vapply(plan$records, `[[`, character(1L), "scenario_id"),
        expected_ids
      ),
    "Preparation/fault plan is incomplete or non-normative."
  )
  plan_hash <- wlv13_sha256_file(plan_path)
  wlv_gate_prep_require(
    is.list(audit) &&
      identical(audit$schema, "wlv-issue13-prep-fault-plan-audit/2") &&
      isTRUE(audit$passed) && identical(audit$status, "passed") &&
      wlv_gate_prep_same_path(audit$plan_path, plan_path) &&
      identical(audit$plan_sha256, plan_hash) &&
      identical(as.integer(audit$scenario_count), 12L) &&
      identical(as.integer(audit$preparation_scenario_count), 2L) &&
      identical(as.integer(audit$fault_scenario_count), 10L) &&
      isTRUE(audit$unique_channels) &&
      isTRUE(audit$evidence_directories_absent) &&
      identical(audit$execution_started, FALSE),
    "Preparation/fault preflight audit is missing, stale, or failed."
  )
  roots <- list(
    baseline = list(root = baseline_root, commit = baseline_commit),
    candidate = list(root = candidate_root, commit = candidate_commit)
  )
  for (engine in names(roots)) {
    planned <- plan$roots[[engine]]
    expected <- roots[[engine]]
    wlv_gate_prep_require(
      is.list(planned) &&
        wlv_gate_prep_same_path(planned$root, expected$root) &&
        identical(planned$commit, expected$commit),
      sprintf("Plan root/commit mismatch for `%s`.", engine)
    )
  }
  audited_ids <- vapply(audit$records, `[[`, character(1L), "scenario_id")
  wlv_gate_prep_require(
    identical(audited_ids, expected_ids) &&
      all(vapply(audit$records, function(record) {
        identical(record$status, "passed")
      }, logical(1L))),
    "The audited scenario record set is incomplete or failed."
  )
  wlv_gate_prep_require(
    is.list(plan$harness_files) && length(plan$harness_files) == 17L &&
      identical(
        vapply(plan$harness_files, `[[`, character(1L), "name"),
        vapply(audit$harness_files, `[[`, character(1L), "name")
      ),
    "The authenticated harness file set is incomplete."
  )
  for (index in seq_along(plan$harness_files)) {
    planned <- plan$harness_files[[index]]
    audited_file <- audit$harness_files[[index]]
    wlv_gate_prep_require(
      identical(planned$sha256, audited_file$sha256) &&
        wlv_gate_prep_same_path(planned$path, audited_file$path) &&
        identical(wlv13_sha256_file(planned$path), planned$sha256),
      sprintf("Harness file changed after preflight: `%s`.", planned$name)
    )
  }
  for (index in seq_along(plan$records)) {
    record <- plan$records[[index]]
    audited_record <- audit$records[[index]]
    wlv_gate_prep_require(
      identical(wlv13_sha256_file(record$scenario_spec_path),
        record$scenario_spec_sha256
      ) &&
        identical(wlv13_sha256_file(record$process_spec_path),
          record$process_spec_sha256
        ) &&
        identical(record$scenario_spec_sha256,
          audited_record$scenario_spec_sha256
        ) &&
        identical(record$process_spec_sha256,
          audited_record$process_spec_sha256
        ),
      sprintf("Scenario/process spec changed after preflight for `%s`.",
        record$scenario_id
      )
    )
  }
  cache_checks <- audit$preparation_cache_checks
  wlv_gate_prep_require(
    isTRUE(cache_checks$baseline$passed) &&
      isTRUE(cache_checks$candidate$passed) &&
      identical(cache_checks$baseline$records, cache_checks$candidate$records),
    "Audited official preparation caches are incomplete or differ."
  )
  records <- plan$records[seq_len(2L)]
  names(records) <- c("baseline", "candidate")
  list(
    passed = TRUE,
    plan_path = plan_path,
    plan_sha256 = plan_hash,
    audit_path = audit_path,
    audit_sha256 = wlv13_sha256_file(audit_path),
    records = records
  )
}

wlv_gate_prep_authenticate_metrics <- function(
    metrics_path,
    engine,
    root,
    commit,
    r_library,
    plan_record) {
  metrics_path <- normalizePath(metrics_path, winslash = "/", mustWork = TRUE)
  evidence_dir <- normalizePath(dirname(metrics_path), winslash = "/",
    mustWork = TRUE
  )
  metrics <- wlv13_json_read(metrics_path, simplify = FALSE)
  id <- paste0(engine, "/prepare/all")
  required_metrics <- c(
    "schema", "scenario_id", "status", "passed", "executable",
    "arguments", "working_directory", "root_pid", "exit_code",
    "expected_exit_codes", "exit_code_matched", "timed_out",
    "timeout_seconds", "started_at_utc", "finished_at_utc",
    "elapsed_seconds", "sample_interval_ms", "samples", "peak_rss_bytes",
    "peak_private_bytes", "cumulative_cpu_seconds_peak",
    "max_concurrent_processes", "expected_worker_processes",
    "max_concurrent_worker_processes", "worker_count_matched",
    "cluster_closed", "lingering_pids", "observed_processes",
    "stdout_path", "stderr_path", "stdout_sha256", "stderr_sha256",
    "samples_path", "samples_sha256", "process_spec_path",
    "process_spec_sha256"
  )
  wlv_gate_prep_require(
    is.list(metrics) && setequal(names(metrics), required_metrics) &&
      identical(metrics$schema, "wlv-issue13-process-metrics/2") &&
      identical(metrics$scenario_id, id) &&
      identical(metrics$status, "passed") && isTRUE(metrics$passed) &&
      identical(as.integer(metrics$exit_code), 0L) &&
      identical(as.integer(unlist(metrics$expected_exit_codes)), 0L) &&
      isTRUE(metrics$exit_code_matched) && !isTRUE(metrics$timed_out) &&
      isTRUE(metrics$worker_count_matched) && isTRUE(metrics$cluster_closed) &&
      identical(as.integer(metrics$expected_worker_processes), 0L) &&
      identical(as.integer(metrics$max_concurrent_worker_processes), 0L) &&
      !length(unlist(metrics$lingering_pids, use.names = FALSE)) &&
      is.finite(as.numeric(metrics$elapsed_seconds)) &&
      as.numeric(metrics$elapsed_seconds) > 0 &&
      is.finite(as.numeric(metrics$peak_rss_bytes)) &&
      as.numeric(metrics$peak_rss_bytes) >= 0 &&
      as.integer(metrics$root_pid) > 0L &&
      as.integer(metrics$samples) > 0 &&
      as.integer(metrics$max_concurrent_processes) >= 1L &&
      length(metrics$observed_processes) >= 1L &&
      wlv_gate_prep_same_path(metrics$working_directory, root) &&
      wlv_gate_prep_same_path(plan_record$evidence_directory, evidence_dir),
    sprintf("Process metrics failed for `%s`.", id)
  )
  expected_logs <- list(
    stdout = file.path(evidence_dir, "stdout.log"),
    stderr = file.path(evidence_dir, "stderr.log"),
    samples = file.path(evidence_dir, "process-samples.csv")
  )
  observed_logs <- list(
    stdout = metrics$stdout_path,
    stderr = metrics$stderr_path,
    samples = metrics$samples_path
  )
  observed_hashes <- list(
    stdout = metrics$stdout_sha256,
    stderr = metrics$stderr_sha256,
    samples = metrics$samples_sha256
  )
  for (name in names(expected_logs)) {
    wlv_gate_prep_require(
      wlv_gate_prep_same_path(observed_logs[[name]], expected_logs[[name]]) &&
        identical(wlv13_sha256_file(observed_logs[[name]]),
          observed_hashes[[name]]
        ),
      sprintf("Authenticated `%s` log failed for `%s`.", name, id)
    )
  }
  process_path <- normalizePath(metrics$process_spec_path, winslash = "/",
    mustWork = TRUE
  )
  wlv_gate_prep_require(
    wlv_gate_prep_same_path(process_path, plan_record$process_spec_path) &&
      identical(metrics$process_spec_sha256,
        plan_record$process_spec_sha256
      ) &&
      identical(wlv13_sha256_file(process_path),
        plan_record$process_spec_sha256
      ),
    sprintf("Process spec authentication failed for `%s`.", id)
  )
  process <- wlv13_json_read(process_path, simplify = FALSE)
  scenario_path <- normalizePath(plan_record$scenario_spec_path,
    winslash = "/", mustWork = TRUE
  )
  scenario <- wlv13_json_read(scenario_path, simplify = FALSE)
  arguments <- wlv_gate_prep_text(process$arguments)
  expected_rscript <- normalizePath(
    file.path(R.home("bin"), if (.Platform$OS.type == "windows") {
      "Rscript.exe"
    } else {
      "Rscript"
    }),
    winslash = "/",
    mustWork = TRUE
  )
  expected_scenario_script <- normalizePath(
    file.path(dirname(script_path), "issue13-evidence-harness",
      "issue13-scenario.R"
    ),
    winslash = "/",
    mustWork = TRUE
  )
  wlv_gate_prep_require(
    identical(process$schema, "wlv-issue13-process-spec/1") &&
      identical(process$scenario_id, id) &&
      wlv_gate_prep_same_path(process$executable, expected_rscript) &&
      wlv_gate_prep_same_path(metrics$executable, expected_rscript) &&
      identical(wlv_gate_prep_text(metrics$arguments), arguments) &&
      identical(arguments, c("--vanilla", expected_scenario_script,
        scenario_path, evidence_dir
      )) &&
      wlv_gate_prep_same_path(process$working_directory, root) &&
      identical(as.integer(unlist(process$expected_exit_codes)), 0L) &&
      identical(as.numeric(metrics$timeout_seconds),
        as.numeric(process$timeout_seconds)
      ) &&
      identical(as.integer(metrics$sample_interval_ms),
        as.integer(process$sample_interval_ms)
      ) &&
      identical(as.integer(metrics$expected_worker_processes),
        as.integer(process$expected_worker_processes)
      ) &&
      identical(as.integer(process$expected_worker_processes), 0L) &&
      identical(names(process$environment), c(
        "R_LIBS_USER", "RENV_PATHS_LIBRARY",
        "RENV_CONFIG_AUTO_SNAPSHOT", "RENV_CONFIG_CACHE_ENABLED",
        "RENV_CONFIG_LOCKING_ENABLED",
        "RENV_CONFIG_SANDBOX_ENABLED", "RENV_CONFIG_UPDATES_CHECK",
        "RENV_CONFIG_USER_ENVIRON", "RENV_CONFIG_USER_LIBRARY", "TZ"
      )) &&
      wlv_gate_prep_same_path(process$environment$R_LIBS_USER, r_library) &&
      wlv_gate_prep_same_path(
        process$environment$RENV_PATHS_LIBRARY,
        wlv13_renv_library_root(r_library)
      ) &&
      identical(process$environment$RENV_CONFIG_AUTO_SNAPSHOT, "FALSE") &&
      identical(process$environment$RENV_CONFIG_CACHE_ENABLED, "FALSE") &&
      identical(process$environment$RENV_CONFIG_LOCKING_ENABLED, "FALSE") &&
      identical(process$environment$RENV_CONFIG_SANDBOX_ENABLED, "FALSE") &&
      identical(process$environment$RENV_CONFIG_UPDATES_CHECK, "FALSE") &&
      identical(process$environment$RENV_CONFIG_USER_ENVIRON, "FALSE") &&
      identical(process$environment$RENV_CONFIG_USER_LIBRARY, "FALSE") &&
      identical(process$environment$TZ, "UTC"),
    sprintf("Process binding failed for `%s`.", id)
  )
  wlv_gate_prep_require(
    identical(wlv13_sha256_file(scenario_path),
      plan_record$scenario_spec_sha256
    ) &&
      identical(scenario$schema, "wlv-issue13-scenario/1") &&
      identical(scenario$scenario_id, id) &&
      wlv_gate_prep_same_path(scenario$project_root, root) &&
      identical(scenario$expected_commit, commit) &&
      identical(scenario$kind, "prepare") &&
      identical(wlv_gate_prep_text(scenario$methods),
        c("wiodr13", "wiodr16")
      ) &&
      identical(as.integer(unlist(scenario$euklems_years)),
        as.integer(1995:2015)
      ) &&
      identical(scenario$channel, plan_record$channel) &&
      identical(as.integer(scenario$workers), 1L) &&
      identical(scenario$allow_experimental, FALSE) &&
      identical(scenario$expected_failure, FALSE),
    sprintf("Scenario spec binding failed for `%s`.", id)
  )
  list(
    passed = TRUE,
    schema = metrics$schema,
    scenario_id = id,
    metrics_path = metrics_path,
    process_spec_path = process_path,
    process_spec_sha256 = plan_record$process_spec_sha256,
    scenario_spec_path = scenario_path,
    scenario_spec_sha256 = plan_record$scenario_spec_sha256,
    elapsed_seconds = as.numeric(metrics$elapsed_seconds),
    peak_rss_bytes = as.numeric(metrics$peak_rss_bytes),
    cluster_closed = TRUE,
    worker_count_matched = TRUE,
    authenticated_logs = TRUE
  )
}

wlv_gate_prep_authenticate_execution <- function(
    execution_path,
    engine,
    root,
    commit,
    plan_record) {
  execution_path <- normalizePath(execution_path, winslash = "/",
    mustWork = TRUE
  )
  report <- wlv13_json_read(execution_path, simplify = FALSE)
  id <- paste0(engine, "/prepare/all")
  required_report <- c(
    "schema", "scenario_id", "status", "passed", "kind", "project_root",
    "expected_commit", "observed_commit", "started_at", "finished_at",
    "elapsed_seconds", "request", "outputs", "seed", "publication_before",
    "publication_after", "source_before", "source_after", "error"
  )
  wlv_gate_prep_require(
    is.list(report) && setequal(names(report), required_report) &&
      identical(report$schema, "wlv-issue13-scenario-result/1") &&
      identical(report$scenario_id, id) &&
      identical(report$status, "passed") && isTRUE(report$passed) &&
      identical(report$kind, "prepare") &&
      wlv_gate_prep_same_path(report$project_root, root) &&
      identical(report$expected_commit, commit) &&
      identical(report$observed_commit, commit) &&
      is.null(report$error) && is.null(report$seed) &&
      as.numeric(report$elapsed_seconds) > 0,
    sprintf("Preparation execution identity failed for `%s`.", id)
  )
  request <- report$request
  wlv_gate_prep_require(
    is.list(request) && is.null(request$method) &&
      identical(wlv_gate_prep_text(request$methods),
        c("wiodr13", "wiodr16")
      ) &&
      identical(request$channel, plan_record$channel) &&
      identical(as.integer(request$workers), 1L) &&
      is.null(request$at_stage) && is.null(request$sea_vars) &&
      is.null(request$paper) && identical(request$expected_failure, FALSE),
    sprintf("Preparation request failed for `%s`.", id)
  )
  wlv_gate_prep_require(
    identical(report$publication_before, report$publication_after) &&
      identical(report$publication_before$exists, FALSE) &&
      !length(wlv_gate_prep_text(report$publication_before$staging)),
    sprintf("Preparation unexpectedly changed publication state for `%s`.", id)
  )
  before <- report$source_before
  after <- report$source_after
  before_fresh <- all(vapply(c("wiodr13", "wiodr16"), function(source) {
    identical(before$sources[[source]]$exists, FALSE)
  }, logical(1L))) &&
    !length(wlv_gate_prep_text(before$euklems)) &&
    !length(wlv_gate_prep_text(before$preparation_staging)) &&
    !length(wlv_gate_prep_text(before$preparation_locks))
  after_clean <- all(vapply(c("wiodr13", "wiodr16"), function(source) {
    identical(after$sources[[source]]$exists, TRUE)
  }, logical(1L))) &&
    identical(sort(names(after$euklems), method = "radix"), sort(setdiff(
      wlv_gate_expected_euklems_artifacts(),
      c("Statistical_Capital.rds", "Statistical_National-Accounts.rds")
    ), method = "radix")) &&
    !length(wlv_gate_prep_text(after$preparation_staging)) &&
    !length(wlv_gate_prep_text(after$preparation_locks))
  transaction <- wlv_gate_prep_transaction_state(root)
  wlv_gate_prep_require(before_fresh && after_clean && isTRUE(transaction$passed),
    sprintf("Preparation staging/lock or source-state gate failed for `%s`.", id)
  )
  outputs <- report$outputs
  wlv_gate_prep_require(is.list(outputs) && length(outputs) == 3L,
    sprintf("Preparation outputs are incomplete for `%s`.", id)
  )
  for (index in seq_along(c("wiodr13", "wiodr16"))) {
    source <- c("wiodr13", "wiodr16")[[index]]
    output <- outputs[[index]]
    expected_root <- file.path(root, "source_data", source, "normalized")
    inventory <- wlv13_source_inventory(expected_root)
    wlv_gate_prep_require(
      setequal(names(output), c(
        "kind", "source", "root", "manifest_path", "manifest_sha256",
        "inventory_sha256", "identity"
      )) &&
        identical(output$kind, "source") && identical(output$source, source) &&
        wlv_gate_prep_same_path(output$root, expected_root) &&
        wlv_gate_prep_same_path(output$manifest_path,
          inventory$manifest_path
        ) &&
        identical(output$manifest_sha256, inventory$manifest_sha256) &&
        identical(output$inventory_sha256,
          wlv13_inventory_signature(inventory)
        ) && identical(output$identity, inventory$identity),
      sprintf("Authenticated source output failed for `%s` in `%s`.",
        source, id
      )
    )
  }
  output <- outputs[[3L]]
  snapshot <- wlv13_snapshot_inventory(output$manifest_path)
  expected_euklems <- sort(setdiff(
    wlv_gate_expected_euklems_artifacts(),
    c("Statistical_Capital.rds", "Statistical_National-Accounts.rds")
  ), method = "radix")
  wlv_gate_prep_require(
    setequal(names(output), c(
      "kind", "source", "root", "manifest_path", "manifest_sha256",
      "inventory_sha256", "identity"
    )) &&
      identical(output$kind, "snapshot") &&
      identical(output$source, "euklems") &&
      wlv_gate_prep_same_path(output$root,
        file.path(root, "source_data", "euklems")
      ) &&
      identical(output$manifest_sha256, snapshot$manifest_sha256) &&
      identical(output$inventory_sha256,
        wlv13_inventory_signature(snapshot)
      ) &&
      identical(output$identity, snapshot$identity) &&
      identical(snapshot$records$path, expected_euklems) &&
      all(snapshot$records$role == "euklems_table"),
    sprintf("Authenticated EU KLEMS output failed for `%s`.", id)
  )
  list(
    passed = TRUE,
    schema = report$schema,
    scenario_id = id,
    execution_path = execution_path,
    execution_sha256 = wlv13_sha256_file(execution_path),
    outputs_authenticated = TRUE,
    fresh_seed_verified = TRUE,
    publication_unchanged = TRUE,
    transaction = transaction
  )
}
