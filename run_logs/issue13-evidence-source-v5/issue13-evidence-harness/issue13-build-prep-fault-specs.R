# Build immutable preparation and fault-gate specifications without executing them.

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

options <- wlv13_parse_cli(commandArgs(trailingOnly = TRUE))
wlv13_cli_required(options, c(
  "output_root", "baseline_root", "baseline_commit", "candidate_root",
  "candidate_commit", "fault_root", "r_library", "channel_prefix"
))

output_requested <- normalizePath(
  options$output_root,
  winslash = "/",
  mustWork = FALSE
)
if (dir.exists(output_requested) || file.exists(output_requested)) {
  stop("Specification output root must not already exist.", call. = FALSE)
}
output_root <- wlv13_ensure_dir(output_requested, "specification output root")
baseline_root <- wlv13_normalize_existing_dir(
  options$baseline_root,
  "baseline preparation root"
)
candidate_root <- wlv13_normalize_existing_dir(
  options$candidate_root,
  "candidate preparation root"
)
fault_root <- wlv13_normalize_existing_dir(options$fault_root, "fault root")
r_library <- wlv13_normalize_existing_dir(options$r_library, "R library")
baseline_commit <- wlv13_scalar_text(
  options$baseline_commit,
  "baseline_commit",
  "^[0-9a-f]{40}$"
)
candidate_commit <- wlv13_scalar_text(
  options$candidate_commit,
  "candidate_commit",
  "^[0-9a-f]{40}$"
)
channel_prefix <- wlv13_scalar_text(
  options$channel_prefix,
  "channel_prefix",
  "^[a-z0-9][a-z0-9.-]*-$"
)
if (nchar(channel_prefix) > 55L) {
  stop("channel_prefix is too long for deterministic fault channels.",
    call. = FALSE)
}

roots <- c(baseline_root, candidate_root, fault_root)
if (any(vapply(roots, function(root) wlv13_is_within(output_root, root),
    logical(1L)))) {
  stop("Specification output must be outside every evaluated worktree.",
    call. = FALSE)
}
expected_roots <- list(
  baseline = list(root = baseline_root, commit = baseline_commit),
  candidate = list(root = candidate_root, commit = candidate_commit),
  fault = list(root = fault_root, commit = candidate_commit)
)
for (record in expected_roots) {
  if (!identical(wlv13_git_commit(record$root), record$commit) ||
      !wlv13_git_runtime_clean(record$root)) {
    stop("A specification worktree is not pinned and runtime-clean.",
      call. = FALSE)
  }
}

rscript <- normalizePath(
  file.path(R.home("bin"), if (.Platform$OS.type == "windows") {
    "Rscript.exe"
  } else {
    "Rscript"
  }),
  winslash = "/",
  mustWork = TRUE
)
scenario_script <- normalizePath(
  file.path(script_dir, "issue13-scenario.R"),
  winslash = "/",
  mustWork = TRUE
)
spec_root <- wlv13_ensure_dir(file.path(output_root, "specs"), "spec root")
scenario_evidence_root <- file.path(output_root, "scenarios")

safe_id <- function(value) gsub("/", "__", value, fixed = TRUE)
records <- list()

write_pair <- function(scenario, timeout_seconds, requires_seed_channel = FALSE) {
  id <- scenario$scenario_id
  safe <- safe_id(id)
  directory <- wlv13_ensure_dir(file.path(spec_root, safe), "scenario spec directory")
  evidence <- normalizePath(
    file.path(scenario_evidence_root, safe),
    winslash = "/",
    mustWork = FALSE
  )
  scenario_path <- file.path(directory, "scenario-spec.json")
  process_path <- file.path(directory, "process-spec.json")
  checkpoint_path <- normalizePath(
    file.path(directory, "execution-checkpoint.json"),
    winslash = "/",
    mustWork = FALSE
  )
  scenario$checkpoint_path <- checkpoint_path
  wlv13_json_write(scenario, scenario_path)
  process <- list(
    schema = "wlv-issue13-process-spec/1",
    scenario_id = id,
    executable = rscript,
    arguments = as.list(c(
      "--vanilla",
      scenario_script,
      normalizePath(scenario_path, winslash = "/", mustWork = TRUE),
      evidence
    )),
    working_directory = scenario$project_root,
    expected_exit_codes = as.list(0L),
    timeout_seconds = as.numeric(timeout_seconds),
    sample_interval_ms = 2000L,
    shutdown_grace_seconds = 60,
    expected_worker_processes = 0L,
    environment = list(R_LIBS_USER = r_library)
  )
  wlv13_json_write(process, process_path)
  records[[id]] <<- list(
    scenario_id = id,
    kind = scenario$kind,
    project_root = scenario$project_root,
    expected_commit = scenario$expected_commit,
    channel = scenario$channel,
    requires_seed_channel = requires_seed_channel,
    scenario_spec_path = normalizePath(
      scenario_path,
      winslash = "/",
      mustWork = TRUE
    ),
    scenario_spec_sha256 = wlv13_sha256_file(scenario_path),
    checkpoint_path = checkpoint_path,
    process_spec_path = normalizePath(
      process_path,
      winslash = "/",
      mustWork = TRUE
    ),
    process_spec_sha256 = wlv13_sha256_file(process_path),
    evidence_directory = evidence
  )
  invisible(records[[id]])
}

