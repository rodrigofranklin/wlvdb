# Build one fail-closed paper-0 scenario/process specification for the external
# issue #13 evidence harness.

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_argument)) stop("Run with Rscript.", call. = FALSE)
script_path <- normalizePath(sub("^--file=", "", script_argument[[1L]]),
  winslash = "/", mustWork = TRUE
)
script_dir <- dirname(script_path)
sys.source(file.path(script_dir, "issue13-lib.R"), envir = environment())
sys.source(file.path(script_dir, "issue13-matrix.R"), envir = environment())

options <- wlv13_parse_cli(commandArgs(trailingOnly = TRUE))
wlv13_cli_required(options, c(
  "arm", "project_root", "runtime_commit", "channel", "output",
  "evidence_root", "r_library"
))
arm <- match.arg(options$arm, wlv13_arms)
scenario_id <- paste0(arm, "/paper/0")
if (!scenario_id %in% wlv13_scenario_ids()) {
  stop("Paper scenario is outside the canonical matrix.", call. = FALSE)
}
project_root <- wlv13_normalize_existing_dir(options$project_root, "project root")
runtime_commit <- wlv13_scalar_text(options$runtime_commit,
  "runtime_commit", "^[0-9a-f]{40}$"
)
if (!identical(wlv13_git_commit(project_root), runtime_commit) ||
    !wlv13_git_runtime_clean(project_root)) {
  stop("Paper worktree must be pinned and runtime-clean.", call. = FALSE)
}
channel <- wlv13_scalar_text(options$channel, "channel",
  "^[a-z0-9][a-z0-9._-]*$"
)
channel_root <- file.path(project_root, "results", "channels", channel)
if (dir.exists(channel_root) && length(list.files(
    channel_root, all.files = TRUE, no.. = TRUE
  ))) {
  stop("Paper channel is not empty.", call. = FALSE)
}
output <- wlv13_ensure_dir(options$output, "bundle output")
evidence_root <- wlv13_ensure_dir(options$evidence_root, "evidence root")
if (wlv13_is_within(output, project_root) ||
    wlv13_is_within(evidence_root, project_root)) {
  stop("Bundle and evidence roots must be outside the worktree.", call. = FALSE)
}
safe_id <- gsub("[^A-Za-z0-9._-]", "__", scenario_id)
scenario_evidence <- file.path(evidence_root, "scenarios", safe_id)
if (dir.exists(scenario_evidence)) {
  stop("Refusing to reuse paper scenario evidence directory.", call. = FALSE)
}
rscript <- if ("rscript" %in% names(options)) {
  normalizePath(options$rscript, winslash = "/", mustWork = TRUE)
} else {
  normalizePath(file.path(R.home("bin"), if (.Platform$OS.type == "windows") {
    "Rscript.exe"
  } else {
    "Rscript"
  }), winslash = "/", mustWork = TRUE)
}
r_library <- wlv13_normalize_existing_dir(options$r_library, "R library")
timeout <- if ("timeout_seconds" %in% names(options)) {
  wlv13_integer(suppressWarnings(as.numeric(options$timeout_seconds)),
    "timeout_seconds", 1L
  )
} else {
  21600L
}
scenario_spec_path <- file.path(output, "scenario-spec.json")
process_spec_path <- file.path(output, "process-spec.json")
bundle_path <- file.path(output, "bundle.json")
scenario_spec <- list(
  schema = "wlv-issue13-scenario/1",
  scenario_id = scenario_id,
  project_root = project_root,
  expected_commit = runtime_commit,
  kind = "paper0",
  methods = as.list(wlv13_paper0_methods),
  channel = channel,
  checkpoint_path = file.path(dirname(output), "execution-checkpoint.json"),
  workers = 1L,
  allow_experimental = TRUE,
  expected_failure = FALSE
)
process_spec <- list(
  schema = "wlv-issue13-process-spec/1",
  scenario_id = scenario_id,
  executable = rscript,
  arguments = list(
    "--vanilla", file.path(script_dir, "issue13-scenario.R"),
    scenario_spec_path, scenario_evidence
  ),
  working_directory = project_root,
  environment = wlv13_r_environment(r_library),
  expected_exit_codes = list(0L),
  timeout_seconds = timeout,
  sample_interval_ms = 1000L,
  shutdown_grace_seconds = 60,
  expected_worker_processes = 0L
)
bundle <- list(
  schema = "wlv-issue13-paper-bundle/1",
  scenario_id = scenario_id,
  process_spec = process_spec_path,
  scenario_evidence = scenario_evidence,
  runtime_commit = runtime_commit,
  r_library = r_library,
  channel = channel
)
wlv13_assert_json_bundle_envelope(output, c(
  "scenario-spec.json", "process-spec.json", "bundle.json"
))
wlv13_json_write_or_verify(scenario_spec, scenario_spec_path)
wlv13_json_write_or_verify(process_spec, process_spec_path)
wlv13_json_write_or_verify(bundle, bundle_path)
cat(bundle_path, "\n")
