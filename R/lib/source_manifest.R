wlv_source_manifest_schema <- c(
  "schema_version",
  "source_generation_id",
  "contract_id",
  "contract_version",
  "contract_sha256",
  "artifact",
  "artifact_role",
  "size_bytes",
  "sha256"
)

wlv_source_provenance_schema <- c(
  "schema_version",
  "source",
  "source_generation_id",
  "contract_id",
  "contract_version",
  "contract_sha256",
  "manifest_sha256"
)

wlv_source_manifest_version <- "1"
wlv_source_provenance_filename <- "_source_provenance.csv"

wlv_source_sha256_raw <- function(value) {
  if (!is.raw(value)) {
    stop("SHA-256 input must be a raw vector.", call. = FALSE)
  }
  if (!requireNamespace("openssl", quietly = TRUE)) {
    stop(
      "Package `openssl` is required to verify source generations.",
      call. = FALSE
    )
  }
  paste0(
    tolower(as.character(openssl::sha256(value))),
    collapse = ""
  )
}

wlv_source_file_sha256 <- function(path) {
  if (
    !is.character(path) ||
    length(path) != 1L ||
    is.na(path) ||
    !nzchar(path) ||
    !file.exists(path) ||
    isTRUE(file.info(path)$isdir)
  ) {
    stop(sprintf("Cannot hash source file: %s", path), call. = FALSE)
  }
  if (!requireNamespace("openssl", quietly = TRUE)) {
    stop(
      "Package `openssl` is required to verify source generations.",
      call. = FALSE
    )
  }

  connection <- file(path, open = "rb")
  on.exit(close(connection), add = TRUE)
  paste0(
    tolower(as.character(openssl::sha256(connection))),
    collapse = ""
  )
}

wlv_source_validate_text <- function(value, label, allow_empty = FALSE) {
  if (
    !is.character(value) ||
    anyNA(value) ||
    (!allow_empty && any(!nzchar(value))) ||
    any(is.na(iconv(value, from = "UTF-8", to = "UTF-8", sub = NA))) ||
    any(grepl("[\r\n\t]", value))
  ) {
    stop(sprintf("`%s` must contain valid single-line UTF-8 text.", label), call. = FALSE)
  }
  invisible(value)
}

wlv_source_length_prefix <- function(value) {
  value <- enc2utf8(as.character(value))
  paste0(nchar(value, type = "bytes"), ":", value)
}

wlv_source_table_payload <- function(value, columns, domain) {
  if (!is.data.frame(value) || !identical(names(value), columns)) {
    stop(sprintf("Invalid %s table schema.", domain), call. = FALSE)
  }
  if (any(!vapply(value, is.character, logical(1)))) {
    stop(sprintf("Every %s field must be character data.", domain), call. = FALSE)
  }

  flattened <- unlist(value[columns], use.names = FALSE)
  wlv_source_validate_text(flattened, domain, allow_empty = TRUE)
  fields <- c(
    domain,
    as.character(length(columns)),
    columns,
    as.character(nrow(value)),
    unlist(
      lapply(seq_len(nrow(value)), function(index) {
        as.character(value[index, columns, drop = TRUE])
      }),
      use.names = FALSE
    )
  )
  charToRaw(enc2utf8(paste0(wlv_source_length_prefix(fields), collapse = "")))
}

