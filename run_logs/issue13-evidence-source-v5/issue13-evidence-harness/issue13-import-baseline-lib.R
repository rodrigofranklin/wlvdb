# Authenticated import of an already completed baseline full run.
#
# The scientific run store is imported exclusively with NTFS hard links.  The
# original execution evidence is retained byte-for-byte under `source-auth/`;
# the evidence at the import root records only the relocations required by the
# effective validation profile.

wlv13_import_spec_fields <- c(
  "schema", "scenario_id", "source_project_root", "target_project_root",
  "expected_source_commit", "expected_target_commit", "method", "run_id",
  "result_id", "manifest_sha256", "inventory_sha256",
  "expected_run_dirty", "inventory", "validation_profile", "auxiliary"
)

wlv13_import_profile_fields <- c(
  "schema", "id", "inventory_value", "source_commit", "runtime_commit",
  "run_dirty", "overlay_patch_path", "overlay_patch_sha256",
  "overlay_patch_id"
)

wlv13_import_auxiliary_names <- c(
  "scenario_result", "process_metrics", "process_spec", "stdout", "stderr",
  "samples"
)

wlv13_import_auxiliary_filenames <- c(
  scenario_result = "scenario-result.json",
  process_metrics = "process-metrics.json",
  process_spec = "process-spec.json",
  stdout = "stdout.log",
  stderr = "stderr.log",
  samples = "process-samples.csv"
)

wlv13_import_require <- function(condition, message) {
  if (!isTRUE(condition)) stop(message, call. = FALSE)
  invisible(TRUE)
}

wlv13_import_exact_names <- function(value, expected, label) {
  wlv13_import_require(
    is.list(value) && length(names(value)) == length(expected) &&
      setequal(names(value), expected),
    sprintf("%s has an invalid schema.", label)
  )
  invisible(value)
}

wlv13_import_hash <- function(value, name) {
  wlv13_scalar_text(value, name, "^[0-9a-f]{64}$")
}

wlv13_import_commit <- function(value, name) {
  wlv13_scalar_text(value, name, "^[0-9a-f]{40}$")
}

wlv13_import_size <- function(value, name) {
  value <- suppressWarnings(as.numeric(value))
  wlv13_import_require(
    length(value) == 1L && !is.na(value) && is.finite(value) && value >= 0 &&
      value == floor(value) && value <= 2^53 - 1,
    sprintf("`%s` must be an exact non-negative JSON integer.", name)
  )
  value
}

wlv13_import_clone <- function(value) {
  unserialize(serialize(value, NULL, xdr = FALSE))
}

wlv13_import_normalize_file <- function(path, name) {
  path <- wlv13_scalar_text(path, name)
  wlv13_import_require(
    grepl("^[A-Za-z]:[/\\\\]", path, perl = TRUE),
    sprintf("`%s` must be an absolute Windows path.", name)
  )
  wlv13_import_require(
    file.exists(path) && !isTRUE(file.info(path)$isdir),
    sprintf("`%s` is not an existing file.", name)
  )
  wlv13_import_assert_plain_path(path, name)
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  wlv13_import_require(
    file.exists(path) && !isTRUE(file.info(path)$isdir),
    sprintf("`%s` is not an existing file.", name)
  )
  path
}

wlv13_import_normalize_dir <- function(path, name) {
  path <- wlv13_scalar_text(path, name)
  wlv13_import_require(
    grepl("^[A-Za-z]:[/\\\\]", path, perl = TRUE),
    sprintf("`%s` must be an absolute Windows path.", name)
  )
  wlv13_import_require(
    dir.exists(path),
    sprintf("`%s` is not an existing directory.", name)
  )
  wlv13_import_assert_plain_path(path, name)
  wlv13_normalize_existing_dir(path, name)
}

wlv13_import_path_equal <- function(left, right, must_work = TRUE) {
  left <- normalizePath(left, winslash = "/", mustWork = must_work)
  right <- normalizePath(right, winslash = "/", mustWork = must_work)
  if (.Platform$OS.type == "windows") {
    left <- tolower(left)
    right <- tolower(right)
  }
  identical(left, right)
}

wlv13_import_json_utf8 <- function(path) {
  raw <- readBin(path, what = "raw", n = file.info(path)$size)
  wlv13_import_require(
    length(raw) < 3L || !identical(raw[seq_len(3L)], as.raw(c(0xef, 0xbb, 0xbf))),
    sprintf("Generated JSON must be UTF-8 without BOM: %s.", path)
  )
  text <- rawToChar(raw)
  checked <- iconv(text, from = "UTF-8", to = "UTF-8", sub = NA_character_)
  wlv13_import_require(
    length(checked) == 1L && !is.na(checked) &&
      !grepl("\ufffd", checked, fixed = TRUE) &&
      identical(charToRaw(enc2utf8(checked)), raw),
    sprintf("Generated JSON failed strict UTF-8 round-trip: %s.", path)
  )
  invisible(wlv13_json_read(path, simplify = FALSE))
}

wlv13_import_write_json <- function(value, path) {
  wlv13_json_write(value, path)
  wlv13_import_json_utf8(path)
  invisible(path)
}

wlv13_import_length_field <- function(name, value) {
  name <- enc2utf8(name)
  if (is.null(value)) value <- "<null>"
  value <- enc2utf8(as.character(value))
  sprintf("%d:%s=%d:%s", length(charToRaw(name)), name,
    length(charToRaw(value)), value
  )
}

wlv13_import_canonical_inventory_row <- function(row) {
  if (is.data.frame(row)) {
    wlv13_import_require(nrow(row) == 1L, "Inventory row must have one row.")
    row <- unlist(row[1L, , drop = FALSE], use.names = TRUE)
  }
  wlv13_import_require(
    is.character(row) && length(row) && !is.null(names(row)) &&
      !anyNA(row) && !anyDuplicated(names(row)),
    "Inventory row must be a named, non-missing character vector."
  )
  paste(vapply(seq_along(row), function(index) {
    wlv13_import_length_field(names(row)[[index]], row[[index]])
  }, character(1L)), collapse = "\n")
}

wlv13_import_inventory_row_sha256 <- function(row) {
  wlv13_sha256_text(wlv13_import_canonical_inventory_row(row))
}

wlv13_import_profile_signature <- function(profile) {
  wlv13_import_exact_names(profile, wlv13_import_profile_fields,
    "Validation profile"
  )
  payload <- paste(vapply(wlv13_import_profile_fields, function(name) {
    wlv13_import_length_field(name, profile[[name]])
  }, character(1L)), collapse = "\n")
  wlv13_sha256_text(payload)
}

wlv13_import_patch_id <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  value <- system2("git", c("patch-id", "--stable"),
    stdin = path, stdout = TRUE, stderr = TRUE
  )
  status <- attr(value, "status", exact = TRUE)
  wlv13_import_require(
    (is.null(status) || identical(as.integer(status), 0L)) &&
      length(value) >= 1L,
    sprintf("Cannot calculate stable patch-id for `%s`.", path)
  )
  tokens <- strsplit(trimws(value[[1L]]), "[[:space:]]+",
    perl = TRUE
  )[[1L]]
  wlv13_scalar_text(tokens[[1L]], "overlay patch-id", "^[0-9a-f]{40}$")
}

