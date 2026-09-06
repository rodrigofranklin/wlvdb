# Aggregate the two real preparation gates, the authenticated fault-store
# import, ten channel seeds, and ten transactional failures.

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_argument)) stop("Run with Rscript.", call. = FALSE)
script_path <- normalizePath(
  sub("^--file=", "", script_argument[[1L]]),
  winslash = "/",
  mustWork = TRUE
)
script_dir <- dirname(script_path)
sys.source(file.path(script_dir, "issue13-lib.R"), envir = environment())
sys.source(file.path(script_dir, "issue13-matrix.R"), envir = environment())
sys.source(file.path(dirname(script_dir), "issue13-prep-paper-lib.R"),
  envir = environment()
)
sys.source(file.path(dirname(script_dir), "issue13-preparation-auth-lib.R"),
  envir = environment()
)

options <- wlv13_parse_cli(commandArgs(trailingOnly = TRUE))
wlv13_cli_required(options, c(
  "plan", "preparation_comparison", "import_report", "seed_plan", "output"
))
wlv_gate_require_namespaces(c("jsonlite", "openssl", "fst"))
plan_path <- normalizePath(options$plan, winslash = "/", mustWork = TRUE)
comparison_path <- normalizePath(options$preparation_comparison,
  winslash = "/", mustWork = TRUE
)
import_path <- normalizePath(options$import_report,
  winslash = "/", mustWork = TRUE
)
seed_plan_path <- normalizePath(options$seed_plan,
  winslash = "/", mustWork = TRUE
)
output_requested <- normalizePath(options$output,
  winslash = "/", mustWork = FALSE
)
if (dir.exists(output_requested) || file.exists(output_requested)) {
  stop("Prep/fault aggregate output must not already exist.", call. = FALSE)
}
output <- wlv13_ensure_dir(output_requested, "prep/fault aggregate output")
report_path <- file.path(output, "prep-fault-aggregate.json")
running_path <- file.path(output, "prep-fault-aggregate.running.json")
failed_path <- file.path(output, "prep-fault-aggregate.failed.json")
running <- list(
  schema = "wlv-issue13-prep-fault-aggregate-running/1",
  status = "running",
  passed = FALSE,
  started_at = wlv13_now(),
  plan_path = plan_path,
  plan_sha256 = wlv13_sha256_file(plan_path),
  preparation_comparison_path = comparison_path,
  preparation_comparison_sha256 = wlv13_sha256_file(comparison_path),
  import_report_path = import_path,
  import_report_sha256 = wlv13_sha256_file(import_path),
  seed_plan_path = seed_plan_path,
  seed_plan_sha256 = wlv13_sha256_file(seed_plan_path)
)
wlv13_json_write(running, running_path)
running_path <- normalizePath(running_path, winslash = "/", mustWork = TRUE)
running_sha256 <- wlv13_sha256_file(running_path)
report <- list(
  schema = "wlv-issue13-prep-fault-aggregate/1",
  status = "running",
  passed = FALSE,
  started_at = running$started_at,
  running_marker_path = running_path,
  running_marker_sha256 = running_sha256
)

require_gate <- function(condition, message) {
  if (!isTRUE(condition)) stop(message, call. = FALSE)
  invisible(TRUE)
}

hash_matches <- function(path, expected) {
  tryCatch(
    identical(wlv13_sha256_file(path), expected),
    error = function(error) FALSE
  )
}

