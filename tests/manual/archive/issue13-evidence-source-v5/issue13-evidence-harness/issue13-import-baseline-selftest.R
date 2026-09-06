# Self-test for authenticated baseline imports. The fixtures are intentionally
# tiny, but exercise the same hard-link, evidence, profile, and fail-closed
# paths used by the real validation matrix.

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE),
  value = TRUE
)
if (!length(script_argument)) stop("Run with Rscript.", call. = FALSE)
script_path <- normalizePath(
  sub("^--file=", "", script_argument[[1L]]),
  winslash = "/",
  mustWork = TRUE
)
script_dir <- dirname(script_path)
sys.source(file.path(script_dir, "issue13-lib.R"), envir = environment())
sys.source(file.path(script_dir, "issue13-import-baseline-lib.R"),
  envir = environment()
)

wlv13_import_test_require <- function(condition, message) {
  if (!isTRUE(condition)) stop(paste("SELFTEST:", message), call. = FALSE)
  invisible(TRUE)
}

wlv13_import_test_error <- function(expression, pattern = NULL) {
  observed <- tryCatch({
    force(expression)
    NULL
  }, error = identity)
  wlv13_import_test_require(inherits(observed, "error"),
    "expected an error but the operation passed"
  )
  if (!is.null(pattern)) {
    wlv13_import_test_require(
      grepl(pattern, conditionMessage(observed), perl = TRUE,
        ignore.case = TRUE),
      paste0("unexpected error: ", conditionMessage(observed))
    )
  }
  invisible(observed)
}

wlv13_import_test_false <- function(value, label) {
  wlv13_import_test_require(
    is.list(value) && identical(value$passed, FALSE) &&
      is.character(value$detail) && length(value$detail) == 1L &&
      nzchar(value$detail),
    paste(label, "did not fail closed")
  )
}

