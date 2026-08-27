# Fail-closed audit for preparation/fault specs before any real scenario starts.

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

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 1L) stop("Expected <plan.json>.", call. = FALSE)
plan_path <- normalizePath(arguments[[1L]], winslash = "/", mustWork = TRUE)
plan <- wlv13_json_read(plan_path, simplify = FALSE)
required_plan <- c(
  "schema", "created_at", "execution_started",
  "preparation_scenario_count", "fault_scenario_count",
  "candidate_channel_prefix", "r_library", "harness_files", "roots", "records"
)
if (!is.list(plan) || !setequal(names(plan), required_plan) ||
    !identical(plan$schema, "wlv-issue13-prep-fault-plan/2") ||
    !identical(plan$execution_started, FALSE) ||
    !identical(as.integer(plan$preparation_scenario_count), 2L) ||
    !identical(as.integer(plan$fault_scenario_count), 10L)) {
  stop("Preparation/fault plan has an invalid schema or counts.",
    call. = FALSE)
}
prefix <- wlv13_scalar_text(
  plan$candidate_channel_prefix,
  "candidate_channel_prefix",
  "^[a-z0-9][a-z0-9.-]*-$"
)
r_library <- wlv13_normalize_existing_dir(plan$r_library, "plan R library")
expected_harness <- c(
  "issue13-build-prep-fault-specs.R" = file.path(
    script_dir, "issue13-build-prep-fault-specs.R"
  ),
  "issue13-audit-prep-fault-plan.R" = file.path(
    script_dir, "issue13-audit-prep-fault-plan.R"
  ),
  "issue13-scenario.R" = file.path(script_dir, "issue13-scenario.R"),
  "issue13-lib.R" = file.path(script_dir, "issue13-lib.R"),
  "issue13-matrix.R" = file.path(script_dir, "issue13-matrix.R"),
  "issue13-monitor.ps1" = file.path(script_dir, "issue13-monitor.ps1"),
  "issue13-run-prep-fault-record.ps1" = file.path(
    script_dir, "issue13-run-prep-fault-record.ps1"
  ),
  "issue13-seed-channel.R" = file.path(script_dir, "issue13-seed-channel.R"),
  "issue13-import-fault-inputs.R" = file.path(
    script_dir, "issue13-import-fault-inputs.R"
  ),
  "issue13-build-fault-seed-specs.R" = file.path(
    script_dir, "issue13-build-fault-seed-specs.R"
  ),
  "issue13-run-fault-seeds.ps1" = file.path(
    script_dir, "issue13-run-fault-seeds.ps1"
  ),
  "issue13-aggregate-prep-fault.R" = file.path(
    script_dir, "issue13-aggregate-prep-fault.R"
  ),
  "issue13-prep-paper-lib.R" = file.path(
    dirname(script_dir), "issue13-prep-paper-lib.R"
  ),
  "issue13-preparation-auth-lib.R" = file.path(
    dirname(script_dir), "issue13-preparation-auth-lib.R"
  ),
  "issue13-preparation-compare.R" = file.path(
    dirname(script_dir), "issue13-preparation-compare.R"
  ),
  "issue13-preparation-rule-matrix.json" = file.path(
    dirname(script_dir), "issue13-preparation-rule-matrix.json"
  ),
  "issue13-runtime-loader-selftest.R" = file.path(
    dirname(script_dir), "issue13-runtime-loader-selftest.R"
  )
)
if (!is.list(plan$harness_files) ||
    length(plan$harness_files) != length(expected_harness)) {
  stop("Plan harness inventory is incomplete.", call. = FALSE)
}
observed_harness_names <- vapply(plan$harness_files, `[[`,
  character(1L), "name"
)
if (!identical(observed_harness_names, names(expected_harness))) {
  stop("Plan harness inventory is unordered or unexpected.", call. = FALSE)
}
harness_audit <- lapply(seq_along(plan$harness_files), function(index) {
  record <- plan$harness_files[[index]]
  expected_path <- normalizePath(expected_harness[[index]],
    winslash = "/", mustWork = TRUE
  )
  observed_path <- normalizePath(record$path,
    winslash = "/", mustWork = TRUE
  )
  if (!setequal(names(record), c("name", "path", "sha256")) ||
      !identical(observed_path, expected_path) ||
      !identical(record$sha256, wlv13_sha256_file(expected_path))) {
    stop(sprintf("Harness file authentication failed for `%s`.",
      names(expected_harness)[[index]]
    ), call. = FALSE)
  }
  list(
    name = record$name,
    path = observed_path,
    sha256 = record$sha256,
    passed = TRUE
  )
})
root_names <- c("baseline", "candidate", "fault")
if (!is.list(plan$roots) || !identical(names(plan$roots), root_names)) {
  stop("Plan roots are incomplete or unordered.", call. = FALSE)
}
roots <- lapply(root_names, function(name) {
  record <- plan$roots[[name]]
  if (!is.list(record) || !setequal(names(record), c("root", "commit"))) {
    stop(sprintf("Plan root `%s` has an invalid schema.", name), call. = FALSE)
  }
  root <- wlv13_normalize_existing_dir(record$root, paste(name, "root"))
  commit <- wlv13_scalar_text(record$commit, paste(name, "commit"),
    "^[0-9a-f]{40}$"
  )
  if (!identical(wlv13_git_commit(root), commit) ||
      !wlv13_git_runtime_clean(root)) {
    stop(sprintf("Plan root `%s` is not pinned/runtime-clean.", name),
      call. = FALSE)
  }
  list(root = root, commit = commit)
})
names(roots) <- root_names
if (!identical(roots$candidate$commit, roots$fault$commit)) {
  stop("Candidate preparation and fault runtimes must use one commit.",
    call. = FALSE)
}

