# Shared, external evidence helpers for issue #13 preparation and paper gates.
# This file deliberately lives under run_logs/ and is not part of either
# baseline or candidate runtime.

wlv_gate_scalar_character <- function(value, name) {
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !nzchar(value)) {
    stop(sprintf("`%s` must be one non-empty string.", name), call. = FALSE)
  }
  value
}

wlv_gate_use_library <- function(path = Sys.getenv(
    "WLV_ISSUE13_R_LIBRARY", unset = "")) {
  if (!nzchar(path)) {
    return(invisible(.libPaths()))
  }
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  .libPaths(unique(c(path, .libPaths())))
  invisible(.libPaths())
}

wlv_gate_require_namespaces <- function(packages) {
  missing <- packages[!vapply(
    packages,
    requireNamespace,
    logical(1L),
    quietly = TRUE
  )]
  if (length(missing)) {
    stop(
      sprintf("Missing gate package(s): %s.", paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
  invisible(packages)
}

wlv_gate_normalize_path <- function(path, name, must_work = TRUE) {
  path <- wlv_gate_scalar_character(path, name)
  normalizePath(path, winslash = "/", mustWork = must_work)
}

wlv_gate_path_within <- function(path, parent) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  parent <- normalizePath(parent, winslash = "/", mustWork = TRUE)
  if (.Platform$OS.type == "windows") {
    path <- tolower(path)
    parent <- tolower(parent)
  }
  identical(path, parent) || startsWith(path, paste0(sub("/+$", "", parent), "/"))
}

wlv_gate_git_commit <- function(root) {
  value <- system2(
    "git",
    c("-C", shQuote(root), "rev-parse", "HEAD"),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(value, "status", exact = TRUE)
  if (!is.null(status) && !identical(status, 0L)) {
    stop(sprintf("Cannot read Git commit for `%s`.", root), call. = FALSE)
  }
  trimws(value[[1L]])
}

wlv_gate_assert_commit <- function(root, expected) {
  expected <- wlv_gate_scalar_character(expected, "expected_commit")
  actual <- wlv_gate_git_commit(root)
  if (!identical(actual, expected)) {
    stop(
      sprintf("Commit mismatch for `%s`: expected %s, found %s.",
        root, expected, actual),
      call. = FALSE
    )
  }
  actual
}

wlv_gate_git_status <- function(root) {
  value <- system2(
    "git",
    c("-C", shQuote(root), "status", "--porcelain=v1", "--untracked-files=no"),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(value, "status", exact = TRUE)
  if (!is.null(status) && !identical(status, 0L)) {
    stop(sprintf("Cannot read Git status for `%s`.", root), call. = FALSE)
  }
  enc2utf8(value)
}

wlv_gate_sha256 <- function(path) {
  if (!file.exists(path) || isTRUE(file.info(path)$isdir)) {
    stop(sprintf("Cannot hash missing regular file `%s`.", path), call. = FALSE)
  }
  connection <- file(path, open = "rb")
  on.exit(close(connection), add = TRUE)
  value <- openssl::sha256(connection)
  tolower(sprintf("%s", value))
}

wlv_gate_json_payload <- function(value) {
  json <- jsonlite::toJSON(
    value,
    auto_unbox = TRUE,
    pretty = TRUE,
    digits = NA,
    null = "null",
    na = "null"
  )
  charToRaw(enc2utf8(paste0(json, "\n")))
}

wlv_gate_json_sha256 <- function(value) {
  tolower(sprintf("%s", openssl::sha256(wlv_gate_json_payload(value))))
}

wlv_gate_claim_empty_directory <- function(path, name = "report directory") {
  path <- wlv_gate_scalar_character(path, name)
  if (file.exists(path) && !dir.exists(path)) {
    stop(sprintf("%s is not a directory: `%s`.", name, path), call. = FALSE)
  }
  if (!dir.create(path, recursive = TRUE, showWarnings = FALSE) &&
      !dir.exists(path)) {
    stop(sprintf("Cannot create %s `%s`.", name, path), call. = FALSE)
  }
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  entries <- list.files(path,
    all.files = TRUE,
    no.. = TRUE,
    full.names = FALSE
  )
  if (length(entries)) {
    stop(sprintf(
      "%s is not empty; refusing to resume or overwrite: %s.",
      name,
      paste(sort(entries, method = "radix"), collapse = ", ")
    ), call. = FALSE)
  }
  path
}

wlv_gate_write_json <- function(value, path) {
  directory <- dirname(path)
  if (!dir.create(directory, recursive = TRUE, showWarnings = FALSE) &&
      !dir.exists(directory)) {
    stop(sprintf("Cannot create report directory `%s`.", directory), call. = FALSE)
  }
  directory <- normalizePath(directory, winslash = "/", mustWork = TRUE)
  path <- file.path(directory, basename(path))
  if (file.exists(path) || dir.exists(path)) {
    stop(sprintf("Refusing to overwrite report `%s`.", path), call. = FALSE)
  }
  temporary <- tempfile(
    pattern = paste0(".", basename(path), "-"),
    tmpdir = directory,
    fileext = ".tmp"
  )
  on.exit(if (file.exists(temporary)) unlink(temporary, force = TRUE), add = TRUE)
  payload <- wlv_gate_json_payload(value)
  connection <- file(temporary, open = "wb")
  tryCatch(
    writeBin(payload, connection),
    finally = close(connection)
  )
  roundtrip_raw <- readBin(temporary, what = "raw", n = file.info(temporary)$size)
  if (!identical(roundtrip_raw, payload)) {
    stop("UTF-8 JSON round-trip verification failed.", call. = FALSE)
  }
  invisible(jsonlite::fromJSON(rawToChar(roundtrip_raw), simplifyVector = FALSE))
  if (file.exists(path) || dir.exists(path) ||
      !file.rename(temporary, path)) {
    stop(sprintf("Cannot atomically install report `%s`.", path), call. = FALSE)
  }
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  installed_raw <- readBin(path, what = "raw", n = file.info(path)$size)
  if (!identical(installed_raw, payload)) {
    stop("Installed JSON failed UTF-8 round-trip verification.", call. = FALSE)
  }
  invisible(jsonlite::fromJSON(rawToChar(installed_raw), simplifyVector = FALSE))
  path
}

wlv_gate_read_utf8_text <- function(path) {
  size <- file.info(path)$size
  raw <- readBin(path, what = "raw", n = size)
  value <- tryCatch(
    iconv(rawToChar(raw), from = "UTF-8", to = "UTF-8", sub = NA_character_),
    error = function(error) NA_character_
  )
  if (length(value) != 1L || is.na(value) || grepl("\ufffd", value, fixed = TRUE)) {
    stop(sprintf("File is not strict UTF-8: `%s`.", path), call. = FALSE)
  }
  value
}

wlv_gate_read_character_csv <- function(path) {
  text <- wlv_gate_read_utf8_text(path)
  separator <- if (identical(basename(path), "_source_manifest.csv")) "," else ";"
  connection <- textConnection(text, open = "r", local = TRUE)
  on.exit(close(connection), add = TRUE)
  utils::read.table(
    connection,
    header = TRUE,
    sep = separator,
    quote = "\"",
    comment.char = "",
    colClasses = "character",
    na.strings = NULL,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

wlv_gate_data_frame_identical <- function(left, right) {
  identical(class(left), class(right)) &&
    identical(names(left), names(right)) &&
    identical(row.names(left), row.names(right)) &&
    identical(vapply(left, typeof, character(1L)),
      vapply(right, typeof, character(1L))) &&
    identical(left, right)
}

wlv_gate_compare_csv <- function(left_path, right_path, artifact) {
  left <- wlv_gate_read_character_csv(left_path)
  right <- wlv_gate_read_character_csv(right_path)
  passed <- wlv_gate_data_frame_identical(left, right)
  list(
    artifact = artifact,
    kind = "csv",
    passed = passed,
    rows = nrow(left),
    columns = names(left),
    baseline_sha256 = wlv_gate_sha256(left_path),
    candidate_sha256 = wlv_gate_sha256(right_path),
    schema_identical = identical(names(left), names(right)),
    cells_identical = identical(left, right)
  )
}

wlv_gate_fst_sidecar <- function(path) {
  metadata_path <- paste0(path, ".meta")
  if (!file.exists(metadata_path)) {
    stop(sprintf("Missing FST sidecar `%s`.", metadata_path), call. = FALSE)
  }
  metadata <- readRDS(metadata_path)
  if (!is.list(metadata) || !length(metadata) ||
      !identical(names(metadata)[[1L]], "dim")) {
    stop(sprintf("Invalid FST sidecar `%s`.", metadata_path), call. = FALSE)
  }
  dimensions <- metadata[[1L]]
  if (!is.numeric(dimensions) || !length(dimensions) || anyNA(dimensions) ||
      any(!is.finite(dimensions)) || any(dimensions < 0) ||
      any(dimensions != floor(dimensions)) ||
      any(dimensions > .Machine$integer.max)) {
    stop(sprintf("Invalid dimensions in `%s`.", metadata_path), call. = FALSE)
  }
  dimensions <- as.integer(dimensions)
  expected_length <- prod(as.double(dimensions))
  if (!is.finite(expected_length)) {
    stop(sprintf("Dimensions are too large in `%s`.", metadata_path),
      call. = FALSE)
  }

  validate_dimnames <- function(value) {
    if (is.null(value)) return(NULL)
    if (!is.list(value) || length(value) != length(dimensions)) {
      stop(sprintf("Invalid dimnames in `%s`.", metadata_path), call. = FALSE)
    }
    valid <- vapply(seq_along(dimensions), function(index) {
      labels <- value[[index]]
      is.null(labels) || (is.character(labels) &&
        length(labels) == dimensions[[index]] && !anyNA(labels) &&
        !anyDuplicated(labels))
    }, logical(1L))
    if (!all(valid)) {
      stop(sprintf("Invalid dimnames in `%s`.", metadata_path), call. = FALSE)
    }
    value
  }

  legacy_field_count <- length(dimensions) + 1L
  legacy <- length(metadata) <= legacy_field_count
  if (legacy) {
    available <- min(length(dimensions), max(0L, length(metadata) - 1L))
    array_dimnames <- if (!available) NULL else {
      value <- rep(list(NULL), length(dimensions))
      value[seq_len(available)] <- metadata[seq.int(2L,
        length.out = available)]
      names(value) <- NULL
      value
    }
    array_dimnames <- validate_dimnames(array_dimnames)
    fst_sha256 <- NULL
    schema_version <- NULL
  } else {
    extra <- metadata[seq.int(legacy_field_count + 1L, length(metadata))]
    expected_fields <- c("schema_version", "fst_sha256", "array_dimnames")
    if (!identical(names(extra), expected_fields) ||
        !identical(extra[[1L]], "1") ||
        !is.character(extra[[2L]]) || length(extra[[2L]]) != 1L ||
        is.na(extra[[2L]]) ||
        !grepl("^[0-9a-f]{64}$", extra[[2L]])) {
      stop(sprintf("Invalid versioned FST sidecar `%s`.", metadata_path),
        call. = FALSE)
    }
    schema_version <- extra[[1L]]
    fst_sha256 <- extra[[2L]]
    array_dimnames <- validate_dimnames(extra[[3L]])
  }
  list(
    raw = metadata,
    dimensions = dimensions,
    dimnames = array_dimnames,
    expected_length = expected_length,
    fst_sha256 = fst_sha256,
    schema_version = schema_version,
    legacy = legacy
  )
}

wlv_gate_raw_double_mismatch <- function(left, right, limit = 20L) {
  left_raw <- writeBin(as.double(left), raw(), size = 8L, endian = "little")
  right_raw <- writeBin(as.double(right), raw(), size = 8L, endian = "little")
  if (identical(left_raw, right_raw)) {
    return(integer())
  }
  changed_bytes <- which(left_raw != right_raw)
  unique(head(((changed_bytes - 1L) %/% 8L) + 1L, limit))
}

wlv_gate_value_label <- function(value) {
  if (is.nan(value)) return("NaN")
  if (is.na(value)) return("NA")
  if (is.infinite(value)) return(if (value > 0) "Inf" else "-Inf")
  sprintf("%.17g", value)
}

wlv_gate_compare_fst_array <- function(
    left_path,
    right_path,
    artifact,
    chunk_rows = 1000000L) {
  chunk_rows <- as.integer(chunk_rows)
  if (length(chunk_rows) != 1L || is.na(chunk_rows) || chunk_rows < 1L) {
    stop("`chunk_rows` must be a positive integer.", call. = FALSE)
  }
  left_contract <- wlv_gate_fst_sidecar(left_path)
  right_contract <- wlv_gate_fst_sidecar(right_path)
  left_metadata <- fst::metadata_fst(left_path)
  right_metadata <- fst::metadata_fst(right_path)
  expected_length <- prod(as.double(left_contract$dimensions))
  shape_passed <- identical(left_contract$dimensions, right_contract$dimensions) &&
    identical(left_contract$dimnames, right_contract$dimnames) &&
    identical(left_metadata$columnNames, right_metadata$columnNames) &&
    identical(left_metadata$columnBaseTypes, right_metadata$columnBaseTypes) &&
    identical(left_metadata$columnTypes, right_metadata$columnTypes) &&
    identical(as.double(left_metadata$nrOfRows), expected_length) &&
    identical(as.double(right_metadata$nrOfRows), expected_length)
  mismatch_indices <- numeric()
  compared <- 0
  values_passed <- shape_passed
  if (shape_passed && expected_length > 0) {
    starts <- seq.int(1, expected_length, by = chunk_rows)
    for (start in starts) {
      end <- min(expected_length, start + chunk_rows - 1)
      left <- fst::read_fst(
        left_path,
        from = start,
        to = end,
        as.data.table = FALSE
      )[[1L]]
      right <- fst::read_fst(
        right_path,
        from = start,
        to = end,
        as.data.table = FALSE
      )[[1L]]
      if (!identical(typeof(left), typeof(right))) {
        values_passed <- FALSE
        mismatch_indices <- start
        break
      }
      compared <- compared + length(left)
      local_mismatch <- wlv_gate_raw_double_mismatch(left, right)
      if (length(local_mismatch)) {
        mismatch_indices <- c(mismatch_indices, start - 1 + local_mismatch)
        values_passed <- FALSE
        break
      }
    }
  }
  mismatch_details <- lapply(head(mismatch_indices, 20L), function(index) {
    left <- fst::read_fst(
      left_path, from = index, to = index, as.data.table = FALSE
    )[[1L]][[1L]]
    right <- fst::read_fst(
      right_path, from = index, to = index, as.data.table = FALSE
    )[[1L]][[1L]]
    list(
      flattened_index = index,
      baseline = wlv_gate_value_label(left),
      candidate = wlv_gate_value_label(right),
      baseline_is_na = is.na(left) && !is.nan(left),
      candidate_is_na = is.na(right) && !is.nan(right),
      baseline_is_nan = is.nan(left),
      candidate_is_nan = is.nan(right)
    )
  })
  left_sha <- wlv_gate_sha256(left_path)
  right_sha <- wlv_gate_sha256(right_path)
  left_internal_hash_ok <- is.null(left_contract$fst_sha256) ||
    identical(left_contract$fst_sha256, left_sha)
  right_internal_hash_ok <- is.null(right_contract$fst_sha256) ||
    identical(right_contract$fst_sha256, right_sha)
  passed <- shape_passed && values_passed && left_internal_hash_ok &&
    right_internal_hash_ok
  list(
    artifact = artifact,
    kind = "fst_array",
    passed = passed,
    dimensions = unname(left_contract$dimensions),
    dimension_names_identical = identical(
      left_contract$dimnames,
      right_contract$dimnames
    ),
    fst_column_schema_identical = identical(
      left_metadata[c("columnNames", "columnBaseTypes", "columnTypes")],
      right_metadata[c("columnNames", "columnBaseTypes", "columnTypes")]
    ),
    flattened_values = expected_length,
    compared_values = compared,
    bitwise_values_identical = values_passed,
    first_mismatches = mismatch_details,
    baseline_sha256 = left_sha,
    candidate_sha256 = right_sha,
    baseline_sidecar_sha256 = wlv_gate_sha256(paste0(left_path, ".meta")),
    candidate_sidecar_sha256 = wlv_gate_sha256(paste0(right_path, ".meta")),
    baseline_internal_hash_ok = left_internal_hash_ok,
    candidate_internal_hash_ok = right_internal_hash_ok,
    sidecars_semantically_identical = identical(
      left_contract$raw,
      right_contract$raw
    )
  )
}

wlv_gate_compare_rds <- function(left_path, right_path, artifact) {
  left <- readRDS(left_path)
  right <- readRDS(right_path)
  list(
    artifact = artifact,
    kind = "rds",
    passed = identical(left, right),
    class = class(left),
    structure_identical = identical(typeof(left), typeof(right)) &&
      identical(length(left), length(right)) &&
      identical(attributes(left), attributes(right)),
    object_identical = identical(left, right),
    baseline_sha256 = wlv_gate_sha256(left_path),
    candidate_sha256 = wlv_gate_sha256(right_path)
  )
}

wlv_gate_compare_fst_table <- function(left_path, right_path, artifact) {
  left_metadata <- fst::metadata_fst(left_path)
  right_metadata <- fst::metadata_fst(right_path)
  schema_passed <- identical(left_metadata$columnNames, right_metadata$columnNames) &&
    identical(left_metadata$columnBaseTypes, right_metadata$columnBaseTypes) &&
    identical(left_metadata$columnTypes, right_metadata$columnTypes) &&
    identical(left_metadata$nrOfRows, right_metadata$nrOfRows)
  left <- fst::read_fst(left_path, as.data.table = FALSE)
  right <- fst::read_fst(right_path, as.data.table = FALSE)
  passed <- schema_passed && wlv_gate_data_frame_identical(left, right)
  list(
    artifact = artifact,
    kind = "fst_table",
    passed = passed,
    rows = nrow(left),
    columns = names(left),
    column_types = vapply(left, typeof, character(1L)),
    schema_identical = schema_passed,
    cells_identical = identical(left, right),
    baseline_sha256 = wlv_gate_sha256(left_path),
    candidate_sha256 = wlv_gate_sha256(right_path)
  )
}

wlv_gate_expected_raw_caches <- function() {
  data.frame(
    artifact = c(
      "source_data/wiodr13/WIOTS_in_MATLAB.zip",
      "source_data/wiodr13/Socio_Economic_Accounts_July14.xlsx",
      "source_data/wiodr16/WIOTS_in_R.zip",
      "source_data/wiodr16/Socio_Economic_Accounts.xlsx",
      "source_data/euklems/Statistical_Capital.rds",
      "source_data/euklems/Statistical_National-Accounts.rds"
    ),
    size_bytes = c(
      292278662,
      7831205,
      641578409,
      5536437,
      129637707,
      44200266
    ),
    sha256 = tolower(c(
      "1A5EE1F445AB27CD9927CF2F6D21A2D65EB8B4977B681F0FD8A252353D051AFE",
      "1CA319D414E9490FE4A868F79459C2B92E1994715C0D09C6AF807DA31FD8C36D",
      "30B17452273EA4AE94B6CB015AACB112BE3A8F8D27E0A0F35C1B5C584B60CE90",
      "8CF5ED3D1B7D7DDAE93037CC5E1C1D0A2721B9A7679DCC076B85AC5220C576CE",
      "77BF752A4C79C0E324E6BE31164E8F27FDC100C89B08F68C3A227DA7C7AB3B44",
      "C6F7B65EB263839EA824FE223A8CF5FC13FAD444DB5B7A857B6AA01B29D0A4F2"
    )),
    stringsAsFactors = FALSE
  )
}

wlv_gate_verify_raw_caches <- function(root) {
  expected <- wlv_gate_expected_raw_caches()
  records <- lapply(seq_len(nrow(expected)), function(index) {
    path <- file.path(root, expected$artifact[[index]])
    present <- file.exists(path) && !isTRUE(file.info(path)$isdir)
    actual_size <- if (present) as.double(file.info(path)$size) else NA_real_
    actual_hash <- if (present) wlv_gate_sha256(path) else NA_character_
    list(
      artifact = expected$artifact[[index]],
      present = present,
      expected_size_bytes = expected$size_bytes[[index]],
      actual_size_bytes = actual_size,
      expected_sha256 = expected$sha256[[index]],
      actual_sha256 = actual_hash,
      passed = present && identical(actual_size, expected$size_bytes[[index]]) &&
        identical(actual_hash, expected$sha256[[index]])
    )
  })
  list(
    passed = all(vapply(records, `[[`, logical(1L), "passed")),
    records = records
  )
}

wlv_gate_normalized_artifacts <- function() {
  c(
    "_gfcf_canonical.rds",
    "_normalization_contract.csv",
    "_source_manifest.csv",
    "_unit_contract.csv",
    "countries.csv",
    "demand.csv",
    "m_io.fst",
    "m_io.fst.meta",
    "sea.fst",
    "sea.fst.meta",
    "sectors.csv"
  )
}

wlv_gate_expected_euklems_artifacts <- function() {
  years <- 1995:2015
  c(
    "Statistical_Capital.rds",
    "Statistical_National-Accounts.rds",
    paste0("ekk_", years, ".fst"),
    paste0("ekdeprate_", years, ".fst")
  )
}

wlv_gate_regular_file_inventory <- function(path) {
  if (!dir.exists(path)) return(character())
  sort(list.files(
    path,
    all.files = TRUE,
    no.. = TRUE,
    recursive = TRUE,
    include.dirs = FALSE,
    full.names = FALSE
  ), method = "radix")
}

wlv_gate_directory_inventory <- function(path) {
  if (!dir.exists(path)) return(character())
  entries <- list.files(
    path,
    all.files = TRUE,
    no.. = TRUE,
    recursive = TRUE,
    include.dirs = TRUE,
    full.names = TRUE
  )
  entries <- entries[file.info(entries)$isdir %in% TRUE]
  root <- normalizePath(path, winslash = "/", mustWork = TRUE)
  normalized <- normalizePath(entries, winslash = "/", mustWork = TRUE)
  sort(sub(paste0("^", gsub("([][{}()+*^$|\\?.])", "\\\\\\1", root), "/"),
    "", normalized), method = "radix")
}

wlv_gate_assert_fresh_preparation_root <- function(root) {
  source_root <- file.path(root, "source_data")
  expected_files <- sort(wlv_gate_expected_raw_caches()$artifact, method = "radix")
  prefix <- "source_data/"
  expected_files <- substring(expected_files, nchar(prefix) + 1L)
  actual_files <- wlv_gate_regular_file_inventory(source_root)
  expected_directories <- c("euklems", "wiodr13", "wiodr16")
  actual_directories <- wlv_gate_directory_inventory(source_root)
  if (!identical(actual_files, expected_files) ||
      !identical(actual_directories, expected_directories)) {
    stop(
      paste0(
        "Preparation worktree is not a six-cache-only seed. Recreate it ",
        "instead of deleting evidence in place."
      ),
      call. = FALSE
    )
  }
  forbidden <- c(
    file.path(root, "source_data", "wiodr13", "normalized"),
    file.path(root, "source_data", "wiodr16", "normalized")
  )
  annual <- list.files(
    file.path(root, "source_data", "euklems"),
    pattern = "^(ekk|ekdeprate)_[0-9]{4}\\.fst$",
    full.names = TRUE
  )
  generated_labels <- unlist(lapply(c("wiodr13", "wiodr16"), function(source) {
    file.path(root, "source_data", source, c(
      "countries.csv", "demand.csv", "sectors.csv"
    ))
  }), use.names = FALSE)
  existing <- c(forbidden[dir.exists(forbidden)], annual, generated_labels[
    file.exists(generated_labels)
  ])
  if (length(existing)) {
    stop(
      sprintf(
        paste0(
          "Preparation worktree is not raw-cache-only. Recreate it instead ",
          "of deleting evidence in place; generated path(s): %s."
        ),
        paste(existing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

wlv_gate_preparation_inventory <- function(root) {
  sources <- lapply(c("wiodr13", "wiodr16"), function(source) {
    normalized <- file.path(root, "source_data", source, "normalized")
    files <- wlv_gate_regular_file_inventory(normalized)
    expected <- wlv_gate_normalized_artifacts()
    root_entries <- list.files(
      file.path(root, "source_data", source),
      all.files = TRUE,
      no.. = TRUE,
      recursive = FALSE,
      full.names = TRUE
    )
    root_files <- sort(basename(root_entries[
      !(file.info(root_entries)$isdir %in% TRUE)
    ]), method = "radix")
    expected_root <- sort(c(
      if (identical(source, "wiodr13")) {
        c("WIOTS_in_MATLAB.zip", "Socio_Economic_Accounts_July14.xlsx")
      } else {
        c("WIOTS_in_R.zip", "Socio_Economic_Accounts.xlsx")
      },
      "countries.csv", "demand.csv", "sectors.csv"
    ), method = "radix")
    root_directories <- wlv_gate_directory_inventory(file.path(
      root, "source_data", source
    ))
    list(
      source = source,
      normalized_files = files,
      expected_normalized_files = expected,
      root_files = root_files,
      expected_root_files = expected_root,
      root_directories = root_directories,
      expected_root_directories = "normalized",
      normalized_directories = wlv_gate_directory_inventory(normalized),
      passed = identical(files, expected) &&
        identical(root_files, expected_root) &&
        identical(root_directories, "normalized") &&
        !length(wlv_gate_directory_inventory(normalized))
    )
  })
  names(sources) <- c("wiodr13", "wiodr16")
  euklems_path <- file.path(root, "source_data", "euklems")
  euklems_files <- sort(list.files(
    euklems_path,
    all.files = TRUE,
    no.. = TRUE,
    recursive = FALSE,
    include.dirs = FALSE,
    full.names = FALSE
  ), method = "radix")
  expected_euklems <- sort(wlv_gate_expected_euklems_artifacts(), method = "radix")
  euklems_dirs <- wlv_gate_directory_inventory(euklems_path)
  euklems <- list(
    files = euklems_files,
    expected_files = expected_euklems,
    directories = euklems_dirs,
    passed = identical(euklems_files, expected_euklems) && !length(euklems_dirs)
  )
  list(
    passed = all(vapply(sources, `[[`, logical(1L), "passed")) &&
      isTRUE(euklems$passed),
    sources = sources,
    euklems = euklems
  )
}

wlv_gate_verify_source_manifest <- function(normalized_root) {
  path <- file.path(normalized_root, "_source_manifest.csv")
  manifest <- wlv_gate_read_character_csv(path)
  required <- c(
    "schema_version", "source_generation_id", "contract_id",
    "contract_version", "contract_sha256", "artifact", "artifact_role",
    "size_bytes", "sha256"
  )
  schema_ok <- identical(names(manifest), required)
  safe_artifacts <- schema_ok && nrow(manifest) > 0L &&
    !anyDuplicated(manifest$artifact) &&
    identical(manifest$artifact, sort(manifest$artifact, method = "radix")) &&
    all(basename(manifest$artifact) == manifest$artifact) &&
    all(!grepl("(^|/)\\.\\.(/|$)", manifest$artifact))
  records <- if (!schema_ok) list() else lapply(seq_len(nrow(manifest)), function(index) {
    artifact <- manifest$artifact[[index]]
    artifact_path <- file.path(normalized_root, artifact)
    present <- file.exists(artifact_path) && !isTRUE(file.info(artifact_path)$isdir)
    size <- if (present) format(
      file.info(artifact_path)$size,
      scientific = FALSE,
      trim = TRUE
    ) else NA_character_
    hash <- if (present) wlv_gate_sha256(artifact_path) else NA_character_
    list(
      artifact = artifact,
      present = present,
      size_bytes = size,
      expected_size_bytes = manifest$size_bytes[[index]],
      sha256 = hash,
      expected_sha256 = manifest$sha256[[index]],
      passed = present && identical(size, manifest$size_bytes[[index]]) &&
        identical(hash, manifest$sha256[[index]])
    )
  })
  common_identity <- schema_ok && nrow(manifest) > 0L && all(vapply(
    manifest[c(
      "schema_version", "source_generation_id", "contract_id",
      "contract_version", "contract_sha256"
    )],
    function(column) length(unique(column)) == 1L,
    logical(1L)
  ))
  expected_manifest_artifacts <- setdiff(
    wlv_gate_normalized_artifacts(),
    "_source_manifest.csv"
  )
  inventory_ok <- schema_ok && identical(
    manifest$artifact,
    sort(expected_manifest_artifacts, method = "radix")
  )
  passed <- schema_ok && safe_artifacts && common_identity && inventory_ok &&
    all(vapply(records, `[[`, logical(1L), "passed"))
  list(
    passed = passed,
    schema_ok = schema_ok,
    safe_artifacts = safe_artifacts,
    common_identity = common_identity,
    inventory_ok = inventory_ok,
    source_generation_id = if (schema_ok && nrow(manifest))
      manifest$source_generation_id[[1L]] else NULL,
    contract_id = if (schema_ok && nrow(manifest))
      manifest$contract_id[[1L]] else NULL,
    contract_version = if (schema_ok && nrow(manifest))
      manifest$contract_version[[1L]] else NULL,
    contract_sha256 = if (schema_ok && nrow(manifest))
      manifest$contract_sha256[[1L]] else NULL,
    records = records,
    table = manifest
  )
}

wlv_gate_load_runtime <- function(root) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  bootstrap_path <- file.path(root, "R", "bootstrap.R")
  if (file.exists(bootstrap_path)) {
    bootstrap <- new.env(parent = baseenv())
    sys.source(bootstrap_path, envir = bootstrap, chdir = FALSE)
    runtime <- bootstrap$wlv_load_runtime(root)
    runtime$wlv_assert_loaded_runtime_unchanged()
    return(list(kind = "candidate", runtime = runtime))
  }
  runtime <- new.env(parent = globalenv())
  previous <- setwd(root)
  on.exit(setwd(previous), add = TRUE)
  # cc2 loaded this definition in each scientific run environment rather than
  # in R/main.R. Paper 0 consumed read_fst_array() from that run environment.
  sys.source(file.path(root, "R", "lib", "functions.R"),
    envir = runtime, chdir = FALSE)
  sys.source(file.path(root, "R", "main.R"), envir = runtime, chdir = FALSE)
  list(kind = "baseline", runtime = runtime)
}

wlv_gate_parse_run_mapping <- function(values) {
  if (!length(values)) {
    stop("At least one `<method>=<run-directory>` mapping is required.",
      call. = FALSE)
  }
  positions <- regexpr("=", values, fixed = TRUE)
  if (any(positions < 2L)) {
    stop("Each run mapping must be `<method>=<run-directory>`.", call. = FALSE)
  }
  methods <- substring(values, 1L, positions - 1L)
  paths <- substring(values, positions + 1L)
  valid_methods <- grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", methods)
  if (any(!valid_methods) || any(!nzchar(paths)) || anyDuplicated(methods)) {
    stop("Run mappings contain invalid or duplicate methods.", call. = FALSE)
  }
  paths <- vapply(paths, normalizePath, character(1L), winslash = "/",
    mustWork = TRUE)
  names(paths) <- methods
  paths
}

wlv_gate_verify_run_directories <- function(
    runtime,
    result_dirs,
    expected_commit = NULL) {
  records <- lapply(names(result_dirs), function(method) {
    directory <- result_dirs[[method]]
    manifest_path <- file.path(directory, "run_manifest.json")
    manifest <- runtime$wlv_read_run_manifest(manifest_path)
    runtime$wlv_verify_run_manifest(
      manifest,
      directory,
      reject_unlisted = TRUE
    )
    if (!identical(manifest$method, method)) {
      stop(sprintf("Run directory method mismatch for `%s`.", method),
        call. = FALSE)
    }
    run_commit <- manifest$result$provenance$git$commit
    run_dirty <- manifest$result$provenance$git$dirty
    if (!is.null(expected_commit) && !identical(run_commit, expected_commit)) {
      stop(sprintf(
        "Run `%s` was produced by commit `%s`, expected `%s`.",
        manifest$run_id,
        run_commit,
        expected_commit
      ), call. = FALSE)
    }
    list(
      method = method,
      run_id = manifest$run_id,
      result_id = manifest$result_id,
      parent_run_id = manifest$parent_run_id,
      run_commit = run_commit,
      run_dirty = run_dirty,
      input_tree_sha256 = manifest$result$provenance$git$input_tree_sha256,
      status_sha256 = manifest$result$provenance$git$status_sha256,
      output_contract = manifest$output_contract,
      manifest_path = normalizePath(manifest_path, winslash = "/",
        mustWork = TRUE),
      manifest_sha256 = wlv_gate_sha256(manifest_path),
      directory = directory
    )
  })
  names(records) <- names(result_dirs)
  records
}

wlv_gate_table_summary <- function(sheets) {
  lapply(seq_along(sheets), function(index) {
    sheet <- sheets[[index]]
    types <- vapply(sheet, typeof, character(1L))
    missing <- vapply(sheet, function(column) sum(is.na(column)), integer(1L))
    list(
      index = index,
      name = if (!is.null(names(sheets)) && nzchar(names(sheets)[[index]]))
        names(sheets)[[index]] else paste0("Sheet", index),
      rows = nrow(sheet),
      columns = ncol(sheet),
      column_names = names(sheet),
      column_types = unname(types),
      missing_cells_by_column = unname(missing)
    )
  })
}

wlv_gate_column_index <- function(reference) {
  letters <- strsplit(sub("[0-9]+$", "", reference), "", fixed = TRUE)[[1L]]
  if (!length(letters) || any(!letters %in% LETTERS)) return(NA_integer_)
  Reduce(function(total, letter) total * 26L + match(letter, LETTERS),
    letters, init = 0L)
}

wlv_gate_cell_position <- function(reference) {
  reference <- toupper(reference)
  row <- suppressWarnings(as.integer(sub("^[A-Z]+", "", reference)))
  column <- wlv_gate_column_index(reference)
  if (is.na(row) || row < 1L || is.na(column) || column < 1L) {
    stop(sprintf("Invalid worksheet cell reference `%s`.", reference),
      call. = FALSE)
  }
  c(row = row, column = column)
}

wlv_gate_safe_zip_entries <- function(path) {
  entries <- utils::unzip(path, list = TRUE)$Name
  normalized <- gsub("\\\\", "/", entries)
  unsafe <- startsWith(normalized, "/") |
    grepl("^[A-Za-z]:", normalized) |
    grepl("(^|/)\\.\\.(/|$)", normalized)
  if (any(unsafe) || anyDuplicated(normalized)) {
    stop("Workbook ZIP contains unsafe or duplicate entries.", call. = FALSE)
  }
  normalized
}

wlv_gate_xml_text <- function(node, xpath) {
  selected <- xml2::xml_find_first(node, xpath)
  if (inherits(selected, "xml_missing")) "" else xml2::xml_text(selected)
}

wlv_gate_core_properties_semantics <- function(path) {
  if (!file.exists(path)) return(NULL)
  document <- xml2::read_xml(path)
  xml2::xml_ns_strip(document)
  dynamic <- xml2::xml_find_all(document, "//*[local-name()='created' or local-name()='modified']")
  if (length(dynamic)) xml2::xml_set_text(dynamic, "<generation-timestamp>")
  as.character(document)
}

wlv_gate_workbook_semantics <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  entries <- wlv_gate_safe_zip_entries(path)
  required <- c("xl/workbook.xml", "xl/_rels/workbook.xml.rels")
  missing <- setdiff(required, entries)
  if (length(missing)) {
    stop(sprintf("Workbook misses OOXML entry(s): %s.",
      paste(missing, collapse = ", ")), call. = FALSE)
  }
  extraction <- tempfile("wlv-paper0-xlsx-")
  if (!dir.create(extraction, recursive = TRUE, showWarnings = FALSE)) {
    stop("Cannot create workbook extraction directory.", call. = FALSE)
  }
  on.exit(unlink(extraction, recursive = TRUE, force = TRUE), add = TRUE)
  utils::unzip(path, files = entries, exdir = extraction, junkpaths = FALSE)

  workbook <- xml2::read_xml(file.path(extraction, "xl", "workbook.xml"))
  relationships <- xml2::read_xml(file.path(
    extraction, "xl", "_rels", "workbook.xml.rels"
  ))
  xml2::xml_ns_strip(workbook)
  xml2::xml_ns_strip(relationships)
  relationship_nodes <- xml2::xml_find_all(relationships, "//Relationship")
  relationship_ids <- xml2::xml_attr(relationship_nodes, "Id")
  relationship_targets <- xml2::xml_attr(relationship_nodes, "Target")
  relationship_map <- stats::setNames(relationship_targets, relationship_ids)

  shared_strings <- character()
  shared_path <- file.path(extraction, "xl", "sharedStrings.xml")
  if (file.exists(shared_path)) {
    shared <- xml2::read_xml(shared_path)
    xml2::xml_ns_strip(shared)
    shared_strings <- vapply(
      xml2::xml_find_all(shared, "//si"),
      function(node) paste0(xml2::xml_text(xml2::xml_find_all(node, ".//t")),
        collapse = ""),
      character(1L)
    )
  }

  sheet_nodes <- xml2::xml_find_all(workbook, "//sheets/sheet")
  sheet_names <- xml2::xml_attr(sheet_nodes, "name")
  sheet_states <- xml2::xml_attr(sheet_nodes, "state")
  sheet_states[is.na(sheet_states)] <- "visible"
  sheet_ids <- vapply(sheet_nodes, function(node) {
    attributes <- xml2::xml_attrs(node)
    names <- names(attributes)
    index <- which(names == "id" | endsWith(names, ":id"))
    if (length(index) != 1L) {
      stop("Workbook sheet lacks one relationship id.", call. = FALSE)
    }
    unname(attributes[[index]])
  }, character(1L))
  targets <- unname(relationship_map[sheet_ids])
  if (anyNA(targets)) {
    stop("Workbook contains an unresolved worksheet relationship.", call. = FALSE)
  }

  sheets <- lapply(seq_along(sheet_names), function(index) {
    target <- gsub("\\\\", "/", targets[[index]])
    target <- sub("^/", "", target)
    if (!startsWith(target, "xl/")) target <- paste0("xl/", target)
    if (grepl("(^|/)\\.\\.(/|$)", target)) {
      stop("Workbook worksheet target escapes the archive root.", call. = FALSE)
    }
    sheet_path <- do.call(
      file.path,
      c(list(extraction), as.list(strsplit(target, "/", fixed = TRUE)[[1L]]))
    )
    if (!file.exists(sheet_path)) {
      stop(sprintf("Workbook worksheet is missing: `%s`.", target),
        call. = FALSE)
    }
    sheet <- xml2::read_xml(sheet_path)
    xml2::xml_ns_strip(sheet)
    dimension_node <- xml2::xml_find_first(sheet, "//dimension")
    dimension <- if (inherits(dimension_node, "xml_missing")) "" else
      xml2::xml_attr(dimension_node, "ref")
    cells <- lapply(xml2::xml_find_all(sheet, "//sheetData/row/c"), function(cell) {
      reference <- xml2::xml_attr(cell, "r")
      position <- wlv_gate_cell_position(reference)
      storage_type <- xml2::xml_attr(cell, "t")
      if (is.na(storage_type) || !nzchar(storage_type)) storage_type <- "n"
      formula <- wlv_gate_xml_text(cell, "./f")
      raw_value <- wlv_gate_xml_text(cell, "./v")
      inline_value <- paste0(
        xml2::xml_text(xml2::xml_find_all(cell, "./is//t")),
        collapse = ""
      )
      semantic_type <- switch(
        storage_type,
        s = "string",
        inlineStr = "string",
        str = "string",
        b = "boolean",
        e = "error",
        d = "date",
        n = "numeric",
        storage_type
      )
      present <- nzchar(raw_value) || nzchar(inline_value) || nzchar(formula)
      if (!present) semantic_type <- "blank"
      value <- switch(
        semantic_type,
        string = if (identical(storage_type, "s")) {
          shared_index <- suppressWarnings(as.integer(raw_value)) + 1L
          if (is.na(shared_index) || shared_index < 1L ||
              shared_index > length(shared_strings)) {
            stop("Workbook contains an invalid shared-string index.",
              call. = FALSE)
          }
          shared_strings[[shared_index]]
        } else if (identical(storage_type, "inlineStr")) inline_value else raw_value,
        numeric = {
          number <- suppressWarnings(as.double(raw_value))
          if (is.na(number) && nzchar(raw_value)) {
            stop(sprintf("Invalid numeric worksheet value `%s`.", raw_value),
              call. = FALSE)
          }
          number
        },
        boolean = identical(raw_value, "1"),
        error = raw_value,
        date = raw_value,
        blank = NA,
        raw_value
      )
      list(
        reference = reference,
        row = unname(position[["row"]]),
        column = unname(position[["column"]]),
        present = present,
        type = semantic_type,
        value = value,
        formula = formula,
        style = {
          style <- xml2::xml_attr(cell, "s")
          if (is.na(style)) "0" else style
        }
      )
    })
    names(cells) <- vapply(cells, `[[`, character(1L), "reference")
    nonblank <- cells[vapply(cells, `[[`, logical(1L), "present")]
    list(
      name = sheet_names[[index]],
      state = sheet_states[[index]],
      dimension = dimension,
      nonblank_references = names(nonblank),
      cells = nonblank
    )
  })
  names(sheets) <- sheet_names
  # file.path() cannot vectorize a list of path components portably; resolve
  # each archive entry explicitly after the traversal checks above.
  extracted_paths <- vapply(entries, function(entry) {
    do.call(
      file.path,
      c(list(extraction), as.list(strsplit(entry, "/", fixed = TRUE)[[1L]]))
    )
  }, character(1L))
  regular <- file.exists(extracted_paths) & !(file.info(extracted_paths)$isdir %in% TRUE)
  entry_hashes <- vapply(extracted_paths[regular], wlv_gate_sha256, character(1L))
  names(entry_hashes) <- entries[regular]
  core_path <- file.path(extraction, "docProps", "core.xml")
  list(
    path = path,
    sha256 = wlv_gate_sha256(path),
    zip_entries = entries,
    sheet_names = sheet_names,
    sheet_states = sheet_states,
    sheets = sheets,
    entry_hashes = entry_hashes,
    core_properties_semantics = wlv_gate_core_properties_semantics(core_path)
  )
}

wlv_gate_cell_value_identical <- function(left, right, type) {
  if (!identical(type, "numeric")) return(identical(left, right))
  identical(
    writeBin(as.double(left), raw(), size = 8L, endian = "little"),
    writeBin(as.double(right), raw(), size = 8L, endian = "little")
  )
}

wlv_gate_compare_workbook_semantics <- function(left_path, right_path) {
  left <- wlv_gate_workbook_semantics(left_path)
  right <- wlv_gate_workbook_semantics(right_path)
  sheet_names_identical <- identical(left$sheet_names, right$sheet_names)
  sheet_states_identical <- identical(left$sheet_states, right$sheet_states)
  entry_names_identical <- setequal(names(left$entry_hashes), names(right$entry_hashes))
  stable_entries <- setdiff(
    intersect(names(left$entry_hashes), names(right$entry_hashes)),
    "docProps/core.xml"
  )
  changed_package_entries <- stable_entries[
    left$entry_hashes[stable_entries] != right$entry_hashes[stable_entries]
  ]
  core_properties_identical <- identical(
    left$core_properties_semantics,
    right$core_properties_semantics
  )
  package_semantics_identical <- entry_names_identical &&
    !length(changed_package_entries) && core_properties_identical
  shared_sheets <- intersect(left$sheet_names, right$sheet_names)
  sheet_reports <- lapply(shared_sheets, function(name) {
    left_sheet <- left$sheets[[name]]
    right_sheet <- right$sheets[[name]]
    masks_identical <- identical(
      left_sheet$nonblank_references,
      right_sheet$nonblank_references
    )
    references <- intersect(
      left_sheet$nonblank_references,
      right_sheet$nonblank_references
    )
    differences <- list()
    for (reference in references) {
      left_cell <- left_sheet$cells[[reference]]
      right_cell <- right_sheet$cells[[reference]]
      type_ok <- identical(left_cell$type, right_cell$type)
      value_ok <- type_ok && wlv_gate_cell_value_identical(
        left_cell$value,
        right_cell$value,
        left_cell$type
      )
      formula_ok <- identical(left_cell$formula, right_cell$formula)
      if (!type_ok || !value_ok || !formula_ok) {
        differences[[length(differences) + 1L]] <- list(
          reference = reference,
          baseline_type = left_cell$type,
          candidate_type = right_cell$type,
          baseline_value = if (identical(left_cell$type, "numeric"))
            wlv_gate_value_label(left_cell$value) else left_cell$value,
          candidate_value = if (identical(right_cell$type, "numeric"))
            wlv_gate_value_label(right_cell$value) else right_cell$value,
          baseline_formula = left_cell$formula,
          candidate_formula = right_cell$formula
        )
        if (length(differences) >= 20L) break
      }
    }
    passed <- identical(left_sheet$dimension, right_sheet$dimension) &&
      masks_identical && !length(differences)
    list(
      sheet = name,
      passed = passed,
      baseline_dimension = left_sheet$dimension,
      candidate_dimension = right_sheet$dimension,
      nonblank_mask_identical = masks_identical,
      baseline_nonblank_cells = length(left_sheet$nonblank_references),
      candidate_nonblank_cells = length(right_sheet$nonblank_references),
      first_cell_differences = differences
    )
  })
  names(sheet_reports) <- shared_sheets
  passed <- sheet_names_identical && sheet_states_identical &&
    package_semantics_identical &&
    length(shared_sheets) == length(left$sheet_names) &&
    all(vapply(sheet_reports, `[[`, logical(1L), "passed"))
  list(
    schema = "wlv-issue13-paper0-workbook-comparison/1",
    passed = passed,
    baseline_path = left$path,
    candidate_path = right$path,
    baseline_sha256 = left$sha256,
    candidate_sha256 = right$sha256,
    sheet_names_identical = sheet_names_identical,
    sheet_states_identical = sheet_states_identical,
    package_entry_names_identical = entry_names_identical,
    package_semantics_identical = package_semantics_identical,
    changed_package_entries = unname(changed_package_entries),
    core_properties_identical_after_timestamp_normalization =
      core_properties_identical,
    baseline_sheet_names = unname(left$sheet_names),
    candidate_sheet_names = unname(right$sheet_names),
    baseline_only_sheets = setdiff(left$sheet_names, right$sheet_names),
    candidate_only_sheets = setdiff(right$sheet_names, left$sheet_names),
    sheets = sheet_reports,
    ignored_physical_differences = c(
      "ZIP entry timestamps", "ZIP compression", "ZIP entry order",
      "OOXML core created/modified generation timestamps"
    )
  )
}