authenticate_process <- function(
    metrics_path,
    process_path,
    process_hash,
    scenario_id,
    project_root,
    evidence_directory) {
  metrics_path <- normalizePath(metrics_path, winslash = "/", mustWork = TRUE)
  process_path <- normalizePath(process_path, winslash = "/", mustWork = TRUE)
  evidence_directory <- normalizePath(evidence_directory,
    winslash = "/", mustWork = TRUE
  )
  metrics <- wlv13_json_read(metrics_path, simplify = FALSE)
  process <- wlv13_json_read(process_path, simplify = FALSE)
  process_arguments <- wlv_gate_prep_text(process$arguments)
  expected_logs <- c(
    stdout_path = file.path(evidence_directory, "stdout.log"),
    stderr_path = file.path(evidence_directory, "stderr.log"),
    samples_path = file.path(evidence_directory, "process-samples.csv")
  )
  logs_ok <- all(c(
    hash_matches(metrics$stdout_path, metrics$stdout_sha256),
    hash_matches(metrics$stderr_path, metrics$stderr_sha256),
    hash_matches(metrics$samples_path, metrics$samples_sha256)
  ))
  passed <- identical(metrics$schema, "wlv-issue13-process-metrics/2") &&
    identical(metrics$scenario_id, scenario_id) &&
    identical(metrics$status, "passed") && isTRUE(metrics$passed) &&
    identical(as.integer(metrics$exit_code), 0L) &&
    isTRUE(metrics$exit_code_matched) && !isTRUE(metrics$timed_out) &&
    isTRUE(metrics$worker_count_matched) && isTRUE(metrics$cluster_closed) &&
    identical(as.integer(metrics$expected_worker_processes), 0L) &&
    identical(as.integer(metrics$max_concurrent_worker_processes), 0L) &&
    !length(unlist(metrics$lingering_pids, use.names = FALSE)) &&
    as.numeric(metrics$elapsed_seconds) > 0 &&
    as.numeric(metrics$peak_rss_bytes) >= 0 && logs_ok &&
    wlv_gate_prep_same_path(metrics$working_directory, project_root) &&
    wlv_gate_prep_same_path(dirname(metrics_path), evidence_directory) &&
    wlv_gate_prep_same_path(metrics$stdout_path, expected_logs[["stdout_path"]]) &&
    wlv_gate_prep_same_path(metrics$stderr_path, expected_logs[["stderr_path"]]) &&
    wlv_gate_prep_same_path(metrics$samples_path, expected_logs[["samples_path"]]) &&
    wlv_gate_prep_same_path(metrics$process_spec_path, process_path) &&
    identical(metrics$process_spec_sha256, process_hash) &&
    hash_matches(process_path, process_hash) &&
    identical(process$schema, "wlv-issue13-process-spec/1") &&
    identical(process$scenario_id, scenario_id) &&
    wlv_gate_prep_same_path(process$working_directory, project_root) &&
    length(process_arguments) == 4L &&
    wlv_gate_prep_same_path(process_arguments[[4L]], evidence_directory) &&
    identical(as.integer(process$expected_worker_processes), 0L)
  require_gate(passed,
    sprintf("Process evidence authentication failed for `%s`.", scenario_id)
  )
  list(
    passed = TRUE,
    metrics_path = metrics_path,
    metrics_sha256 = wlv13_sha256_file(metrics_path),
    process_spec_path = process_path,
    process_spec_sha256 = process_hash,
    elapsed_seconds = as.numeric(metrics$elapsed_seconds),
    peak_rss_bytes = as.numeric(metrics$peak_rss_bytes),
    authenticated_logs = TRUE,
    cluster_closed = TRUE
  )
}