wlv13_import_test_system <- function(command, arguments, label) {
  if (.Platform$OS.type == "windows") {
    arguments <- vapply(as.character(arguments), function(argument) {
      if (grepl("[[:space:]\"]", argument)) {
        shQuote(argument, type = "cmd")
      } else {
        argument
      }
    }, character(1L), USE.NAMES = FALSE)
  }
  output <- system2(command, arguments, stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status", exact = TRUE)
  wlv13_import_test_require(is.null(status) || identical(as.integer(status), 0L),
    sprintf("%s failed: %s", label, paste(output, collapse = " "))
  )
  invisible(output)
}

wlv13_import_test_git_fixture <- function(source_root, target_root) {
  dir.create(source_root, recursive = TRUE, showWarnings = FALSE)
  writeLines("authenticated import selftest", file.path(source_root,
    "README.fixture"), useBytes = TRUE
  )
  wlv13_import_test_system("git", c("-C", source_root, "init", "-q"),
    "git init"
  )
  wlv13_import_test_system("git", c("-C", source_root, "config",
    "user.email", "issue13-selftest@example.invalid"), "git config email"
  )
  wlv13_import_test_system("git", c("-C", source_root, "config",
    "user.name", "Issue 13 selftest"), "git config name"
  )
  wlv13_import_test_system("git", c("-C", source_root, "add",
    "README.fixture"), "git add"
  )
  wlv13_import_test_system("git", c("-C", source_root, "commit", "-q",
    "-m", "selftest fixture"), "git commit"
  )
  wlv13_import_test_system("git", c("clone", "-q", "--no-hardlinks",
    source_root, target_root), "git clone"
  )
  list(
    source_commit = wlv13_git_commit(source_root),
    runtime_commit = wlv13_git_commit(target_root)
  )
}

wlv13_import_test_write_run <- function(source_root, commit, method, run_id) {
  run_root <- file.path(source_root, "results", "runs", method, run_id)
  dir.create(run_root, recursive = TRUE, showWarnings = FALSE)
  artifact_paths <- sprintf("artifact-%02d.bin", seq_len(24L))
  for (index in seq_along(artifact_paths)) {
    writeBin(as.raw(c(index, 255L - index)), file.path(run_root,
      artifact_paths[[index]]
    ))
  }
  records <- lapply(artifact_paths, function(path) {
    record <- wlv13_file_record(file.path(run_root, path))
    list(
      path = path,
      role = "fixture",
      size_bytes = record$size_bytes,
      sha256 = record$sha256
    )
  })
  result_id <- wlv13_sha256_text(paste(method, run_id, sep = "|"))
  manifest <- list(
    schema = "wlv-run-manifest",
    schema_version = "1",
    run_id = run_id,
    result_id = result_id,
    created_at_utc = "2026-08-24T00:00:00Z",
    parent_run_id = NULL,
    method = method,
    output_contract = list(id = "wlvpanel-output", version = "1.0.0"),
    result = list(
      provenance = list(
        complete = TRUE,
        git = list(
          commit = commit,
          dirty = FALSE,
          input_tree_sha256 = wlv13_sha256_text("fixture-input"),
          status_sha256 = wlv13_sha256_text("")
        )
      ),
      request = list(
        at_stage = NULL,
        method = method,
        mode = "calculate",
        sea_vars = NULL,
        workers = 1L
      )
    ),
    execution = list(
      started_at_utc = "2026-08-24T00:00:00Z",
      finished_at_utc = "2026-08-24T00:00:01Z",
      duration_seconds = 1,
      warnings = list()
    ),
    artifacts = records
  )
  manifest_path <- file.path(run_root, "run_manifest.json")
  wlv13_import_write_json(manifest, manifest_path)
  inventory <- wlv13_run_inventory(run_root)
  list(root = run_root, manifest_path = manifest_path, inventory = inventory,
    result_id = result_id)
}

wlv13_import_test_write_auxiliary <- function(root, source_root, commit,
                                               method, run) {
  evidence_root <- file.path(root, "source-evidence")
  process_spec_root <- file.path(root, "source-spec")
  dir.create(evidence_root, recursive = TRUE, showWarnings = FALSE)
  dir.create(process_spec_root, recursive = TRUE, showWarnings = FALSE)
  stdout_path <- file.path(evidence_root, "stdout.log")
  stderr_path <- file.path(evidence_root, "stderr.log")
  samples_path <- file.path(evidence_root, "process-samples.csv")
  writeLines(c("fixture stdout", "complete"), stdout_path, useBytes = TRUE)
  writeLines("fixture stderr", stderr_path, useBytes = TRUE)
  writeLines(c("sample,rss", "1,4096"), samples_path, useBytes = TRUE)
  rscript <- Sys.which("Rscript")
  wlv13_import_test_require(nzchar(rscript), "Rscript executable not found")
  scenario_id <- paste0("baseline/calculate/", method, "/workers1")
  process_spec <- list(
    schema = "wlv-issue13-process-spec/1",
    scenario_id = scenario_id,
    executable = normalizePath(rscript, winslash = "/", mustWork = TRUE),
    arguments = list(
      "--vanilla",
      file.path(script_dir, "issue13-scenario.R"),
      evidence_root
    ),
    working_directory = source_root,
    environment = list(),
    expected_exit_codes = list(0L),
    timeout_seconds = 60,
    sample_interval_ms = 1000L,
    shutdown_grace_seconds = 5L,
    expected_worker_processes = 0L
  )
  process_spec_path <- file.path(process_spec_root, "process-spec.json")
  wlv13_import_write_json(process_spec, process_spec_path)
  output <- list(
    kind = "run",
    root = run$inventory$root,
    manifest_path = run$inventory$manifest_path,
    manifest_sha256 = run$inventory$manifest_sha256,
    inventory_sha256 = wlv13_inventory_signature(run$inventory),
    run_id = run$inventory$manifest$run_id,
    result_id = run$result_id,
    parent_run_id = NULL,
    release_id = NULL,
    method = method,
    request = list(
      at_stage = NULL, method = method, mode = "calculate",
      sea_vars = NULL, workers = 1L
    )
  )
  scenario <- list(
    schema = wlv13_schema$scenario,
    scenario_id = scenario_id,
    status = "passed",
    passed = TRUE,
    kind = "calculate",
    project_root = source_root,
    expected_commit = commit,
    observed_commit = commit,
    started_at = "2026-08-24T00:00:00-0300",
    finished_at = "2026-08-24T00:00:01-0300",
    elapsed_seconds = 1,
    request = list(
      method = method,
      methods = list(method),
      channel = "issue13-import-selftest",
      workers = 1L,
      at_stage = NULL,
      sea_vars = NULL,
      paper = NULL,
      expected_failure = FALSE
    ),
    outputs = list(output),
    seed = NULL,
    publication_before = list(exists = FALSE, channel =
      "issue13-import-selftest", staging = list()),
    publication_after = list(exists = TRUE, channel =
      "issue13-import-selftest", staging = list()),
    source_before = list(),
    source_after = list(),
    error = NULL
  )
  scenario_path <- file.path(evidence_root, "scenario-result.json")
  wlv13_import_write_json(scenario, scenario_path)
  metrics <- list(
    schema = "wlv-issue13-process-metrics/2",
    scenario_id = scenario_id,
    status = "passed",
    passed = TRUE,
    executable = chartr("/", "\\", normalizePath(rscript,
      winslash = "/", mustWork = TRUE)),
    arguments = process_spec$arguments,
    working_directory = chartr("/", "\\", source_root),
    root_pid = 1L,
    exit_code = 0L,
    expected_exit_codes = list(0L),
    exit_code_matched = TRUE,
    timed_out = FALSE,
    timeout_seconds = 60,
    started_at_utc = "2026-08-24T03:00:00Z",
    finished_at_utc = "2026-08-24T03:00:01Z",
    elapsed_seconds = 1,
    sample_interval_ms = 1000L,
    samples = 1L,
    peak_rss_bytes = 4096,
    peak_private_bytes = 8192,
    cumulative_cpu_seconds_peak = 0.5,
    max_concurrent_processes = 1L,
    expected_worker_processes = 0L,
    max_concurrent_worker_processes = 0L,
    worker_count_matched = TRUE,
    cluster_closed = TRUE,
    lingering_pids = list(),
    observed_processes = list(),
    stdout_path = stdout_path,
    stderr_path = stderr_path,
    stdout_sha256 = wlv13_sha256_file(stdout_path),
    stderr_sha256 = wlv13_sha256_file(stderr_path),
    samples_path = samples_path,
    samples_sha256 = wlv13_sha256_file(samples_path),
    process_spec_path = process_spec_path,
    process_spec_sha256 = wlv13_sha256_file(process_spec_path)
  )
  metrics_path <- file.path(evidence_root, "process-metrics.json")
  wlv13_import_write_json(metrics, metrics_path)
  list(
    scenario_result = scenario_path,
    process_metrics = metrics_path,
    process_spec = process_spec_path,
    stdout = stdout_path,
    stderr = stderr_path,
    samples = samples_path
  )
}

wlv13_import_test_record <- function(path) {
  observed <- wlv13_file_record(path)
  list(
    path = normalizePath(path, winslash = "/", mustWork = TRUE),
    size_bytes = observed$size_bytes,
    sha256 = observed$sha256
  )
}

wlv13_import_test_fixture <- function(root) {
  source_root <- normalizePath(file.path(root, "source"),
    winslash = "/", mustWork = FALSE
  )
  target_root <- normalizePath(file.path(root, "target"),
    winslash = "/", mustWork = FALSE
  )
  commits <- wlv13_import_test_git_fixture(source_root, target_root)
  method <- "fixture"
  run_id <- "run-issue13-import-selftest"
  run <- wlv13_import_test_write_run(source_root, commits$source_commit,
    method, run_id
  )
  aux <- wlv13_import_test_write_auxiliary(root, source_root,
    commits$source_commit, method, run
  )
  inventory_path <- file.path(root, "normative-inventory.csv")
  profile <- list(
    schema = wlv13_schema$validation_profile,
    id = "strict-selftest",
    inventory_value = "strict-selftest",
    source_commit = commits$source_commit,
    runtime_commit = commits$runtime_commit,
    run_dirty = FALSE,
    overlay_patch_path = NULL,
    overlay_patch_sha256 = NULL,
    overlay_patch_id = NULL
  )
  row <- data.frame(
    method = method,
    scenario = "full_workers1",
    status = "reusable",
    commit = commits$source_commit,
    overlay = profile$inventory_value,
    release_id = "",
    run_id = run_id,
    result_id = run$result_id,
    evidence = run$manifest_path,
    notes = "authenticated import selftest",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  utils::write.csv(row, inventory_path, row.names = FALSE, quote = TRUE,
    fileEncoding = "UTF-8", na = ""
  )
  aux_records <- lapply(aux, wlv13_import_test_record)
  spec <- list(
    schema = wlv13_schema$baseline_import_spec,
    scenario_id = paste0("baseline/calculate/", method, "/workers1"),
    source_project_root = source_root,
    target_project_root = target_root,
    expected_source_commit = commits$source_commit,
    expected_target_commit = commits$runtime_commit,
    method = method,
    run_id = run_id,
    result_id = run$result_id,
    manifest_sha256 = run$inventory$manifest_sha256,
    inventory_sha256 = wlv13_inventory_signature(run$inventory),
    expected_run_dirty = FALSE,
    inventory = list(
      path = normalizePath(inventory_path,
        winslash = "/", mustWork = TRUE),
      sha256 = wlv13_sha256_file(inventory_path),
      canonical_row_sha256 = wlv13_import_inventory_row_sha256(
        unlist(row[1L, , drop = FALSE], use.names = TRUE)
      )
    ),
    validation_profile = profile,
    auxiliary = aux_records
  )
  spec_path <- file.path(root, "import-spec.json")
  wlv13_import_write_json(spec, spec_path)
  list(
    source_root = source_root,
    target_root = target_root,
    commits = commits,
    run = run,
    aux = aux,
    profile = profile,
    spec_path = spec_path,
    spec = wlv13_json_read(spec_path, simplify = FALSE)
  )
}

wlv13_import_test_restore_file <- function(path, action) {
  bytes <- readBin(path, what = "raw", n = file.info(path)$size)
  on.exit({
    connection <- file(path, open = "wb")
    tryCatch(writeBin(bytes, connection),
      finally = close(connection)
    )
  }, add = TRUE)
  force(action)
}

main <- function() {
root <- tempfile("wlv-issue13-import-selftest-")
dir.create(root, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
fixture <- wlv13_import_test_fixture(root)
validated <- wlv13_import_validate_spec(fixture$spec)
source <- wlv13_import_read_source(validated)

# Pure source/spec failures: identity, manifest binding, parent, workers,
# selected variables, commit provenance, profile, and auxiliary records.
wrong_id <- wlv13_import_clone(fixture$spec)
wrong_id$scenario_id <- "candidate/calculate/fixture/workers1"
wlv13_import_test_error(wlv13_import_validate_spec(wrong_id), "scenario_id")

wrong_hash <- wlv13_import_clone(fixture$spec)
wrong_hash$auxiliary$stdout$sha256 <- paste(rep("0", 64L), collapse = "")
wlv13_import_test_error(wlv13_import_validate_spec(wrong_hash), "differs")

wrong_profile <- wlv13_import_clone(fixture$spec)
wrong_profile$validation_profile$runtime_commit <-
  paste(rep("0", 40L), collapse = "")
wlv13_import_test_error(wlv13_import_validate_spec(wrong_profile), "profile")

bad_inventory <- wlv13_import_clone(source$inventory)
bad_inventory$manifest$parent_run_id <- "run-parent"
wlv13_import_test_error(
  wlv13_import_assert_full_run(bad_inventory, validated), "parent"
)
bad_inventory <- wlv13_import_clone(source$inventory)
bad_inventory$manifest$result$request$workers <- 2L
wlv13_import_test_error(
  wlv13_import_assert_full_run(bad_inventory, validated), "workers=1"
)
bad_inventory <- wlv13_import_clone(source$inventory)
bad_inventory$manifest$result$request$sea_vars <- list("trade_balance.s.mv")
wlv13_import_test_error(
  wlv13_import_assert_full_run(bad_inventory, validated), "workers=1"
)
bad_inventory <- wlv13_import_clone(source$inventory)
bad_inventory$manifest$result$provenance$git$commit <-
  paste(rep("0", 40L), collapse = "")
wlv13_import_test_error(
  wlv13_import_assert_full_run(bad_inventory, validated), "provenance"
)
bad_scenario <- wlv13_import_clone(source$scenario)
bad_scenario$request$workers <- 2L
wlv13_import_test_error(
  wlv13_import_assert_source_scenario(bad_scenario, source$inventory,
    validated), "workers=1"
)
bad_scenario <- wlv13_import_clone(source$scenario)
bad_scenario$request$sea_vars <- list("trade_balance.s.mv")
wlv13_import_test_error(
  wlv13_import_assert_source_scenario(bad_scenario, source$inventory,
    validated), "workers=1"
)

missing_path <- tempfile("missing-aux-", tmpdir = root)
writeLines("temporary", missing_path, useBytes = TRUE)
missing_record <- wlv13_import_test_record(missing_path)
unlink(missing_path, force = TRUE)
wlv13_import_test_error(
  wlv13_import_validate_aux_record(missing_record, "missing"), "existing file"
)
tampered_path <- tempfile("tampered-aux-", tmpdir = root)
writeLines("before", tampered_path, useBytes = TRUE)
tampered_record <- wlv13_import_test_record(tampered_path)
writeLines("after", tampered_path, useBytes = TRUE)
wlv13_import_test_error(
  wlv13_import_validate_aux_record(tampered_record, "tampered"), "differs"
)

# Positive import and independent aggregate-time authentication.
evidence <- file.path(root, "imported-evidence")
result <- wlv13_import_baseline_run(fixture$spec, evidence)
imported <- wlv13_json_read(result$scenario_path, simplify = FALSE)
positive <- wlv13_validate_authenticated_import(imported,
  fixture$spec$scenario_id, fixture$commits$runtime_commit,
  fixture$commits$source_commit, fixture$spec$validation_profile
)
wlv13_import_test_require(isTRUE(positive$passed), positive$detail)
wlv13_import_test_require(
  identical(imported$project_root, fixture$target_root) &&
    identical(imported$expected_commit, fixture$commits$runtime_commit) &&
    identical(imported$observed_commit, fixture$commits$runtime_commit) &&
    identical(imported$authentication$source_commit,
      fixture$commits$source_commit) &&
    identical(imported$authentication$runtime_commit,
      fixture$commits$runtime_commit),
  "effective/source commit separation failed"
)
wlv13_import_test_require(
  !file.exists(file.path(evidence, ".issue13-import-incomplete")),
  "successful import retained its incomplete marker"
)
source_metrics <- wlv13_json_read(fixture$aux$process_metrics,
  simplify = FALSE
)
relocated_metrics <- wlv13_json_read(file.path(evidence,
  "process-metrics.json"), simplify = FALSE
)
wlv13_import_test_require(
  identical(source_metrics$elapsed_seconds, relocated_metrics$elapsed_seconds) &&
    identical(source_metrics$peak_rss_bytes,
      relocated_metrics$peak_rss_bytes) &&
    identical(source_metrics$peak_private_bytes,
      relocated_metrics$peak_private_bytes),
  "process elapsed/RSS fields changed during import"
)

# Aggregate-time mode/index/profile/authentication failures.
candidate <- wlv13_import_clone(imported)
candidate$scenario_id <- "candidate/calculate/fixture/workers1"
wlv13_import_test_false(wlv13_validate_authenticated_import(candidate,
  candidate$scenario_id, fixture$commits$runtime_commit,
  fixture$commits$source_commit, fixture$spec$validation_profile),
"candidate authenticated_import")
null_mode <- wlv13_import_clone(imported)
null_mode$execution_mode <- NULL
wlv13_import_test_false(wlv13_validate_authenticated_import(null_mode,
  fixture$spec$scenario_id, fixture$commits$runtime_commit,
  fixture$commits$source_commit, fixture$spec$validation_profile),
"null execution mode")
unknown_mode <- wlv13_import_clone(imported)
unknown_mode$execution_mode <- "unknown"
wlv13_import_test_false(wlv13_validate_authenticated_import(unknown_mode,
  fixture$spec$scenario_id, fixture$commits$runtime_commit,
  fixture$commits$source_commit, fixture$spec$validation_profile),
"unknown execution mode")
wrong_runtime <- paste(rep("0", 40L), collapse = "")
wlv13_import_test_false(wlv13_validate_authenticated_import(imported,
  fixture$spec$scenario_id, wrong_runtime, fixture$commits$source_commit,
  fixture$spec$validation_profile), "wrong runtime commit")
wrong_base <- paste(rep("1", 40L), collapse = "")
wlv13_import_test_false(wlv13_validate_authenticated_import(imported,
  fixture$spec$scenario_id, fixture$commits$runtime_commit, wrong_base,
  fixture$spec$validation_profile), "wrong base commit")
index_profile <- wlv13_import_clone(fixture$spec$validation_profile)
index_profile$id <- "wrong-profile"
wlv13_import_test_false(wlv13_validate_authenticated_import(imported,
  fixture$spec$scenario_id, fixture$commits$runtime_commit,
  fixture$commits$source_commit, index_profile), "wrong indexed profile")
bad_auth <- wlv13_import_clone(imported)
bad_auth$authentication$import_report_sha256 <- paste(rep("0", 64L),
  collapse = "")
wlv13_import_test_false(wlv13_validate_authenticated_import(bad_auth,
  fixture$spec$scenario_id, fixture$commits$runtime_commit,
  fixture$commits$source_commit, fixture$spec$validation_profile),
"wrong import-report hash")

# Missing and tampered materialized auxiliaries must fail but are restored so
# the positive fixture remains usable for subsequent assertions.
source_auth_stderr <- file.path(evidence, "source-auth", "stderr.log")
source_auth_stderr_hidden <- paste0(source_auth_stderr, ".missing")
wlv13_import_test_require(file.rename(source_auth_stderr,
  source_auth_stderr_hidden), "cannot stage missing-aux negative"
)
missing_result <- wlv13_validate_authenticated_import(imported,
  fixture$spec$scenario_id, fixture$commits$runtime_commit,
  fixture$commits$source_commit, fixture$spec$validation_profile
)
wlv13_import_test_require(file.rename(source_auth_stderr_hidden,
  source_auth_stderr), "cannot restore missing auxiliary"
)
wlv13_import_test_false(missing_result, "missing source-auth auxiliary")

stdout_materialized <- file.path(evidence, "stdout.log")
wlv13_import_test_restore_file(stdout_materialized, {
  connection <- file(stdout_materialized, open = "ab")
  writeBin(charToRaw("tampered"), connection)
  close(connection)
  wlv13_import_test_false(wlv13_validate_authenticated_import(imported,
    fixture$spec$scenario_id, fixture$commits$runtime_commit,
    fixture$commits$source_commit, fixture$spec$validation_profile),
  "tampered relocated auxiliary")
})

# A second invocation cannot overwrite or delete the promoted target run.
target_signature_before <- wlv13_inventory_signature(
  wlv13_run_inventory(result$target_run_root)
)
wlv13_import_test_error(
  wlv13_import_baseline_run(fixture$spec,
    file.path(root, "second-evidence")),
  "already exists"
)
target_signature_after <- wlv13_inventory_signature(
  wlv13_run_inventory(result$target_run_root)
)
wlv13_import_test_require(
  identical(target_signature_before, target_signature_after),
  "preexisting target was changed or removed"
)

message("SKIP cross-volume negative: no disposable second NTFS volume fixture.")
message("SKIP reparse negative: no disposable reparse-point fixture.")
message("issue13-import-baseline-selftest: PASS")
}

main()