wlv13_import_validate_profile <- function(profile, source_commit,
                                            target_commit, run_dirty) {
  wlv13_import_exact_names(profile, wlv13_import_profile_fields,
    "Validation profile"
  )
  wlv13_import_require(
    identical(profile$schema, wlv13_schema$validation_profile),
    "Validation profile has an unsupported schema."
  )
  wlv13_id(profile$id, "validation_profile.id")
  inventory_value <- wlv13_scalar_text(profile$inventory_value,
    "validation_profile.inventory_value", "^[a-z0-9][a-z0-9._+-]*$"
  )
  wlv13_import_require(
    identical(wlv13_import_commit(profile$source_commit,
      "validation_profile.source_commit"), source_commit) &&
      identical(wlv13_import_commit(profile$runtime_commit,
        "validation_profile.runtime_commit"), target_commit) &&
      identical(wlv13_bool(profile$run_dirty,
        "validation_profile.run_dirty"), run_dirty),
    "Validation profile does not match the import commits or dirty state."
  )
  patch_null <- is.null(profile$overlay_patch_path) &&
    is.null(profile$overlay_patch_sha256) &&
    is.null(profile$overlay_patch_id)
  patch_present <- !is.null(profile$overlay_patch_path) &&
    !is.null(profile$overlay_patch_sha256) &&
    !is.null(profile$overlay_patch_id)
  wlv13_import_require(
    patch_null || patch_present,
    "Validation profile overlay identifiers must both be null or both present."
  )
  if (patch_present) {
    patch_path <- wlv13_import_normalize_file(profile$overlay_patch_path,
      "validation_profile.overlay_patch_path"
    )
    wlv13_import_hash(profile$overlay_patch_sha256,
      "validation_profile.overlay_patch_sha256"
    )
    wlv13_scalar_text(profile$overlay_patch_id,
      "validation_profile.overlay_patch_id", "^[0-9a-f]{40}$"
    )
    wlv13_import_require(
      identical(wlv13_sha256_file(patch_path),
        profile$overlay_patch_sha256) &&
        identical(wlv13_import_patch_id(patch_path),
          profile$overlay_patch_id),
      "Validation profile overlay patch hash/patch-id differs from its file."
    )
  }
  if (patch_null) {
    wlv13_import_require(
      identical(source_commit, target_commit) && !isTRUE(run_dirty),
      "A patch-free validation profile must be clean at the source commit."
    )
  } else {
    wlv13_import_require(
      !identical(source_commit, target_commit),
      "An overlay validation profile must have a distinct runtime commit."
    )
  }
  list(
    schema = profile$schema,
    id = profile$id,
    inventory_value = inventory_value,
    source_commit = source_commit,
    runtime_commit = target_commit,
    run_dirty = run_dirty,
    overlay_patch_path = if (patch_null) NULL else patch_path,
    overlay_patch_sha256 = profile$overlay_patch_sha256,
    overlay_patch_id = profile$overlay_patch_id
  )
}

wlv13_import_read_utf8_csv <- function(path) {
  raw <- readBin(path, what = "raw", n = file.info(path)$size)
  wlv13_import_require(
    length(raw) < 3L || !identical(raw[seq_len(3L)], as.raw(c(0xef, 0xbb, 0xbf))),
    "Normative inventory CSV must be UTF-8 without BOM."
  )
  text <- rawToChar(raw)
  checked <- iconv(text, from = "UTF-8", to = "UTF-8", sub = NA_character_)
  wlv13_import_require(
    length(checked) == 1L && !is.na(checked) &&
      !grepl("\ufffd", checked, fixed = TRUE) &&
      identical(charToRaw(enc2utf8(checked)), raw),
    "Normative inventory CSV failed strict UTF-8 round-trip."
  )
  connection <- textConnection(checked, open = "r", encoding = "UTF-8")
  on.exit(close(connection), add = TRUE)
  utils::read.csv(connection,
    stringsAsFactors = FALSE, colClasses = "character", check.names = FALSE,
    na.strings = NULL
  )
}

wlv13_import_validate_inventory_csv <- function(spec, source_manifest_path) {
  record <- spec$inventory
  wlv13_import_exact_names(record,
    c("path", "sha256", "canonical_row_sha256"), "Inventory CSV record"
  )
  path <- wlv13_import_normalize_file(record$path, "inventory.path")
  expected_hash <- wlv13_import_hash(record$sha256, "inventory.sha256")
  row_hash <- wlv13_import_hash(record$canonical_row_sha256,
    "inventory.canonical_row_sha256"
  )
  wlv13_import_require(
    identical(wlv13_sha256_file(path), expected_hash),
    "Normative inventory CSV hash differs from the import specification."
  )
  inventory <- wlv13_import_read_utf8_csv(path)
  expected_columns <- c(
    "method", "scenario", "status", "commit", "overlay", "release_id",
    "run_id", "result_id", "evidence", "notes"
  )
  wlv13_import_require(
    identical(names(inventory), expected_columns) && nrow(inventory) > 0L &&
      !anyNA(inventory),
    "Normative inventory CSV has an unsupported schema."
  )
  matches <- inventory$method == spec$method &
    inventory$scenario == "full_workers1" &
    inventory$commit == spec$expected_source_commit &
    inventory$overlay == spec$validation_profile$inventory_value &
    inventory$run_id == spec$run_id & inventory$result_id == spec$result_id
  candidates <- which(matches)
  candidates <- candidates[vapply(candidates, function(index) {
    evidence <- inventory$evidence[[index]]
    grepl("^[A-Za-z]:[/\\\\]", evidence, perl = TRUE) &&
      file.exists(evidence) &&
      wlv13_import_path_equal(evidence, source_manifest_path)
  }, logical(1L))]
  wlv13_import_require(
    length(candidates) == 1L,
    "Normative inventory CSV does not contain exactly one authenticated full-run row."
  )
  row <- unlist(inventory[candidates, , drop = FALSE], use.names = TRUE)
  observed_row_hash <- wlv13_import_inventory_row_sha256(row)
  wlv13_import_require(
    identical(observed_row_hash, row_hash),
    "Normative inventory canonical row hash differs from the specification."
  )
  wlv13_import_require(
    inventory$status[[candidates]] %in% c("done", "reusable"),
    "Normative inventory row is not marked done or reusable."
  )
  list(
    path = path,
    sha256 = expected_hash,
    canonical_row_sha256 = observed_row_hash,
    row = as.list(row)
  )
}

wlv13_import_validate_aux_record <- function(record, name) {
  wlv13_import_exact_names(record, c("path", "size_bytes", "sha256"),
    sprintf("Auxiliary `%s`", name)
  )
  path <- wlv13_import_normalize_file(record$path,
    sprintf("auxiliary.%s.path", name)
  )
  size <- wlv13_import_size(record$size_bytes,
    sprintf("auxiliary.%s.size_bytes", name)
  )
  hash <- wlv13_import_hash(record$sha256,
    sprintf("auxiliary.%s.sha256", name)
  )
  observed <- wlv13_file_record(path)
  wlv13_import_require(
    identical(observed$size_bytes, size) && identical(observed$sha256, hash),
    sprintf("Auxiliary `%s` differs from its exact record.", name)
  )
  list(path = path, size_bytes = size, sha256 = hash)
}

wlv13_import_validate_spec <- function(spec) {
  wlv13_import_exact_names(spec, wlv13_import_spec_fields,
    "Baseline import specification"
  )
  wlv13_import_require(
    identical(spec$schema, wlv13_schema$baseline_import_spec),
    "Baseline import specification has an unsupported schema."
  )
  method <- wlv13_scalar_text(spec$method, "method", "^[a-z][a-z0-9_]*$")
  scenario_id <- wlv13_scalar_text(spec$scenario_id, "scenario_id",
    "^baseline/calculate/[a-z][a-z0-9_]*/workers1$"
  )
  wlv13_import_require(
    identical(scenario_id, paste0("baseline/calculate/", method, "/workers1")),
    "Import scenario_id and method disagree."
  )
  source_root <- wlv13_import_normalize_dir(spec$source_project_root,
    "source_project_root"
  )
  target_root <- wlv13_import_normalize_dir(spec$target_project_root,
    "target_project_root"
  )
  wlv13_import_require(
    !wlv13_import_path_equal(source_root, target_root),
    "Source and target project roots must be different."
  )
  source_commit <- wlv13_import_commit(spec$expected_source_commit,
    "expected_source_commit"
  )
  target_commit <- wlv13_import_commit(spec$expected_target_commit,
    "expected_target_commit"
  )
  run_id <- wlv13_scalar_text(spec$run_id, "run_id",
    "^run-[A-Za-z0-9._-]+$"
  )
  result_id <- wlv13_import_hash(spec$result_id, "result_id")
  manifest_hash <- wlv13_import_hash(spec$manifest_sha256, "manifest_sha256")
  inventory_hash <- wlv13_import_hash(spec$inventory_sha256,
    "inventory_sha256"
  )
  run_dirty <- wlv13_bool(spec$expected_run_dirty, "expected_run_dirty")
  profile <- wlv13_import_validate_profile(spec$validation_profile, source_commit,
    target_commit, run_dirty
  )
  wlv13_import_exact_names(spec$auxiliary, wlv13_import_auxiliary_names,
    "Import auxiliary records"
  )
  auxiliary <- lapply(wlv13_import_auxiliary_names, function(name) {
    wlv13_import_validate_aux_record(spec$auxiliary[[name]], name)
  })
  names(auxiliary) <- wlv13_import_auxiliary_names
  paths <- vapply(auxiliary, `[[`, character(1L), "path")
  wlv13_import_require(
    !anyDuplicated(tolower(paths)),
    "Import auxiliary records must identify six distinct files."
  )
  list(
    raw = spec, scenario_id = scenario_id, source_root = source_root,
    target_root = target_root, source_commit = source_commit,
    target_commit = target_commit, method = method, run_id = run_id,
    result_id = result_id, manifest_sha256 = manifest_hash,
    inventory_sha256 = inventory_hash, run_dirty = run_dirty,
    profile = profile,
    profile_sha256 = wlv13_import_profile_signature(profile),
    auxiliary = auxiliary
  )
}

