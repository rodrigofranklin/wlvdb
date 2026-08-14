# Constants and structural checks for the WIOD 2016 source files.

wiodr16_years <- as.character(2000:2014)
wiodr16_countries <- c(
  "AUS", "AUT", "BEL", "BGR", "BRA", "CAN", "CHE", "CHN", "CYP",
  "CZE", "DEU", "DNK", "ESP", "EST", "FIN", "FRA", "GBR", "GRC",
  "HRV", "HUN", "IDN", "IND", "IRL", "ITA", "JPN", "KOR", "LTU",
  "LUX", "LVA", "MEX", "MLT", "NLD", "NOR", "POL", "PRT", "ROU",
  "RUS", "SVK", "SVN", "SWE", "TUR", "TWN", "USA"
)
wiodr16_sea_variables <- c(
  "CAP", "COMP", "EMP", "EMPE", "GO", "GO_PI", "GO_QI", "H_EMPE",
  "II", "II_PI", "II_QI", "K", "LAB", "VA", "VA_PI", "VA_QI"
)
wiodr16_sectors <- c(
  "A01", "A02", "A03", "B", "C10-C12", "C13-C15", "C16", "C17",
  "C18", "C19", "C20", "C21", "C22", "C23", "C24", "C25", "C26",
  "C27", "C28", "C29", "C30", "C31_C32", "C33", "D35", "E36",
  "E37-E39", "F", "G45", "G46", "G47", "H49", "H50", "H51", "H52",
  "H53", "I", "J58", "J59_J60", "J61", "J62_J63", "K64", "K65",
  "K66", "L68", "M69_M70", "M71", "M72", "M73", "M74_M75", "N",
  "O84", "P85", "Q", "R_S", "T", "U"
)
wiodr16_demand <- paste0("c", 57:61)
wiodr16_supplementary_rows <- c(
  "II_fob", "TXSP", "EXP_adj", "PURR", "PURNR", "VA", "IntTTM", "GO"
)
wiodr16_rdata_members <- sprintf(
  "WIOT%d_October16_ROW.RData",
  as.integer(wiodr16_years)
)

wiodr16_download_manifest <- list(
  wiots = list(
    url = "https://dataverse.nl/api/access/datafile/199101",
    destination = "source_data/wiodr16/WIOTS_in_R.zip",
    size = 641578409,
    hash_algorithm = "sha1",
    hash = "51efc2a6c0358cff485e24d6b4b96ffe27f4e23a"
  ),
  sea = list(
    url = "https://dataverse.nl/api/access/datafile/199095",
    destination = "source_data/wiodr16/Socio_Economic_Accounts.xlsx",
    size = 5536437,
    hash_algorithm = "sha1",
    hash = "821bba29c42f3a42009eb1b14dbdaa2922d01236"
  )
)

wlv_validate_wiodr16_wiots_archive <- function(
    path,
    unzip_list = function(path) utils::unzip(path, list = TRUE)) {
  listing <- unzip_list(path)
  if (!is.data.frame(listing) || !all(c("Name", "Length") %in% names(listing))) {
    stop("WIOD16 WIOT ZIP listing is invalid.", call. = FALSE)
  }
  missing <- setdiff(wiodr16_rdata_members, listing$Name)
  unexpected <- setdiff(listing$Name, wiodr16_rdata_members)
  if (length(missing) || length(unexpected)) {
    stop(
      sprintf(
        "WIOD16 WIOT ZIP members differ from the pinned release; missing: %s; unexpected: %s.",
        if (length(missing)) paste(missing, collapse = ", ") else "none",
        if (length(unexpected)) paste(unexpected, collapse = ", ") else "none"
      ),
      call. = FALSE
    )
  }
  required_sizes <- listing$Length[match(wiodr16_rdata_members, listing$Name)]
  if (anyNA(required_sizes) || any(required_sizes <= 0)) {
    stop("One or more WIOD16 WIOT ZIP members are empty.", call. = FALSE)
  }
  invisible(TRUE)
}

