if (!exists(
  "wlv_wiodr_analyze_m_io_negative_gfcf",
  envir = environment(),
  mode = "function",
  inherits = FALSE
)) {
  sys.source("R/lib/gfcf_contracts.R", envir = environment())
}

wlv_wiodr13_validate_labels <- function(values, name) {
  if (!is.character(values) || !length(values)) {
    stop(sprintf("`%s` must be a non-empty character vector.", name), call. = FALSE)
  }
  invalid <- is.na(values) | !nzchar(values)
  if (any(invalid)) {
    stop(sprintf("`%s` contains missing or empty labels.", name), call. = FALSE)
  }
  if (anyDuplicated(values)) {
    duplicates <- unique(values[duplicated(values)])
    stop(
      sprintf("`%s` contains duplicate labels: %s", name, paste(duplicates, collapse = ", ")),
      call. = FALSE
    )
  }
  unname(values)
}

wlv_wiodr13_workbook_missingness_signature <- function(
    sea,
    years = as.character(1995:2009)) {
  identifier_columns <- c("country", "variable", "code")
  required <- c(identifier_columns, years)
  if (!is.data.frame(sea) || length(years) == 0L || anyNA(years) ||
      any(!nzchar(years)) || length(setdiff(required, names(sea)))) {
    stop("Invalid WIOD13 SEA table for missingness signature.", call. = FALSE)
  }
  if (anyNA(sea[identifier_columns])) {
    stop("WIOD13 SEA identifiers contain missing values.", call. = FALSE)
  }
  missing <- which(is.na(as.matrix(sea[years])), arr.ind = TRUE)
  keys <- if (nrow(missing)) {
    sort(
      paste(
        years[missing[, 2L]],
        sea$country[missing[, 1L]],
        sea$variable[missing[, 1L]],
        sea$code[missing[, 1L]],
        sep = "|"
      ),
      method = "radix"
    )
  } else {
    character()
  }
  hash_file <- tempfile("wlv-wiodr13-sea-missing-", fileext = ".txt")
  on.exit(unlink(hash_file), add = TRUE)
  connection <- file(hash_file, open = "wb")
  writeBin(charToRaw(enc2utf8(paste(keys, collapse = "\n"))), connection)
  close(connection)
  by_year <- vapply(
    sea[years],
    function(values) sum(is.na(values)),
    integer(1L)
  )
  list(
    count = length(keys),
    by_year = by_year,
    md5 = unname(tools::md5sum(hash_file))
  )
}

wlv_wiodr13_validate_workbook_missingness <- function(
    sea,
    years = as.character(1995:2009),
    expected_by_year = stats::setNames(
      c(rep(371L, 13L), 1861L, 2073L),
      as.character(1995:2009)
    ),
    expected_count = 8757L,
    expected_md5 = "c6d680700338a625abc5e3df78b61c0a") {
  signature <- wlv_wiodr13_workbook_missingness_signature(sea, years)
  valid <-
    identical(names(signature$by_year), names(expected_by_year)) &&
    identical(as.integer(signature$by_year), as.integer(expected_by_year)) &&
    identical(as.integer(signature$count), as.integer(expected_count)) &&
    identical(signature$md5, expected_md5)
  if (!valid) {
    stop(
      sprintf(
        paste0(
          "WIOD13 SEA missingness differs from the pinned coordinate signature ",
          "(count=%s, md5=%s)."
        ),
        signature$count,
        signature$md5
      ),
      call. = FALSE
    )
  }
  invisible(signature)
}

wlv_wiodr13_expected_dimensions <- function(countries, sectors, demands) {
  countries <- wlv_wiodr13_validate_labels(countries, "countries")
  sectors <- wlv_wiodr13_validate_labels(sectors, "sectors")
  demands <- wlv_wiodr13_validate_labels(demands, "demands")

  inputs <- paste(
    rep(countries, each = length(sectors)),
    rep(sectors, times = length(countries)),
    sep = "."
  )
  final_demand <- paste(
    rep(countries, each = length(demands)),
    rep(demands, times = length(countries)),
    sep = "."
  )

  list(
    countries = countries,
    sectors = sectors,
    demands = demands,
    inputs = inputs,
    outputs = c(inputs, final_demand)
  )
}