wlv13_import_null_or_empty <- function(value) {
  is.null(value) || (is.list(value) && !length(value)) ||
    (is.character(value) && !length(value))
}

wlv13_import_assert_full_run <- function(inventory, validated) {
  manifest <- inventory$manifest
  request <- manifest$result$request
  provenance_git <- manifest$result$provenance$git
  wlv13_import_require(
    identical(inventory$manifest_sha256, validated$manifest_sha256) &&
      identical(wlv13_inventory_signature(inventory),
        validated$inventory_sha256),
    "Source run manifest or inventory signature differs from the specification."
  )
  wlv13_import_require(
    identical(manifest$method, validated$method) &&
      identical(manifest$run_id, validated$run_id) &&
      identical(manifest$result_id, validated$result_id) &&
      is.null(manifest$parent_run_id),
    "Source run identity is wrong or the full run has a parent."
  )
  wlv13_import_require(
    nrow(inventory$records) == 24L &&
      identical(manifest$output_contract$id, "wlvpanel-output") &&
      identical(manifest$output_contract$version, "1.0.0"),
    "Source run must have 24 artifacts and output contract 1.0.0."
  )
  wlv13_import_require(
    is.list(request) && identical(request$mode, "calculate") &&
      identical(request$method, validated$method) &&
      identical(as.integer(request$workers), 1L) &&
      is.null(request$at_stage) && is.null(request$sea_vars),
    "Source run request is not a full workers=1 calculation."
  )
  wlv13_import_require(
    is.list(provenance_git) &&
      identical(provenance_git$commit, validated$source_commit) &&
      identical(provenance_git$dirty, validated$run_dirty),
    "Source run Git provenance differs from the expected commit/dirty state."
  )
  invisible(inventory)
}

wlv13_import_assert_source_scenario <- function(scenario, inventory,
                                                 validated) {
  wlv13_import_require(
    is.list(scenario) && identical(scenario$schema, wlv13_schema$scenario) &&
      identical(scenario$scenario_id, validated$scenario_id) &&
      identical(scenario$status, "passed") && isTRUE(scenario$passed) &&
      identical(scenario$kind, "calculate") && is.null(scenario$error) &&
      !("execution_mode" %in% names(scenario)) &&
      !("authentication" %in% names(scenario)),
    "Source scenario result is not a native passed calculation."
  )
  wlv13_import_require(
    wlv13_import_path_equal(scenario$project_root, validated$source_root) &&
      identical(scenario$expected_commit, validated$source_commit) &&
      identical(scenario$observed_commit, validated$source_commit) &&
      is.numeric(scenario$elapsed_seconds) && scenario$elapsed_seconds > 0,
    "Source scenario project root, commit, or elapsed time is invalid."
  )
  request <- scenario$request
  wlv13_import_require(
    is.list(request) && identical(request$method, validated$method) &&
      identical(as.integer(request$workers), 1L) && is.null(request$at_stage) &&
      is.null(request$sea_vars) && !isTRUE(request$expected_failure),
    "Source scenario request is not canonical full workers=1."
  )
  wlv13_import_require(
    is.list(scenario$outputs) && length(scenario$outputs) == 1L,
    "Source scenario must expose exactly one run output."
  )
  output <- scenario$outputs[[1L]]
  wlv13_import_require(
    is.list(output) && identical(output$kind, "run") &&
      identical(output$method, validated$method) &&
      identical(output$run_id, validated$run_id) &&
      identical(output$result_id, validated$result_id) &&
      is.null(output$parent_run_id) &&
      identical(output$manifest_sha256, validated$manifest_sha256) &&
      identical(output$inventory_sha256, validated$inventory_sha256) &&
      wlv13_import_path_equal(output$root, inventory$root) &&
      wlv13_import_path_equal(output$manifest_path, inventory$manifest_path),
    "Source scenario output is not bound to the authenticated full run."
  )
  output_request <- output$request
  wlv13_import_require(
    is.list(output_request) && identical(output_request$mode, "calculate") &&
      identical(output_request$method, validated$method) &&
      identical(as.integer(output_request$workers), 1L) &&
      is.null(output_request$at_stage) && is.null(output_request$sea_vars),
    "Source scenario output request is not canonical."
  )
  invisible(scenario)
}

