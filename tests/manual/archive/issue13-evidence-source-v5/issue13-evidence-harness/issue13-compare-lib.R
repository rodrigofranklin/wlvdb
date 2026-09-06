# Semantic, manifest-guided comparison helpers for issue #13.

wlv13_parse_array_sidecar <- function(path, data_hash = NULL) {
  metadata <- tryCatch(
    readRDS(path),
    error = function(error) {
      stop(sprintf("Cannot read FST sidecar `%s`: %s", path,
        conditionMessage(error)
      ), call. = FALSE)
    }
  )
  if (!is.list(metadata) || !length(metadata)) {
    stop(sprintf("FST sidecar is not a metadata list: %s.", path),
      call. = FALSE
    )
  }
  dimensions <- metadata[[1L]]
  if (!is.numeric(dimensions) || !length(dimensions) || anyNA(dimensions) ||
      any(!is.finite(dimensions)) || any(dimensions <= 0) ||
      any(dimensions != floor(dimensions)) || any(dimensions > .Machine$integer.max)) {
    stop(sprintf("FST sidecar has invalid dimensions: %s.", path),
      call. = FALSE
    )
  }
  dimensions <- as.integer(dimensions)
  expected_length <- prod(as.numeric(dimensions))
  if (!is.finite(expected_length) || expected_length > 2^53 - 1) {
    stop(sprintf("FST sidecar dimensions exceed safe comparison limits: %s.",
      path
    ), call. = FALSE)
  }
  positional <- seq.int(2L, length.out = length(dimensions))
  if (max(positional) > length(metadata)) {
    stop(sprintf("FST sidecar lacks positional dimnames: %s.", path),
      call. = FALSE
    )
  }
  dimnames_value <- metadata[positional]
  if ("array_dimnames" %in% names(metadata)) {
    dimnames_value <- metadata[[which(names(metadata) == "array_dimnames")[[1L]]]]
  }
  if (is.null(dimnames_value)) {
    dimnames_value <- rep(list(NULL), length(dimensions))
  }
  if (!is.list(dimnames_value) || length(dimnames_value) != length(dimensions)) {
    stop(sprintf("FST sidecar has invalid dimnames: %s.", path),
      call. = FALSE
    )
  }
  for (axis in seq_along(dimensions)) {
    labels <- dimnames_value[[axis]]
    if (!is.null(labels) &&
        (!is.atomic(labels) || length(labels) != dimensions[[axis]] ||
          anyNA(labels) || anyDuplicated(as.character(labels)))) {
      stop(sprintf("FST sidecar axis %d has invalid labels: %s.", axis, path),
        call. = FALSE
      )
    }
    if (!is.null(labels)) {
      dimnames_value[[axis]] <- enc2utf8(as.character(labels))
    }
  }
  embedded_hash <- if ("fst_sha256" %in% names(metadata)) {
    as.character(metadata[[which(names(metadata) == "fst_sha256")[[1L]]]])
  } else {
    NULL
  }
  if (!is.null(embedded_hash)) {
    if (length(embedded_hash) != 1L || is.na(embedded_hash) ||
        !grepl("^[0-9a-f]{64}$", embedded_hash)) {
      stop(sprintf("FST sidecar embeds an invalid SHA-256: %s.", path),
        call. = FALSE
      )
    }
    if (!is.null(data_hash) && !identical(embedded_hash, data_hash)) {
      stop(sprintf("FST sidecar/data SHA-256 binding is invalid: %s.", path),
        call. = FALSE
      )
    }
  }
  list(
    dimensions = dimensions,
    dimnames = dimnames_value,
    expected_length = expected_length,
    embedded_sha256 = embedded_hash
  )
}

wlv13_fst_metadata <- function(path) {
  wlv13_require("fst")
  value <- tryCatch(
    fst::metadata_fst(path),
    error = function(error) {
      stop(sprintf("Cannot read FST metadata `%s`: %s", path,
        conditionMessage(error)
      ), call. = FALSE)
    }
  )
  if (!is.list(value) || is.null(value$nrOfRows) ||
      is.null(value$columnNames) || !length(value$columnNames)) {
    stop(sprintf("FST metadata is incomplete: %s.", path), call. = FALSE)
  }
  value
}

wlv13_array_logical_key <- function(relative, sidecar) {
  name <- sub("[.]fst$", "", basename(relative), ignore.case = TRUE)
  if (startsWith(tolower(name), "m_io")) {
    years <- sidecar$dimnames[[1L]]
    if (is.null(years) || !length(years)) {
      stop(sprintf("I/O array lacks year labels: %s.", relative), call. = FALSE)
    }
    year_hash <- wlv13_sha256_text(paste(years, collapse = "\n"))
    return(sprintf("array:m_io:%d:%s", length(years), year_hash))
  }
  paste0("array:", sub("[.]fst$", "", relative, ignore.case = TRUE))
}