runtime_loader_checks <- lapply(c("baseline", "candidate"), function(engine) {
  root <- roots[[engine]]$root
  working_directory <- getwd()
  search_path <- search()
  loaded <- wlv_gate_load_runtime(root)
  runtime <- loaded$runtime
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
  api_ok <- all(vapply(names(expected_api), function(name) {
    exists(name, envir = runtime, mode = "function", inherits = FALSE) &&
      identical(names(formals(get(name, envir = runtime, inherits = FALSE))),
        expected_api[[name]]
      )
  }, logical(1L)))
  catalog <- if (exists("wlv_runtime_catalog", envir = runtime,
      mode = "function", inherits = FALSE)) {
    runtime$wlv_runtime_catalog()
  } else {
    runtime$method_catalog
  }
  preparation_sources <- vapply(c("wiodr13", "wiodr16"), function(method) {
    runtime$wlv_catalog_method(catalog, method)$source[[1L]]
  }, character(1L))
  publication_absent <- is.null(runtime$wlv_read_current_release(
    root,
    channel = "issue13-loader-preflight",
    required = FALSE
  ))
  if (identical(engine, "candidate")) {
    runtime$wlv_assert_loaded_runtime_unchanged()
  }
  passed <- identical(loaded$kind, engine) && api_ok &&
    identical(preparation_sources,
      c(wiodr13 = "wiodr13", wiodr16 = "wiodr16")
    ) && publication_absent &&
    identical(getwd(), working_directory) && identical(search(), search_path) &&
    identical(wlv13_git_commit(root), roots[[engine]]$commit) &&
    wlv13_git_runtime_clean(root)
  if (!passed) {
    stop(sprintf("Runtime loader preflight failed for `%s`.", engine),
      call. = FALSE
    )
  }
  list(
    engine = engine,
    root = root,
    commit = roots[[engine]]$commit,
    loader_kind = loaded$kind,
    api_signatures_passed = api_ok,
    preparation_sources = as.list(preparation_sources),
    publication_probe_absent = publication_absent,
    working_directory_unchanged = TRUE,
    search_path_unchanged = TRUE,
    runtime_clean = TRUE,
    passed = TRUE
  )
})
names(runtime_loader_checks) <- c("baseline", "candidate")