wlv13_import_normalize_executable <- function(path) {
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

wlv13_import_assert_source_process <- function(scenario, metrics, process_spec,
                                                validated) {
  auxiliary <- validated$auxiliary
  wlv13_import_require(
    identical(metrics$schema, "wlv-issue13-process-metrics/2") &&
      identical(metrics$scenario_id, validated$scenario_id) &&
      identical(metrics$status, "passed") && isTRUE(metrics$passed) &&
      identical(as.integer(metrics$exit_code), 0L) &&
      isTRUE(metrics$exit_code_matched) && !isTRUE(metrics$timed_out) &&
      isTRUE(metrics$cluster_closed) && isTRUE(metrics$worker_count_matched) &&
      identical(as.integer(metrics$expected_worker_processes), 0L) &&
      identical(as.integer(metrics$max_concurrent_worker_processes), 0L) &&
      wlv13_import_null_or_empty(metrics$lingering_pids) &&
      is.numeric(metrics$elapsed_seconds) && metrics$elapsed_seconds > 0 &&
      is.numeric(metrics$peak_rss_bytes) && metrics$peak_rss_bytes >= 0,
    "Source process metrics are not a canonical passed workers=1 record."
  )
  wlv13_import_require(
    identical(process_spec$schema, "wlv-issue13-process-spec/1") &&
      identical(process_spec$scenario_id, validated$scenario_id) &&
      identical(as.integer(process_spec$expected_worker_processes), 0L) &&
      identical(as.integer(process_spec$expected_exit_codes), 0L),
    "Source process specification is not canonical workers=1."
  )
  wlv13_import_require(
    identical(metrics$arguments, process_spec$arguments) &&
      identical(as.integer(metrics$expected_exit_codes),
        as.integer(process_spec$expected_exit_codes)) &&
      identical(as.numeric(metrics$timeout_seconds),
        as.numeric(process_spec$timeout_seconds)) &&
      identical(as.integer(metrics$sample_interval_ms),
        as.integer(process_spec$sample_interval_ms)) &&
      wlv13_import_path_equal(metrics$working_directory,
        validated$source_root) &&
      wlv13_import_path_equal(process_spec$working_directory,
        validated$source_root) &&
      identical(wlv13_import_normalize_executable(metrics$executable),
        wlv13_import_normalize_executable(process_spec$executable)),
    "Source process metrics/specification are not mutually linked."
  )
  linked <- list(
    stdout = c("stdout_path", "stdout_sha256"),
    stderr = c("stderr_path", "stderr_sha256"),
    samples = c("samples_path", "samples_sha256"),
    process_spec = c("process_spec_path", "process_spec_sha256")
  )
  for (name in names(linked)) {
    fields <- linked[[name]]
    wlv13_import_require(
      wlv13_import_path_equal(metrics[[fields[[1L]]]],
        auxiliary[[name]]$path) &&
        identical(metrics[[fields[[2L]]]], auxiliary[[name]]$sha256),
      sprintf("Source process metrics are not linked to `%s`.", name)
    )
  }
  evidence_root <- dirname(auxiliary$scenario_result$path)
  wlv13_import_require(
    wlv13_import_path_equal(auxiliary$process_metrics$path,
      file.path(evidence_root, "process-metrics.json")) &&
      wlv13_import_path_equal(auxiliary$stdout$path,
        file.path(evidence_root, "stdout.log")) &&
      wlv13_import_path_equal(auxiliary$stderr$path,
        file.path(evidence_root, "stderr.log")) &&
      wlv13_import_path_equal(auxiliary$samples$path,
        file.path(evidence_root, "process-samples.csv")),
    "Source scenario, metrics, logs, and samples are not one canonical record."
  )
  arguments <- process_spec$arguments
  wlv13_import_require(
    is.list(arguments) && length(arguments) >= 1L &&
      wlv13_import_path_equal(arguments[[length(arguments)]], evidence_root),
    "Source process specification is not bound to the scenario evidence directory."
  )
  invisible(list(scenario = scenario, metrics = metrics, spec = process_spec))
}

wlv13_import_powershell <- function(expression, label) {
  wlv13_import_require(.Platform$OS.type == "windows",
    "Authenticated baseline imports require Windows NTFS."
  )
  encoded_raw <- iconv(enc2utf8(expression), from = "UTF-8", to = "UTF-16LE",
    toRaw = TRUE
  )[[1L]]
  wlv13_import_require(!is.null(encoded_raw),
    sprintf("Cannot encode PowerShell check for %s.", label)
  )
  wlv13_require("openssl")
  encoded <- openssl::base64_encode(encoded_raw)
  stderr_path <- tempfile("wlv13-powershell-stderr-", fileext = ".txt")
  on.exit(unlink(stderr_path, force = TRUE), add = TRUE)
  output <- suppressWarnings(system2("powershell.exe", c(
    "-NoLogo", "-NoProfile", "-NonInteractive", "-EncodedCommand", encoded
  ), stdout = TRUE, stderr = stderr_path))
  status <- attr(output, "status", exact = TRUE)
  error_output <- if (file.exists(stderr_path)) {
    readLines(stderr_path, warn = FALSE, encoding = "UTF-8")
  } else {
    character()
  }
  wlv13_import_require(is.null(status) || identical(as.integer(status), 0L),
    sprintf("PowerShell check failed for %s: %s", label,
      paste(c(output, error_output), collapse = " ")
    )
  )
  trimws(output)
}

wlv13_import_ps_quote <- function(value) {
  paste0("'", gsub("'", "''", enc2utf8(value), fixed = TRUE), "'")
}

wlv13_import_drive_format <- function(path) {
  path <- normalizePath(path, winslash = "\\", mustWork = TRUE)
  root <- paste0(substring(path, 1L, 2L), "\\")
  expression <- sprintf(
    "[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); [IO.DriveInfo]::new(%s).DriveFormat",
    wlv13_import_ps_quote(root)
  )
  output <- wlv13_import_powershell(expression, "filesystem type")
  wlv13_import_require(length(output) == 1L && identical(toupper(output), "NTFS"),
    sprintf("Import volume is not authenticated as NTFS: %s.", root)
  )
  "NTFS"
}

wlv13_import_assert_plain_path <- function(path, label) {
  path <- wlv13_scalar_text(path, label)
  expression <- sprintf(paste0(
    "[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); ",
    "$p=[IO.Path]::GetFullPath(%s); ",
    "while ($null -ne $p) { ",
    "$i=(Get-Item -LiteralPath $p -Force); ",
    "if (($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) ",
    "{ 'REPARSE'; exit 0 }; ",
    "$parent=[IO.Directory]::GetParent($p); ",
    "if ($null -eq $parent) { $p=$null } else { $p=$parent.FullName } ",
    "}; 'PLAIN'"
  ), wlv13_import_ps_quote(path))
  output <- wlv13_import_powershell(expression, label)
  wlv13_import_require(length(output) == 1L && identical(output, "PLAIN"),
    sprintf("%s must not be a reparse point.", label)
  )
  invisible(path)
}

wlv13_import_assert_same_ntfs <- function(source_root, target_root) {
  source_drive <- tolower(substring(normalizePath(source_root,
    winslash = "/", mustWork = TRUE
  ), 1L, 2L))
  target_drive <- tolower(substring(normalizePath(target_root,
    winslash = "/", mustWork = TRUE
  ), 1L, 2L))
  wlv13_import_require(
    identical(source_drive, target_drive),
    "Source and target project roots must be on the same volume."
  )
  wlv13_import_drive_format(source_root)
  wlv13_import_drive_format(target_root)
  invisible(source_drive)
}

wlv13_import_hardlink_paths <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  output <- suppressWarnings(system2("fsutil.exe", c(
    "hardlink", "list", shQuote(chartr("/", "\\", path), type = "cmd")
  ), stdout = TRUE, stderr = TRUE))
  status <- attr(output, "status", exact = TRUE)
  wlv13_import_require(is.null(status) || identical(as.integer(status), 0L),
    sprintf("Cannot authenticate NTFS hard links for %s.", path)
  )
  drive <- substring(path, 1L, 2L)
  values <- trimws(output)
  values <- values[nzchar(values)]
  values <- vapply(values, function(value) {
    value <- chartr("\\", "/", value)
    if (startsWith(value, "/")) value <- paste0(drive, value)
    normalizePath(value, winslash = "/", mustWork = TRUE)
  }, character(1L))
  unique(tolower(unname(values)))
}

wlv13_import_assert_hardlink_pair <- function(source, target) {
  source <- normalizePath(source, winslash = "/", mustWork = TRUE)
  target <- normalizePath(target, winslash = "/", mustWork = TRUE)
  links <- wlv13_import_hardlink_paths(target)
  wlv13_import_require(
    all(tolower(c(source, target)) %in% links),
    sprintf("Target is not the authenticated NTFS hard link of source: %s.",
      target
    )
  )
  invisible(TRUE)
}

wlv13_import_copy_exact <- function(source, target, expected) {
  wlv13_import_require(!file.exists(target) && !dir.exists(target),
    sprintf("Refusing to overwrite evidence artifact: %s.", target)
  )
  wlv13_ensure_dir(dirname(target), "evidence artifact directory")
  wlv13_import_require(
    file.copy(source, target, overwrite = FALSE, copy.mode = FALSE,
      copy.date = TRUE),
    sprintf("Cannot copy authenticated evidence artifact: %s.", source)
  )
  observed <- wlv13_file_record(target)
  wlv13_import_require(
    identical(observed$size_bytes, expected$size_bytes) &&
      identical(observed$sha256, expected$sha256),
    sprintf("Evidence copy differs from source bytes: %s.", target)
  )
  invisible(observed)
}

wlv13_import_record <- function(path) {
  value <- wlv13_file_record(path)
  list(
    path = normalizePath(path, winslash = "/", mustWork = TRUE),
    size_bytes = value$size_bytes,
    sha256 = value$sha256
  )
}

wlv13_import_aux_records_equal <- function(left, right) {
  identical(left$size_bytes, right$size_bytes) &&
    identical(left$sha256, right$sha256)
}

wlv13_import_recheck_auxiliary <- function(auxiliary) {
  for (name in names(auxiliary)) {
    observed <- wlv13_file_record(auxiliary[[name]]$path)
    wlv13_import_require(
      wlv13_import_aux_records_equal(observed, auxiliary[[name]]),
      sprintf("Source auxiliary changed during import: %s.", name)
    )
  }
  invisible(TRUE)
}

wlv13_import_assert_git <- function(validated) {
  wlv13_import_require(
    identical(wlv13_git_commit(validated$source_root),
      validated$source_commit),
    "Source worktree is no longer at expected_source_commit."
  )
  wlv13_import_require(
    identical(wlv13_git_commit(validated$target_root),
      validated$target_commit) &&
      isTRUE(wlv13_git_runtime_clean(validated$target_root)),
    "Target worktree is not pinned and runtime-clean."
  )
  invisible(TRUE)
}