wlv_source_normalize_artifacts <- function(artifacts) {
  wlv_source_validate_text(artifacts, "artifacts")
  artifacts <- chartr("\\", "/", artifacts)
  invalid <-
    grepl("^(/|[A-Za-z]:/|//)", artifacts) |
    grepl("(^|/)[.][.](/|$)", artifacts) |
    grepl("(^|/)[.](/|$)", artifacts) |
    grepl("//", artifacts, fixed = TRUE) |
    grepl("/$", artifacts)
  if (any(invalid)) {
    stop(
      sprintf(
        "Source artifact paths must be normalized relative paths: %s.",
        paste(unique(artifacts[invalid]), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  artifacts
}

wlv_source_resolve_artifacts <- function(source_root, artifacts) {
  if (
    !is.character(source_root) ||
    length(source_root) != 1L ||
    is.na(source_root) ||
    !dir.exists(source_root)
  ) {
    stop("`source_root` must be an existing directory.", call. = FALSE)
  }
  artifacts <- wlv_source_normalize_artifacts(artifacts)
  root <- normalizePath(source_root, winslash = "/", mustWork = TRUE)
  paths <- file.path(root, artifacts)
  missing <- !file.exists(paths) | file.info(paths)$isdir %in% TRUE
  if (any(missing)) {
    stop(
      sprintf(
        "Source artifact files are missing: %s.",
        paste(artifacts[missing], collapse = ", ")
      ),
      call. = FALSE
    )
  }

  resolved <- normalizePath(paths, winslash = "/", mustWork = TRUE)
  comparison_root <- root
  comparison_resolved <- resolved
  if (.Platform$OS.type == "windows") {
    comparison_root <- tolower(comparison_root)
    comparison_resolved <- tolower(comparison_resolved)
  }
  inside <- startsWith(comparison_resolved, paste0(comparison_root, "/"))
  if (any(!inside)) {
    stop(
      sprintf(
        "Source artifacts must resolve inside `source_root`: %s.",
        paste(artifacts[!inside], collapse = ", ")
      ),
      call. = FALSE
    )
  }
  resolved
}

wlv_source_file_record <- function(path) {
  before <- unname(file.info(path)$size)
  hash <- wlv_source_file_sha256(path)
  after <- unname(file.info(path)$size)
  if (
    is.na(before) ||
    is.na(after) ||
    !identical(before, after)
  ) {
    stop(
      sprintf("Source artifact changed while it was being hashed: %s.", basename(path)),
      call. = FALSE
    )
  }
  list(
    size_bytes = format(before, scientific = FALSE, trim = TRUE),
    sha256 = hash
  )
}

wlv_source_manifest_generation_id <- function(manifest) {
  if (!is.data.frame(manifest) || !identical(names(manifest), wlv_source_manifest_schema)) {
    stop("Invalid source manifest schema.", call. = FALSE)
  }
  payload <- manifest[setdiff(
    wlv_source_manifest_schema,
    "source_generation_id"
  )]
  wlv_source_sha256_raw(wlv_source_table_payload(
    payload,
    names(payload),
    "wlv-source-generation-v1"
  ))
}

wlv_source_manifest_sha256 <- function(manifest) {
  wlv_validate_source_manifest(manifest)
  wlv_source_sha256_raw(wlv_source_table_payload(
    manifest,
    wlv_source_manifest_schema,
    "wlv-source-manifest-v1"
  ))
}

wlv_validate_source_manifest <- function(manifest) {
  if (!is.data.frame(manifest) || !identical(names(manifest), wlv_source_manifest_schema)) {
    stop(
      sprintf(
        "Source manifest must have exactly these columns: %s.",
        paste(wlv_source_manifest_schema, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (!nrow(manifest) || any(!vapply(manifest, is.character, logical(1)))) {
    stop("Source manifest must contain character rows.", call. = FALSE)
  }
  wlv_source_validate_text(
    unlist(manifest, use.names = FALSE),
    "source manifest"
  )
  if (any(manifest$schema_version != wlv_source_manifest_version)) {
    stop("Unsupported source manifest schema version.", call. = FALSE)
  }

  global_fields <- c(
    "source_generation_id", "contract_id", "contract_version", "contract_sha256"
  )
  if (any(vapply(manifest[global_fields], function(value) length(unique(value)) != 1L, logical(1)))) {
    stop("Source manifest identity fields must be identical on every row.", call. = FALSE)
  }
  if (
    !grepl("^[0-9a-f]{64}$", manifest$source_generation_id[[1L]]) ||
    !grepl("^[0-9a-f]{64}$", manifest$contract_sha256[[1L]]) ||
    any(!grepl("^[0-9a-f]{64}$", manifest$sha256))
  ) {
    stop("Source manifest SHA-256 fields must be lowercase hexadecimal strings.", call. = FALSE)
  }
  if (any(!grepl("^(0|[1-9][0-9]*)$", manifest$size_bytes))) {
    stop("Source manifest sizes must be canonical non-negative integers.", call. = FALSE)
  }

  normalized <- wlv_source_normalize_artifacts(manifest$artifact)
  if (!identical(normalized, manifest$artifact) || anyDuplicated(manifest$artifact)) {
    stop("Source manifest artifact paths must be unique and normalized.", call. = FALSE)
  }
  canonical_order <- order(manifest$artifact, method = "radix")
  if (!identical(canonical_order, seq_len(nrow(manifest)))) {
    stop("Source manifest artifacts must be in canonical path order.", call. = FALSE)
  }
  wlv_source_validate_text(manifest$artifact_role, "artifact_role")

  expected_generation <- wlv_source_manifest_generation_id(manifest)
  if (!identical(manifest$source_generation_id[[1L]], expected_generation)) {
    stop("Source manifest generation ID does not match its contents.", call. = FALSE)
  }
  invisible(manifest)
}

wlv_build_source_manifest <- function(
    source_root,
    artifacts,
    artifact_roles,
    contract_path,
    contract_id,
    contract_version) {
  artifacts <- wlv_source_normalize_artifacts(artifacts)
  wlv_source_validate_text(artifact_roles, "artifact_roles")
  wlv_source_validate_text(contract_id, "contract_id")
  wlv_source_validate_text(contract_version, "contract_version")
  if (
    !length(artifacts) ||
    length(artifacts) != length(artifact_roles) ||
    anyDuplicated(artifacts)
  ) {
    stop(
      "Artifacts and roles must be unique, non-empty vectors of equal length.",
      call. = FALSE
    )
  }
  if (length(contract_id) != 1L || length(contract_version) != 1L) {
    stop("Contract ID and version must each be one value.", call. = FALSE)
  }
  if (
    !is.character(contract_path) ||
    length(contract_path) != 1L ||
    is.na(contract_path) ||
    !file.exists(contract_path) ||
    isTRUE(file.info(contract_path)$isdir)
  ) {
    stop("`contract_path` must identify an existing contract file.", call. = FALSE)
  }

  paths <- wlv_source_resolve_artifacts(source_root, artifacts)
  records <- lapply(paths, wlv_source_file_record)
  order_index <- order(artifacts, method = "radix")
  manifest <- data.frame(
    schema_version = rep(wlv_source_manifest_version, length(artifacts)),
    source_generation_id = rep("", length(artifacts)),
    contract_id = rep(contract_id, length(artifacts)),
    contract_version = rep(contract_version, length(artifacts)),
    contract_sha256 = rep(wlv_source_file_sha256(contract_path), length(artifacts)),
    artifact = artifacts,
    artifact_role = artifact_roles,
    size_bytes = vapply(records, `[[`, character(1), "size_bytes"),
    sha256 = vapply(records, `[[`, character(1), "sha256"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  manifest <- manifest[order_index, wlv_source_manifest_schema, drop = FALSE]
  rownames(manifest) <- NULL
  manifest$source_generation_id <- rep(
    wlv_source_manifest_generation_id(manifest),
    nrow(manifest)
  )
  wlv_validate_source_manifest(manifest)
  manifest
}

wlv_source_read_csv <- function(path, schema, label) {
  if (
    !is.character(path) ||
    length(path) != 1L ||
    is.na(path) ||
    !file.exists(path) ||
    isTRUE(file.info(path)$isdir)
  ) {
    stop(sprintf("%s file is missing: %s.", label, path), call. = FALSE)
  }
  bytes <- readBin(path, what = "raw", n = file.info(path)$size)
  decoded <- tryCatch(rawToChar(bytes), error = function(error) NA_character_)
  if (
    is.na(decoded) ||
    is.na(iconv(decoded, from = "UTF-8", to = "UTF-8", sub = NA))
  ) {
    stop(sprintf("%s is not valid UTF-8.", label), call. = FALSE)
  }

  value <- tryCatch(
    utils::read.csv(
      path,
      stringsAsFactors = FALSE,
      colClasses = "character",
      check.names = FALSE,
      na.strings = character(),
      comment.char = "",
      fileEncoding = "UTF-8"
    ),
    error = function(error) {
      stop(sprintf("Cannot parse %s: %s", label, conditionMessage(error)), call. = FALSE)
    }
  )
  if (!identical(names(value), schema)) {
    stop(
      sprintf(
        "%s must have exactly these columns: %s.",
        label,
        paste(schema, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  rownames(value) <- NULL
  value
}

wlv_read_source_manifest <- function(path) {
  manifest <- wlv_source_read_csv(path, wlv_source_manifest_schema, "Source manifest")
  wlv_validate_source_manifest(manifest)
  manifest
}

wlv_source_tables_identical <- function(left, right) {
  identical(names(left), names(right)) &&
    identical(dim(left), dim(right)) &&
    all(vapply(names(left), function(column) {
      identical(enc2utf8(left[[column]]), enc2utf8(right[[column]]))
    }, logical(1)))
}

wlv_source_write_csv <- function(value, path, reader, label) {
  if (
    !is.character(path) ||
    length(path) != 1L ||
    is.na(path) ||
    !nzchar(path) ||
    !dir.exists(dirname(path))
  ) {
    stop(sprintf("Invalid %s destination: %s.", label, path), call. = FALSE)
  }
  temporary <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(unlink(temporary, force = TRUE), add = TRUE)
  utils::write.table(
    value,
    temporary,
    sep = ",",
    row.names = FALSE,
    col.names = TRUE,
    quote = TRUE,
    qmethod = "double",
    eol = "\n",
    fileEncoding = "UTF-8"
  )
  roundtrip <- reader(temporary)
  if (!wlv_source_tables_identical(value, roundtrip)) {
    stop(sprintf("%s failed exact UTF-8 round-trip verification.", label), call. = FALSE)
  }
  if (!file.copy(temporary, path, overwrite = TRUE, copy.mode = TRUE)) {
    stop(sprintf("Could not write %s: %s.", label, path), call. = FALSE)
  }
  installed <- reader(path)
  if (!wlv_source_tables_identical(value, installed)) {
    stop(sprintf("Installed %s differs from its verified payload.", label), call. = FALSE)
  }
  invisible(path)
}

wlv_write_source_manifest <- function(manifest, path) {
  wlv_validate_source_manifest(manifest)
  wlv_source_write_csv(manifest, path, wlv_read_source_manifest, "source manifest")
}

wlv_source_as_manifest <- function(manifest) {
  if (is.character(manifest) && length(manifest) == 1L && !is.na(manifest)) {
    return(wlv_read_source_manifest(manifest))
  }
  wlv_validate_source_manifest(manifest)
  manifest
}

wlv_verify_source_manifest <- function(
    manifest,
    source_root,
    contract_path,
    expected_contract_id = NULL,
    expected_contract_version = NULL) {
  manifest <- wlv_source_as_manifest(manifest)
  if (!is.null(expected_contract_id)) {
    wlv_source_validate_text(expected_contract_id, "expected_contract_id")
    if (
      length(expected_contract_id) != 1L ||
      !identical(manifest$contract_id[[1L]], expected_contract_id)
    ) {
      stop("Source manifest contract ID differs from the configured contract.", call. = FALSE)
    }
  }
  if (!is.null(expected_contract_version)) {
    wlv_source_validate_text(expected_contract_version, "expected_contract_version")
    if (
      length(expected_contract_version) != 1L ||
      !identical(manifest$contract_version[[1L]], expected_contract_version)
    ) {
      stop("Source manifest contract version differs from the configured contract.", call. = FALSE)
    }
  }
  if (
    !is.character(contract_path) ||
    length(contract_path) != 1L ||
    is.na(contract_path) ||
    !file.exists(contract_path) ||
    isTRUE(file.info(contract_path)$isdir)
  ) {
    stop("Configured source contract file is missing.", call. = FALSE)
  }
  actual_contract_hash <- wlv_source_file_sha256(contract_path)
  if (!identical(manifest$contract_sha256[[1L]], actual_contract_hash)) {
    stop("Contract SHA-256 mismatch for the source generation.", call. = FALSE)
  }

  paths <- wlv_source_resolve_artifacts(source_root, manifest$artifact)
  for (index in seq_along(paths)) {
    record <- wlv_source_file_record(paths[[index]])
    if (!identical(record$size_bytes, manifest$size_bytes[[index]])) {
      stop(
        sprintf("Size mismatch for source artifact `%s`.", manifest$artifact[[index]]),
        call. = FALSE
      )
    }
    if (!identical(record$sha256, manifest$sha256[[index]])) {
      stop(
        sprintf("SHA-256 mismatch for source artifact `%s`.", manifest$artifact[[index]]),
        call. = FALSE
      )
    }
  }
  invisible(manifest)
}

wlv_source_provenance <- function(manifest, source) {
  manifest <- wlv_source_as_manifest(manifest)
  wlv_source_validate_text(source, "source")
  if (length(source) != 1L) {
    stop("`source` must be one value.", call. = FALSE)
  }
  data.frame(
    schema_version = wlv_source_manifest_version,
    source = source,
    source_generation_id = manifest$source_generation_id[[1L]],
    contract_id = manifest$contract_id[[1L]],
    contract_version = manifest$contract_version[[1L]],
    contract_sha256 = manifest$contract_sha256[[1L]],
    manifest_sha256 = wlv_source_manifest_sha256(manifest),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

wlv_validate_source_provenance <- function(provenance) {
  if (
    !is.data.frame(provenance) ||
    !identical(names(provenance), wlv_source_provenance_schema) ||
    nrow(provenance) != 1L ||
    any(!vapply(provenance, is.character, logical(1)))
  ) {
    stop(
      sprintf(
        "Source provenance must contain one row with exactly these columns: %s.",
        paste(wlv_source_provenance_schema, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  wlv_source_validate_text(unlist(provenance, use.names = FALSE), "source provenance")
  if (!identical(provenance$schema_version, wlv_source_manifest_version)) {
    stop("Unsupported source provenance schema version.", call. = FALSE)
  }
  hashes <- provenance[c(
    "source_generation_id", "contract_sha256", "manifest_sha256"
  )]
  if (any(!vapply(hashes, function(value) grepl("^[0-9a-f]{64}$", value), logical(1)))) {
    stop("Source provenance SHA-256 fields must be lowercase hexadecimal strings.", call. = FALSE)
  }
  invisible(provenance)
}

wlv_read_source_provenance <- function(path) {
  provenance <- wlv_source_read_csv(
    path,
    wlv_source_provenance_schema,
    "Source provenance"
  )
  wlv_validate_source_provenance(provenance)
  provenance
}

wlv_read_result_source_provenance <- function(result_dir) {
  wlv_read_source_provenance(
    file.path(result_dir, wlv_source_provenance_filename)
  )
}

wlv_write_result_source_provenance <- function(result_dir, source, manifest) {
  if (!dir.exists(result_dir)) {
    stop("Result directory must exist before provenance is written.", call. = FALSE)
  }
  provenance <- wlv_source_provenance(manifest, source)
  wlv_validate_source_provenance(provenance)
  path <- file.path(result_dir, wlv_source_provenance_filename)
  wlv_source_write_csv(
    provenance,
    path,
    wlv_read_source_provenance,
    "source provenance"
  )
}

wlv_assert_recalculation_source_provenance <- function(
    result_dir,
    current_manifest,
    source) {
  provenance_path <- file.path(result_dir, wlv_source_provenance_filename)
  if (!file.exists(provenance_path)) {
    stop(
      paste0(
        "Recalculation is blocked: this legacy result has no source-provenance ",
        "sidecar. Run a full calculation with the current source generation."
      ),
      call. = FALSE
    )
  }
  previous <- wlv_read_result_source_provenance(result_dir)
  current <- wlv_source_provenance(current_manifest, source)
  if (!identical(previous$source, current$source)) {
    stop(
      "Recalculation is blocked because the result belongs to a different source.",
      call. = FALSE
    )
  }

  contract_fields <- c("contract_id", "contract_version", "contract_sha256")
  contract_matches <- vapply(contract_fields, function(field) {
    identical(previous[[field]], current[[field]])
  }, logical(1))
  if (any(!contract_matches)) {
    stop(
      paste0(
        "Recalculation is blocked because the source unit contract differs from ",
        "the result snapshot. Run a full calculation."
      ),
      call. = FALSE
    )
  }
  if (!identical(previous$source_generation_id, current$source_generation_id)) {
    stop(
      paste0(
        "Recalculation is blocked because the source generation differs from ",
        "the result snapshot. Run a full calculation."
      ),
      call. = FALSE
    )
  }
  if (!identical(previous$manifest_sha256, current$manifest_sha256)) {
    stop(
      "Recalculation is blocked because the source manifest snapshot differs.",
      call. = FALSE
    )
  }
  invisible(current)
}