wlv_wiodr13_assert_array <- function(value, name, dimensions) {
  if (!is.array(value) || length(dim(value)) != dimensions) {
    stop(sprintf("`%s` must be a %s-dimensional array.", name, dimensions), call. = FALSE)
  }
  if (!is.numeric(value)) {
    stop(sprintf("`%s` must contain numeric data.", name), call. = FALSE)
  }
  invisible(value)
}

wlv_wiodr13_assert_dimnames <- function(value, name, expected) {
  actual <- dimnames(value)
  if (is.null(actual) || length(actual) != length(expected)) {
    stop(sprintf("`%s` must declare all dimension labels.", name), call. = FALSE)
  }

  for (index in seq_along(expected)) {
    labels <- actual[[index]]
    if (is.null(labels) || !identical(unname(as.character(labels)), expected[[index]])) {
      stop(
        sprintf("`%s` has unexpected %s dimnames.", name, names(expected)[[index]]),
        call. = FALSE
      )
    }
  }
  invisible(value)
}

wlv_wiodr13_format_positions <- function(value, failed, maximum = 3L) {
  positions <- which(failed)
  positions <- positions[seq_len(min(length(positions), maximum))]
  coordinates <- arrayInd(positions, .dim = dim(value), .dimnames = dimnames(value))
  apply(coordinates, 1L, paste, collapse = "/")
}

