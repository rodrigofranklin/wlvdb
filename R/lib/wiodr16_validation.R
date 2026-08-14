if (!exists("wlv_wiodr16_validate_source_negative_k", mode = "function")) {
  sys.source("R/lib/wiodr16_allocation.R", envir = environment())
}

wlv_wiodr16_assert_count <- function(value, expected, name) {
  if (
    length(expected) != 1L ||
    !is.numeric(expected) ||
    is.na(expected) ||
    !is.finite(expected) ||
    expected < 1L ||
    expected != floor(expected)
  ) {
    stop(sprintf("`%s` expected count must be one positive integer.", name), call. = FALSE)
  }
  if (length(value) != expected) {
    stop(
      sprintf("WIOD16 requires %s %s; found %s.", expected, name, length(value)),
      call. = FALSE
    )
  }
  invisible(value)
}

wlv_wiodr16_expected_dimensions <- function(
    countries,
    sectors,
    demands,
    expected_country_count = 44L,
    expected_countries = c(
      "AUS", "AUT", "BEL", "BGR", "BRA", "CAN", "CHE", "CHN", "CYP", "CZE",
      "DEU", "DNK", "ESP", "EST", "FIN", "FRA", "GBR", "GRC", "HRV", "HUN",
      "IDN", "IND", "IRL", "ITA", "JPN", "KOR", "LTU", "LUX", "LVA", "MEX",
      "MLT", "NLD", "NOR", "POL", "PRT", "ROU", "RUS", "SVK", "SVN", "SWE",
      "TUR", "TWN", "USA", "ROW"
    ),
    expected_sector_count = 56L,
    expected_demand_count = 5L,
    expected_demands = paste0("c", 57:61)) {
  countries <- wlv_wiodr13_validate_labels(countries, "countries")
  sectors <- wlv_wiodr13_validate_labels(sectors, "sectors")
  demands <- wlv_wiodr13_validate_labels(demands, "demands")

  wlv_wiodr16_assert_count(countries, expected_country_count, "countries")
  wlv_wiodr16_assert_count(sectors, expected_sector_count, "sectors")
  wlv_wiodr16_assert_count(demands, expected_demand_count, "final-demand categories")
  expected_countries <- wlv_wiodr13_validate_labels(
    expected_countries,
    "expected_countries"
  )
  if (!identical(countries, expected_countries)) {
    stop(
      sprintf(
        "WIOD16 country labels/order must be: %s; found: %s.",
        paste(expected_countries, collapse = ", "),
        paste(countries, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  expected_demands <- wlv_wiodr13_validate_labels(expected_demands, "expected_demands")
  if (!identical(demands, expected_demands)) {
    stop(
      sprintf(
        "WIOD16 final-demand labels must be: %s; found: %s.",
        paste(expected_demands, collapse = ", "),
        paste(demands, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  inputs <- as.vector(vapply(
    countries,
    function(country) paste(country, sectors, sep = "."),
    character(length(sectors))
  ))
  final_demand <- as.vector(vapply(
    countries,
    function(country) paste(country, demands, sep = "."),
    character(length(demands))
  ))

  list(
    countries = countries,
    sectors = sectors,
    demands = demands,
    inputs = inputs,
    outputs = c(inputs, final_demand)
  )
}

wlv_wiodr16_assert_sea_missingness <- function(
    sea,
    countries,
    raw_variables,
    china_missing_variables = c("EMPE", "H_EMPE"),
    required_variables = c("VA_USD", "GO_USD")) {
  row_index <- which(countries == "ROW")
  china_index <- which(countries == "CHN")
  if (length(row_index) != 1L || length(china_index) != 1L) {
    stop("WIOD16 countries must contain exactly one `CHN` and one `ROW` entry.", call. = FALSE)
  }

  china_missing_variables <- wlv_wiodr13_validate_labels(
    china_missing_variables,
    "china_missing_variables"
  )
  missing_china_variables <- setdiff(china_missing_variables, raw_variables)
  if (length(missing_china_variables)) {
    stop(
      sprintf(
        "WIOD16 SEA lacks official China-missing variable(s): %s.",
        paste(missing_china_variables, collapse = ", ")
      ),
      call. = FALSE
    )
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

  expected_missing <- array(FALSE, dim = dim(sea), dimnames = dimnames(sea))
  expected_missing[, raw_variables, , "ROW"] <- TRUE
  expected_missing[, china_missing_variables, , "CHN"] <- TRUE
  observed_missing <- is.na(sea)

  unexpected_missing <- observed_missing & !expected_missing
  if (any(unexpected_missing)) {
    examples <- wlv_wiodr13_format_positions(sea, unexpected_missing)
    stop(
      sprintf(
        "WIOD16 SEA contains %s unexpected missing value(s); example position(s): %s.",
        sum(unexpected_missing),
        paste(examples, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  unexpectedly_populated <- !observed_missing & expected_missing
  if (any(unexpectedly_populated)) {
    examples <- wlv_wiodr13_format_positions(sea, unexpectedly_populated)
    stop(
      sprintf(
        paste0(
          "WIOD16 SEA expects official/structural missing values at %s position(s); ",
          "populated example position(s): %s."
        ),
        sum(unexpectedly_populated),
        paste(examples, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  expected_row_na_count <- length(sea[, raw_variables, , "ROW", drop = FALSE])
  expected_china_na_count <- length(
    sea[, china_missing_variables, , "CHN", drop = FALSE]
  )
  list(
    expected_row_na_count = expected_row_na_count,
    observed_row_na_count = sum(observed_missing[, raw_variables, , "ROW", drop = FALSE]),
    expected_china_na_count = expected_china_na_count,
    observed_china_na_count = sum(
      observed_missing[, china_missing_variables, , "CHN", drop = FALSE]
    ),
    expected_total_na_count = sum(expected_missing),
    observed_total_na_count = sum(observed_missing)
  )
}

wlv_validate_wiodr16_arrays <- function(
    m_io,
    sea,
    countries,
    sectors,
    demands,
    expected_years = as.character(2000:2014),
    expected_country_count = 44L,
    expected_countries = c(
      "AUS", "AUT", "BEL", "BGR", "BRA", "CAN", "CHE", "CHN", "CYP", "CZE",
      "DEU", "DNK", "ESP", "EST", "FIN", "FRA", "GBR", "GRC", "HRV", "HUN",
      "IDN", "IND", "IRL", "ITA", "JPN", "KOR", "LTU", "LUX", "LVA", "MEX",
      "MLT", "NLD", "NOR", "POL", "PRT", "ROU", "RUS", "SVK", "SVN", "SWE",
      "TUR", "TWN", "USA", "ROW"
    ),
    expected_sector_count = 56L,
    expected_demand_count = 5L,
    expected_demands = paste0("c", 57:61),
    expected_raw_variables = c(
      "CAP", "COMP", "EMP", "EMPE", "GO", "GO_PI", "GO_QI", "H_EMPE",
      "II", "II_PI", "II_QI", "K", "LAB", "VA", "VA_PI", "VA_QI"
    ),
    expected_raw_variable_count = length(expected_raw_variables),
    china_missing_variables = c("EMPE", "H_EMPE"),
    relative_tolerance = 1e-8,
    absolute_tolerance = 1e-6) {
  expected_years <- wlv_wiodr13_validate_labels(
    as.character(expected_years),
    "expected_years"
  )
  labels <- wlv_wiodr16_expected_dimensions(
    countries = countries,
    sectors = sectors,
    demands = demands,
    expected_country_count = expected_country_count,
    expected_countries = expected_countries,
    expected_sector_count = expected_sector_count,
    expected_demand_count = expected_demand_count,
    expected_demands = expected_demands
  )

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
  sea_variables <- wlv_wiodr13_validate_labels(
    unname(as.character(sea_variables)),
    "sea variables"
  )
  required_variables <- c("VA_USD", "GO_USD")
  missing_variables <- setdiff(required_variables, sea_variables)
  if (length(missing_variables)) {
    stop(
      sprintf("`sea` lacks required variable(s): %s", paste(missing_variables, collapse = ", ")),
      call. = FALSE
    )
  }
  raw_variables <- setdiff(sea_variables, required_variables)
  expected_raw_variables <- wlv_wiodr13_validate_labels(
    expected_raw_variables,
    "expected_raw_variables"
  )
  wlv_wiodr16_assert_count(
    raw_variables,
    expected_raw_variable_count,
    "raw SEA variables"
  )
  if (!identical(raw_variables, expected_raw_variables)) {
    stop(
      sprintf(
        "WIOD16 raw SEA variable labels/order must be: %s; found: %s.",
        paste(expected_raw_variables, collapse = ", "),
        paste(raw_variables, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  expected_sea_variables <- c(expected_raw_variables, required_variables)
  if (!identical(sea_variables, expected_sea_variables)) {
    stop(
      sprintf(
        "WIOD16 SEA variable labels/order must be: %s; found: %s.",
        paste(expected_sea_variables, collapse = ", "),
        paste(sea_variables, collapse = ", ")
      ),
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
  sea_missingness <- wlv_wiodr16_assert_sea_missingness(
    sea = sea,
    countries = labels$countries,
    raw_variables = raw_variables,
    china_missing_variables = china_missing_variables,
    required_variables = required_variables
  )
  negative_source_k <- wlv_wiodr16_validate_source_negative_k(sea)
  source_va_exception <- wlv_wiodr16_validate_source_va_exception(sea)

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
          "The WIOD16 gross-output identity failed in %s country-sector-year cell(s); ",
          "example position(s): %s; maximum absolute residual: %.12g."
        ),
        sum(failed),
        paste(examples, collapse = ", "),
        max(abs(residual[failed]))
      ),
      call. = FALSE
    )
  }

  invisible(c(
    list(
      years = expected_years,
      countries = labels$countries,
      sectors = labels$sectors,
      demands = labels$demands,
      inputs = labels$inputs,
      outputs = labels$outputs,
      raw_variables = raw_variables,
      dimensions = list(m_io = dim(m_io), sea = dim(sea)),
      known_negative_source_k_count = nrow(negative_source_k),
      known_source_va_exception_count = nrow(source_va_exception),
      maximum_absolute_gross_output_residual = max(abs(residual))
    ),
    sea_missingness
  ))
}

wlv_wiodr16_read_array <- function(path) {
  wlv_wiodr13_read_array(path)
}

wlv_validate_wiodr16_prepared <- function(
    source_dir = file.path("source_data", "wiodr16"),
    expected_years = as.character(2000:2014),
    read_array = wlv_wiodr16_read_array,
    relative_tolerance = 1e-8,
    absolute_tolerance = 1e-6,
    ...) {
  if (!is.function(read_array)) {
    stop("`read_array` must be a function.", call. = FALSE)
  }
  source_dir <- normalizePath(source_dir, mustWork = TRUE)
  csv_paths <- file.path(source_dir, c("countries.csv", "sectors.csv", "demand.csv"))
  missing <- csv_paths[!file.exists(csv_paths)]
  if (length(missing)) {
    stop(sprintf("Prepared WIOD16 labels are missing: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }

  read_label <- function(path, column) {
    value <- utils::read.csv2(path, stringsAsFactors = FALSE)
    if (!column %in% names(value)) {
      stop(sprintf("Prepared WIOD16 label file `%s` lacks `%s`.", path, column), call. = FALSE)
    }
    value[[column]]
  }
  countries <- read_label(csv_paths[[1L]], "country.source")
  sectors <- read_label(csv_paths[[2L]], "sector.source")
  demands <- read_label(csv_paths[[3L]], "demand")

  wlv_validate_wiodr16_arrays(
    m_io = read_array(file.path(source_dir, "m_io.fst")),
    sea = read_array(file.path(source_dir, "sea.fst")),
    countries = countries,
    sectors = sectors,
    demands = demands,
    expected_years = expected_years,
    relative_tolerance = relative_tolerance,
    absolute_tolerance = absolute_tolerance,
    ...
  )
}

wlv_validate_wiodr16_euklems <- function(
    paths,
    required_variables,
    required_sectors,
    required_countries = c("UK", "EL", "MD")) {
  summaries <- wlv_validate_wiodr13_euklems(
    paths = paths,
    required_variables = required_variables,
    required_sectors = required_sectors,
    required_countries = required_countries
  )

  names <- basename(paths)
  capital_match <- regexec("^ekk_([0-9]{4})\\.fst$", names)
  capital_parts <- regmatches(names, capital_match)
  depreciation_match <- regexec("^ekdeprate_([0-9]{4})\\.fst$", names)
  depreciation_parts <- regmatches(names, depreciation_match)
  capital_indices <- which(lengths(capital_parts) == 2L)
  depreciation_indices <- which(lengths(depreciation_parts) == 2L)

  for (capital_index in capital_indices) {
    capital_year <- capital_parts[[capital_index]][[2L]]
    wlv_wiodr16_validate_negative_euklems_weights(
      fst::read_fst(paths[[capital_index]]),
      capital_year
    )
  }

  if (length(capital_indices) && length(depreciation_indices)) {
    depreciation_years <- vapply(
      depreciation_parts[depreciation_indices],
      `[[`,
      character(1),
      2L
    )
    for (capital_index in capital_indices) {
      capital_year <- as.integer(capital_parts[[capital_index]][[2L]])
      paired_index <- depreciation_indices[
        depreciation_years == as.character(capital_year + 1L)
      ]
      if (length(paired_index) != 1L) {
        stop(
          sprintf(
            "WIOD16 EU KLEMS capital year %s requires exactly one depreciation file for %s.",
            capital_year,
            capital_year + 1L
          ),
          call. = FALSE
        )
      }

      key_columns <- c("country", "sector")
      capital_keys <- fst::read_fst(paths[[capital_index]], columns = key_columns)
      depreciation_keys <- fst::read_fst(paths[[paired_index]], columns = key_columns)
      capital_keys <- sort(paste(capital_keys$country, capital_keys$sector, sep = "\034"))
      depreciation_keys <- sort(paste(
        depreciation_keys$country,
        depreciation_keys$sector,
        sep = "\034"
      ))
      if (!identical(capital_keys, depreciation_keys)) {
        stop(
          sprintf(
            paste0(
              "WIOD16 EU KLEMS key coverage differs between `ekk_%s.fst` ",
              "and `ekdeprate_%s.fst`."
            ),
            capital_year,
            capital_year + 1L
          ),
          call. = FALSE
        )
      }
    }
  }

  invisible(summaries)
}