for (arm in c("baseline", "candidate")) {
  arm_root <- if (identical(arm, "baseline")) baseline_root else candidate_root
  arm_commit <- if (identical(arm, "baseline")) {
    baseline_commit
  } else {
    candidate_commit
  }
  write_pair(list(
    schema = "wlv-issue13-scenario/1",
    scenario_id = paste0(arm, "/prepare/all"),
    project_root = arm_root,
    expected_commit = arm_commit,
    kind = "prepare",
    methods = as.list(c("wiodr13", "wiodr16")),
    euklems_years = as.list(as.integer(1995:2015)),
    channel = paste0(channel_prefix, "prep-", arm),
    workers = 1L,
    allow_experimental = FALSE,
    expected_failure = FALSE
  ), timeout_seconds = 8 * 60 * 60)
}

if (!identical(wlv13_fault_bindings$fault_id, wlv13_fault_names) ||
    anyDuplicated(wlv13_fault_bindings$fault_id)) {
  stop("Canonical fault matrix is inconsistent.", call. = FALSE)
}
for (index in seq_along(wlv13_fault_names)) {
  fault_id <- wlv13_fault_names[[index]]
  kind <- wlv13_fault_bindings$kind[[index]]
  channel <- paste0(channel_prefix, "fault-", gsub("-", "", fault_id))
  checkpoint <- wlv13_fault_bindings$checkpoint[[index]]
  scenario <- list(
    schema = "wlv-issue13-scenario/1",
    scenario_id = paste0("candidate/fault/", fault_id),
    project_root = fault_root,
    expected_commit = candidate_commit,
    kind = kind,
    channel = channel,
    workers = 1L,
    allow_experimental = FALSE,
    expected_failure = TRUE,
    fault = list(
      fault_id = fault_id,
      binding = wlv13_fault_bindings$binding[[index]],
      when = wlv13_fault_bindings$when[[index]],
      call = wlv13_fault_bindings$call[[index]],
      checkpoint = if (is.na(checkpoint)) NULL else checkpoint,
      token = paste0(
        "issue13-injected-",
        substr(candidate_commit, 1L, 7L),
        "-",
        gsub("-", "", fault_id),
        "-transactional"
      )
    )
  )
  if (identical(kind, "calculate")) {
    scenario$method <- "wiodr13"
  } else {
    scenario$euklems_years <- as.list(as.integer(1995:2015))
  }
  write_pair(
    scenario,
    timeout_seconds = if (identical(kind, "prepare_euklems")) {
      2 * 60 * 60
    } else {
      4 * 60 * 60
    },
    requires_seed_channel = TRUE
  )
}

ordered_ids <- c(
  "baseline/prepare/all",
  "candidate/prepare/all",
  paste0("candidate/fault/", wlv13_fault_names)
)
if (!identical(names(records), ordered_ids)) {
  stop("Generated preparation/fault specification set is incomplete.",
    call. = FALSE)
}
harness_paths <- c(
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
harness_files <- lapply(names(harness_paths), function(name) {
  path <- normalizePath(harness_paths[[name]], winslash = "/", mustWork = TRUE)
  list(name = name, path = path, sha256 = wlv13_sha256_file(path))
})
plan <- list(
  schema = "wlv-issue13-prep-fault-plan/2",
  created_at = wlv13_now(),
  execution_started = FALSE,
  preparation_scenario_count = 2L,
  fault_scenario_count = length(wlv13_fault_names),
  candidate_channel_prefix = channel_prefix,
  r_library = r_library,
  harness_files = harness_files,
  roots = expected_roots,
  records = unname(records)
)
plan_path <- file.path(output_root, "plan.json")
wlv13_json_write(plan, plan_path)
cat("Preparation/fault specs built:", plan_path, "\n")