wlv13_artifact_descriptors <- function(inventory) {
  records <- inventory$records
  descriptors <- list()
  consumed <- rep(FALSE, nrow(records))
  names(consumed) <- records$path
  fst_rows <- which(grepl("[.]fst$", records$path, ignore.case = TRUE))
  for (index in fst_rows) {
    relative <- records$path[[index]]
    meta_relative <- paste0(relative, ".meta")
    meta_index <- match(meta_relative, records$path)
    data_path <- file.path(inventory$root, relative)
    if (!is.na(meta_index)) {
      sidecar <- wlv13_parse_array_sidecar(
        file.path(inventory$root, meta_relative),
        data_hash = records$sha256[[index]]
      )
      fst_metadata <- wlv13_fst_metadata(data_path)
      if (length(fst_metadata$columnNames) != 1L ||
          fst_metadata$nrOfRows != sidecar$expected_length) {
        stop(sprintf("FST array payload disagrees with its sidecar: %s.",
          relative
        ), call. = FALSE)
      }
      key <- wlv13_array_logical_key(relative, sidecar)
      descriptor <- list(
        key = key,
        type = "fst_array",
        relative = relative,
        path = data_path,
        role = records$role[[index]],
        sha256 = records$sha256[[index]],
        meta_relative = meta_relative,
        meta_path = file.path(inventory$root, meta_relative),
        meta_role = records$role[[meta_index]],
        meta_sha256 = records$sha256[[meta_index]],
        sidecar = sidecar,
        fst_metadata = fst_metadata
      )
      consumed[[index]] <- TRUE
      consumed[[meta_index]] <- TRUE
    } else {
      key <- paste0("fst_table:", relative)
      descriptor <- list(
        key = key,
        type = "fst_table",
        relative = relative,
        path = data_path,
        role = records$role[[index]],
        sha256 = records$sha256[[index]],
        fst_metadata = wlv13_fst_metadata(data_path)
      )
      consumed[[index]] <- TRUE
    }
    if (key %in% names(descriptors)) {
      stop(sprintf("Duplicate logical artifact key: %s.", key), call. = FALSE)
    }
    descriptors[[key]] <- descriptor
  }
  orphan_meta <- which(grepl("[.]fst[.]meta$", records$path, ignore.case = TRUE) &
    !consumed)
  if (length(orphan_meta)) {
    stop(sprintf("Orphan FST sidecar(s): %s.",
      paste(records$path[orphan_meta], collapse = ", ")
    ), call. = FALSE)
  }
  remaining <- which(!consumed)
  for (index in remaining) {
    relative <- records$path[[index]]
    extension <- tolower(tools::file_ext(relative))
    type <- switch(extension,
      csv = "csv",
      rds = "rds",
      json = "json",
      xlsx = "xlsx",
      txt = "text",
      md = "text",
      "raw"
    )
    key <- paste0("file:", relative)
    descriptors[[key]] <- list(
      key = key,
      type = type,
      relative = relative,
      path = file.path(inventory$root, relative),
      role = records$role[[index]],
      sha256 = records$sha256[[index]]
    )
  }
  descriptors[order(names(descriptors), method = "radix")]
}

wlv13_value_state <- function(value) {
  state <- rep.int(1L, length(value))
  state[is.na(value)] <- 2L
  state[is.nan(value)] <- 3L
  state[is.infinite(value) & value > 0] <- 4L
  state[is.infinite(value) & value < 0] <- 5L
  state
}

wlv13_state_names <- c("finite", "NA", "NaN", "+Inf", "-Inf")

wlv13_format_value <- function(value) {
  if (!length(value)) return("")
  value <- value[[1L]]
  if (is.nan(value)) return("NaN")
  if (is.na(value)) return("NA")
  if (is.infinite(value)) return(if (value > 0) "+Inf" else "-Inf")
  format(value, digits = 17L, scientific = TRUE, trim = TRUE)
}

wlv13_linear_coordinate <- function(position, dimensions) {
  remainder <- as.numeric(position) - 1
  indices <- numeric(length(dimensions))
  for (axis in seq_along(dimensions)) {
    indices[[axis]] <- (remainder %% dimensions[[axis]]) + 1
    remainder <- floor(remainder / dimensions[[axis]])
  }
  as.integer(indices)
}

wlv13_coordinate_label <- function(position, sidecar) {
  indices <- wlv13_linear_coordinate(position, sidecar$dimensions)
  axes <- names(sidecar$dimnames)
  if (is.null(axes) || length(axes) != length(indices) || any(!nzchar(axes))) {
    axes <- paste0("axis", seq_along(indices))
  }
  labels <- vapply(seq_along(indices), function(axis) {
    values <- sidecar$dimnames[[axis]]
    if (is.null(values)) as.character(indices[[axis]]) else
      as.character(values[[indices[[axis]]]])
  }, character(1L))
  paste(axes, labels, sep = "=", collapse = ";")
}

wlv13_read_fst_rows <- function(path, from, to, columns = NULL) {
  wlv13_require("fst")
  value <- fst::read_fst(
    path,
    columns = columns,
    from = as.numeric(from),
    to = as.numeric(to),
    as.data.table = FALSE
  )
  if (!is.data.frame(value)) {
    value <- as.data.frame(value, stringsAsFactors = FALSE)
  }
  value
}