wlv_wiodr13_assert_finite <- function(value, name) {
  failed <- !is.finite(value)
  count <- sum(failed)
  if (count) {
    examples <- wlv_wiodr13_format_positions(value, failed)
    stop(
      sprintf(
        "`%s` contains %s non-finite value(s); example position(s): %s.",
        name,
        count,
        paste(examples, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(value)
}

wlv_wiodr13_assert_sea_missingness <- function(
    sea,
    countries,
    required_variables = c("VA_USD", "GO_USD")) {
  row_index <- which(countries == "ROW")
  if (length(row_index) != 1L) {
    stop("WIOD13 countries must contain exactly one `ROW` entry.", call. = FALSE)
  }

  invalid_numeric <- is.nan(sea) | is.infinite(sea)
  if (any(invalid_numeric)) {
    examples <- wlv_wiodr13_format_positions(sea, invalid_numeric)
    stop(
      sprintf(
        "`sea` contains %s NaN or infinite value(s); example position(s): %s.",
        sum(invalid_numeric),
        paste(examples, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  required <- sea[, required_variables, , , drop = FALSE]
  if (any(!is.finite(required))) {
    failed <- !is.finite(required)
    examples <- wlv_wiodr13_format_positions(required, failed)
    stop(
      sprintf(
        paste0(
          "`sea` requires finite VA_USD and GO_USD values for every country; ",
          "missing position(s): %s."
        ),
        paste(examples, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  non_row_countries <- countries[-row_index]
  non_row <- sea[, , , non_row_countries, drop = FALSE]
  if (any(!is.finite(non_row))) {
    failed <- !is.finite(non_row)
    examples <- wlv_wiodr13_format_positions(non_row, failed)
    stop(
      sprintf(
        "`sea` requires finite values outside ROW; missing position(s): %s.",
        paste(examples, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  other_variables <- setdiff(dimnames(sea)[[2L]], required_variables)
  row_other <- sea[, other_variables, , "ROW", drop = FALSE]
  expected_row_na_count <- length(row_other)
  observed_row_na_count <- sum(is.na(row_other))
  if (observed_row_na_count != expected_row_na_count) {
    unexpected <- !is.na(row_other)
    examples <- wlv_wiodr13_format_positions(row_other, unexpected)
    stop(
      sprintf(
        paste0(
          "`sea` expects missing ROW observations for all non-VA/GO variables; ",
          "found %s of %s expected NA values; populated position(s): %s."
        ),
        observed_row_na_count,
        expected_row_na_count,
        paste(examples, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  list(
    expected_row_na_count = expected_row_na_count,
    observed_row_na_count = observed_row_na_count
  )
}

wlv_validate_wiodr13_arrays <- function(
    m_io,
    sea,
    countries,
    sectors,
    demands,
    expected_years = as.character(1995:2009),
    input_unit = "million_usd",
    gfcf_observations = NULL,
    relative_tolerance = 1e-8,
    absolute_tolerance = 1e-6) {
  expected_years <- wlv_wiodr13_validate_labels(
    as.character(expected_years),
    "expected_years"
  )
  labels <- wlv_wiodr13_expected_dimensions(countries, sectors, demands)

  tolerances <- c(relative_tolerance, absolute_tolerance)
  if (
    any(lengths(list(relative_tolerance, absolute_tolerance)) != 1L) ||
    !is.numeric(tolerances) ||
    anyNA(tolerances) ||
    any(!is.finite(tolerances)) ||
    any(tolerances < 0)
  ) {
    stop("Accounting tolerances must be finite, non-negative numbers.", call. = FALSE)
  }

  wlv_wiodr13_assert_array(m_io, "m_io", 3L)
  wlv_wiodr13_assert_array(sea, "sea", 4L)

  sea_variables <- dimnames(sea)[[2L]]
  if (is.null(sea_variables)) {
    stop("`sea` must declare variable dimnames.", call. = FALSE)
  }
  sea_variables <- unname(as.character(sea_variables))
  invalid_variables <- is.na(sea_variables) | !nzchar(sea_variables)
  if (any(invalid_variables) || anyDuplicated(sea_variables)) {
    stop("`sea` variable dimnames must be non-empty and unique.", call. = FALSE)
  }
  required_variables <- c("VA_USD", "GO_USD")
  missing_variables <- setdiff(required_variables, sea_variables)
  if (length(missing_variables)) {
    stop(
      sprintf("`sea` lacks required variable(s): %s", paste(missing_variables, collapse = ", ")),
      call. = FALSE
    )
  }

  wlv_wiodr13_assert_dimnames(
    m_io,
    "m_io",
    list(years = expected_years, inputs = labels$inputs, outputs = labels$outputs)
  )
  wlv_wiodr13_assert_dimnames(
    sea,
    "sea",
    list(
      years = expected_years,
      variables = sea_variables,
      sectors = labels$sectors,
      countries = labels$countries
    )
  )

  wlv_wiodr13_assert_finite(m_io, "m_io")
  wlv_wiodr_gfcf_unit_divisor(input_unit)
  negative_gfcf <- if (is.null(gfcf_observations)) {
    wlv_wiodr_analyze_m_io_negative_gfcf(
      m_io,
      method = "wiodr13",
      input_unit = input_unit
    )
  } else {
    if (!identical(input_unit, "usd")) {
      stop(
        "Raw GFCF observations can only accompany canonical USD arrays.",
        call. = FALSE
      )
    }
    wlv_wiodr_analyze_prepared_m_io_negative_gfcf(
      m_io,
      method = "wiodr13",
      observations = gfcf_observations
    )
  }
  sea_missingness <- wlv_wiodr13_assert_sea_missingness(
    sea,
    labels$countries,
    required_variables
  )

  supplied_output <- apply(m_io, c(1L, 2L), sum)
  gross_output <- matrix(
    sea[, "GO_USD", labels$sectors, labels$countries, drop = FALSE],
    nrow = length(expected_years),
    ncol = length(labels$inputs),
    dimnames = list(expected_years, labels$inputs)
  )
  supplied_output <- matrix(
    supplied_output,
    nrow = length(expected_years),
    ncol = length(labels$inputs),
    dimnames = list(expected_years, labels$inputs)
  )

  residual <- supplied_output - gross_output
  scale <- pmax(abs(supplied_output), abs(gross_output), 1)
  failed <- abs(residual) > absolute_tolerance + relative_tolerance * scale
  if (any(failed)) {
    examples <- wlv_wiodr13_format_positions(residual, failed)
    stop(
      sprintf(
        paste0(
          "The WIOD13 gross-output identity failed in %s country-sector-year cell(s); ",
          "example position(s): %s; maximum absolute residual: %.12g."
        ),
        sum(failed),
        paste(examples, collapse = ", "),
        max(abs(residual[failed]))
      ),
      call. = FALSE
    )
  }

  invisible(list(
    years = expected_years,
    countries = labels$countries,
    sectors = labels$sectors,
    demands = labels$demands,
    inputs = labels$inputs,
    outputs = labels$outputs,
    dimensions = list(m_io = dim(m_io), sea = dim(sea)),
    non_finite = list(m_io = 0L, sea_nan_or_infinite = 0L),
    known_negative_gfcf_count = negative_gfcf$signature$count,
    negative_gfcf_coordinate_md5 = negative_gfcf$signature$coordinate_md5,
    negative_gfcf_value_md5 = negative_gfcf$signature$value_md5,
    negative_gfcf_canonical_unit = negative_gfcf$canonical_unit,
    negative_gfcf_input_unit = negative_gfcf$input_unit,
    expected_row_na_count = sea_missingness$expected_row_na_count,
    observed_row_na_count = sea_missingness$observed_row_na_count,
    maximum_absolute_gross_output_residual = max(abs(residual))
  ))
}

wlv_wiodr13_read_array <- function(path) {
  if (!requireNamespace("fst", quietly = TRUE)) {
    stop("Package `fst` is required to read prepared WIOD13 arrays.", call. = FALSE)
  }
  metadata_path <- paste0(path, ".meta")
  if (!file.exists(path) || !file.exists(metadata_path)) {
    stop(sprintf("Prepared array or metadata is missing: %s", path), call. = FALSE)
  }

  table <- fst::read_fst(path)
  metadata <- readRDS(metadata_path)
  dimensions <- metadata[[1L]]
  if (length(table) != 1L || is.null(dimensions) || prod(dimensions) != nrow(table)) {
    stop(sprintf("Prepared array metadata is inconsistent: %s", path), call. = FALSE)
  }

  value <- table[[1L]]
  dim(value) <- dimensions
  dimnames(value) <- metadata[seq_len(length(dimensions)) + 1L]
  value
}

wlv_wiodr_analyze_prepared_m_io_negative_gfcf <- function(
    value,
    method,
    observations) {
  required <- c(
    "year", "input", "output", "value", "value_million_usd",
    "policy_id", "action"
  )
  if (
    !is.data.frame(observations) ||
      length(setdiff(required, names(observations))) ||
      anyNA(observations[required]) ||
      !is.numeric(observations$value) ||
      !is.numeric(observations$value_million_usd) ||
      any(!is.finite(observations$value)) ||
      any(!is.finite(observations$value_million_usd)) ||
      any(observations$value >= 0) ||
      any(observations$value_million_usd >= 0) ||
      !identical(observations$value, observations$value_million_usd) ||
      any(observations$policy_id != paste0(method, "_negative_gfcf_v1")) ||
      any(observations$action != "truncate_allowlisted_negative_gfcf")
  ) {
    stop("Invalid prepared raw-GFCF observation sidecar.", call. = FALSE)
  }

  wlv_wiodr_assert_gfcf_array(value)
  pin <- wlv_wiodr_negative_gfcf_pin(method)
  suffix <- paste0(".", pin$demand)
  output_positions <- which(endsWith(dimnames(value)[[3L]], suffix))
  canonical_source_scope <-
    identical(dimnames(value)[[1L]], pin$years) &&
    identical(dim(value)[[2L]], pin$input_count)
  if (
    canonical_source_scope &&
      !identical(length(output_positions), pin$output_count)
  ) {
    stop(
      sprintf(
        "WIOD %s requires exactly %s `%s` GFCF output columns; found %s.",
        sub("^wiodr", "", method),
        pin$output_count,
        pin$demand,
        length(output_positions)
      ),
      call. = FALSE
    )
  }

  gfcf <- value[, , output_positions, drop = FALSE]
  array_observations <- wlv_wiodr_observe_negative_gfcf(
    gfcf,
    input_unit = "usd"
  )
  canonical_scope <- wlv_wiodr_is_canonical_gfcf_scope(gfcf, pin)
  if (!canonical_scope && (nrow(array_observations) || nrow(observations))) {
    stop(
      sprintf(
        "WIOD %s negative GFCF cannot be accepted outside the pinned full source scope.",
        sub("^wiodr", "", method)
      ),
      call. = FALSE
    )
  }

  signature <- if (canonical_scope) {
    wlv_wiodr_assert_negative_gfcf_coordinates(
      array_observations,
      method,
      pin
    )
    wlv_wiodr_assert_negative_gfcf_profile(observations, method, pin)
  } else {
    wlv_wiodr_negative_gfcf_signature(observations)
  }

  array_keys <- paste(
    array_observations$year,
    array_observations$input,
    array_observations$output,
    sep = "|"
  )
  sidecar_keys <- paste(
    observations$year,
    observations$input,
    observations$output,
    sep = "|"
  )
  array_order <- order(array_keys, method = "radix")
  sidecar_order <- order(sidecar_keys, method = "radix")
  values_match <- identical(
    as.numeric(array_observations$value[array_order]),
    as.numeric(observations$value[sidecar_order] * 1000000)
  )
  if (
    !identical(array_keys[array_order], sidecar_keys[sidecar_order]) ||
      !values_match
  ) {
    stop(
      "Prepared canonical GFCF values differ from their raw observation sidecar.",
      call. = FALSE
    )
  }

  structure(
    list(
      observations = array_observations,
      raw_observations = observations,
      signature = signature,
      canonical_scope = canonical_scope,
      input_unit = "usd",
      canonical_unit = pin$canonical_unit
    ),
    class = c("wlv_negative_gfcf_analysis", "list")
  )
}

wlv_wiodr_read_prepared_gfcf_observations <- function(source_dir, method) {
  path <- file.path(source_dir, "_gfcf_canonical.rds")
  if (!file.exists(path)) {
    stop(
      sprintf("Prepared %s raw-GFCF observation sidecar is missing: %s", method, path),
      call. = FALSE
    )
  }
  tryCatch(
    readRDS(path),
    error = function(error) {
      stop(
        sprintf(
          "Cannot read prepared %s raw-GFCF observation sidecar `%s`: %s",
          method,
          path,
          conditionMessage(error)
        ),
        call. = FALSE
      )
    }
  )
}

wlv_validate_wiodr13_prepared <- function(
    source_dir = file.path("source_data", "wiodr13", "normalized"),
    expected_years = as.character(1995:2009),
    read_array = wlv_wiodr13_read_array,
    relative_tolerance = 1e-8,
    absolute_tolerance = 1e-6) {
  if (!is.function(read_array)) {
    stop("`read_array` must be a function.", call. = FALSE)
  }
  source_dir <- normalizePath(source_dir, mustWork = TRUE)
  csv_paths <- file.path(source_dir, c("countries.csv", "sectors.csv", "demand.csv"))
  missing <- csv_paths[!file.exists(csv_paths)]
  if (length(missing)) {
    stop(sprintf("Prepared WIOD13 labels are missing: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }

  countries <- utils::read.csv2(csv_paths[[1L]], stringsAsFactors = FALSE)$country.source
  sectors <- utils::read.csv2(csv_paths[[2L]], stringsAsFactors = FALSE)$sector.source
  demands <- utils::read.csv2(csv_paths[[3L]], stringsAsFactors = FALSE)$demand
  gfcf_observations <- wlv_wiodr_read_prepared_gfcf_observations(
    source_dir,
    "wiodr13"
  )

  wlv_validate_wiodr13_arrays(
    m_io = read_array(file.path(source_dir, "m_io.fst")),
    sea = read_array(file.path(source_dir, "sea.fst")),
    countries = countries,
    sectors = sectors,
    demands = demands,
    expected_years = expected_years,
    input_unit = "usd",
    gfcf_observations = gfcf_observations,
    relative_tolerance = relative_tolerance,
    absolute_tolerance = absolute_tolerance
  )
}

wlv_validate_wiodr13_euklems <- function(
    paths,
    required_variables,
    required_sectors,
    required_countries = c("UK", "EL", "MD")) {
  required_variables <- wlv_wiodr13_validate_labels(
    unique(as.character(required_variables)),
    "required_variables"
  )
  required_sectors <- wlv_wiodr13_validate_labels(
    unique(as.character(required_sectors)),
    "required_sectors"
  )
  required_countries <- wlv_wiodr13_validate_labels(
    unique(as.character(required_countries)),
    "required_countries"
  )
  if (!is.character(paths) || !length(paths) || anyNA(paths)) {
    stop("`paths` must be a non-empty character vector without NA.", call. = FALSE)
  }

  summaries <- lapply(paths, function(path) {
    metadata <- tryCatch(
      fst::metadata_fst(path),
      error = function(error) {
        stop(
          sprintf("Cannot read EU KLEMS FST `%s`: %s", path, conditionMessage(error)),
          call. = FALSE
        )
      }
    )
    columns <- c("country", "sector", required_variables)
    missing_columns <- setdiff(columns, metadata$columnNames)
    if (length(missing_columns)) {
      stop(
        sprintf(
          "EU KLEMS FST `%s` lacks required columns: %s.",
          path,
          paste(missing_columns, collapse = ", ")
        ),
        call. = FALSE
      )
    }

    value <- fst::read_fst(path, columns = columns)
    invalid_identifiers <-
      is.na(value$country) | !nzchar(value$country) |
      is.na(value$sector) | !nzchar(value$sector)
    if (any(invalid_identifiers)) {
      stop(sprintf("EU KLEMS FST `%s` has invalid identifiers.", path), call. = FALSE)
    }
    keys <- paste(value$country, value$sector, sep = "\034")
    if (anyDuplicated(keys)) {
      stop(sprintf("EU KLEMS FST `%s` has duplicate country-sector keys.", path), call. = FALSE)
    }

    missing_countries <- setdiff(required_countries, unique(value$country))
    if (length(missing_countries)) {
      stop(
        sprintf(
          "EU KLEMS FST `%s` lacks required countries: %s.",
          path,
          paste(missing_countries, collapse = ", ")
        ),
        call. = FALSE
      )
    }
    expected_keys <- as.vector(outer(
      unique(value$country),
      required_sectors,
      paste,
      sep = "\034"
    ))
    missing_keys <- setdiff(expected_keys, keys)
    if (length(missing_keys)) {
      stop(
        sprintf(
          "EU KLEMS FST `%s` lacks required country-sector keys: %s.",
          path,
          paste(utils::head(missing_keys, 3L), collapse = ", ")
        ),
        call. = FALSE
      )
    }

    numeric_values <- value[required_variables]
    if (!all(vapply(numeric_values, is.numeric, logical(1)))) {
      stop(sprintf("EU KLEMS FST `%s` has non-numeric required data.", path), call. = FALSE)
    }
    non_finite <- !is.finite(as.matrix(numeric_values))
    if (any(non_finite)) {
      stop(
        sprintf(
          "EU KLEMS FST `%s` has %s non-finite value(s) in required columns.",
          path,
          sum(non_finite)
        ),
        call. = FALSE
      )
    }

    list(path = path, rows = nrow(value), columns = columns)
  })

  invisible(summaries)
}
