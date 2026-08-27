# External evidence helpers for issue #13.
#
# This file intentionally lives under run_logs.  It must never be sourced by
# the candidate runtime or included in its publication input inventory.

wlv13_schema <- list(
  snapshot = "wlv-issue13-evidence-snapshot/1",
  comparison = "wlv-issue13-artifact-comparison/1",
  scenario = "wlv-issue13-scenario-result/1",
  aggregate = "wlv-issue13-evidence-aggregate/1",
  fault = "wlv-issue13-fault-result/1",
  baseline_import_spec = "wlv-issue13-baseline-run-import-spec/1",
  baseline_import = "wlv-issue13-baseline-run-import/1",
  import_authentication = "wlv-issue13-authenticated-import/1",
  validation_profile = "wlv-issue13-validation-profile/1",
  baseline_runtime_index = "wlv-issue13-baseline-runtime-index/1"
)

wlv13_require <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop(sprintf("Package `%s` is required by the issue #13 harness.", package),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

wlv13_scalar_text <- function(value, name, pattern = NULL) {
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !nzchar(value)) {
    stop(sprintf("`%s` must be one non-empty string.", name), call. = FALSE)
  }
  value <- enc2utf8(value)
  if (!is.null(pattern) && !grepl(pattern, value, perl = TRUE)) {
    stop(sprintf("`%s` has an invalid value: %s.", name, value), call. = FALSE)
  }
  value
}

wlv13_renv_library_root <- function(r_library) {
  library <- wlv13_normalize_existing_dir(r_library, "R library")
  architecture <- basename(library)
  version_path <- dirname(library)
  version <- basename(version_path)
  platform_path <- dirname(version_path)
  platform <- basename(platform_path)
  root <- dirname(platform_path)
  valid_component <- "^[A-Za-z0-9._+-]+$"
  reconstructed <- normalizePath(
    file.path(root, platform, version, architecture),
    winslash = "/", mustWork = TRUE
  )
  if (!grepl(valid_component, architecture, perl = TRUE) ||
      !grepl("^R-[0-9]+[.][0-9]+$", version, perl = TRUE) ||
      !grepl(valid_component, platform, perl = TRUE) ||
      !identical(basename(root), "library") ||
      !identical(reconstructed, library)) {
    stop("The R library does not have the sealed renv profile layout.",
      call. = FALSE
    )
  }
  root
}

wlv13_r_environment <- function(r_library) {
  if (is.null(r_library)) {
    stop("`r_library` is required for every monitored R process.",
      call. = FALSE
    )
  }
  library <- wlv13_normalize_existing_dir(r_library, "R library")
  list(
    R_LIBS_USER = library,
    RENV_PATHS_LIBRARY = wlv13_renv_library_root(library),
    RENV_CONFIG_AUTO_SNAPSHOT = "FALSE",
    RENV_CONFIG_CACHE_ENABLED = "FALSE",
    RENV_CONFIG_LOCKING_ENABLED = "FALSE",
    RENV_CONFIG_SANDBOX_ENABLED = "FALSE",
    RENV_CONFIG_UPDATES_CHECK = "FALSE",
    RENV_CONFIG_USER_ENVIRON = "FALSE",
    RENV_CONFIG_USER_LIBRARY = "FALSE",
    TZ = "UTC"
  )
}

wlv13_id <- function(value, name = "id") {
  wlv13_scalar_text(value, name, "^[a-z0-9][a-z0-9._/-]*$")
}

wlv13_bool <- function(value, name) {
  if (!is.logical(value) || length(value) != 1L || is.na(value)) {
    stop(sprintf("`%s` must be one non-missing logical value.", name),
      call. = FALSE
    )
  }
  value
}

wlv13_integer <- function(value, name, minimum = 0L) {
  if (!is.numeric(value) || length(value) != 1L || is.na(value) ||
      !is.finite(value) || value != floor(value) || value < minimum ||
      value > .Machine$integer.max) {
    stop(sprintf("`%s` must be one integer >= %s.", name, minimum),
      call. = FALSE
    )
  }
  as.integer(value)
}

wlv13_now <- function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3%z")
}

