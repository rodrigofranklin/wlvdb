# Build ten authenticated channel-seed process specs after fault inputs have
# been copied into the isolated candidate store. This does not execute them.

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
wlv13_cli_required(options, c("plan", "import_report", "output"))
plan_path <- normalizePath(options$plan, winslash = "/", mustWork = TRUE)
import_report_path <- normalizePath(options$import_report,
  winslash = "/", mustWork = TRUE
)
output_requested <- normalizePath(options$output,
  winslash = "/", mustWork = FALSE
)
if (dir.exists(output_requested) || file.exists(output_requested)) {
  stop("Fault-seed spec output must not already exist.", call. = FALSE)
}
output <- wlv13_ensure_dir(output_requested, "fault-seed spec output")

plan <- wlv13_json_read(plan_path, simplify = FALSE)
if (!identical(plan$schema, "wlv-issue13-prep-fault-plan/2") ||
    length(plan$records) != 12L) {
  stop("Preparation/fault plan is invalid.", call. = FALSE)
}
baseline_root <- wlv13_normalize_existing_dir(
  plan$roots$baseline$root, "baseline root"
)
candidate_root <- wlv13_normalize_existing_dir(
  plan$roots$candidate$root, "candidate root"
)
fault_root <- wlv13_normalize_existing_dir(plan$roots$fault$root, "fault root")
plan_auth <- wlv_gate_prep_load_plan(
  plan_path,
  baseline_root,
  candidate_root,
  plan$roots$baseline$commit,
  plan$roots$candidate$commit
)
import_report <- wlv13_json_read(import_report_path, simplify = FALSE)
if (!identical(import_report$schema, "wlv-issue13-fault-input-import/1") ||
    !isTRUE(import_report$passed) ||
    !identical(import_report$status, "passed") ||
    !identical(import_report$candidate_commit,
      plan$roots$candidate$commit
    ) ||
    !wlv_gate_prep_same_path(import_report$fault_root, fault_root) ||
    !isTRUE(import_report$source_stores_unchanged)) {
  stop("Fault-input import report is missing, stale, or failed.", call. = FALSE)
}
proof_path <- normalizePath(import_report$imported_seed_proof_path,
  winslash = "/", mustWork = TRUE
)
if (!identical(wlv13_sha256_file(proof_path),
    import_report$imported_seed_proof_sha256)) {
  stop("Imported seed proof changed after authentication.", call. = FALSE)
}
proof <- wlv13_json_read(proof_path, simplify = FALSE)
if (!identical(proof$schema, wlv13_schema$scenario) ||
    !isTRUE(proof$passed) ||
    !identical(proof$observed_commit, import_report$seed_commit)) {
  stop("Imported seed proof is invalid.", call. = FALSE)
}
if (!identical(wlv13_git_commit(fault_root), plan$roots$fault$commit) ||
    !wlv13_git_runtime_clean(fault_root)) {
  stop("Fault worktree is not pinned/runtime-clean.", call. = FALSE)
}

rscript <- normalizePath(file.path(
  R.home("bin"),
  if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
), winslash = "/", mustWork = TRUE)
seed_script <- normalizePath(file.path(script_dir, "issue13-seed-channel.R"),
  winslash = "/", mustWork = TRUE
)
spec_root <- wlv13_ensure_dir(file.path(output, "specs"), "seed spec root")
evidence_root <- normalizePath(file.path(output, "evidence"),
  winslash = "/", mustWork = FALSE
)
fault_records <- plan$records[seq.int(3L, 12L)]
expected_fault_ids <- paste0("candidate/fault/", wlv13_fault_names)
if (!identical(vapply(fault_records, `[[`, character(1L), "scenario_id"),
    expected_fault_ids
)) {
  stop("Fault plan record set is incomplete or unordered.", call. = FALSE)
}

records <- lapply(seq_along(fault_records), function(index) {
  fault_record <- fault_records[[index]]
  fault_id <- wlv13_fault_names[[index]]
  safe <- paste0("candidate__seed__fault__", gsub("-", "", fault_id))
  directory <- wlv13_ensure_dir(file.path(spec_root, safe),
    "seed spec directory"
  )
  evidence <- normalizePath(file.path(evidence_root, safe),
    winslash = "/", mustWork = FALSE
  )
  if (dir.exists(evidence) || file.exists(evidence)) {
    stop(sprintf("Seed evidence already exists for `%s`.", fault_id),
      call. = FALSE
    )
  }
  seed_id <- paste0("candidate/seed/fault/", fault_id)
  seed_spec <- list(
    schema = "wlv-issue13-channel-seed/1",
    scenario_id = seed_id,
    project_root = fault_root,
    expected_commit = plan$roots$fault$commit,
    method = "wiodr13",
    channel = fault_record$channel,
    seed_result_path = proof_path,
    expected_seed_commit = import_report$seed_commit
  )
  seed_spec_path <- file.path(directory, "seed-spec.json")
  process_spec_path <- file.path(directory, "process-spec.json")
  wlv13_json_write(seed_spec, seed_spec_path)
  process_spec <- list(
    schema = "wlv-issue13-process-spec/1",
    scenario_id = seed_id,
    executable = rscript,
    arguments = as.list(c(
      "--vanilla", seed_script,
      normalizePath(seed_spec_path, winslash = "/", mustWork = TRUE),
      evidence
    )),
    working_directory = fault_root,
    expected_exit_codes = as.list(0L),
    timeout_seconds = 30 * 60,
    sample_interval_ms = 1000L,
    shutdown_grace_seconds = 60,
    expected_worker_processes = 0L,
    environment = wlv13_r_environment(plan$r_library)
  )
  wlv13_json_write(process_spec, process_spec_path)
  list(
    scenario_id = seed_id,
    fault_id = fault_id,
    channel = fault_record$channel,
    seed_spec_path = normalizePath(seed_spec_path,
      winslash = "/", mustWork = TRUE
    ),
    seed_spec_sha256 = wlv13_sha256_file(seed_spec_path),
    process_spec_path = normalizePath(process_spec_path,
      winslash = "/", mustWork = TRUE
    ),
    process_spec_sha256 = wlv13_sha256_file(process_spec_path),
    evidence_directory = evidence
  )
})
channels <- vapply(records, `[[`, character(1L), "channel")
if (anyDuplicated(channels)) stop("Fault seed channels are not unique.",
  call. = FALSE
)
seed_plan <- list(
  schema = "wlv-issue13-fault-seed-plan/1",
  created_at = wlv13_now(),
  execution_started = FALSE,
  source_plan_path = plan_path,
  source_plan_sha256 = plan_auth$plan_sha256,
  source_plan_audit_path = plan_auth$audit_path,
  source_plan_audit_sha256 = plan_auth$audit_sha256,
  import_report_path = import_report_path,
  import_report_sha256 = wlv13_sha256_file(import_report_path),
  imported_seed_proof_path = proof_path,
  imported_seed_proof_sha256 = wlv13_sha256_file(proof_path),
  fault_root = fault_root,
  candidate_commit = plan$roots$fault$commit,
  seed_commit = import_report$seed_commit,
  r_library = plan$r_library,
  record_count = length(records),
  records = records
)
seed_plan_path <- file.path(output, "seed-plan.json")
wlv13_json_write(seed_plan, seed_plan_path)
cat("Fault seed specs built:", seed_plan_path, "\n")