wlv13_compare_fst_array <- function(left, right, chunk_rows) {
  left_sidecar <- left$sidecar
  right_sidecar <- right$sidecar
  same_dimensions <- identical(left_sidecar$dimensions, right_sidecar$dimensions)
  same_dimnames <- identical(left_sidecar$dimnames, right_sidecar$dimnames)
  if (!same_dimensions) {
    return(list(
      summary = list(
        passed = FALSE,
        same_dimensions = FALSE,
        same_dimnames = same_dimnames,
        mismatch_count = NULL,
        maximum_absolute_difference = NULL,
        first_mismatch_coordinate = "dimension-mismatch"
      ),
      transitions = data.frame(),
      indicators = data.frame()
    ))
  }
  total <- left_sidecar$expected_length
  if (right_sidecar$expected_length != total) {
    stop("Equal dimensions produced unequal array lengths.", call. = FALSE)
  }
  transitions <- matrix(0,
    nrow = length(wlv13_state_names),
    ncol = length(wlv13_state_names),
    dimnames = list(candidate = wlv13_state_names, baseline = wlv13_state_names)
  )
  mismatch_count <- 0
  maximum_difference <- 0
  maximum_position <- NA_real_
  left_at_maximum <- ""
  right_at_maximum <- ""
  first_mismatch <- NA_real_
  first_left_state <- ""
  first_right_state <- ""
  first_left_value <- ""
  first_right_value <- ""
  axis2_labels <- if (length(left_sidecar$dimensions) >= 2L) {
    left_sidecar$dimnames[[2L]]
  } else {
    NULL
  }
  axis2_counts <- if (!is.null(axis2_labels)) {
    stats::setNames(numeric(length(axis2_labels)), axis2_labels)
  } else {
    numeric()
  }
  axis2_maximum <- if (!is.null(axis2_labels)) {
    stats::setNames(numeric(length(axis2_labels)), axis2_labels)
  } else {
    numeric()
  }
  starts <- seq.int(1, total, by = chunk_rows)
  for (from in starts) {
    to <- min(total, from + chunk_rows - 1)
    left_table <- wlv13_read_fst_rows(left$path, from, to)
    right_table <- wlv13_read_fst_rows(right$path, from, to)
    if (ncol(left_table) != 1L || ncol(right_table) != 1L ||
        nrow(left_table) != to - from + 1 ||
        nrow(right_table) != to - from + 1) {
      stop("Chunked FST array read returned an invalid shape.", call. = FALSE)
    }
    left_value <- left_table[[1L]]
    right_value <- right_table[[1L]]
    if (!is.numeric(left_value) || !is.numeric(right_value)) {
      stop("Published FST arrays must contain numeric values.", call. = FALSE)
    }
    left_state <- wlv13_value_state(left_value)
    right_state <- wlv13_value_state(right_value)
    transitions <- transitions + unclass(table(
      factor(left_state, levels = seq_along(wlv13_state_names)),
      factor(right_state, levels = seq_along(wlv13_state_names))
    ))
    finite <- left_state == 1L & right_state == 1L
    mismatch <- left_state != right_state
    mismatch[finite] <- left_value[finite] != right_value[finite]
    mismatch_count <- mismatch_count + sum(mismatch)
    if (is.na(first_mismatch) && any(mismatch)) {
      local <- which(mismatch)[[1L]]
      first_mismatch <- from + local - 1
      first_left_state <- wlv13_state_names[[left_state[[local]]]]
      first_right_state <- wlv13_state_names[[right_state[[local]]]]
      first_left_value <- wlv13_format_value(left_value[[local]])
      first_right_value <- wlv13_format_value(right_value[[local]])
    }
    if (any(finite)) {
      difference <- abs(left_value[finite] - right_value[finite])
      local_maximum <- max(difference)
      if (is.infinite(local_maximum) || local_maximum > maximum_difference ||
          (is.na(maximum_position) && local_maximum == maximum_difference)) {
        finite_positions <- which(finite)
        local <- finite_positions[[which.max(difference)]]
        maximum_difference <- local_maximum
        maximum_position <- from + local - 1
        left_at_maximum <- wlv13_format_value(left_value[[local]])
        right_at_maximum <- wlv13_format_value(right_value[[local]])
      }
    }
    if (length(axis2_counts) && any(mismatch)) {
      positions <- from - 1 + which(mismatch)
      axis2 <- ((positions - 1) %/% left_sidecar$dimensions[[1L]]) %%
        left_sidecar$dimensions[[2L]] + 1
      counts <- table(factor(axis2, levels = seq_along(axis2_counts)))
      axis2_counts <- axis2_counts + as.numeric(counts)
      finite_mismatch <- which(mismatch & finite)
      if (length(finite_mismatch)) {
        finite_positions <- from - 1 + finite_mismatch
        finite_axis2 <- ((finite_positions - 1) %/%
          left_sidecar$dimensions[[1L]]) %% left_sidecar$dimensions[[2L]] + 1
        finite_difference <- abs(
          left_value[finite_mismatch] - right_value[finite_mismatch]
        )
        for (axis in unique(finite_axis2)) {
          axis2_maximum[[axis]] <- max(
            axis2_maximum[[axis]], finite_difference[finite_axis2 == axis]
          )
        }
      }
    }
    rm(left_table, right_table, left_value, right_value)
  }
  transition_table <- as.data.frame(as.table(transitions),
    stringsAsFactors = FALSE
  )
  names(transition_table) <- c("candidate_state", "baseline_state", "count")
  transition_table <- transition_table[transition_table$count > 0, , drop = FALSE]
  indicator_table <- if (length(axis2_counts)) {
    data.frame(
      indicator = names(axis2_counts),
      mismatch_count = unname(axis2_counts),
      maximum_absolute_difference = vapply(axis2_maximum,
        wlv13_format_value, character(1L)
      ),
      stringsAsFactors = FALSE
    )
  } else {
    data.frame()
  }
  if (nrow(indicator_table)) {
    indicator_table <- indicator_table[indicator_table$mismatch_count > 0, , drop = FALSE]
  }
  passed <- same_dimensions && same_dimnames && mismatch_count == 0
  list(
    summary = list(
      passed = passed,
      same_dimensions = same_dimensions,
      same_dimnames = same_dimnames,
      dimensions = as.list(left_sidecar$dimensions),
      mismatch_count = mismatch_count,
      maximum_absolute_difference = wlv13_format_value(maximum_difference),
      maximum_coordinate = if (is.na(maximum_position)) "" else
        wlv13_coordinate_label(maximum_position, left_sidecar),
      candidate_at_maximum = left_at_maximum,
      baseline_at_maximum = right_at_maximum,
      first_mismatch_coordinate = if (is.na(first_mismatch)) "" else
        wlv13_coordinate_label(first_mismatch, left_sidecar),
      first_candidate_state = first_left_state,
      first_baseline_state = first_right_state,
      first_candidate_value = first_left_value,
      first_baseline_value = first_right_value
    ),
    transitions = transition_table,
    indicators = indicator_table
  )
}

wlv13_compare_atomic_column <- function(left, right) {
  if (!identical(class(left), class(right)) || !identical(typeof(left), typeof(right)) ||
      length(left) != length(right)) {
    return(rep(TRUE, max(length(left), length(right))))
  }
  if (is.numeric(left)) {
    left_state <- wlv13_value_state(left)
    right_state <- wlv13_value_state(right)
    finite <- left_state == 1L & right_state == 1L
    mismatch <- left_state != right_state
    mismatch[finite] <- left[finite] != right[finite]
    return(mismatch)
  }
  left_na <- is.na(left)
  right_na <- is.na(right)
  mismatch <- left_na != right_na
  comparable <- !left_na & !right_na
  mismatch[comparable] <- as.character(left[comparable]) !=
    as.character(right[comparable])
  mismatch
}