wlv13_import_read_source <- function(validated) {
  source_run_root <- file.path(validated$source_root, "results", "runs",
    validated$method, validated$run_id
  )
  source_run_root <- wlv13_import_normalize_dir(source_run_root,
    "source run root"
  )
  wlv13_import_assert_plain_path(validated$source_root, "Source project root")
  wlv13_import_assert_plain_path(source_run_root, "Source run root")
  inventory <- wlv13_run_inventory(source_run_root)
  wlv13_import_assert_full_run(inventory, validated)
  csv <- wlv13_import_validate_inventory_csv(validated$raw,
    inventory$manifest_path
  )
  scenario <- wlv13_json_read(validated$auxiliary$scenario_result$path,
    simplify = FALSE
  )
  metrics <- wlv13_json_read(validated$auxiliary$process_metrics$path,
    simplify = FALSE
  )
  process_spec <- wlv13_json_read(validated$auxiliary$process_spec$path,
    simplify = FALSE
  )
  wlv13_import_assert_source_scenario(scenario, inventory, validated)
  wlv13_import_assert_source_process(scenario, metrics, process_spec, validated)
  list(
    inventory = inventory,
    inventory_csv = csv,
    scenario = scenario,
    metrics = metrics,
    process_spec = process_spec
  )
}

wlv13_import_stage_run <- function(validated, source, staging_root,
                                    target_run_root) {
  wlv13_import_require(
    !file.exists(target_run_root) && !dir.exists(target_run_root),
    "Target run already exists; authenticated imports never overwrite it."
  )
  wlv13_import_require(
    dir.create(staging_root, recursive = FALSE, showWarnings = FALSE),
    "Cannot create run-import staging directory."
  )
  pairs <- rbind(
    data.frame(
      relative = "run_manifest.json",
      source = source$inventory$manifest_path,
      stringsAsFactors = FALSE
    ),
    data.frame(
      relative = source$inventory$records$path,
      source = file.path(source$inventory$root,
        source$inventory$records$path),
      stringsAsFactors = FALSE
    )
  )
  pairs$target <- file.path(staging_root, pairs$relative)
  for (index in seq_len(nrow(pairs))) {
    destination_parent <- dirname(pairs$target[[index]])
    wlv13_ensure_dir(destination_parent, "run-import artifact directory")
    wlv13_import_require(
      file.link(pairs$source[[index]], pairs$target[[index]]),
      sprintf("NTFS hard-link creation failed for `%s`; no copy fallback is allowed.",
        pairs$relative[[index]]
      )
    )
    wlv13_import_assert_hardlink_pair(pairs$source[[index]],
      pairs$target[[index]]
    )
  }
  staged <- wlv13_run_inventory(staging_root)
  wlv13_import_require(
    identical(staged$manifest_sha256, validated$manifest_sha256) &&
      identical(wlv13_inventory_signature(staged),
        validated$inventory_sha256),
    "Staged hard-linked run differs from the authenticated source run."
  )
  list(inventory = staged, pairs = pairs)
}

wlv13_import_transform_metrics <- function(source_metrics, target_root,
                                            evidence_root) {
  value <- wlv13_import_clone(source_metrics)
  value$working_directory <- target_root
  value$stdout_path <- file.path(evidence_root, "stdout.log")
  value$stderr_path <- file.path(evidence_root, "stderr.log")
  value$samples_path <- file.path(evidence_root, "process-samples.csv")
  value$process_spec_path <- file.path(evidence_root, "process-spec.json")
  value
}

wlv13_import_transform_process_spec <- function(source_spec, target_root) {
  value <- wlv13_import_clone(source_spec)
  value$working_directory <- target_root
  value
}

wlv13_import_allowed_metrics_transform <- function(source, target,
                                                    evidence_root,
                                                    target_root) {
  expected <- wlv13_import_transform_metrics(source, target_root, evidence_root)
  identical(target, expected)
}

wlv13_import_allowed_process_spec_transform <- function(source, target,
                                                         target_root) {
  identical(target, wlv13_import_transform_process_spec(source, target_root))
}

wlv13_import_authentication_fields <- c(
  "schema", "scenario_id", "source_commit", "runtime_commit", "profile_id",
  "profile_sha256", "import_report_path", "import_report_sha256",
  "source_scenario_sha256", "inventory_csv_sha256",
  "inventory_row_sha256"
)

wlv13_import_authentication <- function(validated, source, report_path,
                                        report_hash) {
  list(
    schema = wlv13_schema$import_authentication,
    scenario_id = validated$scenario_id,
    source_commit = validated$source_commit,
    runtime_commit = validated$target_commit,
    profile_id = validated$profile$id,
    profile_sha256 = validated$profile_sha256,
    import_report_path = normalizePath(report_path,
      winslash = "/", mustWork = TRUE
    ),
    import_report_sha256 = report_hash,
    source_scenario_sha256 = validated$auxiliary$scenario_result$sha256,
    inventory_csv_sha256 = source$inventory_csv$sha256,
    inventory_row_sha256 = source$inventory_csv$canonical_row_sha256
  )
}

wlv13_import_transform_scenario <- function(source_scenario, validated,
                                             target_inventory,
                                             authentication) {
  value <- wlv13_import_clone(source_scenario)
  value$project_root <- validated$target_root
  value$expected_commit <- validated$target_commit
  value$observed_commit <- validated$target_commit
  value$outputs[[1L]]$root <- target_inventory$root
  value$outputs[[1L]]$manifest_path <- target_inventory$manifest_path
  value$execution_mode <- "authenticated_import"
  value$authentication <- authentication
  value
}

wlv13_import_allowed_scenario_transform <- function(source, target, validated,
                                                     target_inventory,
                                                     authentication) {
  identical(target, wlv13_import_transform_scenario(source, validated,
    target_inventory, authentication
  ))
}

wlv13_import_materialize_auxiliary <- function(validated, source,
                                                evidence_root) {
  source_auth <- file.path(evidence_root, "source-auth")
  wlv13_ensure_dir(source_auth, "source-auth evidence directory")
  source_records <- list()
  for (name in wlv13_import_auxiliary_names) {
    destination <- file.path(source_auth,
      unname(wlv13_import_auxiliary_filenames[[name]])
    )
    wlv13_import_copy_exact(validated$auxiliary[[name]]$path, destination,
      validated$auxiliary[[name]]
    )
    source_records[[name]] <- list(
      original_path = validated$auxiliary[[name]]$path,
      copied_path = normalizePath(destination,
        winslash = "/", mustWork = TRUE
      ),
      size_bytes = validated$auxiliary[[name]]$size_bytes,
      sha256 = validated$auxiliary[[name]]$sha256
    )
  }
  for (name in c("stdout", "stderr", "samples")) {
    destination <- file.path(evidence_root,
      unname(wlv13_import_auxiliary_filenames[[name]])
    )
    wlv13_import_copy_exact(validated$auxiliary[[name]]$path, destination,
      validated$auxiliary[[name]]
    )
  }
  relocated_spec <- wlv13_import_transform_process_spec(source$process_spec,
    validated$target_root
  )
  relocated_spec_path <- file.path(evidence_root, "process-spec.json")
  wlv13_import_write_json(relocated_spec, relocated_spec_path)
  relocated_metrics <- wlv13_import_transform_metrics(source$metrics,
    validated$target_root, evidence_root
  )
  relocated_metrics$process_spec_sha256 <- wlv13_sha256_file(relocated_spec_path)
  relocated_metrics_path <- file.path(evidence_root, "process-metrics.json")
  wlv13_import_write_json(relocated_metrics, relocated_metrics_path)
  expected_metrics_source <- wlv13_import_clone(source$metrics)
  expected_metrics_source$process_spec_sha256 <-
    wlv13_sha256_file(relocated_spec_path)
  wlv13_import_require(
    wlv13_import_allowed_process_spec_transform(source$process_spec,
      relocated_spec, validated$target_root) &&
      wlv13_import_allowed_metrics_transform(expected_metrics_source,
        relocated_metrics, evidence_root, validated$target_root
      ),
    "Materialized process evidence contains an unauthorized transformation."
  )
  relocated_records <- list(
    stdout = wlv13_import_record(file.path(evidence_root, "stdout.log")),
    stderr = wlv13_import_record(file.path(evidence_root, "stderr.log")),
    samples = wlv13_import_record(file.path(evidence_root,
      "process-samples.csv")),
    process_spec = wlv13_import_record(relocated_spec_path),
    process_metrics = wlv13_import_record(relocated_metrics_path)
  )
  list(
    source = source_records,
    relocated = relocated_records,
    metrics = relocated_metrics,
    process_spec = relocated_spec
  )
}

