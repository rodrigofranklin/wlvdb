# Materialize eight exact FST-array proofs from the two authenticated early
# comparisons of campaign 054.  This reads manifests, sidecars, and FST headers;
# it never opens FST payload columns and never runs a scientific calculation.

raw_arguments <- commandArgs(trailingOnly = TRUE)
if (length(raw_arguments) %% 2L != 0L ||
    any(!startsWith(raw_arguments[seq.int(1L, length(raw_arguments), 2L)], "--"))) {
  stop("Arguments must be --name value pairs.", call. = FALSE)
}
argument_names <- sub("^--", "", raw_arguments[seq.int(1L,
  length(raw_arguments), 2L)])
arguments <- as.list(raw_arguments[seq.int(2L, length(raw_arguments), 2L)])
names(arguments) <- gsub("-", "_", argument_names, fixed = TRUE)
required <- c("comparison_root", "config", "science_binding",
  "comparison_binding", "wiodr13_origin", "wiodr16_origin", "output",
  "proof_lib")
missing <- setdiff(required, names(arguments))
if (length(missing)) {
  stop(sprintf("Missing argument(s): %s.", paste(missing, collapse = ", ")),
    call. = FALSE)
}

comparison_root <- normalizePath(arguments$comparison_root,
  winslash = "/", mustWork = TRUE)
harness_root <- file.path(comparison_root, "issue13-evidence-harness")
sys.source(file.path(harness_root, "issue13-lib.R"), envir = environment())
sys.source(file.path(harness_root, "issue13-compare-lib.R"),
  envir = environment())
sys.source(file.path(harness_root, "issue13-v5-difference-fingerprint.R"),
  envir = environment())
sys.source(normalizePath(arguments$proof_lib, winslash = "/", mustWork = TRUE),
  envir = environment())

fixed <- list(
  wiodr13 = list(
    basename = "early-parity-wiodr13-002",
    comparison_id = "early/parity/wiodr13/002",
    attempt = 2L,
    job_sha256 = "cc112dc8683828498cbca325f9d9bb3991dca31a98cfed788b6751be6cd87a04",
    attempt_sha256 = "da660cd0696be928f1d9d46d3c7579ab53c939de41a3adf6ae40519b6f16b5ce",
    process_sha256 = "f4f1d795b90b7f39dc108467a3c2bec15256a70dc50d4e36406d38daab0801ee",
    comparison_sha256 = "bf820579c98f74cc7803998dc2030445fdc7dab69e169a1186372118b233fcca",
    output_hashes = list(
      artifact_summary = "7fc5fd4d7f4c399a93ca98a187b7e5d887d4b7762ec757523944cbb53846c581",
      transitions = "ae6246e63bbc15aee1c7afde88e8a19adcd7864316f00b507f1e51439dcdb923",
      indicators = "91a4e2f100227487a802ac040b85700f03520b347fbfe4c23b7bf2d97b43d9fa"
    )
  ),
  wiodr16 = list(
    basename = "early-parity-wiodr16-001",
    comparison_id = "early/parity/wiodr16/001",
    attempt = 1L,
    job_sha256 = "38cc5ed86094a81b03c49ef6ac30687d1c6b5d41fe7dbe64cf474ef98e3ed8c3",
    attempt_sha256 = "b897a121269a783dc8d14ac0d202b9e56677b121361187afb5921bb5cc9d57c0",
    process_sha256 = "72fad535bf5268f5b3b1d92b253b46f3b35dbcf71b827e9cb993711aad35b6bf",
    comparison_sha256 = "e6df7054cc0226149c38320616f73c887dea58144ac9dce3782d3b625c0273b4",
    output_hashes = list(
      artifact_summary = "09b8da425050f6f8e8544c315d5c0e3701e43e0a574f197ed98b958e0674a80f",
      transitions = "e68517fc91e1dfaae35f791f639276a5e1ee62f29f6a1ed8f3b1c9aa7fe8353e",
      indicators = "91a4e2f100227487a802ac040b85700f03520b347fbfe4c23b7bf2d97b43d9fa"
    )
  )
)
config_path <- normalizePath(arguments$config, winslash = "/", mustWork = TRUE)
science_binding_path <- normalizePath(arguments$science_binding,
  winslash = "/", mustWork = TRUE)
comparison_binding_path <- normalizePath(arguments$comparison_binding,
  winslash = "/", mustWork = TRUE)