wlv13_compare_fst_table <- function(left, right, chunk_rows) {
  left_meta <- left$fst_metadata
  right_meta <- right$fst_metadata
  same_rows <- identical(as.numeric(left_meta$nrOfRows), as.numeric(right_meta$nrOfRows))
  same_columns <- identical(left_meta$columnNames, right_meta$columnNames)
  same_types <- identical(left_meta$columnTypes, right_meta$columnTypes) &&
    identical(left_meta$columnBaseTypes, right_meta$columnBaseTypes)
  if (!same_rows || !same_columns || !same_types) {
    return(list(
      summary = list(
        passed = FALSE,
        same_rows = same_rows,
        same_columns = same_columns,
        same_types = same_types,
        mismatch_count = NULL,
        first_mismatch_coordinate = "table-schema-mismatch"
      ),
      transitions = data.frame(),
      indicators = data.frame()
    ))
  }
  rows <- as.numeric(left_meta$nrOfRows)
  columns <- left_meta$columnNames
  counts <- stats::setNames(numeric(length(columns)), columns)
  first_mismatch <- ""
  starts <- if (rows) seq.int(1, rows, by = chunk_rows) else numeric()
  for (from in starts) {
    to <- min(rows, from + chunk_rows - 1)
    left_table <- wlv13_read_fst_rows(left$path, from, to, columns)
    right_table <- wlv13_read_fst_rows(right$path, from, to, columns)
    for (column in columns) {
      mismatch <- wlv13_compare_atomic_column(
        left_table[[column]], right_table[[column]]
      )
      if (length(mismatch) != nrow(left_table)) {
        stop("FST table columns changed length during comparison.", call. = FALSE)
      }
      counts[[column]] <- counts[[column]] + sum(mismatch)
      if (!nzchar(first_mismatch) && any(mismatch)) {
        first_mismatch <- sprintf("row=%s;column=%s",
          from + which(mismatch)[[1L]] - 1, column
        )
      }
    }
  }
  differences <- data.frame(
    indicator = names(counts),
    mismatch_count = unname(counts),
    maximum_absolute_difference = "",
    stringsAsFactors = FALSE
  )
  differences <- differences[differences$mismatch_count > 0, , drop = FALSE]
  list(
    summary = list(
      passed = !sum(counts),
      same_rows = same_rows,
      same_columns = same_columns,
      same_types = same_types,
      rows = rows,
      columns = as.list(columns),
      mismatch_count = sum(counts),
      first_mismatch_coordinate = first_mismatch
    ),
    transitions = data.frame(),
    indicators = differences
  )
}

wlv13_csv_delimiter <- function(path) {
  header <- readLines(path, n = 1L, encoding = "UTF-8", warn = FALSE)
  if (!length(header)) return(";")
  semicolons <- lengths(regmatches(header, gregexpr(";", header, fixed = TRUE)))
  commas <- lengths(regmatches(header, gregexpr(",", header, fixed = TRUE)))
  if (commas > semicolons) "," else ";"
}

wlv13_read_csv_semantic <- function(path) {
  separator <- wlv13_csv_delimiter(path)
  value <- utils::read.table(
    path,
    header = TRUE,
    sep = separator,
    quote = "\"",
    comment.char = "",
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL,
    fileEncoding = "UTF-8"
  )
  row.names(value) <- NULL
  value[] <- lapply(value, enc2utf8)
  value
}

wlv13_table_row_keys <- function(value) {
  if (!is.data.frame(value)) {
    stop("Canonical row keys require a data frame.", call. = FALSE)
  }
  if (!nrow(value)) return(character())
  columns <- lapply(value, function(column) {
    column <- enc2utf8(as.character(column))
    paste0(nchar(column, type = "bytes"), ":", column)
  })
  keys <- do.call(paste, c(columns, sep = "|"))
  sort(keys, method = "radix")
}

wlv13_canonical_json <- function(value) {
  if (is.list(value)) {
    if (!is.null(names(value))) {
      order_index <- order(names(value), method = "radix")
      value <- value[order_index]
    }
    return(lapply(value, wlv13_canonical_json))
  }
  if (is.character(value)) enc2utf8(value) else value
}

wlv13_compare_xlsx <- function(left_path, right_path) {
  if (!exists("wlv_gate_compare_workbook_semantics", mode = "function",
      inherits = TRUE)) {
    stop("The pinned OOXML workbook comparator is not loaded.", call. = FALSE)
  }
  # Generic comparisons receive candidate first and baseline second. The
  # dedicated report uses baseline/candidate labels, so reverse the arguments.
  comparison <- wlv_gate_compare_workbook_semantics(
    right_path,
    left_path
  )
  comparison$comparison_mode <- "ooxml-semantic"
  comparison
}

wlv13_compare_small_artifact <- function(left, right) {
  type <- left$type
  if (!identical(type, right$type)) {
    return(list(passed = FALSE, reason = "artifact-type-mismatch"))
  }
  if (identical(type, "csv")) {
    left_value <- wlv13_read_csv_semantic(left$path)
    right_value <- wlv13_read_csv_semantic(right$path)
    unordered <- identical(left$role, "diagnostic") &&
      identical(right$role, "diagnostic")
    same_columns <- identical(names(left_value), names(right_value))
    same_dimensions <- identical(dim(left_value), dim(right_value))
    passed <- same_columns && same_dimensions && if (unordered) {
      identical(
        wlv13_table_row_keys(left_value),
        wlv13_table_row_keys(right_value)
      )
    } else {
      identical(left_value, right_value)
    }
    return(list(
      passed = passed,
      comparison_mode = if (unordered) {
        "unordered-row-multiset"
      } else {
        "ordered-table"
      },
      same_columns = same_columns,
      same_dimensions = same_dimensions,
      rows = nrow(left_value),
      columns = ncol(left_value)
    ))
  }
  if (identical(type, "rds")) {
    left_value <- readRDS(left$path)
    right_value <- readRDS(right$path)
    return(list(
      passed = identical(left_value, right_value),
      candidate_class = as.list(class(left_value)),
      baseline_class = as.list(class(right_value))
    ))
  }
  if (identical(type, "json")) {
    left_value <- wlv13_canonical_json(wlv13_json_read(left$path, simplify = FALSE))
    right_value <- wlv13_canonical_json(wlv13_json_read(right$path, simplify = FALSE))
    return(list(passed = identical(left_value, right_value)))
  }
  if (identical(type, "xlsx")) {
    return(wlv13_compare_xlsx(left$path, right$path))
  }
  if (identical(type, "text")) {
    left_value <- enc2utf8(readLines(left$path, encoding = "UTF-8", warn = FALSE))
    right_value <- enc2utf8(readLines(right$path, encoding = "UTF-8", warn = FALSE))
    return(list(passed = identical(left_value, right_value)))
  }
  list(
    passed = identical(left$sha256, right$sha256),
    reason = if (identical(left$sha256, right$sha256)) {
      "byte-identical-unknown-artifact"
    } else {
      "unknown-artifact-bytes-differ"
    }
  )
}

wlv13_cross_engine_run_rules <- function() {
  list(
    normalized = c(
      "file:_anomalies.csv",
      "file:_method_assumptions.csv",
      "file:_method_matrices.csv",
      "file:_method_solutions.csv",
      "file:_scientific_checks.csv",
      "file:_unit_contract.csv"
    ),
    candidate_only = "file:_nonfinite_resolution_diagnostics.csv"
  )
}