wlv13_import_report <- function(validated, source, target_inventory,
                                auxiliary, evidence_root) {
  list(
    schema = wlv13_schema$baseline_import,
    scenario_id = validated$scenario_id,
    execution_mode = "authenticated_import",
    source_project_root = validated$source_root,
    target_project_root = validated$target_root,
    expected_source_commit = validated$source_commit,
    expected_runtime_commit = validated$target_commit,
    method = validated$method,
    run_id = validated$run_id,
    result_id = validated$result_id,
    run_manifest_sha256 = validated$manifest_sha256,
    run_inventory_sha256 = validated$inventory_sha256,
    expected_run_dirty = validated$run_dirty,
    validation_profile = validated$profile,
    validation_profile_sha256 = validated$profile_sha256,
    inventory_csv = source$inventory_csv,
    source_run = list(
      root = source$inventory$root,
      manifest_path = source$inventory$manifest_path,
      manifest_sha256 = source$inventory$manifest_sha256,
      inventory_sha256 = wlv13_inventory_signature(source$inventory),
      artifact_count = nrow(source$inventory$records)
    ),
    target_run = list(
      root = target_inventory$root,
      manifest_path = target_inventory$manifest_path,
      manifest_sha256 = target_inventory$manifest_sha256,
      inventory_sha256 = wlv13_inventory_signature(target_inventory),
      artifact_count = nrow(target_inventory$records)
    ),
    auxiliary = list(
      source = auxiliary$source,
      relocated = auxiliary$relocated
    ),
    transformations = list(
      scenario_result = as.list(c(
        "project_root", "expected_commit", "observed_commit",
        "outputs[1].root", "outputs[1].manifest_path", "execution_mode",
        "authentication"
      )),
      process_metrics = as.list(c(
        "working_directory", "stdout_path", "stderr_path", "samples_path",
        "process_spec_path", "process_spec_sha256"
      )),
      process_spec = list("working_directory"),
      run_store = "ntfs_hardlink_only"
    ),
    flags = list(
      source_scenario_canonical = TRUE,
      process_evidence_canonical = TRUE,
      elapsed_and_rss_preserved = TRUE,
      source_auth_byte_exact = TRUE,
      hardlink_only = TRUE,
      copy_fallback = FALSE,
      readonly_mutated = FALSE,
      acl_mutated = FALSE,
      same_ntfs_volume = TRUE,
      reparse_points_rejected = TRUE,
      target_runtime_clean = TRUE,
      atomic_run_promotion = TRUE,
      source_rechecked = TRUE,
      target_rechecked = TRUE
    )
  )
}

wlv13_import_report_fields <- c(
  "schema", "scenario_id", "execution_mode", "source_project_root",
  "target_project_root", "expected_source_commit", "expected_runtime_commit",
  "method", "run_id", "result_id", "run_manifest_sha256",
  "run_inventory_sha256", "expected_run_dirty",
  "validation_profile", "validation_profile_sha256", "inventory_csv",
  "source_run", "target_run", "auxiliary", "transformations", "flags"
)

wlv13_import_verify_record_path <- function(record, expected_path, label) {
  wlv13_import_exact_names(record, c("path", "size_bytes", "sha256"), label)
  path <- wlv13_import_normalize_file(record$path, paste0(label, ".path"))
  wlv13_import_require(wlv13_import_path_equal(path, expected_path),
    sprintf("%s path is not canonical.", label)
  )
  observed <- wlv13_file_record(path)
  wlv13_import_require(
    identical(observed$size_bytes,
      wlv13_import_size(record$size_bytes, paste0(label, ".size_bytes"))) &&
      identical(observed$sha256,
        wlv13_import_hash(record$sha256, paste0(label, ".sha256"))),
    sprintf("%s bytes differ from the import report.", label)
  )
  invisible(path)
}

