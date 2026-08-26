# Exact, streaming fingerprints for failed within-engine comparisons.
#
# These digests bind every mismatching coordinate and both exact R scalar
# values. Aggregate recalculation evidence can therefore compare complete
# deltas across engines without retaining a potentially enormous mismatch
# table.

wlv13_v5_difference_scalar_token <- function(value) {
  if (length(value) != 1L) {
    stop("Difference fingerprints require scalar values.", call. = FALSE)
  }
  state <- wlv13_state_names[[wlv13_value_state(value)[[1L]]]]
  payload <- wlv13_sha256_raw(serialize(value, NULL, version = 3L))
  paste(
    state,
    typeof(value),
    paste(class(value), collapse = ","),
    payload,
    sep = ":"
  )
}

wlv13_v5_difference_chunk_sha256 <- function(kind, from, to, records) {
  if (!is.character(records) || anyNA(records)) {
    stop("Difference fingerprint records must be complete text.", call. = FALSE)
  }
  wlv13_sha256_text(paste(
    c(
      paste("kind", kind, sep = "="),
      paste("from", format(from, scientific = FALSE), sep = "="),
      paste("to", format(to, scientific = FALSE), sep = "="),
      paste("records", length(records), sep = "="),
      records
    ),
    collapse = "\n"
  ))
}

wlv13_v5_difference_final_sha256 <- function(kind, shape, chunks) {
  if (!is.character(chunks) || anyNA(chunks) ||
      any(!grepl("^[0-9a-f]{64}$", chunks))) {
    stop("Difference fingerprint chunks are invalid.", call. = FALSE)
  }
  shape_sha256 <- wlv13_sha256_raw(serialize(shape, NULL, version = 3L))
  wlv13_sha256_text(paste(
    c(
      "wlv-issue13-complete-difference/1",
      paste("kind", kind, sep = "="),
      paste("shape", shape_sha256, sep = "="),
      paste("chunks", length(chunks), sep = "="),
      chunks
    ),
    collapse = "\n"
  ))
}

wlv13_v5_fst_array_content_sha256 <- function(descriptor, chunk_rows) {
  sidecar <- descriptor$sidecar
  total <- as.numeric(sidecar$expected_length)
  if (length(total) != 1L || is.na(total) || !is.finite(total) ||
      total < 0 || total != floor(total)) {
    stop("FST array fingerprint received an invalid length.", call. = FALSE)
  }
  starts <- if (total) seq.int(1, total, by = chunk_rows) else numeric()
  chunks <- vapply(starts, function(from) {
    to <- min(total, from + chunk_rows - 1)
    value <- wlv13_read_fst_rows(descriptor$path, from, to)
    if (ncol(value) != 1L || nrow(value) != to - from + 1L ||
        !is.numeric(value[[1L]])) {
      stop("FST array fingerprint read an invalid semantic chunk.",
        call. = FALSE
      )
    }
    wlv13_sha256_raw(serialize(list(
      from = from,
      to = to,
      column = names(value),
      value = value[[1L]]
    ), NULL, version = 3L))
  }, character(1L))
  wlv13_v5_difference_final_sha256(
    "fst_array_side",
    list(
      dimensions = sidecar$dimensions,
      dimnames = sidecar$dimnames,
      expected_length = sidecar$expected_length,
      fst_metadata = descriptor$fst_metadata[c(
        "nrOfRows", "columnNames", "columnTypes", "columnBaseTypes"
      )]
    ),
    chunks
  )
}

wlv13_v5_fst_array_pair_sha256 <- function(candidate, baseline, chunk_rows) {
  wlv13_v5_difference_final_sha256(
    "fst_array_pair",
    list(
      candidate = list(
        dimensions = candidate$sidecar$dimensions,
        dimnames = candidate$sidecar$dimnames,
        expected_length = candidate$sidecar$expected_length,
        fst_metadata = candidate$fst_metadata[c(
          "nrOfRows", "columnNames", "columnTypes", "columnBaseTypes"
        )],
        content_sha256 = wlv13_v5_fst_array_content_sha256(
          candidate, chunk_rows
        )
      ),
      baseline = list(
        dimensions = baseline$sidecar$dimensions,
        dimnames = baseline$sidecar$dimnames,
        expected_length = baseline$sidecar$expected_length,
        fst_metadata = baseline$fst_metadata[c(
          "nrOfRows", "columnNames", "columnTypes", "columnBaseTypes"
        )],
        content_sha256 = wlv13_v5_fst_array_content_sha256(
          baseline, chunk_rows
        )
      )
    ),
    character()
  )
}