wlv13_cross_engine_schema <- function(name) {
  switch(name,
    `_anomalies.csv` = c(
      "artifact", "indicator", "checkpoint", "stage", "module", "year",
      "country", "sector", "output", "original_value", "policy_id", "action"
    ),
    `_method_assumptions.csv` = c("names", "computation", "order"),
    `_method_matrices.csv` = c("names", "computation", "order"),
    `_method_solutions.csv` = c(
      "names", "sector_solution", "country_solution", "stage", "order"
    ),
    `_scientific_checks.csv` = c(
      "method", "check_id", "artifact", "indicator", "scope", "status",
      "observations", "maximum_absolute_error", "maximum_scaled_error",
      "tolerance", "detail"
    ),
    `_unit_contract.csv` = c(
      "contract", "schema_version", "source", "indicator", "quantity_kind",
      "source_unit", "source_scale", "canonical_unit", "display_unit",
      "display_multiplier", "currency", "price_basis", "base_year",
      "index_base", "index_base_year", "index_storage_base",
      "labour_concept", "level", "strategy", "module", "numerator",
      "denominator", "weight", "zero_denominator", "unit_notes",
      "aggregation_notes"
    ),
    `_nonfinite_resolution_diagnostics.csv` = c(
      "method", "scientific_profile", "nonfinite_resolution_profile",
      "action", "module", "binding", "indicator", "kind",
      "resolved_count", "coordinate_sha256"
    ),
    stop(sprintf("No cross-engine schema is registered for `%s`.", name),
      call. = FALSE
    )
  )
}

wlv13_cross_engine_read <- function(descriptor, name) {
  if (!identical(descriptor$type, "csv") ||
      !identical(descriptor$relative, name)) {
    stop(sprintf("Cross-engine descriptor mismatch for `%s`.", name),
      call. = FALSE
    )
  }
  value <- wlv13_read_csv_semantic(descriptor$path)
  expected <- wlv13_cross_engine_schema(name)
  list(
    value = value,
    schema_valid = identical(names(value), expected),
    expected_columns = expected
  )
}

wlv13_cross_engine_order_valid <- function(value) {
  if (!nrow(value)) return(TRUE)
  order_value <- suppressWarnings(as.integer(value[["order"]]))
  !anyNA(order_value) && !anyDuplicated(order_value) &&
    identical(sort(order_value), seq_len(nrow(value)))
}

wlv13_cross_engine_nonempty <- function(value, columns) {
  all(columns %in% names(value)) && all(vapply(columns, function(name) {
    all(nzchar(value[[name]]))
  }, logical(1L)))
}

wlv13_cross_engine_assumption_categories <- function(value) {
  text <- tolower(paste(value[["names"]], value[["computation"]]))
  category <- ifelse(grepl("china", text), "china",
    ifelse(grepl("(^|[^a-z])row([^a-z]|$)", text, perl = TRUE), "row", "other")
  )
  sort(category, method = "radix")
}

wlv13_cross_engine_matrix_categories <- function(value) {
  text <- tolower(paste(value[["names"]], value[["computation"]]))
  category <- ifelse(grepl("transfer", text), "transfers",
    ifelse(grepl("depr|basket", text), "consumption_basket",
      ifelse(grepl("composition|capital", text), "capital",
        ifelse(grepl("value|transform", text), "values", "other")
      )
    )
  )
  sort(category, method = "radix")
}

wlv13_cross_engine_solution_projection <- function(value) {
  aggregation <- ifelse(
    value[["country_solution"]] %in% c("sum", "mean"),
    value[["country_solution"]],
    "custom"
  )
  projection <- data.frame(
    indicator = value[["names"]],
    country_aggregation = aggregation,
    stringsAsFactors = FALSE
  )
  projection[order(projection$indicator, method = "radix"), , drop = FALSE]
}

wlv13_cross_engine_check_projection <- function(value) {
  architecture_checks <- c(
    "aggregation_contract", "aggregation_legacy_adapter",
    "nonfinite_resolution"
  )
  value <- value[!value[["check_id"]] %in% architecture_checks, , drop = FALSE]
  value[c(
    "method", "check_id", "artifact", "indicator", "status", "observations",
    "maximum_absolute_error", "maximum_scaled_error", "tolerance"
  )]
}

wlv13_cross_engine_unit_projection <- function(value) {
  value[setdiff(names(value), c("module", "aggregation_notes"))]
}

wlv13_cross_engine_validate_nonfinite <- function(descriptor, method) {
  parsed <- wlv13_cross_engine_read(
    descriptor, "_nonfinite_resolution_diagnostics.csv"
  )
  value <- parsed$value
  count <- suppressWarnings(as.integer(value[["resolved_count"]]))
  valid <- parsed$schema_valid && nrow(value) > 0L &&
    wlv13_cross_engine_nonempty(value, setdiff(names(value), "binding")) &&
    all(value[["method"]] == method) &&
    all(value[["kind"]] %in% c("NaN", "Inf", "-Inf")) &&
    !anyNA(count) && all(count > 0L) &&
    all(grepl("^[0-9a-f]{64}$", value[["coordinate_sha256"]])) &&
    !anyDuplicated(value[c("module", "indicator", "kind")])
  list(
    passed = valid,
    comparison_mode = "validated-candidate-only-diagnostic",
    schema_valid = parsed$schema_valid,
    rows = nrow(value),
    resolved_count = if (length(count) && !anyNA(count)) sum(count) else NULL,
    architecture_difference = TRUE,
    value = value
  )
}