wlv13_import_validate_report <- function(imported_scenario, scenario_id,
                                          expected_runtime_commit,
                                          baseline_base_commit,
                                          expected_profile) {
  expected_runtime_commit <- wlv13_import_commit(expected_runtime_commit,
    "expected_runtime_commit"
  )
  baseline_base_commit <- wlv13_import_commit(baseline_base_commit,
    "baseline_base_commit"
  )
  wlv13_import_validate_profile(expected_profile, baseline_base_commit,
    expected_runtime_commit,
    wlv13_bool(expected_profile$run_dirty, "expected_profile.run_dirty")
  )
  wlv13_import_require(
    grepl("^baseline/calculate/[a-z][a-z0-9_]*/workers1$", scenario_id,
      perl = TRUE
    ) && identical(imported_scenario$scenario_id, scenario_id) &&
      identical(imported_scenario$execution_mode, "authenticated_import"),
    "Authenticated imports are restricted to baseline full workers=1 scenarios."
  )
  authentication <- imported_scenario$authentication
  wlv13_import_exact_names(authentication, wlv13_import_authentication_fields,
    "Import authentication"
  )
  wlv13_import_require(
    identical(authentication$schema, wlv13_schema$import_authentication) &&
      identical(authentication$scenario_id, scenario_id) &&
      identical(authentication$source_commit, baseline_base_commit) &&
      identical(authentication$runtime_commit, expected_runtime_commit),
    "Import authentication scenario or source commit is invalid."
  )
  report_path <- wlv13_import_normalize_file(authentication$import_report_path,
    "authentication.import_report_path"
  )
  wlv13_import_require(
    identical(basename(report_path), "import-report.json") &&
      identical(wlv13_sha256_file(report_path),
        wlv13_import_hash(authentication$import_report_sha256,
          "authentication.import_report_sha256")),
    "Import report path or hash is invalid."
  )
  evidence_root <- dirname(report_path)
  report <- wlv13_json_read(report_path, simplify = FALSE)
  wlv13_import_exact_names(report, wlv13_import_report_fields,
    "Baseline import report"
  )
  wlv13_import_require(
    identical(report$schema, wlv13_schema$baseline_import) &&
      identical(report$execution_mode, "authenticated_import") &&
      identical(report$scenario_id, scenario_id) &&
      identical(report$expected_source_commit, baseline_base_commit) &&
      identical(report$expected_source_commit, authentication$source_commit) &&
      identical(report$expected_runtime_commit,
        authentication$runtime_commit) &&
      identical(report$expected_runtime_commit, expected_runtime_commit) &&
      identical(report$validation_profile, expected_profile) &&
      identical(report$validation_profile$id, authentication$profile_id) &&
      identical(report$run_manifest_sha256,
        report$source_run$manifest_sha256) &&
      identical(report$run_manifest_sha256,
        report$target_run$manifest_sha256) &&
      identical(report$run_inventory_sha256,
        report$source_run$inventory_sha256) &&
      identical(report$run_inventory_sha256,
        report$target_run$inventory_sha256),
    "Import report identity is inconsistent with its authentication."
  )
  source_root <- wlv13_import_normalize_dir(report$source_project_root,
    "import_report.source_project_root"
  )
  target_root <- wlv13_import_normalize_dir(report$target_project_root,
    "import_report.target_project_root"
  )
  wlv13_import_require(
    identical(wlv13_git_commit(source_root), report$expected_source_commit) &&
      identical(wlv13_git_commit(target_root), report$expected_runtime_commit) &&
      isTRUE(wlv13_git_runtime_clean(target_root)),
    "Import report worktrees are no longer pinned/runtime-clean."
  )
  run_dirty <- wlv13_bool(report$expected_run_dirty,
    "import_report.expected_run_dirty"
  )
  wlv13_import_validate_profile(report$validation_profile,
    report$expected_source_commit, report$expected_runtime_commit, run_dirty
  )
  profile_hash <- wlv13_import_profile_signature(report$validation_profile)
  wlv13_import_require(
    identical(profile_hash, report$validation_profile_sha256) &&
      identical(profile_hash, authentication$profile_sha256),
    "Validation profile hash is inconsistent."
  )
  method <- sub("^baseline/calculate/", "", scenario_id)
  method <- sub("/workers1$", "", method)
  wlv13_import_require(
    identical(report$method, method) &&
      identical(imported_scenario$project_root, target_root) &&
      identical(imported_scenario$expected_commit,
        report$expected_runtime_commit) &&
      identical(imported_scenario$observed_commit,
        report$expected_runtime_commit),
    "Imported scenario does not identify the effective target profile."
  )
  source_inventory <- wlv13_run_inventory(report$source_run$root)
  target_inventory <- wlv13_run_inventory(report$target_run$root)
  for (entry in list(
    list(record = report$source_run, inventory = source_inventory,
      label = "source run"),
    list(record = report$target_run, inventory = target_inventory,
      label = "target run")
  )) {
    wlv13_import_require(
      identical(entry$record$manifest_sha256,
        entry$inventory$manifest_sha256) &&
        identical(entry$record$inventory_sha256,
          wlv13_inventory_signature(entry$inventory)) &&
        identical(as.integer(entry$record$artifact_count), 24L),
      sprintf("Authenticated %s inventory differs from import report.",
        entry$label
      )
    )
  }
  wlv13_import_require(
    identical(source_inventory$manifest_sha256,
      target_inventory$manifest_sha256) &&
      identical(wlv13_inventory_signature(source_inventory),
        wlv13_inventory_signature(target_inventory)) &&
      identical(source_inventory$manifest$run_id, report$run_id) &&
      identical(source_inventory$manifest$result_id, report$result_id) &&
      identical(source_inventory$manifest$method, report$method) &&
      is.null(source_inventory$manifest$parent_run_id),
    "Imported source/target run identities or bytes differ."
  )
  source_files <- c(source_inventory$manifest_path,
    file.path(source_inventory$root, source_inventory$records$path)
  )
  target_files <- c(target_inventory$manifest_path,
    file.path(target_inventory$root, target_inventory$records$path)
  )
  for (index in seq_along(source_files)) {
    wlv13_import_assert_hardlink_pair(source_files[[index]],
      target_files[[index]]
    )
  }
  csv <- report$inventory_csv
  wlv13_import_exact_names(csv,
    c("path", "sha256", "canonical_row_sha256", "row"),
    "Import-report inventory CSV"
  )
  csv_path <- wlv13_import_normalize_file(csv$path,
    "import_report.inventory_csv.path"
  )
  wlv13_import_require(
    identical(wlv13_sha256_file(csv_path), csv$sha256) &&
      identical(csv$sha256, authentication$inventory_csv_sha256) &&
      identical(wlv13_import_inventory_row_sha256(unlist(csv$row,
        use.names = TRUE)), csv$canonical_row_sha256) &&
      identical(csv$canonical_row_sha256,
        authentication$inventory_row_sha256),
    "Normative inventory CSV or canonical row is no longer authenticated."
  )
  source_aux <- report$auxiliary$source
  relocated <- report$auxiliary$relocated
  wlv13_import_exact_names(source_aux, wlv13_import_auxiliary_names,
    "Import-report source auxiliary"
  )
  source_values <- list()
  for (name in wlv13_import_auxiliary_names) {
    record <- source_aux[[name]]
    wlv13_import_exact_names(record,
      c("original_path", "copied_path", "size_bytes", "sha256"),
      sprintf("Source auxiliary `%s`", name)
    )
    expected_copy <- file.path(evidence_root, "source-auth",
      unname(wlv13_import_auxiliary_filenames[[name]])
    )
    original <- wlv13_import_normalize_file(record$original_path,
      sprintf("source auxiliary `%s` original", name)
    )
    copied <- wlv13_import_normalize_file(record$copied_path,
      sprintf("source auxiliary `%s` copy", name)
    )
    wlv13_import_require(
      wlv13_import_path_equal(copied, expected_copy),
      sprintf("Source-auth `%s` copy path is not canonical.", name)
    )
    original_record <- wlv13_file_record(original)
    copied_record <- wlv13_file_record(copied)
    wlv13_import_require(
      identical(original_record, copied_record) &&
        identical(original_record$size_bytes,
          wlv13_import_size(record$size_bytes, paste0(name, ".size_bytes"))) &&
        identical(original_record$sha256,
          wlv13_import_hash(record$sha256, paste0(name, ".sha256"))),
      sprintf("Source-auth `%s` is missing or not byte-exact.", name)
    )
    source_values[[name]] <- copied
  }
  wlv13_import_require(
    identical(wlv13_sha256_file(source_values$scenario_result),
      authentication$source_scenario_sha256),
    "Source scenario copy hash differs from authentication."
  )
  expected_relocated <- c("stdout", "stderr", "samples", "process_spec",
    "process_metrics")
  wlv13_import_exact_names(relocated, expected_relocated,
    "Import-report relocated auxiliary"
  )
  relocated_paths <- list(
    stdout = file.path(evidence_root, "stdout.log"),
    stderr = file.path(evidence_root, "stderr.log"),
    samples = file.path(evidence_root, "process-samples.csv"),
    process_spec = file.path(evidence_root, "process-spec.json"),
    process_metrics = file.path(evidence_root, "process-metrics.json")
  )
  for (name in expected_relocated) {
    wlv13_import_verify_record_path(relocated[[name]], relocated_paths[[name]],
      sprintf("Relocated auxiliary `%s`", name)
    )
  }
  for (name in c("stdout", "stderr", "samples")) {
    wlv13_import_require(
      identical(wlv13_sha256_file(relocated_paths[[name]]),
        wlv13_sha256_file(source_values[[name]])),
      sprintf("Relocated `%s` is not byte-exact.", name)
    )
  }
  source_scenario <- wlv13_json_read(source_values$scenario_result,
    simplify = FALSE
  )
  source_metrics <- wlv13_json_read(source_values$process_metrics,
    simplify = FALSE
  )
  source_spec <- wlv13_json_read(source_values$process_spec, simplify = FALSE)
  source_auxiliary <- lapply(wlv13_import_auxiliary_names, function(name) {
    record <- source_aux[[name]]
    list(
      path = normalizePath(record$original_path,
        winslash = "/", mustWork = TRUE
      ),
      size_bytes = as.numeric(record$size_bytes),
      sha256 = record$sha256
    )
  })
  names(source_auxiliary) <- wlv13_import_auxiliary_names
  source_validated <- list(
    scenario_id = scenario_id,
    source_root = source_root,
    target_root = target_root,
    source_commit = report$expected_source_commit,
    target_commit = report$expected_runtime_commit,
    method = report$method,
    run_id = report$run_id,
    result_id = report$result_id,
    manifest_sha256 = source_inventory$manifest_sha256,
    inventory_sha256 = wlv13_inventory_signature(source_inventory),
    run_dirty = run_dirty,
    profile = report$validation_profile,
    profile_sha256 = profile_hash,
    auxiliary = source_auxiliary
  )
  wlv13_import_assert_full_run(source_inventory, source_validated)
  wlv13_import_assert_source_scenario(source_scenario, source_inventory,
    source_validated
  )
  wlv13_import_assert_source_process(source_scenario, source_metrics,
    source_spec, source_validated
  )
  row <- unlist(csv$row, use.names = TRUE)
  wlv13_import_require(
    identical(unname(row[["method"]]), report$method) &&
      identical(unname(row[["scenario"]]), "full_workers1") &&
      identical(unname(row[["commit"]]), report$expected_source_commit) &&
      identical(unname(row[["overlay"]]),
        report$validation_profile$inventory_value) &&
      identical(unname(row[["run_id"]]), report$run_id) &&
      identical(unname(row[["result_id"]]), report$result_id) &&
      wlv13_import_path_equal(unname(row[["evidence"]]),
        source_inventory$manifest_path),
    "Normative inventory row does not identify the authenticated source run/profile."
  )
  target_metrics <- wlv13_json_read(relocated_paths$process_metrics,
    simplify = FALSE
  )
  target_spec <- wlv13_json_read(relocated_paths$process_spec, simplify = FALSE)
  source_metrics$process_spec_sha256 <- wlv13_sha256_file(
    relocated_paths$process_spec
  )
  wlv13_import_require(
    wlv13_import_allowed_metrics_transform(source_metrics, target_metrics,
      evidence_root, target_root) &&
      wlv13_import_allowed_process_spec_transform(source_spec, target_spec,
        target_root),
    "Relocated process metrics/spec contain unauthorized transformations."
  )
  expected_authentication <- authentication
  wlv13_import_require(
    wlv13_import_allowed_scenario_transform(source_scenario,
      imported_scenario,
      list(target_root = target_root, target_commit = report$expected_runtime_commit),
      target_inventory, expected_authentication
    ),
    "Imported scenario result contains unauthorized transformations."
  )
  expected_transformations <- list(
    scenario_result = as.list(c(
      "project_root", "expected_commit", "observed_commit",
      "outputs[1].root", "outputs[1].manifest_path", "execution_mode",
      "authentication"
    )),
    process_metrics = as.list(c(
      "working_directory", "stdout_path", "stderr_path", "samples_path",
      "process_spec_path", "process_spec_sha256"
    )),
    process_spec = list("working_directory"),
    run_store = "ntfs_hardlink_only"
  )
  wlv13_import_require(
    identical(report$transformations, expected_transformations),
    "Import report does not enumerate exactly the permitted transformations."
  )
  flags <- report$flags
  required_true <- c(
    "source_scenario_canonical", "process_evidence_canonical",
    "elapsed_and_rss_preserved", "source_auth_byte_exact", "hardlink_only",
    "same_ntfs_volume", "reparse_points_rejected", "target_runtime_clean",
    "atomic_run_promotion", "source_rechecked", "target_rechecked"
  )
  required_false <- c("copy_fallback", "readonly_mutated", "acl_mutated")
  wlv13_import_require(
    is.list(flags) &&
      setequal(names(flags), c(required_true, required_false)) &&
      length(names(flags)) == length(c(required_true, required_false)) &&
      all(vapply(required_true, function(name) isTRUE(flags[[name]]),
      logical(1L))) &&
      all(vapply(required_false, function(name) identical(flags[[name]], FALSE),
        logical(1L))),
    "Import report safety flags are incomplete or false."
  )
  list(
    passed = TRUE,
    detail = sprintf("authenticated baseline import profile=%s source=%s target=%s",
      report$validation_profile$id, report$expected_source_commit,
      report$expected_runtime_commit
    )
  )
}