wlv_validate_wiodr16_sea_workbook <- function(
    path,
    excel_sheets = readxl::excel_sheets,
    read_excel = readxl::read_excel) {
  sheets <- excel_sheets(path)
  if (!("DATA" %in% sheets)) {
    stop("WIOD16 SEA workbook lacks the `DATA` sheet.", call. = FALSE)
  }
  columns <- names(read_excel(path, sheet = "DATA", n_max = 0))
  required_columns <- c(
    "country", "variable", "description", "code", wiodr16_years
  )
  missing <- setdiff(required_columns, columns)
  if (length(missing)) {
    stop(
      sprintf("WIOD16 SEA workbook lacks columns: %s", paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

wlv_validate_wiodr16_sea_data <- function(
    sea,
    years = wiodr16_years,
    countries = wiodr16_countries,
    variables = wiodr16_sea_variables,
    sectors = wiodr16_sectors) {
  required_columns <- c("country", "variable", "description", "code", years)
  missing_columns <- setdiff(required_columns, names(sea))
  if (length(missing_columns)) {
    stop(
      sprintf("WIOD16 SEA data lacks columns: %s", paste(missing_columns, collapse = ", ")),
      call. = FALSE
    )
  }
  if (anyNA(sea[c("country", "variable", "description", "code")])) {
    stop("WIOD16 SEA identifiers contain missing values.", call. = FALSE)
  }
  if (anyDuplicated(sea[c("country", "variable", "code")])) {
    stop("WIOD16 SEA contains duplicate country-variable-sector rows.", call. = FALSE)
  }
  if (!identical(unique(sea$country), countries)) {
    stop("WIOD16 SEA country labels or their order differ from the pinned release.", call. = FALSE)
  }
  if (!identical(unique(sea$variable), variables)) {
    stop("WIOD16 SEA variable labels or their order differ from the pinned release.", call. = FALSE)
  }
  if (!identical(unique(sea$code), sectors)) {
    stop("WIOD16 SEA sector labels or their order differ from the pinned release.", call. = FALSE)
  }
  expected_rows <- length(countries) * length(variables) * length(sectors)
  if (nrow(sea) != expected_rows) {
    stop(
      sprintf("WIOD16 SEA has %s rows; expected %s.", nrow(sea), expected_rows),
      call. = FALSE
    )
  }
  if (any(!vapply(sea[years], is.numeric, logical(1)))) {
    stop("WIOD16 SEA year columns must be numeric.", call. = FALSE)
  }

  expected_missing_rows <-
    sea$country == "CHN" & sea$variable %in% c("EMPE", "H_EMPE")
  actual_missing <- is.na(sea[years])
  expected_missing <- matrix(
    expected_missing_rows,
    nrow = nrow(sea),
    ncol = length(years)
  )
  if (!identical(unname(actual_missing), expected_missing)) {
    missing_by_year <- colSums(actual_missing)
    stop(
      sprintf(
        paste0(
          "WIOD16 SEA missing-observation profile differs from the pinned workbook: %s. " ,
          "Only CHN EMPE and H_EMPE may be missing."
        ),
        paste(names(missing_by_year), missing_by_year, sep = "=", collapse = ", ")
      ),
      call. = FALSE
    )
  }
  finite_values <- vapply(
    sea[years],
    function(values) all(is.finite(values[!is.na(values)])),
    logical(1)
  )
  if (!all(finite_values)) {
    stop("WIOD16 SEA contains non-finite observations other than the documented missing values.", call. = FALSE)
  }

  invisible(list(
    missing_by_year = stats::setNames(colSums(actual_missing), years),
    missing_rows = which(expected_missing_rows)
  ))
}

wlv_convert_wiodr16_wiot <- function(
    wiot,
    year,
    countries = c(wiodr16_countries, "ROW"),
    sectors = wiodr16_sectors,
    demand = wiodr16_demand,
    supplementary_rows = wiodr16_supplementary_rows) {
  metadata_columns <- c(
    "IndustryCode", "IndustryDescription", "Country", "RNr", "Year"
  )
  missing_columns <- setdiff(metadata_columns, names(wiot))
  if (length(missing_columns)) {
    stop(
      sprintf("WIOD16 WIOT lacks metadata columns: %s", paste(missing_columns, collapse = ", ")),
      call. = FALSE
    )
  }
  wiot <- as.data.frame(wiot, check.names = FALSE, stringsAsFactors = FALSE)
  expected_rows <- c(
    as.vector(vapply(
      countries,
      function(country) paste(country, sectors, sep = "."),
      character(length(sectors))
    )),
    paste("TOT", supplementary_rows, sep = ".")
  )
  actual_rows <- paste(wiot$Country, wiot$IndustryCode, sep = ".")
  if (!identical(actual_rows, expected_rows)) {
    stop("WIOD16 WIOT row labels or their order differ from the pinned release.", call. = FALSE)
  }

  expected_year <- as.integer(year)
  actual_years <- unique(wiot$Year)
  if (
    length(actual_years) != 1L ||
    is.na(actual_years) ||
    !is.numeric(actual_years) ||
    actual_years != expected_year
  ) {
    stop(
      sprintf(
        "WIOD16 WIOT year metadata is %s; expected %s.",
        paste(actual_years, collapse = ", "), expected_year
      ),
      call. = FALSE
    )
  }

  numeric_source_columns <- c(
    as.vector(vapply(
      countries,
      function(country) paste0(country, seq_along(sectors)),
      character(length(sectors))
    )),
    as.vector(vapply(
      countries,
      function(country) {
        paste0(country, length(sectors) + seq_along(demand))
      },
      character(length(demand))
    ))
  )
  expected_columns <- c(metadata_columns, numeric_source_columns, "TOT")
  if (!identical(names(wiot), expected_columns)) {
    stop("WIOD16 WIOT column labels or their order differ from the pinned release.", call. = FALSE)
  }
  if (any(!vapply(wiot[c(numeric_source_columns, "TOT")], is.numeric, logical(1)))) {
    stop("WIOD16 WIOT value columns must be numeric.", call. = FALSE)
  }

  values <- as.matrix(wiot[numeric_source_columns])
  if (anyNA(values) || any(!is.finite(values))) {
    stop("WIOD16 WIOT contains missing or non-finite values.", call. = FALSE)
  }
  output_labels <- c(expected_rows[seq_len(length(countries) * length(sectors))],
                     as.vector(vapply(
                       countries,
                       function(country) paste(country, demand, sep = "."),
                       character(length(demand))
                     )))
  dimnames(values) <- list(actual_rows, output_labels)
  input_labels <- expected_rows[seq_len(length(countries) * length(sectors))]

  invisible(list(
    m_io = values[input_labels, output_labels, drop = FALSE],
    value_added = values["TOT.VA", input_labels],
    gross_output = values["TOT.GO", input_labels]
  ))
}

wlv_load_wiodr16_wiot <- function(path, year, ...) {
  loaded_environment <- new.env(parent = emptyenv())
  loaded_names <- load(path, envir = loaded_environment)
  if (!identical(loaded_names, "wiot")) {
    stop(
      sprintf(
        "WIOD16 RData `%s` contains %s; expected only `wiot`.",
        basename(path), paste(loaded_names, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  wlv_convert_wiodr16_wiot(loaded_environment$wiot, year = year, ...)
}