wlv13_cross_engine_compare_anomalies <- function(left, right,
                                                  candidate_descriptors,
                                                  method) {
  left_parsed <- wlv13_cross_engine_read(left, "_anomalies.csv")
  right_parsed <- wlv13_cross_engine_read(right, "_anomalies.csv")
  candidate <- left_parsed$value
  baseline <- right_parsed$value
  required <- c(
    "artifact", "indicator", "checkpoint", "stage", "module",
    "original_value", "policy_id", "action"
  )
  candidate_valid <- left_parsed$schema_valid &&
    wlv13_cross_engine_nonempty(candidate, required)
  baseline_valid <- right_parsed$schema_valid &&
    wlv13_cross_engine_nonempty(baseline, required)
  removed <- rep(FALSE, nrow(candidate))
  diagnostic_key <- "file:_nonfinite_resolution_diagnostics.csv"
  diagnostic <- candidate_descriptors[[diagnostic_key]]
  resolution_rows <- 0L
  diagnostic_valid <- TRUE
  if (!is.null(diagnostic)) {
    validation <- wlv13_cross_engine_validate_nonfinite(diagnostic, method)
    diagnostic_valid <- isTRUE(validation$passed)
    if (diagnostic_valid) {
      for (index in seq_len(nrow(validation$value))) {
        record <- validation$value[index, , drop = FALSE]
        selected <- !removed &
          candidate[["module"]] == record[["module"]] &
          candidate[["indicator"]] == record[["indicator"]] &
          candidate[["action"]] == record[["action"]] &
          candidate[["original_value"]] == record[["kind"]]
        expected <- as.integer(record[["resolved_count"]])
        if (sum(selected) != expected) diagnostic_valid <- FALSE
        removed <- removed | selected
      }
      resolution_rows <- sum(removed)
    }
  }
  normalize <- function(value) {
    value[["module"]] <- NULL
    value[["policy_id"]] <- sub(
      "_v09_leontief_zero_output_v1$",
      "_leontief_zero_output_v1",
      value[["policy_id"]]
    )
    value
  }
  candidate_core <- candidate[!removed, , drop = FALSE]
  candidate_normalized <- normalize(candidate_core)
  baseline_normalized <- normalize(baseline)
  candidate_stage <- suppressWarnings(as.integer(candidate_normalized[["stage"]]))
  baseline_stage <- suppressWarnings(as.integer(baseline_normalized[["stage"]]))
  stage_valid <- !anyNA(candidate_stage) && !anyNA(baseline_stage)

  # The legacy stage-four runner appends the stage-five diagnostics generated
  # by the child to the identical rows inherited from its parent. The native
  # runner replaces those target diagnostics. Cross-engine comparison accepts
  # only that exact multiplicity difference: rows below stage five remain an
  # exact multiset, while every stage-five semantic row must exist on both
  # sides and the legacy count must be either one or two times the native
  # count. Within-engine `strict` comparison still counts every duplicate.
  candidate_lower <- candidate_normalized[candidate_stage < 5L, , drop = FALSE]
  baseline_lower <- baseline_normalized[baseline_stage < 5L, , drop = FALSE]
  lower_equal <- stage_valid && identical(
    wlv13_table_row_keys(candidate_lower),
    wlv13_table_row_keys(baseline_lower)
  )
  candidate_stage5_keys <- wlv13_table_row_keys(
    candidate_normalized[candidate_stage >= 5L, , drop = FALSE]
  )
  baseline_stage5_keys <- wlv13_table_row_keys(
    baseline_normalized[baseline_stage >= 5L, , drop = FALSE]
  )
  candidate_stage5_counts <- table(candidate_stage5_keys)
  baseline_stage5_counts <- table(baseline_stage5_keys)
  stage5_same_keys <- identical(
    names(candidate_stage5_counts), names(baseline_stage5_counts)
  )
  stage5_multiplicity_valid <- stage_valid && stage5_same_keys &&
    all(
      as.integer(baseline_stage5_counts) ==
        as.integer(candidate_stage5_counts) |
      as.integer(baseline_stage5_counts) ==
        2L * as.integer(candidate_stage5_counts)
    )
  same_core <- candidate_valid && baseline_valid && diagnostic_valid &&
    lower_equal && stage5_multiplicity_valid
  list(
    summary = list(
      passed = same_core,
      comparison_mode = "normalized-anomaly-generation",
      candidate_schema_valid = left_parsed$schema_valid,
      baseline_schema_valid = right_parsed$schema_valid,
      candidate_rows = nrow(candidate),
      baseline_rows = nrow(baseline),
      candidate_resolution_rows = resolution_rows,
      normalized_core_rows = nrow(candidate_core),
      stages_valid = stage_valid,
      lower_stage_multiset_equal = lower_equal,
      stage5_same_semantic_rows = stage5_same_keys,
      stage5_multiplicity_valid = stage5_multiplicity_valid,
      candidate_stage5_rows = length(candidate_stage5_keys),
      baseline_stage5_rows = length(baseline_stage5_keys),
      normalized_core_equal = same_core,
      architecture_difference = !identical(candidate, baseline)
    ),
    transitions = data.frame(),
    indicators = data.frame()
  )
}