wlv13_v5_fst_table_content_sha256 <- function(descriptor, chunk_rows) {
  metadata <- descriptor$fst_metadata
  rows <- as.numeric(metadata$nrOfRows)
  columns <- metadata$columnNames
  if (length(rows) != 1L || is.na(rows) || !is.finite(rows) || rows < 0 ||
      rows != floor(rows) || !is.character(columns) || anyNA(columns) ||
      anyDuplicated(columns)) {
    stop("FST table fingerprint received invalid metadata.", call. = FALSE)
  }
  starts <- if (rows) seq.int(1, rows, by = chunk_rows) else numeric()
  chunks <- unlist(lapply(starts, function(from) {
    to <- min(rows, from + chunk_rows - 1)
    value <- wlv13_read_fst_rows(descriptor$path, from, to, columns)
    if (!identical(names(value), columns) || nrow(value) != to - from + 1L) {
      stop("FST table fingerprint read an invalid semantic chunk.",
        call. = FALSE
      )
    }
    vapply(columns, function(column) {
      wlv13_sha256_raw(serialize(list(
        from = from,
        to = to,
        column = column,
        value = value[[column]]
      ), NULL, version = 3L))
    }, character(1L))
  }), use.names = FALSE)
  wlv13_v5_difference_final_sha256(
    "fst_table_side",
    list(
      rows = metadata$nrOfRows,
      columns = metadata$columnNames,
      types = metadata$columnTypes,
      base_types = metadata$columnBaseTypes
    ),
    chunks
  )
}

wlv13_v5_fst_table_pair_sha256 <- function(candidate, baseline, chunk_rows) {
  wlv13_v5_difference_final_sha256(
    "fst_table_pair",
    list(
      candidate = list(
        metadata = candidate$fst_metadata,
        content_sha256 = wlv13_v5_fst_table_content_sha256(
          candidate, chunk_rows
        )
      ),
      baseline = list(
        metadata = baseline$fst_metadata,
        content_sha256 = wlv13_v5_fst_table_content_sha256(
          baseline, chunk_rows
        )
      )
    ),
    character()
  )
}

wlv13_v5_complete_pair_sha256 <- function(kind, candidate, baseline,
                                           context = list()) {
  wlv13_v5_difference_final_sha256(
    kind,
    list(
      context = context,
      candidate_sha256 = wlv13_sha256_raw(
        serialize(candidate, NULL, version = 3L)
      ),
      baseline_sha256 = wlv13_sha256_raw(
        serialize(baseline, NULL, version = 3L)
      )
    ),
    character()
  )
}

wlv13_v5_double_mismatch <- function(candidate, baseline) {
  candidate <- unclass(candidate)
  baseline <- unclass(baseline)
  if (!is.double(candidate) || !is.double(baseline) ||
      length(candidate) != length(baseline)) {
    stop("Bitwise double comparison received incompatible vectors.",
      call. = FALSE
    )
  }
  candidate_state <- wlv13_value_state(candidate)
  baseline_state <- wlv13_value_state(baseline)
  mismatch <- candidate_state != baseline_state
  finite <- candidate_state == 1L & baseline_state == 1L
  if (any(finite)) {
    candidate_raw <- writeBin(
      candidate[finite], raw(), size = 8L, endian = "little"
    )
    baseline_raw <- writeBin(
      baseline[finite], raw(), size = 8L, endian = "little"
    )
    bytes <- matrix(candidate_raw != baseline_raw, nrow = 8L)
    mismatch[finite] <- colSums(bytes) != 0L
  }
  mismatch
}

wlv13_v5_exact_numeric_mismatch <- function(candidate, baseline) {
  if (!identical(typeof(candidate), typeof(baseline)) ||
      length(candidate) != length(baseline)) {
    return(rep(TRUE, max(length(candidate), length(baseline))))
  }
  if (is.double(candidate)) {
    return(wlv13_v5_double_mismatch(candidate, baseline))
  }
  candidate_state <- wlv13_value_state(candidate)
  baseline_state <- wlv13_value_state(baseline)
  mismatch <- candidate_state != baseline_state
  finite <- candidate_state == 1L & baseline_state == 1L
  mismatch[finite] <- candidate[finite] != baseline[finite]
  mismatch
}