expected_ids <- c(
  "baseline/prepare/all",
  "candidate/prepare/all",
  paste0("candidate/fault/", wlv13_fault_names)
)
if (!is.list(plan$records) || length(plan$records) != length(expected_ids)) {
  stop("Plan record count is invalid.", call. = FALSE)
}
observed_ids <- vapply(plan$records, `[[`, character(1L), "scenario_id")
if (!identical(observed_ids, expected_ids) || anyDuplicated(observed_ids)) {
  stop("Plan scenario ids are incomplete, duplicate, or unordered.",
    call. = FALSE)
}

audited <- lapply(seq_along(plan$records), function(index) {
  record <- plan$records[[index]]
  required_record <- c(
    "scenario_id", "kind", "project_root", "expected_commit", "channel",
    "requires_seed_channel", "scenario_spec_path", "scenario_spec_sha256",
    "checkpoint_path", "process_spec_path", "process_spec_sha256",
    "evidence_directory"
  )
  if (!is.list(record) || !setequal(names(record), required_record)) {
    stop(sprintf("Plan record %s has an invalid schema.", index), call. = FALSE)
  }
  id <- expected_ids[[index]]
  scenario_path <- normalizePath(
    record$scenario_spec_path,
    winslash = "/",
    mustWork = TRUE
  )
  process_path <- normalizePath(
    record$process_spec_path,
    winslash = "/",
    mustWork = TRUE
  )
  checkpoint_path <- normalizePath(
    record$checkpoint_path,
    winslash = "/",
    mustWork = FALSE
  )
  expected_checkpoint_path <- normalizePath(
    file.path(dirname(scenario_path), "execution-checkpoint.json"),
    winslash = "/",
    mustWork = FALSE
  )
  if (!identical(wlv13_sha256_file(scenario_path),
      record$scenario_spec_sha256) ||
      !identical(wlv13_sha256_file(process_path), record$process_spec_sha256)) {
    stop(sprintf("Spec bytes changed for `%s`.", id), call. = FALSE)
  }
  scenario <- wlv13_json_read(scenario_path, simplify = TRUE)
  process <- wlv13_json_read(process_path, simplify = TRUE)
  required_process <- c(
    "schema", "scenario_id", "executable", "arguments",
    "working_directory", "expected_exit_codes", "timeout_seconds",
    "sample_interval_ms", "shutdown_grace_seconds",
    "expected_worker_processes", "environment"
  )
  expected_rscript <- normalizePath(
    file.path(R.home("bin"), if (.Platform$OS.type == "windows") {
      "Rscript.exe"
    } else {
      "Rscript"
    }),
    winslash = "/",
    mustWork = TRUE
  )
  if (!identical(scenario$schema, "wlv-issue13-scenario/1") ||
      !identical(scenario$scenario_id, id) ||
      !identical(scenario$project_root, record$project_root) ||
      !identical(scenario$expected_commit, record$expected_commit) ||
      !identical(scenario$kind, record$kind) ||
      !identical(scenario$channel, record$channel) ||
      !identical(scenario$checkpoint_path, checkpoint_path) ||
      !identical(checkpoint_path, expected_checkpoint_path) ||
      !identical(process$schema, "wlv-issue13-process-spec/1") ||
      !setequal(names(process), required_process) ||
      !identical(process$scenario_id, id) ||
      !identical(normalizePath(process$executable,
        winslash = "/", mustWork = TRUE), expected_rscript) ||
      !identical(process$working_directory, record$project_root) ||
      !identical(as.integer(process$expected_exit_codes), 0L) ||
      !identical(as.integer(process$expected_worker_processes), 0L) ||
      !identical(as.integer(process$sample_interval_ms), 2000L) ||
      !identical(names(process$environment), c(
        "R_LIBS_USER", "RENV_PATHS_LIBRARY",
        "RENV_CONFIG_AUTO_SNAPSHOT", "RENV_CONFIG_CACHE_ENABLED",
        "RENV_CONFIG_LOCKING_ENABLED",
        "RENV_CONFIG_SANDBOX_ENABLED", "RENV_CONFIG_UPDATES_CHECK",
        "RENV_CONFIG_USER_ENVIRON", "RENV_CONFIG_USER_LIBRARY", "TZ"
      )) ||
      as.numeric(process$timeout_seconds) <= 0 ||
      as.numeric(process$shutdown_grace_seconds) < 30) {
    stop(sprintf("Scenario/process spec contract failed for `%s`.", id),
      call. = FALSE)
  }
  arguments <- as.character(unlist(process$arguments, use.names = FALSE))
  expected_arguments <- c(
    "--vanilla",
    normalizePath(file.path(script_dir, "issue13-scenario.R"),
      winslash = "/", mustWork = TRUE),
    scenario_path,
    normalizePath(record$evidence_directory, winslash = "/", mustWork = FALSE)
  )
  if (!identical(arguments, expected_arguments) ||
      !identical(normalizePath(process$environment$R_LIBS_USER,
        winslash = "/", mustWork = TRUE), r_library) ||
      !identical(normalizePath(process$environment$RENV_PATHS_LIBRARY,
        winslash = "/", mustWork = TRUE),
        wlv13_renv_library_root(r_library)) ||
      !identical(process$environment$RENV_CONFIG_AUTO_SNAPSHOT, "FALSE") ||
      !identical(process$environment$RENV_CONFIG_CACHE_ENABLED, "FALSE") ||
      !identical(process$environment$RENV_CONFIG_LOCKING_ENABLED, "FALSE") ||
      !identical(process$environment$RENV_CONFIG_SANDBOX_ENABLED, "FALSE") ||
      !identical(process$environment$RENV_CONFIG_UPDATES_CHECK, "FALSE") ||
      !identical(process$environment$RENV_CONFIG_USER_ENVIRON, "FALSE") ||
      !identical(process$environment$RENV_CONFIG_USER_LIBRARY, "FALSE") ||
      !identical(process$environment$TZ, "UTC") ||
      file.exists(checkpoint_path) || dir.exists(checkpoint_path) ||
      any(grepl(
        "^\\.execution-checkpoint(?:\\.started)?\\.json-[0-9a-f]+(?:\\.tmp)?$",
        list.files(dirname(checkpoint_path), all.files = TRUE, no.. = TRUE),
        perl = TRUE
      )) ||
      dir.exists(record$evidence_directory) || file.exists(record$evidence_directory)) {
    stop(sprintf("Process binding/evidence immutability failed for `%s`.", id),
      call. = FALSE)
  }

  is_fault <- startsWith(id, "candidate/fault/")
  expected_root <- if (identical(id, "baseline/prepare/all")) {
    roots$baseline
  } else if (identical(id, "candidate/prepare/all")) {
    roots$candidate
  } else {
    roots$fault
  }
  if (!identical(record$project_root, expected_root$root) ||
      !identical(record$expected_commit, expected_root$commit) ||
      !identical(record$requires_seed_channel, is_fault) ||
      any(!startsWith(record$channel, prefix))) {
    stop(sprintf("Root/channel/seed policy failed for `%s`.", id),
      call. = FALSE)
  }
  if (!is_fault) {
    if (!identical(scenario$kind, "prepare") ||
        !identical(as.character(scenario$methods), c("wiodr13", "wiodr16")) ||
        !identical(as.integer(scenario$euklems_years), as.integer(1995:2015)) ||
        !identical(scenario$allow_experimental, FALSE) ||
        !identical(scenario$expected_failure, FALSE)) {
      stop(sprintf("Preparation spec is non-normative for `%s`.", id),
        call. = FALSE)
    }
  } else {
    fault_id <- sub("^candidate/fault/", "", id)
    binding_index <- match(fault_id, wlv13_fault_bindings$fault_id)
    expected_checkpoint <- wlv13_fault_bindings$checkpoint[[binding_index]]
    observed_checkpoint <- if (is.null(scenario$fault$checkpoint)) {
      NA_character_
    } else {
      scenario$fault$checkpoint
    }
    if (is.na(binding_index) ||
        !identical(scenario$kind, wlv13_fault_bindings$kind[[binding_index]]) ||
        !identical(scenario$fault$fault_id, fault_id) ||
        !identical(scenario$fault$binding,
          wlv13_fault_bindings$binding[[binding_index]]) ||
        !identical(scenario$fault$when,
          wlv13_fault_bindings$when[[binding_index]]) ||
        !identical(as.integer(scenario$fault$call),
          wlv13_fault_bindings$call[[binding_index]]) ||
        !identical(observed_checkpoint, expected_checkpoint) ||
        !identical(
          scenario$fault$token,
          paste0(
            "issue13-injected-",
            substr(roots$candidate$commit, 1L, 7L),
            "-",
            gsub("-", "", fault_id),
            "-transactional"
          )
        ) ||
        !identical(scenario$expected_failure, TRUE)) {
      stop(sprintf("Fault spec is non-normative for `%s`.", id),
        call. = FALSE)
    }
  }
  list(
    scenario_id = id,
    scenario_spec_sha256 = record$scenario_spec_sha256,
    process_spec_sha256 = record$process_spec_sha256,
    channel = record$channel,
    status = "passed"
  )
})