main <- function() {
  plan <- wlv13_json_read(plan_path, simplify = FALSE)
  require_gate(
    identical(plan$schema, "wlv-issue13-prep-fault-plan/2") &&
      length(plan$records) == 12L,
    "Preparation/fault plan is invalid."
  )
  roots <- lapply(plan$roots, function(record) {
    wlv13_normalize_existing_dir(record$root, "plan root")
  })
  plan_auth <- wlv_gate_prep_load_plan(
    plan_path,
    roots$baseline,
    roots$candidate,
    plan$roots$baseline$commit,
    plan$roots$candidate$commit
  )
  comparison <- wlv13_json_read(comparison_path, simplify = FALSE)
  require_gate(
    identical(comparison$schema, "wlv-issue13-preparation-comparison/2") &&
      identical(comparison$status, "passed") &&
      identical(comparison$baseline_commit, plan$roots$baseline$commit) &&
      identical(comparison$candidate_commit, plan$roots$candidate$commit) &&
      wlv_gate_prep_same_path(comparison$baseline_root, roots$baseline) &&
      wlv_gate_prep_same_path(comparison$candidate_root, roots$candidate) &&
      identical(comparison$plan$plan_sha256, plan_auth$plan_sha256) &&
      all(vapply(comparison$sources, `[[`, logical(1L), "passed")) &&
      isTRUE(comparison$euklems$passed) &&
      isTRUE(comparison$executions$passed) &&
      isTRUE(comparison$performance$passed) &&
      isTRUE(comparison$transaction_state$passed),
    "Preparation comparison is missing, stale, or failed."
  )

  import <- wlv13_json_read(import_path, simplify = FALSE)
  require_gate(
    identical(import$schema, "wlv-issue13-fault-input-import/1") &&
      identical(import$status, "passed") && isTRUE(import$passed) &&
      identical(import$candidate_commit, plan$roots$fault$commit) &&
      wlv_gate_prep_same_path(import$fault_root, roots$fault) &&
      hash_matches(import$preparation_comparison_path,
        import$preparation_comparison_sha256
      ) &&
      hash_matches(import$seed_source_proof_path,
        import$seed_source_proof_sha256
      ) &&
      hash_matches(import$imported_seed_proof_path,
        import$imported_seed_proof_sha256
      ) && isTRUE(import$source_stores_unchanged),
    "Fault-input import is missing, stale, or failed."
  )

  seed_plan <- wlv13_json_read(seed_plan_path, simplify = FALSE)
  require_gate(
    identical(seed_plan$schema, "wlv-issue13-fault-seed-plan/1") &&
      identical(seed_plan$execution_started, FALSE) &&
      identical(as.integer(seed_plan$record_count), 10L) &&
      length(seed_plan$records) == 10L &&
      identical(seed_plan$source_plan_sha256, plan_auth$plan_sha256) &&
      hash_matches(seed_plan$source_plan_path,
        seed_plan$source_plan_sha256
      ) &&
      hash_matches(seed_plan$source_plan_audit_path,
        seed_plan$source_plan_audit_sha256
      ) &&
      hash_matches(seed_plan$import_report_path,
        seed_plan$import_report_sha256
      ) &&
      hash_matches(seed_plan$imported_seed_proof_path,
        seed_plan$imported_seed_proof_sha256
      ) &&
      wlv_gate_prep_same_path(seed_plan$fault_root, roots$fault) &&
      identical(seed_plan$candidate_commit, plan$roots$fault$commit),
    "Fault seed plan is invalid or changed."
  )
  seed_ids <- paste0("candidate/seed/fault/", wlv13_fault_names)
  require_gate(
    identical(vapply(seed_plan$records, `[[`, character(1L), "scenario_id"),
      seed_ids
    ),
    "Fault seed record set is incomplete or unordered."
  )

  seeds <- lapply(seq_along(seed_plan$records), function(index) {
    record <- seed_plan$records[[index]]
    id <- seed_ids[[index]]
    evidence <- normalizePath(record$evidence_directory,
      winslash = "/", mustWork = TRUE
    )
    seed_result_path <- normalizePath(file.path(evidence, "seed-result.json"),
      winslash = "/", mustWork = TRUE
    )
    seed <- wlv13_json_read(seed_result_path, simplify = FALSE)
    process <- authenticate_process(
      file.path(evidence, "process-metrics.json"),
      record$process_spec_path,
      record$process_spec_sha256,
      id,
      roots$fault,
      evidence
    )
    require_gate(
      hash_matches(record$seed_spec_path, record$seed_spec_sha256) &&
        identical(seed$schema, "wlv-issue13-channel-seed-result/1") &&
        identical(seed$scenario_id, id) && identical(seed$status, "passed") &&
        isTRUE(seed$passed) &&
        wlv_gate_prep_same_path(seed$project_root, roots$fault) &&
        identical(seed$expected_commit, plan$roots$fault$commit) &&
        identical(seed$expected_seed_commit, import$seed_commit) &&
        identical(seed$method, "wiodr13") &&
        identical(seed$channel, record$channel) &&
        identical(seed$run_id, import$run_id) &&
        identical(seed$result_id, import$result_id) &&
        identical(seed$run_manifest_sha256, import$run_manifest_sha256) &&
        identical(seed$run_inventory_sha256, import$run_inventory_sha256) &&
        hash_matches(seed$seed_proof_path, seed$seed_proof_sha256) &&
        identical(seed$seed_proof_sha256,
          import$imported_seed_proof_sha256
        ) &&
        hash_matches(seed$release_manifest_path,
          seed$release_manifest_sha256
        ) && hash_matches(seed$marker_path, seed$marker_sha256),
      sprintf("Fault channel seed failed authentication for `%s`.", id)
    )
    list(
      scenario_id = id,
      fault_id = wlv13_fault_names[[index]],
      channel = record$channel,
      seed_result_path = seed_result_path,
      seed_result_sha256 = wlv13_sha256_file(seed_result_path),
      run_id = seed$run_id,
      result_id = seed$result_id,
      release_id = seed$release_id,
      release_manifest_sha256 = seed$release_manifest_sha256,
      marker_sha256 = seed$marker_sha256,
      process = process
    )
  })
  require_gate(!anyDuplicated(vapply(seeds, `[[`, character(1L),
    "release_id"
  )), "Fault channel seed releases are not unique.")

  fault_records <- plan$records[seq.int(3L, 12L)]
  faults <- lapply(seq_along(fault_records), function(index) {
    record <- fault_records[[index]]
    expected <- wlv13_fault_bindings[index, , drop = FALSE]
    id <- paste0("candidate/fault/", expected$fault_id[[1L]])
    evidence <- normalizePath(record$evidence_directory,
      winslash = "/", mustWork = TRUE
    )
    scenario_path <- normalizePath(file.path(evidence, "scenario-result.json"),
      winslash = "/", mustWork = TRUE
    )
    fault_path <- normalizePath(file.path(evidence, "fault-result.json"),
      winslash = "/", mustWork = TRUE
    )
    scenario <- wlv13_json_read(scenario_path, simplify = FALSE)
    fault <- wlv13_json_read(fault_path, simplify = FALSE)
    scenario_spec <- wlv13_json_read(record$scenario_spec_path, simplify = FALSE)
    process <- authenticate_process(
      file.path(evidence, "process-metrics.json"),
      record$process_spec_path,
      record$process_spec_sha256,
      id,
      roots$fault,
      evidence
    )
    expected_checkpoint <- expected$checkpoint[[1L]]
    checkpoint_ok <- if (is.na(expected_checkpoint)) {
      is.null(fault$checkpoint)
    } else {
      identical(fault$checkpoint, expected_checkpoint)
    }
    source_clean <- identical(scenario$source_before,
      scenario$source_after
    ) &&
      !length(wlv_gate_prep_text(scenario$source_after$preparation_staging)) &&
      !length(wlv_gate_prep_text(scenario$source_after$preparation_locks))
    publication_clean <- identical(scenario$publication_before,
      scenario$publication_after
    ) && isTRUE(scenario$publication_before$exists) &&
      identical(scenario$publication_before$release_id,
        seeds[[index]]$release_id
      ) &&
      !length(wlv_gate_prep_text(scenario$publication_after$staging))
    require_gate(
      identical(scenario$schema, wlv13_schema$scenario) &&
        identical(scenario$scenario_id, id) &&
        identical(scenario$status, "passed") && isTRUE(scenario$passed) &&
        identical(scenario$kind, expected$kind[[1L]]) &&
        wlv_gate_prep_same_path(scenario$project_root, roots$fault) &&
        identical(scenario$expected_commit, plan$roots$fault$commit) &&
        identical(scenario$observed_commit, plan$roots$fault$commit) &&
        identical(scenario$request$channel, record$channel) &&
        identical(as.integer(scenario$request$workers), 1L) &&
        identical(scenario$request$expected_failure, TRUE) &&
        is.character(scenario$error) && length(scenario$error) == 1L &&
        grepl(scenario_spec$fault$token, scenario$error, fixed = TRUE) &&
        source_clean && publication_clean,
      sprintf("Fault scenario state failed for `%s`.", id)
    )
    require_gate(
      identical(fault$schema, wlv13_schema$fault) &&
        identical(fault$scenario_id, id) && identical(fault$status, "passed") &&
        isTRUE(fault$passed) &&
        identical(fault$fault_id, expected$fault_id[[1L]]) &&
        identical(fault$binding, expected$binding[[1L]]) &&
        identical(fault$when, expected$when[[1L]]) &&
        identical(as.integer(fault$call), expected$call[[1L]]) &&
        checkpoint_ok &&
        identical(as.integer(fault$binding_call_count), expected$call[[1L]]) &&
        isTRUE(fault$injected) && isTRUE(fault$expected_failure_observed) &&
        isTRUE(fault$expected_error_matched) &&
        isTRUE(fault$channel_marker_unchanged) &&
        isTRUE(fault$no_partial_release_visible) &&
        isTRUE(fault$staging_clean) &&
        isTRUE(fault$preparation_staging_clean) &&
        isTRUE(fault$normalized_generation_unchanged) &&
        isTRUE(fault$previous_release_verified) &&
        grepl(scenario_spec$fault$token, fault$error, fixed = TRUE),
      sprintf("Fault boundary/rollback assertions failed for `%s`.", id)
    )
    list(
      scenario_id = id,
      fault_id = expected$fault_id[[1L]],
      binding = expected$binding[[1L]],
      when = expected$when[[1L]],
      call = expected$call[[1L]],
      checkpoint = if (is.na(expected_checkpoint)) NULL else expected_checkpoint,
      channel = record$channel,
      seed_release_id = seeds[[index]]$release_id,
      scenario_result_path = scenario_path,
      scenario_result_sha256 = wlv13_sha256_file(scenario_path),
      fault_result_path = fault_path,
      fault_result_sha256 = wlv13_sha256_file(fault_path),
      rollback_verified = TRUE,
      process = process
    )
  })

  bootstrap <- new.env(parent = baseenv())
  sys.source(file.path(roots$fault, "R", "bootstrap.R"),
    envir = bootstrap, chdir = FALSE
  )
  runtime <- bootstrap$wlv_load_runtime(roots$fault)
  runtime$wlv_assert_loaded_runtime_unchanged()
  visible <- lapply(seq_along(seeds), function(index) {
    release <- runtime$wlv_read_current_release(
      roots$fault,
      channel = seeds[[index]]$channel,
      required = TRUE
    )
    runtime$wlv_verify_release_manifest(
      release$manifest,
      release$root,
      publication_root = file.path(roots$fault, "results"),
      reject_unlisted = TRUE
    )
    require_gate(
      identical(release$manifest$release_id, seeds[[index]]$release_id) &&
        identical(as.integer(release$manifest$sequence), 1L) &&
        length(release$manifest$runs) == 1L &&
        identical(release$manifest$runs[[1L]]$method,
          seeds[[index]]$method) &&
        identical(release$manifest$runs[[1L]]$run_id,
          seeds[[index]]$run_id) &&
        identical(release$manifest$runs[[1L]]$result_id,
          seeds[[index]]$result_id) &&
        identical(release$manifest$runs[[1L]]$manifest_sha256,
          seeds[[index]]$run_manifest_sha256) &&
        identical(wlv13_sha256_file(release$marker_path),
          seeds[[index]]$marker_sha256
        ),
      sprintf("Visible release changed after fault `%s`.",
        seeds[[index]]$fault_id
      )
    )
    list(
      fault_id = seeds[[index]]$fault_id,
      channel = seeds[[index]]$channel,
      release_id = release$manifest$release_id,
      marker_sha256 = wlv13_sha256_file(release$marker_path),
      passed = TRUE
    )
  })
  transaction <- wlv_gate_prep_transaction_state(roots$fault)
  publication_staging <- file.path(roots$fault, "results", ".staging")
  staging_entries <- if (dir.exists(publication_staging)) {
    list.files(publication_staging, all.files = TRUE, no.. = TRUE)
  } else {
    character()
  }
  require_gate(isTRUE(transaction$passed) && !length(staging_entries),
    "Fault store retained preparation or publication staging."
  )
  require_gate(
    identical(wlv13_git_commit(roots$fault), plan$roots$fault$commit) &&
      wlv13_git_runtime_clean(roots$fault),
    "Fault runtime changed during the gate."
  )

  report$status <<- "passed"
  report$passed <<- TRUE
  report$finished_at <<- wlv13_now()
  report$plan <<- plan_auth
  report$rule_matrix <<- list(
    path = normalizePath(file.path(dirname(script_dir),
      "issue13-preparation-rule-matrix.json"
    ), winslash = "/", mustWork = TRUE),
    sha256 = wlv13_sha256_file(file.path(dirname(script_dir),
      "issue13-preparation-rule-matrix.json"
    ))
  )
  report$preparation <<- list(
    comparison_path = comparison_path,
    comparison_sha256 = wlv13_sha256_file(comparison_path),
    status = comparison$status,
    performance = comparison$performance,
    source_count = length(comparison$sources),
    euklems_artifact_count = comparison$euklems$artifact_count
  )
  report$input_import <<- list(
    path = import_path,
    sha256 = wlv13_sha256_file(import_path),
    source_tree = import$source_tree,
    source_stores_unchanged = TRUE
  )
  report$seed_plan <<- list(
    path = seed_plan_path,
    sha256 = wlv13_sha256_file(seed_plan_path),
    record_count = length(seeds)
  )
  report$seeds <<- seeds
  report$faults <<- faults
  report$visible_seed_releases <<- visible
  report$transaction_state <<- list(
    preparation = transaction,
    publication_staging_entries = as.list(staging_entries),
    passed = TRUE
  )
  report$summary <<- list(
    preparation_scenarios_passed = 2L,
    preparation_sources_compared = 3L,
    fault_channels_seeded = length(seeds),
    fault_gates_passed = length(faults),
    rollback_gates_passed = length(faults),
    visible_partial_releases = 0L,
    staging_entries = 0L,
    p0 = 0L,
    p1 = 0L
  )
  wlv13_json_write(report, report_path)
  invisible(report)
}

tryCatch(
  main(),
  error = function(error) {
    if (!file.exists(report_path)) {
      failed <- report
      failed$schema <- "wlv-issue13-prep-fault-aggregate-failed/1"
      failed$status <- "failed"
      failed$passed <- FALSE
      failed$finished_at <- wlv13_now()
      failed$error <- conditionMessage(error)
      wlv13_json_write(failed, failed_path)
    }
    stop(error)
  }
)

cat("Preparation/fault aggregate passed:", report_path, "\n")
