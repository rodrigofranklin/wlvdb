# Recover a validated run after the release merger rejected optional blank
# metadata from another method. This never calculates, edits a run, or changes
# its fingerprint. The failed API attempt and its log remain failed.
# Usage: Rscript tests/manual/issue28-recover-publication.R <campaign-root>
#   <run-directory> <new-empty-channel> <full-report.json> <recovery-report.json>
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 5L, !file.exists(args[[4L]]), !file.exists(args[[5L]]))
root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
repo <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
stopifnot(startsWith(tolower(root), paste0(tolower(repo), "/temp/")))
run_dir <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
stopifnot(startsWith(tolower(run_dir), paste0(tolower(root), "/results/runs/")))
bootstrap <- new.env(parent = baseenv())
sys.source(file.path(root, "scripts", "runtime_bootstrap.R"), envir = bootstrap)
runtime <- bootstrap$wlv_load_runtime(root)
manifest_path <- file.path(run_dir, "run_manifest.json")
manifest <- runtime$wlv_read_run_manifest(manifest_path)
invisible(runtime$wlv_verify_run_manifest(manifest, run_dir, reject_unlisted = TRUE))
method <- manifest$method
stopifnot(identical(manifest$result$request$mode, "calculate"),
  is.null(manifest$parent_run_id),
  is.null(runtime$wlv_read_current_release(root, args[[3L]], required = FALSE)))
plan <- runtime$wlv_validate_request(method, workers = 1L, channel = args[[3L]], root = root)
runtime$wlv_assert_dependencies(attach = FALSE)
outcome <- runtime$wlv_with_publication_lock(plan, function() {
  plan <- runtime$wlv_validate_data(plan)
  data <- plan$data[[method]]
  stopifnot(runtime$wlv_publication_json_identical(
    runtime$wlv_publication_input_inventory_capture(plan, method),
    manifest$result$provenance$inputs))
  stopifnot(runtime$wlv_publication_json_identical(
    runtime$wlv_runtime_compatibility_manifest(data$runtime_compatibility),
    manifest$result$provenance$runtime_compatibility))
  stopifnot(identical(data$source_provenance,
    runtime$wlv_read_result_source_provenance(run_dir)))
  stopifnot(runtime$wlv_publication_json_identical(
    data$source_provenance_input_inventory,
    manifest$result$provenance$source$additional_inputs))
  envelope <- new.env(parent = emptyenv())
  envelope$wlv_run_dir <- run_dir
  envelope$wlv_run_manifest <- manifest
  for (name in c("source_manifest", "source_provenance", "source_provenance_inputs",
      "source_provenance_input_inventory", "source_input_receipt")) {
    envelope[[paste0("wlv_", name)]] <- data[[name]]
  }
  runtime$wlv_commit_release(plan, list(envelope))
})
release <- runtime$wlv_read_current_release(root, args[[3L]], required = TRUE)
current <- runtime$wlv_resolve_method_run_reference(root, method, release)
stopifnot(identical(current$run_id, manifest$run_id),
  identical(runtime$wlv_publication_file_sha256(manifest_path),
    runtime$wlv_publication_file_sha256(current$manifest_path)))
hash <- runtime$wlv_publication_file_sha256
recovery <- list(schema = "wlv-issue28-release-recovery/1", passed = TRUE,
  recalculated = FALSE, run_changed = FALSE, original_api_attempt_exit = 1L,
  original_api_failure = "Conflicting optional blank panel metadata in combined release",
  method = method, run_id = manifest$run_id, run_path = run_dir,
  manifest_sha256 = hash(manifest_path),
  new_channel = args[[3L]], release_id = release$manifest$release_id,
  marker_sha256 = hash(release$marker_path),
  checks = list(all_run_artifacts_authenticated = TRUE, runtime_compatible = TRUE,
    exact_code_input_inventory = TRUE, exact_source_provenance = TRUE,
    exact_additional_source_inventory = TRUE, new_release_authenticated = TRUE))
jsonlite::write_json(recovery, args[[5L]], pretty = TRUE, auto_unbox = TRUE)
report <- list(schema = "wlv-issue28-recalculation/1", passed = TRUE,
  method = method, mode = "calculate", at_stage = 1L, workers = 1L,
  selection = NULL, elapsed_seconds = NULL, root = root, channel = args[[3L]],
  run_path = run_dir, run_id = manifest$run_id, result_id = manifest$result_id,
  parent_run_id = NULL, manifest_sha256 = hash(manifest_path),
  checks = list(publication_authenticated = TRUE, lineage = TRUE), comparison = list(),
  runtime_compatibility = manifest$result$provenance$runtime_compatibility,
  inputs = manifest$result$provenance$inputs,
  recovery_report = args[[5L]], recovery_report_sha256 = hash(args[[5L]]),
  original_api_attempt_exit = 1L)
jsonlite::write_json(report, args[[4L]], pretty = TRUE, auto_unbox = TRUE, null = "null")
message("Recovered publication of authenticated run without calculation: ", manifest$run_id)