wlv13_cross_engine_compare_config <- function(left, right, name) {
  left_parsed <- wlv13_cross_engine_read(left, name)
  right_parsed <- wlv13_cross_engine_read(right, name)
  candidate <- left_parsed$value
  baseline <- right_parsed$value
  schema_valid <- left_parsed$schema_valid && right_parsed$schema_valid
  valid <- schema_valid
  comparison <- ""
  if (identical(name, "_method_assumptions.csv")) {
    valid <- valid &&
      wlv13_cross_engine_nonempty(candidate, c("names", "computation", "order")) &&
      wlv13_cross_engine_nonempty(baseline, c("names", "computation", "order")) &&
      wlv13_cross_engine_order_valid(candidate) &&
      wlv13_cross_engine_order_valid(baseline) &&
      identical(
        wlv13_cross_engine_assumption_categories(candidate),
        wlv13_cross_engine_assumption_categories(baseline)
      )
    comparison <- "normalized-assumption-categories"
  } else if (identical(name, "_method_matrices.csv")) {
    candidate_categories <- wlv13_cross_engine_matrix_categories(candidate)
    baseline_categories <- wlv13_cross_engine_matrix_categories(baseline)
    valid <- valid &&
      wlv13_cross_engine_nonempty(candidate, c("names", "computation", "order")) &&
      wlv13_cross_engine_nonempty(baseline, c("names", "computation", "order")) &&
      wlv13_cross_engine_order_valid(candidate) &&
      wlv13_cross_engine_order_valid(baseline) &&
      !"other" %in% candidate_categories && !"other" %in% baseline_categories &&
      identical(unique(candidate_categories), unique(baseline_categories))
    comparison <- "normalized-matrix-categories"
  } else if (identical(name, "_method_solutions.csv")) {
    valid <- valid &&
      wlv13_cross_engine_nonempty(candidate, c(
        "names", "sector_solution", "country_solution"
      )) &&
      wlv13_cross_engine_nonempty(baseline, c(
        "names", "sector_solution", "country_solution"
      )) &&
      !anyDuplicated(candidate[["names"]]) &&
      !anyDuplicated(baseline[["names"]]) &&
      identical(
        wlv13_cross_engine_solution_projection(candidate),
        wlv13_cross_engine_solution_projection(baseline)
      )
    comparison <- "normalized-indicator-aggregation-contract"
  } else if (identical(name, "_scientific_checks.csv")) {
    allowed_status <- c("pass", "warning", "not_applicable")
    candidate_ok <- schema_valid && nrow(candidate) > 0L &&
      all(candidate[["status"]] %in% allowed_status)
    baseline_ok <- schema_valid && nrow(baseline) > 0L &&
      all(baseline[["status"]] %in% allowed_status)
    valid <- candidate_ok && baseline_ok && identical(
      wlv13_table_row_keys(wlv13_cross_engine_check_projection(candidate)),
      wlv13_table_row_keys(wlv13_cross_engine_check_projection(baseline))
    )
    comparison <- "normalized-scientific-check-multiset"
  } else if (identical(name, "_unit_contract.csv")) {
    valid <- schema_valid &&
      wlv13_cross_engine_nonempty(candidate, c(
        "contract", "schema_version", "source", "indicator", "quantity_kind",
        "source_unit", "source_scale", "canonical_unit", "display_unit",
        "display_multiplier", "level", "strategy"
      )) &&
      wlv13_cross_engine_nonempty(baseline, c(
        "contract", "schema_version", "source", "indicator", "quantity_kind",
        "source_unit", "source_scale", "canonical_unit", "display_unit",
        "display_multiplier", "level", "strategy"
      )) &&
      identical(
        wlv13_table_row_keys(wlv13_cross_engine_unit_projection(candidate)),
        wlv13_table_row_keys(wlv13_cross_engine_unit_projection(baseline))
      )
    comparison <- "normalized-unit-contract"
  } else {
    stop(sprintf("Unknown cross-engine normalization rule: %s.", name),
      call. = FALSE
    )
  }
  list(
    summary = list(
      passed = valid,
      comparison_mode = comparison,
      candidate_schema_valid = left_parsed$schema_valid,
      baseline_schema_valid = right_parsed$schema_valid,
      candidate_rows = nrow(candidate),
      baseline_rows = nrow(baseline),
      raw_semantic_equal = identical(candidate, baseline),
      architecture_difference = !identical(candidate, baseline)
    ),
    transitions = data.frame(),
    indicators = data.frame()
  )
}

wlv13_compare_identity <- function(left, right) {
  if (identical(left$kind, "run") && identical(right$kind, "run")) {
    left_contract <- left$identity$output_contract
    right_contract <- right$identity$output_contract
    return(list(
      passed = identical(left$identity$method, right$identity$method) &&
        identical(left_contract, right_contract),
      candidate_method = left$identity$method,
      baseline_method = right$identity$method,
      candidate_output_contract = left_contract,
      baseline_output_contract = right_contract
    ))
  }
  if (identical(left$kind, "source") && identical(right$kind, "source")) {
    return(list(
      passed = identical(left$identity$contract_id, right$identity$contract_id) &&
        identical(left$identity$contract_version,
          right$identity$contract_version),
      candidate_contract_id = as.list(left$identity$contract_id),
      baseline_contract_id = as.list(right$identity$contract_id),
      candidate_contract_version = as.list(left$identity$contract_version),
      baseline_contract_version = as.list(right$identity$contract_version)
    ))
  }
  list(passed = identical(left$kind, right$kind),
    candidate_kind = left$kind, baseline_kind = right$kind)
}

