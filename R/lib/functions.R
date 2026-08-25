newDim <- function(x, dimensions) {
  # return a variable with changed dimensions
  dim(x) <- dimensions
  return(x)
}

wlv_euklems_country_codes <- function(countries) {
  if (
    !is.character(countries) ||
    !length(countries) ||
    anyNA(countries) ||
    any(!nzchar(countries))
  ) {
    stop("`countries` must contain non-empty ISO3 country codes.", call. = FALSE)
  }

  countrycode::countrycode(
    countries,
    origin = "iso3c",
    destination = "iso2c",
    custom_match = c(
      GBR = "UK",
      GRC = "EL",
      ROW = NA_character_
    )
  )
}

wlv_wiodr13_euklems_country_codes <- function(countries) {
  wlv_euklems_country_codes(countries)
}

wlv_wiodr16_euklems_country_codes <- function(countries) {
  wlv_euklems_country_codes(countries)
}

wlv_wiodr16_gfcf_columns <- function(column_labels, countries) {
  if (
    !is.character(column_labels) ||
    anyNA(column_labels) ||
    any(!nzchar(column_labels))
  ) {
    stop("`column_labels` must contain non-empty labels.", call. = FALSE)
  }
  if (
    !is.character(countries) ||
    !length(countries) ||
    anyNA(countries) ||
    any(!nzchar(countries)) ||
    anyDuplicated(countries)
  ) {
    stop("`countries` must contain unique, non-empty codes.", call. = FALSE)
  }

  expected <- paste0(countries, ".c60")
  counts <- vapply(expected, function(label) sum(column_labels == label), integer(1))
  if (any(counts != 1L)) {
    invalid <- sprintf("%s (%s found)", expected[counts != 1L], counts[counts != 1L])
    stop(
      sprintf(
        paste0(
          "WIOD16 requires exactly one GFCF column `<country>.c60` per country; ",
          "invalid: %s."
        ),
        paste(invalid, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  match(expected, column_labels)
}

wlv_read_wiodr16_china_hours_per_worker <- function(
    path,
    expected_codes,
    expected_names,
    expected_years = as.character(2000:2014)) {
  canonical_years <- as.character(2000:2014)
  if (!identical(as.character(expected_years), canonical_years)) {
    stop(
      "WIOD16 China hours require the complete ordered period 2000-2014.",
      call. = FALSE
    )
  }
  if (
    !is.character(expected_codes) ||
    length(expected_codes) != 56L ||
    anyNA(expected_codes) ||
    any(!nzchar(expected_codes)) ||
    anyDuplicated(expected_codes)
  ) {
    stop(
      "WIOD16 China hours require 56 unique, non-empty sector codes.",
      call. = FALSE
    )
  }
  if (
    !is.character(expected_names) ||
    length(expected_names) != length(expected_codes) ||
    anyNA(expected_names) ||
    any(!nzchar(trimws(expected_names)))
  ) {
    stop(
      "WIOD16 China hours require one non-empty name per sector code.",
      call. = FALSE
    )
  }
  if (!file.exists(path)) {
    stop(sprintf("Missing WIOD16 China hours file: %s", path), call. = FALSE)
  }

  value <- tryCatch(
    utils::read.csv2(
      path,
      stringsAsFactors = FALSE,
      check.names = FALSE
    ),
    error = function(error) {
      stop(
        sprintf(
          "Cannot read WIOD16 China hours file `%s`: %s",
          path,
          conditionMessage(error)
        ),
        call. = FALSE
      )
    }
  )
  expected_columns <- c("setor", "code", canonical_years)
  if (!identical(names(value), expected_columns)) {
    stop(
      sprintf(
        "WIOD16 China hours columns must be exactly: %s.",
        paste(expected_columns, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (!identical(as.character(value$code), expected_codes)) {
    stop(
      "WIOD16 China hours sector codes or their order do not match the method.",
      call. = FALSE
    )
  }
  if (!identical(trimws(as.character(value$setor)), trimws(expected_names))) {
    stop(
      "WIOD16 China hours sector names or their order do not match the method.",
      call. = FALSE
    )
  }
  if (!all(vapply(value[canonical_years], is.numeric, logical(1)))) {
    stop("WIOD16 China hours contain a non-numeric year column.", call. = FALSE)
  }

  hours <- as.matrix(value[canonical_years])
  if (anyNA(hours) || any(!is.finite(hours))) {
    stop("WIOD16 China hours must all be finite.", call. = FALSE)
  }
  # Coefficients are thousands of annual hours per person. The upper bound is
  # the number of hours in a leap year, expressed in the same unit.
  if (any(hours < 0 | hours > 8.784)) {
    stop(
      "WIOD16 China hours must be between 0 and 8.784 thousand hours per person.",
      call. = FALSE
    )
  }

  dimnames(hours) <- list(expected_codes, canonical_years)
  t(hours)
}

wlv_distribute_capital_stock <- function(
    weights,
    capital_stock,
    fallback_weights = NULL,
    tolerance = 1e-10) {
  if (
    !is.matrix(weights) || !is.numeric(weights) || anyNA(weights) ||
    any(!is.finite(weights))
  ) {
    stop("`weights` must be a finite numeric matrix.", call. = FALSE)
  }
  if (
    !is.numeric(capital_stock) ||
    length(capital_stock) != ncol(weights) ||
    anyNA(capital_stock) ||
    any(!is.finite(capital_stock))
  ) {
    stop(
      "`capital_stock` must contain one finite number per weight column.",
      call. = FALSE
    )
  }
  if (
    length(tolerance) != 1L || !is.numeric(tolerance) || is.na(tolerance) ||
    !is.finite(tolerance) || tolerance < 0
  ) {
    stop("`tolerance` must be one finite non-negative number.", call. = FALSE)
  }

  totals <- colSums(weights)
  invalid_columns <- totals == 0
  fallback_columns <- which(invalid_columns & capital_stock != 0)
  if (length(fallback_columns)) {
    if (
      is.null(fallback_weights) || !is.matrix(fallback_weights) ||
      !is.numeric(fallback_weights) ||
      !identical(dim(fallback_weights), dim(weights)) ||
      anyNA(fallback_weights) || any(!is.finite(fallback_weights)) ||
      any(fallback_weights < 0)
    ) {
      stop(
        paste0(
          "Positive or negative capital stock without primary weights requires ",
          "a conformable finite non-negative fallback matrix."
        ),
        call. = FALSE
      )
    }
    fallback_totals <- colSums(fallback_weights)
    unresolved <- fallback_columns[fallback_totals[fallback_columns] <= 0]
    if (length(unresolved)) {
      stop(
        sprintf(
          "Capital stock has no primary or fallback weights in column(s): %s.",
          paste(unresolved, collapse = ", ")
        ),
        call. = FALSE
      )
    }
    weights[, fallback_columns] <- fallback_weights[, fallback_columns, drop = FALSE]
    totals[fallback_columns] <- fallback_totals[fallback_columns]
  }
  distribution <- sweep(weights, 2L, totals, "/")
  zero_stock_columns <- totals == 0 & capital_stock == 0
  distribution[, zero_stock_columns] <- 0
  if (any(!is.finite(distribution))) {
    stop("Capital-stock weights produced a non-finite distribution.", call. = FALSE)
  }
  result <- sweep(distribution, 2L, capital_stock, "*")
  residual <- abs(colSums(result) - capital_stock)
  if (any(residual > tolerance * pmax(1, abs(capital_stock)))) {
    stop("Capital-stock allocation does not conserve column totals.", call. = FALSE)
  }
  attr(result, "wlv.fallback_columns") <- fallback_columns
  result
}

wlv_add_synthetic_depreciation_component <- function(
    aggregate_rate,
    component_rate,
    component_stock,
    aggregate_stock,
    direct_rate_provided) {
  numeric_values <- list(
    aggregate_rate = aggregate_rate,
    component_rate = component_rate,
    component_stock = component_stock,
    aggregate_stock = aggregate_stock
  )
  dimensions <- lapply(numeric_values, dim)
  if (
    any(!vapply(numeric_values, is.numeric, logical(1))) ||
    any(vapply(dimensions, is.null, logical(1))) ||
    !all(vapply(dimensions[-1L], identical, logical(1), dimensions[[1L]])) ||
    !is.logical(direct_rate_provided) ||
    !identical(dim(direct_rate_provided), dimensions[[1L]]) ||
    anyNA(direct_rate_provided)
  ) {
    stop(
      paste0(
        "Depreciation rates, stocks and the direct-rate mask must be ",
        "conformable numeric/logical matrices."
      ),
      call. = FALSE
    )
  }

  invalid_input <- vapply(
    numeric_values,
    function(value) anyNA(value) || any(!is.finite(value)),
    logical(1L)
  )
  if (any(invalid_input)) {
    stop("Depreciation rates and stocks must be finite.", call. = FALSE)
  }
  zero_stock <- aggregate_stock == 0
  invalid_zero <- zero_stock & component_stock != 0
  if (any(invalid_zero)) {
    stop(
      "A positive depreciation component cannot have zero aggregate stock.",
      call. = FALSE
    )
  }
  weighted_component <- component_rate * component_stock
  weighted_component[!zero_stock] <-
    weighted_component[!zero_stock] / aggregate_stock[!zero_stock]
  weighted_component[zero_stock] <- 0
  synthesize <- !direct_rate_provided
  aggregate_rate[synthesize] <-
    aggregate_rate[synthesize] + weighted_component[synthesize]
  aggregate_rate
}

wlv_sum_input_flows <- function(
    intermediate_consumption,
    depreciation,
    structural_missing = NULL) {
  if (
    !is.numeric(intermediate_consumption) || !is.numeric(depreciation) ||
    !identical(dim(intermediate_consumption), dim(depreciation))
  ) {
    stop("Input-flow arrays must be conformable numeric values.", call. = FALSE)
  }
  if (anyNA(intermediate_consumption) || any(!is.finite(intermediate_consumption))) {
    stop("Intermediate consumption must be fully finite.", call. = FALSE)
  }
  if (any(is.nan(depreciation)) || any(is.infinite(depreciation))) {
    stop("Depreciation contains NaN or infinite values.", call. = FALSE)
  }
  if (is.null(structural_missing)) {
    structural_missing <- rep(FALSE, length(depreciation))
    dim(structural_missing) <- dim(depreciation)
  }
  if (
    !is.logical(structural_missing) || anyNA(structural_missing) ||
    !identical(dim(structural_missing), dim(depreciation))
  ) {
    stop("`structural_missing` must be a conformable logical mask.", call. = FALSE)
  }
  unexpected <- is.na(depreciation) & !structural_missing
  if (any(unexpected)) {
    stop("Depreciation contains an undeclared missing value.", call. = FALSE)
  }
  if (any(structural_missing & !is.na(depreciation))) {
    stop("The depreciation structural-missing mask is not exact.", call. = FALSE)
  }
  depreciation[structural_missing] <- 0
  intermediate_consumption + depreciation
}

cnames <- function(a,b) {
  #match column named "names"  from a and b
  match(a$names,b$names)
}

wlv_fst_sidecar_schema_version <- function() {
  "1"
}

wlv_fst_file_sha256 <- function(path) {
  if (
    !is.character(path) || length(path) != 1L || is.na(path) ||
    !nzchar(path) || !file.exists(path) || isTRUE(file.info(path)$isdir)
  ) {
    stop(sprintf("Cannot hash FST file: %s", path), call. = FALSE)
  }
  if (!requireNamespace("openssl", quietly = TRUE)) {
    stop(
      "Package `openssl` is required to verify FST array bundles.",
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

wlv_fst_validate_dimnames <- function(value, dimensions, file_name) {
  if (is.null(value)) {
    return(NULL)
  }
  if (!is.list(value) || length(value) != length(dimensions)) {
    stop(
      sprintf(
        "Invalid FST sidecar metadata for `%s`: dimnames must contain one entry per dimension.",
        file_name
      ),
      call. = FALSE
    )
  }

  for (index in seq_along(dimensions)) {
    labels <- value[[index]]
    if (
      !is.null(labels) &&
      (!is.character(labels) || length(labels) != dimensions[[index]])
    ) {
      stop(
        sprintf(
          paste0(
            "Invalid FST sidecar metadata for `%s`: dimnames entry %s ",
            "must be NULL or contain exactly %s character labels."
          ),
          file_name,
          index,
          dimensions[[index]]
        ),
        call. = FALSE
      )
    }
  }

  value
}

wlv_fst_legacy_dimnames <- function(metadata, dimensions) {
  dimension_count <- length(dimensions)
  available_count <- min(dimension_count, max(0L, length(metadata) - 1L))
  if (available_count == 0L) {
    return(NULL)
  }

  value <- rep(list(NULL), dimension_count)
  source_indices <- seq.int(2L, length.out = available_count)
  value[seq_len(available_count)] <- metadata[source_indices]

  metadata_names <- names(metadata)
  if (!is.null(metadata_names)) {
    dimension_names <- rep("", dimension_count)
    provided_names <- metadata_names[source_indices]
    provided_names[is.na(provided_names)] <- ""
    dimension_names[seq_len(available_count)] <- provided_names
    if (any(nzchar(dimension_names))) {
      names(value) <- dimension_names
    }
  }

  value
}

wlv_fst_parse_sidecar <- function(metadata, file_name) {
  if (!is.list(metadata) || !length(metadata) || !identical(names(metadata)[[1L]], "dim")) {
    stop(
      sprintf(
        "Invalid FST sidecar metadata for `%s`: expected a list beginning with `dim`.",
        file_name
      ),
      call. = FALSE
    )
  }

  dimensions <- metadata[[1L]]
  if (
    !is.numeric(dimensions) || !length(dimensions) || anyNA(dimensions) ||
    any(!is.finite(dimensions)) || any(dimensions < 0) ||
    any(dimensions != floor(dimensions)) ||
    any(dimensions > .Machine$integer.max)
  ) {
    stop(
      sprintf(
        "Invalid FST sidecar metadata for `%s`: `dim` must contain non-negative integers.",
        file_name
      ),
      call. = FALSE
    )
  }
  dimensions <- as.integer(dimensions)
  expected_length <- prod(as.double(dimensions))
  if (!is.finite(expected_length)) {
    stop(
      sprintf(
        "Invalid FST sidecar metadata for `%s`: dimensions are too large.",
        file_name
      ),
      call. = FALSE
    )
  }

  legacy_field_count <- length(dimensions) + 1L
  if (length(metadata) <= legacy_field_count) {
    array_dimnames <- wlv_fst_legacy_dimnames(metadata, dimensions)
    array_dimnames <- wlv_fst_validate_dimnames(
      array_dimnames,
      dimensions,
      file_name
    )
    return(list(
      dimensions = dimensions,
      dimnames = array_dimnames,
      expected_length = expected_length,
      fst_sha256 = NULL,
      legacy = TRUE
    ))
  }

  extra <- metadata[seq.int(legacy_field_count + 1L, length(metadata))]
  expected_fields <- c("schema_version", "fst_sha256", "array_dimnames")
  if (!identical(names(extra), expected_fields)) {
    stop(
      sprintf(
        paste0(
          "Invalid FST sidecar metadata for `%s`: versioned metadata fields ",
          "must be exactly %s."
        ),
        file_name,
        paste(expected_fields, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (!identical(extra[[1L]], wlv_fst_sidecar_schema_version())) {
    stop(
      sprintf(
        "Unsupported FST sidecar schema version for `%s`: %s.",
        file_name,
        paste(extra[[1L]], collapse = ", ")
      ),
      call. = FALSE
    )
  }
  fst_sha256 <- extra[[2L]]
  if (
    !is.character(fst_sha256) || length(fst_sha256) != 1L ||
    is.na(fst_sha256) || !grepl("^[0-9a-f]{64}$", fst_sha256)
  ) {
    stop(
      sprintf(
        "Invalid FST sidecar metadata for `%s`: `fst_sha256` must be a lowercase SHA-256 hash.",
        file_name
      ),
      call. = FALSE
    )
  }
  array_dimnames <- wlv_fst_validate_dimnames(
    extra[[3L]],
    dimensions,
    file_name
  )

  list(
    dimensions = dimensions,
    dimnames = array_dimnames,
    expected_length = expected_length,
    fst_sha256 = fst_sha256,
    legacy = FALSE
  )
}

wlv_fst_read_bundle <- function(file_name) {
  if (
    !is.character(file_name) || length(file_name) != 1L ||
    is.na(file_name) || !nzchar(file_name)
  ) {
    stop("`file_name` must be one non-empty path.", call. = FALSE)
  }
  if (!file.exists(file_name) || isTRUE(file.info(file_name)$isdir)) {
    stop(sprintf("FST array file does not exist: %s", file_name), call. = FALSE)
  }

  metadata_path <- paste0(file_name, ".meta")
  if (!file.exists(metadata_path) || isTRUE(file.info(metadata_path)$isdir)) {
    stop(
      sprintf(
        "FST array sidecar metadata is missing: %s",
        metadata_path
      ),
      call. = FALSE
    )
  }
  metadata <- tryCatch(
    readRDS(metadata_path),
    error = function(error) {
      stop(
        sprintf(
          "Cannot read FST sidecar metadata `%s`: %s",
          metadata_path,
          conditionMessage(error)
        ),
        call. = FALSE
      )
    }
  )
  contract <- wlv_fst_parse_sidecar(metadata, file_name)

  if (!is.null(contract$fst_sha256)) {
    actual_sha256 <- wlv_fst_file_sha256(file_name)
    if (!identical(actual_sha256, contract$fst_sha256)) {
      stop(
        sprintf(
          paste0(
            "FST array SHA-256 mismatch for `%s`: expected %s, found %s. ",
            "The data file and its sidecar do not form a valid bundle."
          ),
          file_name,
          contract$fst_sha256,
          actual_sha256
        ),
        call. = FALSE
      )
    }
  }

  table <- tryCatch(
    fst::read_fst(file_name),
    error = function(error) {
      stop(
        sprintf(
          "Cannot read FST array data `%s`: %s",
          file_name,
          conditionMessage(error)
        ),
        call. = FALSE
      )
    }
  )
  if (!is.data.frame(table) || ncol(table) != 1L) {
    stop(
      sprintf(
        "Invalid FST array data `%s`: expected exactly one column.",
        file_name
      ),
      call. = FALSE
    )
  }
  if (nrow(table) != contract$expected_length) {
    stop(
      sprintf(
        paste0(
          "FST array length mismatch for `%s`: sidecar dimensions require ",
          "%s values, found %s."
        ),
        file_name,
        format(contract$expected_length, scientific = FALSE),
        format(nrow(table), scientific = FALSE)
      ),
      call. = FALSE
    )
  }

  value <- table[[1L]]
  dim(value) <- contract$dimensions
  if (!is.null(contract$dimnames)) {
    dimnames(value) <- contract$dimnames
  }
  value
}

read_fst_array <- function(file_name) {
  wlv_fst_read_bundle(file_name)
}

wlv_fst_sidecar <- function(value, fst_sha256, drop_axis_names = FALSE) {
  if (!is.logical(drop_axis_names) || length(drop_axis_names) != 1L ||
      is.na(drop_axis_names)) {
    stop("`drop_axis_names` must be TRUE or FALSE.", call. = FALSE)
  }
  dimensions <- dim(value)
  array_dimnames <- dimnames(value)
  if (isTRUE(drop_axis_names) && !is.null(array_dimnames)) {
    # The names belong to the (small) dimnames list, not to the numeric array.
    # Dropping them here preserves the public sidecar contract without forcing
    # a second copy of a potentially multi-gigabyte array.
    names(array_dimnames) <- NULL
  }
  legacy_dimnames <- if (is.null(array_dimnames)) {
    rep(list(NULL), length(dimensions))
  } else {
    array_dimnames
  }

  metadata <- vector("list", length(dimensions) + 1L)
  metadata[[1L]] <- dimensions
  metadata[seq.int(2L, length.out = length(dimensions))] <- legacy_dimnames
  # Positional dimnames preserve the legacy layout. Their list names are kept
  # only in `array_dimnames`, so they cannot collide with schema field names.
  names(metadata) <- c("dim", rep("", length(dimensions)))

  c(
    metadata,
    list(
      schema_version = wlv_fst_sidecar_schema_version(),
      fst_sha256 = fst_sha256,
      array_dimnames = array_dimnames
    )
  )
}

wlv_fst_arrays_identical <- function(
    actual,
    expected,
    drop_axis_names = FALSE) {
  actual_dimnames <- dimnames(actual)
  expected_dimnames <- dimnames(expected)
  if (isTRUE(drop_axis_names) && !is.null(expected_dimnames)) {
    names(expected_dimnames) <- NULL
  }
  identical(dim(actual), dim(expected)) &&
    identical(actual_dimnames, expected_dimnames) &&
    identical(as.vector(actual), as.vector(expected))
}

wlv_fst_install_bundle <- function(
    temporary_data,
    temporary_metadata,
    destination_data,
    expected_sha256) {
  destination_metadata <- paste0(destination_data, ".meta")
  destinations <- c(destination_data, destination_metadata)
  temporary_paths <- c(temporary_data, temporary_metadata)
  if (any(!file.exists(temporary_paths))) {
    stop("Cannot install an incomplete FST array bundle.", call. = FALSE)
  }
  existing_directories <- destinations[
    file.exists(destinations) & file.info(destinations)$isdir %in% TRUE
  ]
  if (length(existing_directories)) {
    stop(
      sprintf(
        "Cannot replace FST bundle path(s) that are directories: %s",
        paste(existing_directories, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  backups <- vapply(
    destinations,
    function(path) {
      tempfile(
        pattern = ".wlv-fst-backup-",
        tmpdir = dirname(path)
      )
    },
    character(1L),
    USE.NAMES = FALSE
  )
  moved_previous <- rep(FALSE, length(destinations))
  installed <- rep(FALSE, length(destinations))
  transaction_complete <- FALSE

  on.exit({
    if (!transaction_complete) {
      recovery_failures <- character()
      for (index in rev(which(installed))) {
        if (
          file.exists(destinations[[index]]) &&
          unlink(destinations[[index]], force = TRUE) != 0L
        ) {
          recovery_failures <- c(recovery_failures, destinations[[index]])
        }
      }
      for (index in rev(which(moved_previous))) {
        if (
          file.exists(backups[[index]]) &&
          (!file.rename(backups[[index]], destinations[[index]]))
        ) {
          recovery_failures <- c(recovery_failures, destinations[[index]])
        }
      }
      if (length(recovery_failures)) {
        message(
          sprintf(
            "Could not fully recover FST bundle path(s): %s",
            paste(unique(recovery_failures), collapse = ", ")
          )
        )
      }
    }
  }, add = TRUE)

  for (index in seq_along(destinations)) {
    if (file.exists(destinations[[index]])) {
      if (!file.rename(destinations[[index]], backups[[index]])) {
        stop(
          sprintf(
            "Cannot move the previous FST bundle file aside: %s",
            destinations[[index]]
          ),
          call. = FALSE
        )
      }
      moved_previous[[index]] <- TRUE
    }
  }

  # Install metadata first. An abrupt interruption can then never expose a new
  # FST payload without a sidecar, and the checksum rejects mismatched pairs.
  installation_order <- c(2L, 1L)
  for (index in installation_order) {
    if (!file.rename(temporary_paths[[index]], destinations[[index]])) {
      stop(
        sprintf(
          "Cannot install verified FST bundle file at: %s",
          destinations[[index]]
        ),
        call. = FALSE
      )
    }
    installed[[index]] <- TRUE
  }

  installed_metadata <- tryCatch(
    readRDS(destination_metadata),
    error = function(error) NULL
  )
  installed_contract <- if (is.null(installed_metadata)) {
    NULL
  } else {
    tryCatch(
      wlv_fst_parse_sidecar(installed_metadata, destination_data),
      error = function(error) NULL
    )
  }
  installed_sha256 <- tryCatch(
    wlv_fst_file_sha256(destination_data),
    error = function(error) NA_character_
  )
  if (
    is.null(installed_contract) ||
    !identical(installed_contract$fst_sha256, expected_sha256) ||
    !identical(installed_sha256, expected_sha256)
  ) {
    stop(
      sprintf(
        "Installed FST array bundle failed final verification: %s",
        destination_data
      ),
      call. = FALSE
    )
  }
  transaction_complete <- TRUE

  remaining_backups <- backups[file.exists(backups)]
  if (length(remaining_backups) && unlink(remaining_backups, force = TRUE) != 0L) {
    message(
      sprintf(
        "Could not remove replaced FST bundle backup(s): %s",
        paste(remaining_backups, collapse = ", ")
      )
    )
  }

  invisible(destination_data)
}

write_fst_array <- function(m, file_name, drop_axis_names = FALSE) {
  if (!is.array(m)) {
    stop("`m` must be an array or matrix.", call. = FALSE)
  }
  if (
    !is.character(file_name) || length(file_name) != 1L ||
    is.na(file_name) || !nzchar(file_name)
  ) {
    stop("`file_name` must be one non-empty path.", call. = FALSE)
  }
  if (!is.logical(drop_axis_names) || length(drop_axis_names) != 1L ||
      is.na(drop_axis_names)) {
    stop("`drop_axis_names` must be TRUE or FALSE.", call. = FALSE)
  }
  destination_directory <- dirname(file_name)
  if (!dir.exists(destination_directory)) {
    stop(
      sprintf(
        "FST array destination directory does not exist: %s",
        destination_directory
      ),
      call. = FALSE
    )
  }
  if (!requireNamespace("openssl", quietly = TRUE)) {
    stop(
      "Package `openssl` is required to write verifiable FST array bundles.",
      call. = FALSE
    )
  }

  temporary_data <- tempfile(
    pattern = ".wlv-fst-write-",
    tmpdir = destination_directory,
    fileext = ".fst"
  )
  temporary_metadata <- paste0(temporary_data, ".meta")
  temporary_paths <- c(temporary_data, temporary_metadata)
  on.exit({
    remaining <- temporary_paths[file.exists(temporary_paths)]
    if (length(remaining)) {
      unlink(remaining, force = TRUE)
    }
  }, add = TRUE)

  values <- as.vector(m)
  tryCatch(
    fst::write_fst(
      data.frame(Data = values, check.names = FALSE),
      temporary_data
    ),
    error = function(error) {
      stop(
        sprintf(
          "Cannot write temporary FST array data for `%s`: %s",
          file_name,
          conditionMessage(error)
        ),
        call. = FALSE
      )
    }
  )
  rm(values)
  if (
    !file.exists(temporary_data) || is.na(file.info(temporary_data)$size) ||
    file.info(temporary_data)$size <= 0
  ) {
    stop(
      sprintf("FST writer produced no data for `%s`.", file_name),
      call. = FALSE
    )
  }

  fst_sha256 <- wlv_fst_file_sha256(temporary_data)
  metadata <- wlv_fst_sidecar(
    m,
    fst_sha256,
    drop_axis_names = drop_axis_names
  )
  tryCatch(
    saveRDS(metadata, temporary_metadata, version = 3L),
    error = function(error) {
      stop(
        sprintf(
          "Cannot write temporary FST sidecar for `%s`: %s",
          file_name,
          conditionMessage(error)
        ),
        call. = FALSE
      )
    }
  )

  round_trip <- wlv_fst_read_bundle(temporary_data)
  if (!wlv_fst_arrays_identical(
    round_trip,
    m,
    drop_axis_names = drop_axis_names
  )) {
    stop(
      sprintf(
        paste0(
          "Temporary FST array bundle failed round-trip validation for `%s`: ",
          "values, dimensions, or dimnames changed."
        ),
        file_name
      ),
      call. = FALSE
    )
  }
  rm(round_trip)

  wlv_fst_install_bundle(
    temporary_data = temporary_data,
    temporary_metadata = temporary_metadata,
    destination_data = file_name,
    expected_sha256 = fst_sha256
  )
  invisible(file_name)
}