wlv13_parse_cli <- function(arguments) {
  result <- list()
  index <- 1L
  while (index <= length(arguments)) {
    argument <- arguments[[index]]
    if (!startsWith(argument, "--")) {
      stop(sprintf("Unexpected positional argument: %s.", argument),
        call. = FALSE
      )
    }
    payload <- substring(argument, 3L)
    if (grepl("=", payload, fixed = TRUE)) {
      pieces <- strsplit(payload, "=", fixed = TRUE)[[1L]]
      key <- pieces[[1L]]
      value <- paste(pieces[-1L], collapse = "=")
    } else {
      key <- payload
      index <- index + 1L
      if (index > length(arguments) || startsWith(arguments[[index]], "--")) {
        stop(sprintf("--%s requires a value.", key), call. = FALSE)
      }
      value <- arguments[[index]]
    }
    key <- chartr("-", "_", key)
    if (key %in% names(result)) {
      stop(sprintf("Duplicate command-line option: --%s.", payload),
        call. = FALSE
      )
    }
    result[[key]] <- value
    index <- index + 1L
  }
  result
}

wlv13_cli_required <- function(options, names) {
  missing <- names[!names %in% names(options)]
  if (length(missing)) {
    stop(sprintf("Missing option(s): %s.", paste0("--", chartr("_", "-", missing),
      collapse = ", "
    )), call. = FALSE)
  }
  invisible(options)
}