# The V4 fallback converted non-numeric values through as.character(), which
# can erase semantic precision (for example sub-second time values). Preserve
# exact atomic types, attributes and double bits instead.
wlv13_compare_atomic_column <- function(candidate, baseline) {
  if (!identical(class(candidate), class(baseline)) ||
      !identical(typeof(candidate), typeof(baseline)) ||
      length(candidate) != length(baseline) ||
      !identical(attributes(candidate), attributes(baseline))) {
    return(rep(TRUE, max(length(candidate), length(baseline))))
  }
  if (is.numeric(candidate)) {
    return(wlv13_v5_exact_numeric_mismatch(candidate, baseline))
  }
  candidate_na <- is.na(candidate)
  baseline_na <- is.na(baseline)
  mismatch <- candidate_na != baseline_na
  comparable <- !candidate_na & !baseline_na
  if (is.character(candidate) || is.logical(candidate) ||
      is.integer(candidate) || is.raw(candidate)) {
    mismatch[comparable] <- candidate[comparable] != baseline[comparable]
    return(mismatch)
  }
  mismatch[comparable] <- vapply(which(comparable), function(index) {
    !identical(
      candidate[index], baseline[index],
      num.eq = FALSE, single.NA = FALSE, attrib.as.set = FALSE
    )
  }, logical(1L))
  mismatch
}

wlv13_v5_workbook_semantics <- function(path) {
  if (!exists("wlv_gate_workbook_semantics", mode = "function",
      inherits = TRUE)) {
    stop("The complete OOXML semantic reader is not loaded.", call. = FALSE)
  }
  value <- wlv_gate_workbook_semantics(path)
  value$path <- NULL
  value$sha256 <- NULL
  value$entry_hashes <- value$entry_hashes[
    names(value$entry_hashes) != "docProps/core.xml"
  ]
  value
}

# Add complete semantic pair fingerprints to every failed small-artifact
# comparison. Passing artifacts describe an empty delta and need no pair hash.
wlv13_v5_original_compare_small_artifact <- wlv13_compare_small_artifact
wlv13_compare_small_artifact <- function(left, right) {
  result <- wlv13_v5_original_compare_small_artifact(left, right)
  if (isTRUE(result$passed)) {
    return(result)
  }
  type <- left$type
  pair <- if (!identical(type, right$type)) {
    list(candidate = left$sha256, baseline = right$sha256)
  } else if (identical(type, "csv")) {
    candidate <- wlv13_read_csv_semantic(left$path)
    baseline <- wlv13_read_csv_semantic(right$path)
    unordered <- identical(left$role, "diagnostic") &&
      identical(right$role, "diagnostic")
    if (unordered) {
      candidate <- list(
        columns = names(candidate),
        dimensions = dim(candidate),
        rows = wlv13_table_row_keys(candidate)
      )
      baseline <- list(
        columns = names(baseline),
        dimensions = dim(baseline),
        rows = wlv13_table_row_keys(baseline)
      )
    }
    list(candidate = candidate, baseline = baseline)
  } else if (identical(type, "rds")) {
    list(candidate = readRDS(left$path), baseline = readRDS(right$path))
  } else if (identical(type, "json")) {
    list(
      candidate = wlv13_canonical_json(
        wlv13_json_read(left$path, simplify = FALSE)
      ),
      baseline = wlv13_canonical_json(
        wlv13_json_read(right$path, simplify = FALSE)
      )
    )
  } else if (identical(type, "xlsx")) {
    list(
      candidate = wlv13_v5_workbook_semantics(left$path),
      baseline = wlv13_v5_workbook_semantics(right$path)
    )
  } else if (identical(type, "text")) {
    list(
      candidate = enc2utf8(readLines(
        left$path, encoding = "UTF-8", warn = FALSE
      )),
      baseline = enc2utf8(readLines(
        right$path, encoding = "UTF-8", warn = FALSE
      ))
    )
  } else {
    list(candidate = left$sha256, baseline = right$sha256)
  }
  result$difference_sha256 <- wlv13_v5_complete_pair_sha256(
    paste0("small_artifact:", type),
    pair$candidate,
    pair$baseline,
    list(
      candidate_type = left$type,
      baseline_type = right$type,
      candidate_role = left$role,
      baseline_role = right$role
    )
  )
  result
}