wlv13_validate_authenticated_import <- function(report, scenario_id,
                                                expected_runtime_commit,
                                                baseline_base_commit,
                                                expected_profile) {
  tryCatch(
    wlv13_import_validate_report(report, scenario_id,
      expected_runtime_commit, baseline_base_commit, expected_profile),
    error = function(error) list(
      passed = FALSE,
      detail = conditionMessage(error)
    )
  )
}

wlv13_import_baseline_run <- function(spec, evidence_directory) {
  validated <- wlv13_import_validate_spec(spec)
  evidence_requested <- normalizePath(
    wlv13_scalar_text(evidence_directory, "evidence_directory"),
    winslash = "/", mustWork = FALSE
  )
  wlv13_import_require(
    grepl("^[A-Za-z]:/", evidence_requested) &&
      !file.exists(evidence_requested) && !dir.exists(evidence_requested),
    "Evidence directory must be an absent absolute path."
  )
  wlv13_import_assert_git(validated)
  wlv13_import_assert_same_ntfs(validated$source_root, validated$target_root)
  source <- wlv13_import_read_source(validated)
  target_method_store <- file.path(validated$target_root, "results", "runs",
    validated$method
  )
  wlv13_ensure_dir(target_method_store, "target method run store")
  wlv13_import_assert_plain_path(target_method_store,
    "Target method run store"
  )
  target_run_root <- normalizePath(file.path(target_method_store,
    validated$run_id), winslash = "/", mustWork = FALSE
  )
  wlv13_import_require(
    wlv13_is_within(target_run_root, target_method_store),
    "Target run path escapes the target run store."
  )
  wlv13_import_require(
    !file.exists(target_run_root) && !dir.exists(target_run_root),
    "Target run already exists; authenticated imports never overwrite it."
  )
  staging_root <- tempfile(paste0(".issue13-import-", validated$run_id, "-"),
    tmpdir = target_method_store
  )
  promoted <- FALSE
  evidence_owned <- FALSE
  success <- FALSE
  on.exit({
    if (!promoted && (file.exists(staging_root) || dir.exists(staging_root))) {
      unlink(staging_root, recursive = TRUE, force = TRUE)
    }
    if (!success && evidence_owned &&
        (file.exists(evidence_requested) || dir.exists(evidence_requested))) {
      unlink(evidence_requested, recursive = TRUE, force = TRUE)
    }
  }, add = TRUE)
  wlv13_import_require(
    dir.create(evidence_requested, recursive = TRUE, showWarnings = FALSE),
    "Cannot create partial import evidence directory."
  )
  evidence_owned <- TRUE
  marker <- file.path(evidence_requested, ".issue13-import-incomplete")
  writeLines("authenticated baseline import in progress", marker,
    useBytes = TRUE
  )
  auxiliary <- wlv13_import_materialize_auxiliary(validated, source,
    evidence_requested
  )
  staged <- wlv13_import_stage_run(validated, source, staging_root,
    target_run_root
  )
  wlv13_import_recheck_auxiliary(validated$auxiliary)
  wlv13_recheck_inventory(source$inventory)
  wlv13_import_assert_git(validated)
  wlv13_import_require(
    file.rename(staging_root, target_run_root),
    "Could not atomically promote the hard-linked target run."
  )
  promoted <- TRUE
  target_inventory <- wlv13_run_inventory(target_run_root)
  wlv13_import_require(
    identical(target_inventory$manifest_sha256,
      validated$manifest_sha256) &&
      identical(wlv13_inventory_signature(target_inventory),
        validated$inventory_sha256),
    "Promoted target run differs from authenticated source."
  )
  for (index in seq_len(nrow(staged$pairs))) {
    final_path <- file.path(target_run_root, staged$pairs$relative[[index]])
    wlv13_import_assert_hardlink_pair(staged$pairs$source[[index]], final_path)
  }
  wlv13_import_recheck_auxiliary(validated$auxiliary)
  wlv13_recheck_inventory(source$inventory)
  wlv13_import_assert_git(validated)
  report <- wlv13_import_report(validated, source, target_inventory, auxiliary,
    evidence_requested
  )
  report_path <- file.path(evidence_requested, "import-report.json")
  wlv13_import_write_json(report, report_path)
  report_hash <- wlv13_sha256_file(report_path)
  authentication <- wlv13_import_authentication(validated, source, report_path,
    report_hash
  )
  imported_scenario <- wlv13_import_transform_scenario(source$scenario,
    validated, target_inventory, authentication
  )
  wlv13_import_require(
    wlv13_import_allowed_scenario_transform(source$scenario,
      imported_scenario, validated, target_inventory, authentication),
    "Imported scenario contains an unauthorized transformation."
  )
  scenario_path <- file.path(evidence_requested, "scenario-result.json")
  wlv13_import_write_json(imported_scenario, scenario_path)
  validation <- wlv13_validate_authenticated_import(imported_scenario,
    validated$scenario_id, validated$target_commit,
    validated$source_commit, validated$profile
  )
  wlv13_import_require(isTRUE(validation$passed), paste0(
    "Installed authenticated import failed self-validation: ",
    validation$detail
  ))
  wlv13_import_recheck_auxiliary(validated$auxiliary)
  wlv13_recheck_inventory(source$inventory)
  wlv13_recheck_inventory(target_inventory)
  wlv13_import_assert_git(validated)
  wlv13_import_require(unlink(marker, force = TRUE) == 0L,
    "Cannot clear import-incomplete marker."
  )
  success <- TRUE
  invisible(list(
    scenario_path = scenario_path,
    import_report_path = report_path,
    target_run_root = target_run_root,
    validation = validation
  ))
}