wlv13_normalize_existing_dir <- function(path, name = "directory") {
  path <- wlv13_scalar_text(path, name)
  if (!dir.exists(path)) {
    stop(sprintf("%s does not exist: %s.", name, path), call. = FALSE)
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

wlv13_ensure_dir <- function(path, name = "directory") {
  path <- wlv13_scalar_text(path, name)
  if (!dir.exists(path) &&
      !dir.create(path, recursive = TRUE, showWarnings = FALSE)) {
    stop(sprintf("Cannot create %s: %s.", name, path), call. = FALSE)
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

wlv13_is_within <- function(path, parent) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  parent <- normalizePath(parent, winslash = "/", mustWork = TRUE)
  comparison_path <- path
  comparison_parent <- parent
  if (.Platform$OS.type == "windows") {
    comparison_path <- tolower(comparison_path)
    comparison_parent <- tolower(comparison_parent)
  }
  comparison_parent <- sub("/+$", "", comparison_parent)
  identical(comparison_path, comparison_parent) ||
    startsWith(comparison_path, paste0(comparison_parent, "/"))
}

wlv13_sha256_raw <- function(value) {
  wlv13_require("openssl")
  if (!is.raw(value)) {
    stop("SHA-256 input must be raw.", call. = FALSE)
  }
  paste0(tolower(as.character(openssl::sha256(value))), collapse = "")
}

wlv13_sha256_text <- function(value) {
  wlv13_sha256_raw(charToRaw(enc2utf8(paste(value, collapse = ""))))
}

wlv13_sha256_file <- function(path) {
  wlv13_require("openssl")
  if (!file.exists(path) || isTRUE(file.info(path)$isdir)) {
    stop(sprintf("Cannot hash missing file: %s.", path), call. = FALSE)
  }
  connection <- file(path, open = "rb")
  on.exit(close(connection), add = TRUE)
  paste0(tolower(as.character(openssl::sha256(connection))), collapse = "")
}

wlv13_file_record <- function(path) {
  before <- file.info(path)
  if (nrow(before) != 1L || isTRUE(before$isdir) || is.na(before$size)) {
    stop(sprintf("Invalid evidence artifact: %s.", path), call. = FALSE)
  }
  hash <- wlv13_sha256_file(path)
  after <- file.info(path)
  if (nrow(after) != 1L || isTRUE(after$isdir) || is.na(after$size) ||
      !identical(as.numeric(before$size), as.numeric(after$size)) ||
      !identical(as.numeric(before$mtime), as.numeric(after$mtime))) {
    stop(sprintf("Artifact changed while being hashed: %s.", path),
      call. = FALSE
    )
  }
  list(size_bytes = as.numeric(after$size), sha256 = hash)
}

wlv13_json_read <- function(path, simplify = FALSE) {
  wlv13_require("jsonlite")
  if (!file.exists(path) || isTRUE(file.info(path)$isdir)) {
    stop(sprintf("JSON file is missing: %s.", path), call. = FALSE)
  }
  tryCatch(
    jsonlite::read_json(path, simplifyVector = simplify),
    error = function(error) {
      stop(sprintf("Cannot read JSON `%s`: %s", path, conditionMessage(error)),
        call. = FALSE
      )
    }
  )
}

wlv13_json_write <- function(value, path) {
  wlv13_require("jsonlite")
  directory <- wlv13_ensure_dir(dirname(path), "JSON output directory")
  path <- file.path(directory, basename(path))
  temporary <- tempfile(paste0(".", basename(path), "-"), tmpdir = directory)
  on.exit(if (file.exists(temporary)) unlink(temporary, force = TRUE), add = TRUE)
  jsonlite::write_json(
    value,
    temporary,
    auto_unbox = TRUE,
    pretty = TRUE,
    digits = NA,
    null = "null",
    na = "string"
  )
  roundtrip <- wlv13_json_read(temporary, simplify = FALSE)
  if (is.null(roundtrip)) {
    stop("JSON evidence failed round-trip validation.", call. = FALSE)
  }
  if (file.exists(path)) {
    stop(sprintf("Refusing to overwrite evidence JSON: %s.", path),
      call. = FALSE
    )
  }
  if (!file.rename(temporary, path)) {
    stop(sprintf("Cannot install evidence JSON: %s.", path), call. = FALSE)
  }
  invisible(path)
}

wlv13_json_equivalent <- function(value, path) {
  wlv13_require("jsonlite")
  if (!file.exists(path) || isTRUE(file.info(path)$isdir)) return(FALSE)
  expected <- jsonlite::fromJSON(jsonlite::toJSON(
    value,
    auto_unbox = TRUE,
    pretty = TRUE,
    digits = NA,
    null = "null",
    na = "string"
  ), simplifyVector = FALSE)
  identical(wlv13_json_read(path, simplify = FALSE), expected)
}

wlv13_assert_json_bundle_envelope <- function(directory, canonical_names) {
  directory <- wlv13_normalize_existing_dir(directory, "JSON bundle directory")
  canonical_names <- vapply(canonical_names, wlv13_scalar_text,
    character(1L), name = "canonical JSON name"
  )
  entries <- list.files(directory,
    all.files = TRUE,
    no.. = TRUE,
    full.names = FALSE
  )
  temporary_targets <- character()
  for (entry in entries) {
    matched <- canonical_names[vapply(canonical_names, function(name) {
      identical(entry, name) || grepl(paste0(
        "^\\.", gsub(".", "\\.", name, fixed = TRUE),
        "-[0-9a-f]+(?:\\.tmp)?$"
      ), entry, perl = TRUE)
    }, logical(1L))]
    if (length(matched) != 1L || dir.exists(file.path(directory, entry))) {
      stop(sprintf("JSON bundle contains foreign entry `%s`.", entry),
        call. = FALSE
      )
    }
    if (!identical(entry, matched[[1L]])) {
      temporary_targets <- c(temporary_targets, matched[[1L]])
    }
  }
  if (length(temporary_targets) > 1L || anyDuplicated(temporary_targets)) {
    stop("JSON bundle contains multiple simultaneous atomic writes.",
      call. = FALSE
    )
  }
  for (name in canonical_names) {
    has_final <- name %in% entries
    has_temp <- name %in% temporary_targets
    if (has_final && has_temp) {
      stop(sprintf("JSON bundle has final and temp for `%s`.", name),
        call. = FALSE
      )
    }
  }
  invisible(directory)
}

wlv13_json_write_or_verify <- function(value, path) {
  directory <- wlv13_ensure_dir(dirname(path), "JSON output directory")
  path <- file.path(directory, basename(path))
  escaped <- gsub(".", "\\.", basename(path), fixed = TRUE)
  temporary_names <- list.files(directory,
    pattern = paste0("^\\.", escaped, "-[0-9a-f]+(?:\\.tmp)?$"),
    all.files = TRUE,
    no.. = TRUE,
    full.names = FALSE
  )
  if (length(temporary_names) > 1L ||
      (file.exists(path) && length(temporary_names))) {
    stop(sprintf("Ambiguous JSON generation for `%s`.", path), call. = FALSE)
  }
  if (file.exists(path)) {
    if (!wlv13_json_equivalent(value, path)) {
      stop(sprintf("Existing JSON differs from requested payload: `%s`.", path),
        call. = FALSE
      )
    }
    return(invisible(path))
  }
  if (length(temporary_names) == 1L) {
    temporary <- file.path(directory, temporary_names[[1L]])
    equivalent <- tryCatch(
      wlv13_json_equivalent(value, temporary),
      error = function(error) {
        structure(FALSE,
          class = c("wlv13_unreadable_json_staging", "logical"),
          reason = conditionMessage(error)
        )
      }
    )
    if (inherits(equivalent, "wlv13_unreadable_json_staging")) {
      if (!file.exists(temporary) || dir.exists(temporary) ||
          nzchar(Sys.readlink(temporary)) ||
          !identical(
            normalizePath(dirname(temporary), winslash = "/", mustWork = TRUE),
            normalizePath(directory, winslash = "/", mustWork = TRUE)
          ) || unlink(temporary, force = TRUE) != 0L ||
          file.exists(temporary)) {
        stop(sprintf("Cannot safely discard unreadable JSON staging: `%s`.",
          temporary
        ), call. = FALSE)
      }
      message(sprintf(
        "Discarded unreadable target-bound JSON staging for `%s`: %s",
        path,
        attr(equivalent, "reason")
      ))
      return(wlv13_json_write(value, path))
    }
    if (!isTRUE(equivalent)) {
      stop(sprintf("Staged JSON differs from requested payload: `%s`.", path),
        call. = FALSE
      )
    }
    before <- wlv13_sha256_file(temporary)
    if (!file.rename(temporary, path) || !file.exists(path) ||
        !identical(wlv13_sha256_file(path), before) ||
        !wlv13_json_equivalent(value, path)) {
      stop(sprintf("Cannot recover staged JSON: `%s`.", path), call. = FALSE)
    }
    return(invisible(path))
  }
  wlv13_json_write(value, path)
}

wlv13_safe_relative_path <- function(path, name = "artifact path") {
  path <- wlv13_scalar_text(path, name)
  path <- chartr("\\", "/", path)
  invalid <- startsWith(path, "/") || grepl("^[A-Za-z]:", path) ||
    grepl("(^|/)\\.\\.(/|$)", path) || grepl("(^|/)\\.(/|$)", path) ||
    endsWith(path, "/") || grepl("//", path, fixed = TRUE)
  if (invalid) {
    stop(sprintf("Unsafe %s: %s.", name, path), call. = FALSE)
  }
  path
}

wlv13_list_files <- function(root, exclude = character()) {
  root <- wlv13_normalize_existing_dir(root, "artifact root")
  files <- list.files(
    root,
    recursive = TRUE,
    full.names = FALSE,
    all.files = TRUE,
    include.dirs = FALSE,
    no.. = TRUE
  )
  files <- chartr("\\", "/", files)
  files <- setdiff(files, exclude)
  files <- sort(files, method = "radix")
  if (length(files)) {
    vapply(files, wlv13_safe_relative_path, character(1L))
    resolved <- normalizePath(file.path(root, files), winslash = "/", mustWork = TRUE)
    expected <- chartr("\\", "/", file.path(root, files))
    if (.Platform$OS.type == "windows") {
      resolved <- tolower(resolved)
      expected <- tolower(expected)
    }
    if (!identical(unname(resolved), unname(expected))) {
      stop("Artifact roots must not contain links or non-canonical paths.",
        call. = FALSE
      )
    }
  }
  files
}

wlv13_records_data_frame <- function(records, label = "artifacts") {
  if (!is.list(records) || !length(records)) {
    stop(sprintf("%s must be a non-empty JSON array.", label), call. = FALSE)
  }
  rows <- lapply(seq_along(records), function(index) {
    record <- records[[index]]
    required <- c("path", "role", "size_bytes", "sha256")
    if (!is.list(record) || !setequal(names(record), required) ||
        length(names(record)) != length(required)) {
      stop(sprintf("%s record %d has an invalid schema.", label, index),
        call. = FALSE
      )
    }
    path <- wlv13_safe_relative_path(record$path, paste0(label, " path"))
    role <- wlv13_scalar_text(record$role, paste0(label, " role"),
      "^[a-z0-9][a-z0-9._-]*$"
    )
    size <- as.numeric(record$size_bytes)
    if (length(size) != 1L || is.na(size) || !is.finite(size) ||
        size < 0 || size != floor(size) || size > 2^53 - 1) {
      stop(sprintf("%s record `%s` has an invalid size.", label, path),
        call. = FALSE
      )
    }
    hash <- wlv13_scalar_text(record$sha256, paste0(label, " sha256"),
      "^[0-9a-f]{64}$"
    )
    data.frame(
      path = path,
      role = role,
      size_bytes = size,
      sha256 = hash,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  value <- do.call(rbind, rows)
  row.names(value) <- NULL
  if (anyDuplicated(value$path) ||
      !identical(order(value$path, method = "radix"), seq_len(nrow(value)))) {
    stop(sprintf("%s paths must be unique and canonically ordered.", label),
      call. = FALSE
    )
  }
  value
}

wlv13_capture_records <- function(root, paths, roles) {
  root <- wlv13_normalize_existing_dir(root, "artifact root")
  if (!is.character(paths) || !length(paths) || anyNA(paths) ||
      length(paths) != length(roles)) {
    stop("Artifact paths and roles must be equal non-empty vectors.",
      call. = FALSE
    )
  }
  paths <- vapply(paths, wlv13_safe_relative_path, character(1L))
  if (anyDuplicated(paths)) {
    stop("Artifact paths must be unique.", call. = FALSE)
  }
  roles <- vapply(roles, wlv13_scalar_text, character(1L), name = "role",
    pattern = "^[a-z0-9][a-z0-9._-]*$"
  )
  order_index <- order(paths, method = "radix")
  paths <- paths[order_index]
  roles <- roles[order_index]
  absolute <- file.path(root, paths)
  if (any(!file.exists(absolute)) || any(file.info(absolute)$isdir %in% TRUE)) {
    stop(sprintf("Snapshot artifacts are missing: %s.",
      paste(paths[!file.exists(absolute) | file.info(absolute)$isdir %in% TRUE],
        collapse = ", "
      )), call. = FALSE)
  }
  records <- lapply(absolute, wlv13_file_record)
  value <- data.frame(
    path = unname(paths),
    role = unname(roles),
    size_bytes = unname(vapply(records, `[[`, numeric(1L), "size_bytes")),
    sha256 = unname(vapply(records, `[[`, character(1L), "sha256")),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  row.names(value) <- NULL
  value
}

wlv13_verify_records <- function(root, records, excluded = character(),
                                 reject_unlisted = TRUE) {
  root <- wlv13_normalize_existing_dir(root, "artifact root")
  if (!is.data.frame(records) || !identical(names(records),
      c("path", "role", "size_bytes", "sha256"))) {
    stop("Artifact records have an invalid internal schema.", call. = FALSE)
  }
  if (isTRUE(reject_unlisted)) {
    actual <- wlv13_list_files(root, exclude = excluded)
    missing <- setdiff(records$path, actual)
    extra <- setdiff(actual, records$path)
    if (length(missing) || length(extra)) {
      stop(sprintf(
        "Artifact inventory mismatch (missing=%s; unlisted=%s).",
        paste(missing, collapse = ","), paste(extra, collapse = ",")
      ), call. = FALSE)
    }
  }
  observed <- wlv13_capture_records(root, records$path, records$role)
  if (!identical(observed, records)) {
    changed <- records$path[
      observed$size_bytes != records$size_bytes |
        observed$sha256 != records$sha256
    ]
    stop(sprintf("Artifact bytes differ from their manifest: %s.",
      paste(changed, collapse = ", ")
    ), call. = FALSE)
  }
  invisible(observed)
}

wlv13_run_inventory <- function(root) {
  root <- wlv13_normalize_existing_dir(root, "run root")
  manifest_path <- file.path(root, "run_manifest.json")
  manifest <- wlv13_json_read(manifest_path, simplify = FALSE)
  required <- c(
    "schema", "schema_version", "run_id", "result_id", "created_at_utc",
    "parent_run_id", "method", "output_contract", "result", "execution",
    "artifacts"
  )
  if (!is.list(manifest) || !setequal(names(manifest), required) ||
      !identical(manifest$schema, "wlv-run-manifest") ||
      !identical(as.character(manifest$schema_version), "1")) {
    stop("Run manifest has an unsupported schema.", call. = FALSE)
  }
  records <- wlv13_records_data_frame(manifest$artifacts, "run artifacts")
  if ("run_manifest.json" %in% records$path) {
    stop("Run manifests must not inventory themselves.", call. = FALSE)
  }
  wlv13_verify_records(root, records, excluded = "run_manifest.json")
  list(
    kind = "run",
    root = root,
    manifest_path = manifest_path,
    manifest_sha256 = wlv13_sha256_file(manifest_path),
    manifest = manifest,
    records = records,
    identity = list(
      method = manifest$method,
      run_id = manifest$run_id,
      result_id = manifest$result_id,
      output_contract = manifest$output_contract
    )
  )
}

wlv13_release_inventory <- function(root) {
  root <- wlv13_normalize_existing_dir(root, "release root")
  manifest_path <- file.path(root, "release_manifest.json")
  manifest <- wlv13_json_read(manifest_path, simplify = FALSE)
  required <- c(
    "schema", "schema_version", "release_id", "channel", "sequence",
    "created_at_utc", "metadata", "runs", "artifacts"
  )
  if (!is.list(manifest) || !setequal(names(manifest), required) ||
      !identical(manifest$schema, "wlv-release-manifest") ||
      !identical(as.character(manifest$schema_version), "1")) {
    stop("Release manifest has an unsupported schema.", call. = FALSE)
  }
  records <- wlv13_records_data_frame(manifest$artifacts, "release artifacts")
  if ("release_manifest.json" %in% records$path) {
    stop("Release manifests must not inventory themselves.", call. = FALSE)
  }
  wlv13_verify_records(root, records, excluded = "release_manifest.json")
  list(
    kind = "release",
    root = root,
    manifest_path = manifest_path,
    manifest_sha256 = wlv13_sha256_file(manifest_path),
    manifest = manifest,
    records = records,
    identity = list(
      release_id = manifest$release_id,
      channel = manifest$channel,
      sequence = manifest$sequence
    )
  )
}

wlv13_source_manifest_columns <- c(
  "schema_version", "source_generation_id", "contract_id",
  "contract_version", "contract_sha256", "artifact", "artifact_role",
  "size_bytes", "sha256"
)

wlv13_source_inventory <- function(root) {
  root <- wlv13_normalize_existing_dir(root, "normalized source root")
  manifest_path <- file.path(root, "_source_manifest.csv")
  if (!file.exists(manifest_path)) {
    stop(sprintf("Source manifest is missing: %s.", manifest_path),
      call. = FALSE
    )
  }
  manifest <- utils::read.csv(
    manifest_path,
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL,
    fileEncoding = "UTF-8"
  )
  if (!identical(names(manifest), wlv13_source_manifest_columns) ||
      !nrow(manifest) || anyNA(manifest) ||
      any(manifest$schema_version != "1")) {
    stop("Source manifest has an unsupported schema.", call. = FALSE)
  }
  records <- data.frame(
    path = unname(vapply(manifest$artifact, wlv13_safe_relative_path,
      character(1L))),
    role = unname(manifest$artifact_role),
    size_bytes = unname(suppressWarnings(as.numeric(manifest$size_bytes))),
    sha256 = unname(manifest$sha256),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  row.names(records) <- NULL
  if (anyNA(records$size_bytes) || any(records$size_bytes < 0) ||
      any(records$size_bytes != floor(records$size_bytes)) ||
      any(!grepl("^[0-9a-f]{64}$", records$sha256)) ||
      anyDuplicated(records$path) ||
      !identical(order(records$path, method = "radix"), seq_len(nrow(records)))) {
    stop("Source manifest contains invalid artifact records.", call. = FALSE)
  }
  wlv13_verify_records(root, records, excluded = "_source_manifest.csv")
  list(
    kind = "source",
    root = root,
    manifest_path = manifest_path,
    manifest_sha256 = wlv13_sha256_file(manifest_path),
    manifest = manifest,
    records = records,
    identity = list(
      source_generation_id = unique(manifest$source_generation_id),
      contract_id = unique(manifest$contract_id),
      contract_version = unique(manifest$contract_version),
      contract_sha256 = unique(manifest$contract_sha256)
    )
  )
}

wlv13_snapshot_inventory <- function(path) {
  path <- normalizePath(wlv13_scalar_text(path, "snapshot path"),
    winslash = "/", mustWork = TRUE
  )
  snapshot <- wlv13_json_read(path, simplify = FALSE)
  required <- c("schema", "snapshot_id", "root", "created_at", "artifacts")
  if (!is.list(snapshot) || !setequal(names(snapshot), required) ||
      !identical(snapshot$schema, wlv13_schema$snapshot)) {
    stop("External artifact snapshot has an invalid schema.", call. = FALSE)
  }
  root <- wlv13_normalize_existing_dir(snapshot$root, "snapshot root")
  records <- wlv13_records_data_frame(snapshot$artifacts, "snapshot artifacts")
  wlv13_verify_records(root, records, excluded = character(), reject_unlisted = FALSE)
  list(
    kind = "snapshot",
    root = root,
    manifest_path = path,
    manifest_sha256 = wlv13_sha256_file(path),
    manifest = snapshot,
    records = records,
    identity = list(snapshot_id = snapshot$snapshot_id)
  )
}

wlv13_inventory <- function(kind, root) {
  kind <- match.arg(kind, c("run", "release", "source", "snapshot"))
  switch(kind,
    run = wlv13_run_inventory(root),
    release = wlv13_release_inventory(root),
    source = wlv13_source_inventory(root),
    snapshot = wlv13_snapshot_inventory(root)
  )
}

wlv13_inventory_signature <- function(inventory) {
  paste(
    inventory$kind,
    inventory$manifest_sha256,
    paste(inventory$records$path, inventory$records$role,
      format(inventory$records$size_bytes, scientific = FALSE, trim = TRUE),
      inventory$records$sha256,
      sep = "|", collapse = "\n"
    ),
    sep = "\n"
  ) |>
    enc2utf8() |>
    charToRaw() |>
    wlv13_sha256_raw()
}

wlv13_recheck_inventory <- function(inventory) {
  current <- wlv13_inventory(inventory$kind,
    if (identical(inventory$kind, "snapshot")) {
      inventory$manifest_path
    } else {
      inventory$root
    }
  )
  if (!identical(wlv13_inventory_signature(inventory),
      wlv13_inventory_signature(current))) {
    stop("Authenticated artifacts changed during comparison.", call. = FALSE)
  }
  invisible(current)
}

wlv13_create_snapshot <- function(root, paths, roles, snapshot_id, output) {
  root <- wlv13_normalize_existing_dir(root, "snapshot root")
  snapshot_id <- wlv13_id(snapshot_id, "snapshot_id")
  records <- wlv13_capture_records(root, paths, roles)
  artifacts <- lapply(seq_len(nrow(records)), function(index) {
    as.list(records[index, , drop = FALSE])
  })
  value <- list(
    schema = wlv13_schema$snapshot,
    snapshot_id = snapshot_id,
    root = root,
    created_at = wlv13_now(),
    artifacts = artifacts
  )
  wlv13_json_write(value, output)
  installed <- wlv13_snapshot_inventory(output)
  if (!identical(installed$records, records)) {
    stop("Installed snapshot differs from the captured artifact inventory.",
      call. = FALSE
    )
  }
  invisible(installed)
}

wlv13_git_value <- function(root, arguments, label) {
  value <- system2("git", c("-C", root, arguments), stdout = TRUE, stderr = TRUE)
  status <- attr(value, "status", exact = TRUE)
  if (!is.null(status) && status != 0L) {
    stop(sprintf("Cannot read %s: %s.", label, paste(value, collapse = " ")),
      call. = FALSE
    )
  }
  trimws(value)
}

wlv13_git_commit <- function(root) {
  value <- wlv13_git_value(root, c("rev-parse", "HEAD"), "Git commit")
  wlv13_scalar_text(value[[1L]], "Git commit", "^[0-9a-f]{40}$")
}

wlv13_git_runtime_clean <- function(root) {
  scope <- c(
    "R", "catalog", "config", "contracts", "methods", "parameters",
    "scripts/run_wlv.R", "renv.lock", "DESCRIPTION"
  )
  value <- system2(
    "git",
    c("-C", root, "status", "--porcelain=v1", "--untracked-files=all", "--", scope),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(value, "status", exact = TRUE)
  if (!is.null(status) && status != 0L) {
    stop("Cannot inspect candidate runtime Git status.", call. = FALSE)
  }
  !length(value)
}