config_sha <- wlv13_sha256_file(config_path)
science_binding_sha <- wlv13_sha256_file(science_binding_path)
comparison_binding_sha <- wlv13_sha256_file(comparison_binding_path)
if (!identical(config_sha,
    "797d5aa45b5568fea8ac2efb7ee61f21f7d905cbec2354f6263106b4635be2bb") ||
    !identical(science_binding_sha,
      "ea1fa3a8090972018de8cdb65eea92301c4429d9b39da07c16d24012c0044be8") ||
    !identical(comparison_binding_sha,
      "b464b4c29255feed2a30a41c59f22d9ef5df4dd9304efc01dcfd62e37871e3d9")) {
  stop("Array proofs are restricted to the fixed 054-v2 bindings.",
    call. = FALSE)
}
comparison_binding <- wlv13_json_read(comparison_binding_path, simplify = FALSE)
if (!identical(comparison_binding$schema,
    "wlv-issue13-main-comparison-binding/1") ||
    !identical(normalizePath(comparison_binding$runtime_root,
      winslash = "/", mustWork = TRUE), comparison_root)) {
  stop("Comparison binding does not own the requested runtime root.",
    call. = FALSE)
}

algorithm_paths <- c(
  "issue13-evidence-harness/issue13-lib.R",
  "issue13-prep-paper-lib.R",
  "issue13-evidence-harness/issue13-compare-lib.R",
  "issue13-evidence-harness/issue13-v5-difference-fingerprint.R",
  "issue13-evidence-harness/issue13-v5-compare-override.R",
  "issue13-evidence-harness/issue13-v5-diagnostics-override.R",
  "issue13-evidence-harness/issue13-compare-results.R"
)
binding_records <- stats::setNames(comparison_binding$records,
  vapply(comparison_binding$records, `[[`, character(1L), "relative_path"))
algorithms <- lapply(algorithm_paths, function(relative) {
  record <- binding_records[[relative]]
  path <- file.path(comparison_root, relative)
  if (is.null(record) || !identical(wlv13_sha256_file(path), record$sha256)) {
    stop(sprintf("Comparison algorithm differs from its binding: %s.", relative),
      call. = FALSE)
  }
  list(path = relative, sha256 = record$sha256)
})
context <- list(
  config_sha256 = config_sha,
  science_tooling_binding_sha256 = science_binding_sha,
  comparison_binding_sha256 = comparison_binding_sha,
  algorithms = algorithms
)

records_frame <- function(manifest) {
  rows <- lapply(manifest$artifacts, function(record) data.frame(
    path = wlv13_ap_scalar(record$path, "manifest artifact path"),
    role = wlv13_ap_scalar(record$role, "manifest artifact role"),
    size_bytes = as.numeric(record$size_bytes),
    sha256 = wlv13_ap_hex(record$sha256, "manifest artifact SHA-256"),
    stringsAsFactors = FALSE
  ))
  value <- do.call(rbind, rows)
  if (anyDuplicated(value$path) || anyNA(value$size_bytes) ||
      any(value$size_bytes < 0)) {
    stop("Run manifest artifact records are invalid.", call. = FALSE)
  }
  row.names(value) <- NULL
  value
}

read_inventory_without_payload_scan <- function(report_side) {
  root <- normalizePath(report_side$root, winslash = "/", mustWork = TRUE)
  manifest_path <- normalizePath(report_side$manifest_path,
    winslash = "/", mustWork = TRUE)
  if (!wlv13_is_within(manifest_path, root) ||
      !identical(wlv13_sha256_file(manifest_path), report_side$manifest_sha256)) {
    stop("Early comparison manifest binding changed.", call. = FALSE)
  }
  manifest <- wlv13_json_read(manifest_path, simplify = FALSE)
  inventory <- list(kind = "run", root = root, manifest_path = manifest_path,
    manifest_sha256 = report_side$manifest_sha256, manifest = manifest,
    records = records_frame(manifest), identity = report_side$identity)
  if (!identical(wlv13_inventory_signature(inventory),
      report_side$inventory_sha256)) {
    stop("Early comparison inventory signature changed.", call. = FALSE)
  }
  inventory
}

validate_controller_records <- function(records) {
  if (!is.list(records) || length(records) != 4L) {
    stop("Early comparison controller record count changed.", call. = FALSE)
  }
  roles <- vapply(records, `[[`, character(1L), "role")
  if (anyDuplicated(roles) || !setequal(roles, c("early-comparison",
      "shared-lib", "comparison-binding-lib", "comparison-worker"))) {
    stop("Early comparison controller roles changed.", call. = FALSE)
  }
  for (record in records) {
    if (!identical(wlv13_sha256_file(record$snapshot_path),
        record$snapshot_sha256) || !identical(record$sha256,
        record$snapshot_sha256)) {
      stop("Early comparison controller snapshot changed.",
        call. = FALSE)
    }
  }
}

