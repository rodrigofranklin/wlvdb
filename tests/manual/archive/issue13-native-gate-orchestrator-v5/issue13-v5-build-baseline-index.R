#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) {
  stop(
    paste(
      "Usage: issue13-v5-build-baseline-index.R",
      "<materialized-harness-root> <output-json>",
      "<compatibility-runtime-commit> <overlay-patch>"
    ),
    call. = FALSE
  )
}

harness_root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
output <- normalizePath(args[[2L]], winslash = "/", mustWork = FALSE)
runtime_commit <- args[[3L]]
overlay_patch <- normalizePath(args[[4L]], winslash = "/", mustWork = TRUE)
if (file.exists(output) || dir.exists(output)) {
  stop("Refusing to overwrite the V5 baseline index.", call. = FALSE)
}
if (length(runtime_commit) != 1L ||
    !grepl("^[0-9a-f]{40}$", runtime_commit)) {
  stop("The compatibility runtime commit is invalid.", call. = FALSE)
}
expected_runtime <- "e2f4d6dae9a6d35c966b305fabac52e489faa3e7"
expected_patch_sha256 <-
  "9f9b878f8e557973127e6260a0f224c868a0c4e8dc2db52dd6aa3f7131f28cd9"
expected_patch_id <- "253ca5f1397132f94e3432264084a37395c60ec3"

sys.source(file.path(harness_root, "issue13-lib.R"), envir = environment())
sys.source(file.path(harness_root, "issue13-matrix.R"), envir = environment())
sys.source(
  file.path(harness_root, "issue13-baseline-runtime-index-lib.R"),
  envir = environment()
)
sys.source(
  file.path(harness_root, "issue13-v5-compatibility-baseline-override.R"),
  envir = environment()
)

base_commit <- "cc2c86189a06676bcb9f0e05e08033d710a92509"
if (identical(runtime_commit, base_commit)) {
  stop("The compatibility runtime must be a child of cc2.", call. = FALSE)
}
if (!identical(runtime_commit, expected_runtime) ||
    !identical(wlv13_sha256_file(overlay_patch), expected_patch_sha256) ||
    !identical(wlv13_index_patch_id(overlay_patch), expected_patch_id)) {
  stop("The sealed V5 compatibility oracle or patch differs.", call. = FALSE)
}
profile_id <- "compatibility-oracle-cc2"
scenario_ids <- sort(
  wlv13_scenario_ids()[startsWith(wlv13_scenario_ids(), "baseline/")],
  method = "radix"
)
index <- list(
  schema = wlv13_schema$baseline_runtime_index,
  baseline_base_commit = base_commit,
  created_at = wlv13_now(),
  profiles = list(list(
    schema = wlv13_schema$validation_profile,
    id = profile_id,
    inventory_value = profile_id,
    source_commit = runtime_commit,
    runtime_commit = runtime_commit,
    run_dirty = FALSE,
    overlay_patch_path = overlay_patch,
    overlay_patch_sha256 = wlv13_sha256_file(overlay_patch),
    overlay_patch_id = wlv13_index_patch_id(overlay_patch)
  )),
  scenarios = lapply(scenario_ids, function(id) {
    list(
      scenario_id = id,
      runtime_commit = runtime_commit,
      profile_id = profile_id
    )
  })
)

wlv13_json_write(index, output)
sha256 <- wlv13_sha256_file(output)
validated <- wlv13_read_baseline_runtime_index(output, sha256, base_commit)
wlv13_validate_baseline_runtime_matrix(
  validated,
  "1111111111111111111111111111111111111111"
)
cat(sprintf("%s  %s\n", sha256, normalizePath(
  output,
  winslash = "/",
  mustWork = TRUE
)))