wlv13_compare_inventories <- function(candidate, baseline, chunk_rows,
                                      scenario_id,
                                      comparison_mode = c(
                                        "strict", "cross_engine_run_v3"
                                      )) {
  chunk_rows <- wlv13_integer(chunk_rows, "chunk_rows", 1L)
  scenario_id <- wlv13_id(scenario_id, "scenario_id")
  comparison_mode <- match.arg(comparison_mode)
  cross_engine <- identical(comparison_mode, "cross_engine_run_v3")
  if (cross_engine && (!identical(candidate$kind, "run") ||
      !identical(baseline$kind, "run"))) {
    stop("cross_engine_run_v3 accepts only authenticated run inventories.",
      call. = FALSE
    )
  }
  candidate_descriptors <- wlv13_artifact_descriptors(candidate)
  baseline_descriptors <- wlv13_artifact_descriptors(baseline)
  candidate_keys <- names(candidate_descriptors)
  baseline_keys <- names(baseline_descriptors)
  missing_candidate <- setdiff(baseline_keys, candidate_keys)
  extra_candidate <- setdiff(candidate_keys, baseline_keys)
  rules <- if (cross_engine) wlv13_cross_engine_run_rules() else NULL
  allowed_candidate_only <- if (cross_engine) {
    intersect(extra_candidate, rules$candidate_only)
  } else {
    character()
  }
  unexpected_extra_candidate <- setdiff(extra_candidate, allowed_candidate_only)
  shared <- intersect(candidate_keys, baseline_keys)
  identity <- wlv13_compare_identity(candidate, baseline)
  summaries <- list()
  transitions <- list()
  indicators <- list()
  for (key in shared) {
    left <- candidate_descriptors[[key]]
    right <- baseline_descriptors[[key]]
    role_match <- identical(left$role, right$role)
    type_match <- identical(left$type, right$type)
    result <- if (!type_match) {
      list(summary = list(passed = FALSE, reason = "artifact-type-mismatch"),
        transitions = data.frame(), indicators = data.frame())
    } else if (cross_engine && identical(key, "file:_anomalies.csv")) {
      wlv13_cross_engine_compare_anomalies(
        left, right, candidate_descriptors, candidate$identity$method
      )
    } else if (cross_engine && key %in% setdiff(
      rules$normalized, "file:_anomalies.csv"
    )) {
      wlv13_cross_engine_compare_config(left, right, sub("^file:", "", key))
    } else if (identical(left$type, "fst_array")) {
      value <- wlv13_compare_fst_array(left, right, chunk_rows)
      value$summary$meta_role_match <- identical(left$meta_role, right$meta_role)
      value$summary$passed <- isTRUE(value$summary$passed) &&
        isTRUE(value$summary$meta_role_match)
      value
    } else if (identical(left$type, "fst_table")) {
      wlv13_compare_fst_table(left, right, chunk_rows)
    } else {
      list(
        summary = wlv13_compare_small_artifact(left, right),
        transitions = data.frame(),
        indicators = data.frame()
      )
    }
    result$summary$key <- key
    result$summary$type <- left$type
    result$summary$candidate_path <- left$relative
    result$summary$baseline_path <- right$relative
    result$summary$role_match <- role_match
    result$summary$passed <- isTRUE(result$summary$passed) && role_match
    summaries[[key]] <- result$summary
    if (nrow(result$transitions)) {
      result$transitions$artifact <- key
      transitions[[key]] <- result$transitions
    }
    if (nrow(result$indicators)) {
      result$indicators$artifact <- key
      indicators[[key]] <- result$indicators
    }
  }
  if (length(allowed_candidate_only)) {
    for (key in allowed_candidate_only) {
      descriptor <- candidate_descriptors[[key]]
      validation <- wlv13_cross_engine_validate_nonfinite(
        descriptor, candidate$identity$method
      )
      validation$value <- NULL
      validation$key <- key
      validation$type <- descriptor$type
      validation$candidate_path <- descriptor$relative
      validation$baseline_path <- ""
      validation$role_match <- identical(descriptor$role, "diagnostic")
      validation$passed <- isTRUE(validation$passed) &&
        isTRUE(validation$role_match)
      summaries[[key]] <- validation
    }
  }
  artifact_passed <- !length(missing_candidate) &&
    !length(unexpected_extra_candidate) &&
    all(vapply(summaries, function(value) isTRUE(value$passed), logical(1L)))
  passed <- isTRUE(identity$passed) && artifact_passed
  architecture_differences <- names(summaries)[vapply(
    summaries,
    function(value) isTRUE(value$architecture_difference),
    logical(1L)
  )]
  list(
    schema = wlv13_schema$comparison,
    scenario_id = scenario_id,
    status = if (passed) "passed" else "failed",
    passed = passed,
    compared_at = wlv13_now(),
    chunk_rows = chunk_rows,
    comparison_mode = comparison_mode,
    candidate = list(
      kind = candidate$kind,
      root = candidate$root,
      manifest_path = candidate$manifest_path,
      manifest_sha256 = candidate$manifest_sha256,
      inventory_sha256 = wlv13_inventory_signature(candidate),
      identity = candidate$identity
    ),
    baseline = list(
      kind = baseline$kind,
      root = baseline$root,
      manifest_path = baseline$manifest_path,
      manifest_sha256 = baseline$manifest_sha256,
      inventory_sha256 = wlv13_inventory_signature(baseline),
      identity = baseline$identity
    ),
    identity = identity,
    missing_candidate_artifacts = as.list(missing_candidate),
    extra_candidate_artifacts = as.list(unexpected_extra_candidate),
    allowed_candidate_only_artifacts = as.list(allowed_candidate_only),
    architecture_differences = as.list(architecture_differences),
    artifact_count = length(summaries),
    artifacts = unname(summaries),
    transitions = if (length(transitions)) do.call(rbind, transitions) else
      data.frame(),
    indicator_differences = if (length(indicators)) do.call(rbind, indicators) else
      data.frame(),
    policy_exceptions = list()
  )
}

wlv13_write_comparison_csv_once <- function(value, path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  directory <- wlv13_normalize_existing_dir(dirname(path),
    "comparison CSV directory"
  )
  path <- file.path(directory, basename(path))
  if (file.exists(path) || dir.exists(path)) {
    stop(sprintf("Refusing to overwrite comparison CSV: %s.", path),
      call. = FALSE
    )
  }
  temporary <- tempfile(
    pattern = paste0(".", basename(path), "-"),
    tmpdir = directory,
    fileext = ".tmp"
  )
  on.exit(if (file.exists(temporary)) unlink(temporary, force = TRUE), add = TRUE)
  utils::write.csv(value, temporary,
    row.names = FALSE, fileEncoding = "UTF-8", na = ""
  )
  if (!file.exists(temporary) || isTRUE(file.info(temporary)$isdir)) {
    stop(sprintf("Comparison CSV staging was not materialized: %s.", path),
      call. = FALSE
    )
  }
  if (file.exists(path) || dir.exists(path) ||
      !file.rename(temporary, path)) {
    stop(sprintf("Cannot atomically install comparison CSV: %s.", path),
      call. = FALSE
    )
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

wlv13_write_comparison_outputs <- function(report, output_dir) {
  output_dir <- wlv13_ensure_dir(output_dir, "comparison output directory")
  output_names <- c(
    "artifact-summary.csv",
    "state-transitions.csv",
    "indicator-differences.csv",
    "comparison.json"
  )
  output_paths <- file.path(output_dir, output_names)
  existing <- file.exists(output_paths) | dir.exists(output_paths)
  if (any(existing)) {
    stop(sprintf(
      "Refusing to overwrite comparison output(s): %s.",
      paste(output_names[existing], collapse = ", ")
    ), call. = FALSE)
  }
  artifact_rows <- lapply(report$artifacts, function(value) {
    data.frame(
      key = value$key,
      type = value$type,
      candidate_path = value$candidate_path,
      baseline_path = value$baseline_path,
      passed = isTRUE(value$passed),
      mismatch_count = if (is.null(value$mismatch_count)) NA_real_ else
        as.numeric(value$mismatch_count),
      first_mismatch_coordinate = if (is.null(value$first_mismatch_coordinate))
        "" else value$first_mismatch_coordinate,
      stringsAsFactors = FALSE
    )
  })
  artifacts <- if (length(artifact_rows)) do.call(rbind, artifact_rows) else
    data.frame()
  wlv13_write_comparison_csv_once(
    artifacts,
    file.path(output_dir, "artifact-summary.csv")
  )
  wlv13_write_comparison_csv_once(
    report$transitions,
    file.path(output_dir, "state-transitions.csv")
  )
  wlv13_write_comparison_csv_once(
    report$indicator_differences,
    file.path(output_dir, "indicator-differences.csv")
  )
  report_path <- file.path(output_dir, "comparison.json")
  wlv13_json_write(report, report_path)
  invisible(report_path)
}