read_origin <- function(method, path) {
  expectation <- fixed[[method]]
  root <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (!identical(basename(root), expectation$basename)) {
    stop(sprintf("Unexpected %s early comparison root.", method), call. = FALSE)
  }
  paths <- list(
    job = file.path(root, "job.json"),
    attempt = file.path(root, "attempt-result.json"),
    process = file.path(root, "process.json"),
    comparison = file.path(root, "comparison", "comparison.json"),
    artifact_summary = file.path(root, "comparison", "artifact-summary.csv"),
    transitions = file.path(root, "comparison", "state-transitions.csv"),
    indicators = file.path(root, "comparison", "indicator-differences.csv"),
    stdout = file.path(root, "worker.stdout.log"),
    stderr = file.path(root, "worker.stderr.log")
  )
  observed <- vapply(paths[c("job", "attempt", "process", "comparison")],
    wlv13_sha256_file, character(1L))
  expected <- c(job = expectation$job_sha256,
    attempt = expectation$attempt_sha256,
    process = expectation$process_sha256,
    comparison = expectation$comparison_sha256)
  if (!identical(observed, expected) ||
      !identical(wlv13_sha256_file(paths$artifact_summary),
        expectation$output_hashes$artifact_summary) ||
      !identical(wlv13_sha256_file(paths$transitions),
        expectation$output_hashes$transitions) ||
      !identical(wlv13_sha256_file(paths$indicators),
        expectation$output_hashes$indicators) ||
      !identical(wlv13_sha256_file(paths$stdout),
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") ||
      !identical(wlv13_sha256_file(paths$stderr),
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")) {
    stop(sprintf("Authenticated %s early proof files changed.", method),
      call. = FALSE)
  }
  job <- wlv13_json_read(paths$job, simplify = FALSE)
  attempt <- wlv13_json_read(paths$attempt, simplify = FALSE)
  process <- wlv13_json_read(paths$process, simplify = FALSE)
  report <- wlv13_json_read(paths$comparison, simplify = FALSE)
  valid <- identical(job$schema, "wlv-issue13-main-comparison-job/2") &&
    identical(job$comparison_id, expectation$comparison_id) &&
    identical(as.integer(job$attempt), expectation$attempt) &&
    identical(job$mode, "cross_engine_run_v3") &&
    identical(job$allow_difference, FALSE) &&
    identical(job$config_sha256, config_sha) &&
    identical(job$tooling_binding_sha256, science_binding_sha) &&
    identical(job$comparison_binding_sha256, comparison_binding_sha) &&
    identical(wlv13_sha256_file(job$candidate_result),
      job$candidate_result_sha256) &&
    identical(wlv13_sha256_file(job$baseline_result),
      job$baseline_result_sha256) &&
    identical(attempt$schema, "wlv-issue13-main-comparison-attempt/2") &&
    identical(attempt$comparison_id, job$comparison_id) &&
    identical(as.integer(attempt$attempt), expectation$attempt) &&
    identical(attempt$status, "passed") && identical(attempt$passed, TRUE) &&
    identical(attempt$comparison_passed, TRUE) &&
    identical(attempt$job_sha256, expectation$job_sha256) &&
    identical(attempt$comparison_sha256, expectation$comparison_sha256) &&
    identical(process$schema, "wlv-issue13-main-early-comparison-process/1") &&
    identical(process$job_sha256, expectation$job_sha256) &&
    identical(process$writes_main_state, FALSE) &&
    identical(report$schema, "wlv-issue13-artifact-comparison/1") &&
    identical(report$scenario_id, job$comparison_id) &&
    identical(report$status, "passed") && identical(report$passed, TRUE) &&
    identical(as.integer(report$chunk_rows), 1000000L) &&
    identical(report$comparison_mode, "cross_engine_run_v3") &&
    identical(report$indicator_differences, list())
  if (!valid || !identical(wlv13_ap_token(job$controller_records),
      wlv13_ap_token(attempt$controller_records))) {
    stop(sprintf("Authenticated %s early proof envelope changed.", method),
      call. = FALSE)
  }
  validate_controller_records(job$controller_records)
  contracts <- job$input_contracts
  if (!is.list(contracts) || length(contracts) != 2L ||
      !setequal(vapply(contracts, `[[`, character(1L), "side"),
        c("candidate", "baseline")) ||
      !all(vapply(contracts, function(record) identical(record$method, method) &&
        identical(as.integer(record$expected_worker_processes), 0L), logical(1L)))) {
    stop(sprintf("Authenticated %s input contracts changed.", method),
      call. = FALSE)
  }
  contract_for <- function(side) {
    record <- contracts[[which(vapply(contracts, `[[`, character(1L),
      "side") == side)]]
    list(arm = record$arm, method = record$method,
      expected_commit = record$commit, observed_commit = record$commit)
  }
  candidate <- read_inventory_without_payload_scan(report$candidate)
  baseline <- read_inventory_without_payload_scan(report$baseline)
  list(
    root = root, job = job, attempt = attempt, process = process,
    report = report, candidate = candidate, baseline = baseline,
    engine_pair = list(candidate = contract_for("candidate"),
      baseline = contract_for("baseline")),
    origin = list(
      method = method,
      comparison_id = job$comparison_id,
      job = list(path = paths$job, sha256 = observed[["job"]]),
      attempt_result = list(path = paths$attempt,
        sha256 = observed[["attempt"]]),
      process = list(path = paths$process, sha256 = observed[["process"]]),
      comparison = list(path = paths$comparison,
        sha256 = observed[["comparison"]]),
      candidate_result = list(path = job$candidate_result,
        sha256 = job$candidate_result_sha256),
      baseline_result = list(path = job$baseline_result,
        sha256 = job$baseline_result_sha256),
      controller_records = job$controller_records
    )
  )
}

raw_summary <- function(value) {
  remove <- c("meta_role_match", "key", "type", "candidate_path",
    "baseline_path", "role_match")
  value[setdiff(names(value), remove)]
}

raw_transitions <- function(report, key) {
  rows <- Filter(function(row) identical(row$artifact, key), report$transitions)
  if (!length(rows)) stop("FST proof lacks state transitions.", call. = FALSE)
  states <- vapply(rows, `[[`, character(1L), "candidate_state")
  indices <- match(states, wlv13_state_names)
  row_names <- as.character(indices + (indices - 1L) * length(wlv13_state_names))
  values <- lapply(rows, function(row) list(
    candidate_state = row$candidate_state,
    baseline_state = row$baseline_state,
    count = format(as.numeric(row$count), scientific = FALSE, trim = TRUE)
  ))
  list(row_names = as.list(row_names), rows = values)
}

origins <- list(
  read_origin("wiodr13", arguments$wiodr13_origin),
  read_origin("wiodr16", arguments$wiodr16_origin)
)
proof_records <- list()
for (origin in origins) {
  left <- wlv13_artifact_descriptors(origin$candidate)
  right <- wlv13_artifact_descriptors(origin$baseline)
  summaries <- Filter(function(value) identical(value$type, "fst_array"),
    origin$report$artifacts)
  if (length(summaries) != 4L) {
    stop("Early comparison does not contain four FST-array proofs.",
      call. = FALSE)
  }
  for (summary in summaries) {
    key <- summary$key
    if (is.null(left[[key]]) || is.null(right[[key]])) {
      stop("Early FST proof lacks a current descriptor.", call. = FALSE)
    }
    key_document <- wlv13_ap_key_document(left[[key]], right[[key]],
      1000000L, "cross_engine_run_v3", context,
      origin$engine_pair)
    proof <- list(
      summary = raw_summary(summary),
      transitions = raw_transitions(origin$report, key),
      indicator_differences = list()
    )
    record <- list(
      logical_key = key,
      key_sha256 = wlv13_ap_sha(key_document),
      key = key_document,
      origin_comparison_id = origin$job$comparison_id,
      proof = proof,
      proof_sha256 = wlv13_ap_sha(proof)
    )
    # Validate the exact proof before it can enter the cache.
    wlv13_ap_result(record, key_document)
    proof_records[[length(proof_records) + 1L]] <- record
  }
}
if (anyDuplicated(vapply(proof_records, `[[`, character(1L), "key_sha256"))) {
  stop("The eight early array proofs are not unique.", call. = FALSE)
}
cache <- list(
  schema = "wlv-issue13-main-array-proof-cache/1",
  campaign_id = "issue13-main-054-v2",
  classification = "authenticated-comparison-proof-reuse-no-science-reexecution",
  created_at_utc = "2026-09-05T02:59:38.3010344Z",
  context = context,
  origins = lapply(origins, `[[`, "origin"),
  records = proof_records
)
output <- normalizePath(arguments$output, winslash = "/", mustWork = FALSE)
wlv13_json_write(cache, output)
cat(sprintf("array-proof-cache=%s\nsha256=%s\nrecords=%d\n",
  normalizePath(output, winslash = "/", mustWork = TRUE),
  wlv13_sha256_file(output), length(proof_records)))