channels <- vapply(audited, `[[`, character(1L), "channel")
if (anyDuplicated(channels)) stop("Plan channels are not unique.", call. = FALSE)
checkpoint_paths <- vapply(plan$records, `[[`, character(1L), "checkpoint_path")
if (anyDuplicated(tolower(checkpoint_paths))) {
  stop("Plan execution checkpoint paths are not unique.", call. = FALSE)
}

cache_checks <- list(
  baseline = wlv_gate_verify_raw_caches(roots$baseline$root),
  candidate = wlv_gate_verify_raw_caches(roots$candidate$root)
)
wlv_gate_assert_fresh_preparation_root(roots$baseline$root)
wlv_gate_assert_fresh_preparation_root(roots$candidate$root)
if (!all(vapply(cache_checks, `[[`, logical(1L), "passed")) ||
    !identical(cache_checks$baseline$records, cache_checks$candidate$records)) {
  stop("Preparation cache pins are incomplete or differ between arms.",
    call. = FALSE)
}

report_path <- file.path(dirname(plan_path), "plan-audit.json")
audit_candidates <- list.files(dirname(plan_path),
  pattern = "^(plan-audit\\.json|\\.plan-audit\\.json-[0-9a-f]+(?:\\.tmp)?)$",
  all.files = TRUE,
  no.. = TRUE,
  full.names = TRUE
)
audited_at <- wlv13_now()
if (length(audit_candidates) == 1L) {
  prior <- tryCatch(
    wlv13_json_read(audit_candidates[[1L]], simplify = FALSE),
    error = function(error) NULL
  )
  if (is.list(prior) && is.character(prior$audited_at) &&
      length(prior$audited_at) == 1L &&
      grepl(
        "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\\.[0-9]+)?(?:Z|[+-][0-9]{4})$",
        prior$audited_at,
        perl = TRUE
      )) {
    audited_at <- prior$audited_at
  }
}

report <- list(
  schema = "wlv-issue13-prep-fault-plan-audit/2",
  status = "passed",
  passed = TRUE,
  audited_at = audited_at,
  plan_path = plan_path,
  plan_sha256 = wlv13_sha256_file(plan_path),
  harness_files = harness_audit,
  preparation_cache_checks = cache_checks,
  runtime_loader_checks = runtime_loader_checks,
  scenario_count = length(audited),
  preparation_scenario_count = 2L,
  fault_scenario_count = 10L,
  unique_channels = TRUE,
  evidence_directories_absent = TRUE,
  execution_started = FALSE,
  records = audited
)
wlv13_json_write_or_verify(report, report_path)
cat("Preparation/fault plan audit passed:", report_path, "\n")
