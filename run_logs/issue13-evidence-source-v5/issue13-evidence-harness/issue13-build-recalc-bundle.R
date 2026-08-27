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
  "arm", "method", "stage", "variant", "project_root", "runtime_commit",
  "seed_commit", "seed_result", "channel", "output", "evidence_root"
))
arm <- match.arg(options$arm, wlv13_arms)
method <- match.arg(options$method, wlv13_methods)
stage <- wlv13_integer(suppressWarnings(as.numeric(options$stage)), "stage", 1L)
variant <- wlv13_scalar_text(options$variant, "variant",
  "^[a-z][a-z0-9-]*$"
)
phase <- paste0("recalculate/", method, "/stage", stage, "/", variant)
expectation <- wlv13_recalculation_expectation(phase)
project_root <- wlv13_normalize_existing_dir(options$project_root, "project root")
runtime_commit <- wlv13_scalar_text(options$runtime_commit,
  "runtime_commit", "^[0-9a-f]{40}$"
)
seed_commit <- wlv13_scalar_text(options$seed_commit,
  "seed_commit", "^[0-9a-f]{40}$"
)
seed_result <- normalizePath(options$seed_result,
  winslash = "/", mustWork = TRUE
)
channel <- wlv13_scalar_text(options$channel, "channel",
  "^[a-z0-9][a-z0-9._-]*$"
)
output <- wlv13_ensure_dir(options$output, "bundle output")
evidence_root <- wlv13_ensure_dir(options$evidence_root, "evidence root")
if (wlv13_is_within(output, project_root) ||
    wlv13_is_within(evidence_root, project_root) ||
    wlv13_is_within(seed_result, project_root)) {
  stop("Bundle, evidence, and seed proof must be outside the worktree.",
    call. = FALSE
  )
}
scenario_id <- paste0(arm, "/", phase)
safe_id <- gsub("[^A-Za-z0-9._-]", "__", scenario_id)
seed_evidence <- file.path(evidence_root, "seeds", safe_id)
scenario_evidence <- file.path(evidence_root, "scenarios", safe_id)
if (dir.exists(seed_evidence) || dir.exists(scenario_evidence)) {
  stop("Refusing to reuse seed/scenario evidence directories.", call. = FALSE)
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
r_library <- if ("r_library" %in% names(options)) {
  wlv13_normalize_existing_dir(options$r_library, "R library")
} else {
  NULL
}
timeout <- if ("timeout_seconds" %in% names(options)) {
  wlv13_integer(suppressWarnings(as.numeric(options$timeout_seconds)),
    "timeout_seconds", 1L
  )
} else {
  14400L
}
seed_spec_path <- file.path(output, "seed-spec.json")
scenario_spec_path <- file.path(output, "scenario-spec.json")
process_spec_path <- file.path(output, "process-spec.json")
bundle_path <- file.path(output, "bundle.json")
seed_spec <- list(
  schema = "wlv-issue13-channel-seed/1",
  scenario_id = scenario_id,
  project_root = project_root,
  expected_commit = runtime_commit,
  expected_seed_commit = seed_commit,
  method = method,
  channel = channel,
  seed_result_path = seed_result
)
scenario_spec <- list(
  schema = "wlv-issue13-scenario/1",
  scenario_id = scenario_id,
  project_root = project_root,
  expected_commit = runtime_commit,
  expected_seed_commit = seed_commit,
  kind = "recalculate",
  method = method,
  channel = channel,
  checkpoint_path = file.path(dirname(output), "execution-checkpoint.json"),
  workers = 1L,
  allow_experimental = TRUE,
  at_stage = stage,
  sea_vars = if (is.null(expectation$sea_vars)) NULL else
    as.list(expectation$sea_vars),
  seed_result_path = seed_result
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
  environment = if (is.null(r_library)) NULL else list(R_LIBS_USER = r_library),
  expected_exit_codes = list(0L),
  timeout_seconds = timeout,
  sample_interval_ms = 1000L,
  shutdown_grace_seconds = 60,
  expected_worker_processes = 0L
)
bundle <- list(
  schema = "wlv-issue13-recalc-bundle/1",
  scenario_id = scenario_id,
  seed_script = file.path(script_dir, "issue13-seed-channel.R"),
  seed_spec = seed_spec_path,
  seed_evidence = seed_evidence,
  process_spec = process_spec_path,
  scenario_evidence = scenario_evidence,
  runtime_commit = runtime_commit,
  seed_commit = seed_commit,
  r_library = r_library,
  channel = channel
)
wlv13_assert_json_bundle_envelope(output, c(
  "seed-spec.json", "scenario-spec.json", "process-spec.json", "bundle.json"
))
wlv13_json_write_or_verify(seed_spec, seed_spec_path)
wlv13_json_write_or_verify(scenario_spec, scenario_spec_path)
wlv13_json_write_or_verify(process_spec, process_spec_path)
wlv13_json_write_or_verify(bundle, bundle_path)
cat(bundle_path, "\n")
