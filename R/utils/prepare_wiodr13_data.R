# Download and prepare WIOD 2013 data.

if (!exists("wlv_download_verified", mode = "function", inherits = FALSE)) {
  sys.source("R/utils/preparation_downloads.R", envir = environment())
}
if (!exists("write_fst_array", mode = "function", inherits = FALSE)) {
  sys.source("R/lib/functions.R", envir = environment())
}

dir.create("source_data", recursive = TRUE, showWarnings = FALSE)
dir.create("source_data/wiodr13", recursive = TRUE, showWarnings = FALSE)
if (!dir.exists("source_data/wiodr13")) {
  stop("Cannot create WIOD13 source-data directory.", call. = FALSE)
}

wiodr13_mat_members <- c(
  "WIOT95_00.mat",
  "WIOT01_05.mat",
  "WIOT06_09.mat",
  "WIOT08_11.mat"
)

wiodr13_download_manifest <- list(
  wiots = list(
    url = "https://dataverse.nl/api/access/datafile/199125",
    destination = "source_data/wiodr13/WIOTS_in_MATLAB.zip",
    size = 292278662,
    hash_algorithm = "sha1",
    hash = "7e921fda5e3b80605a27e7404ac16fbf1f5a3cd7"
  ),
  sea = list(
    url = "https://dataverse.nl/api/access/datafile/199111",
    destination = "source_data/wiodr13/Socio_Economic_Accounts_July14.xlsx",
    size = 7831205,
    hash_algorithm = "sha1",
    hash = "4056b31e2399fd2bb92a311109f279f07ff15faa"
  )
)

wlv_validate_wiodr13_sea_workbook <- function(path) {
  sheets <- readxl::excel_sheets(path)
  if (!("DATA" %in% sheets)) {
    stop("WIOD13 SEA workbook lacks the `DATA` sheet.", call. = FALSE)
  }
  columns <- names(readxl::read_excel(path, sheet = "DATA", n_max = 0))
  required_columns <- c(
    "Country", "Variable", "Description", "Code", paste0("_", 1995:2011)
  )
  missing <- setdiff(required_columns, columns)
  if (length(missing)) {
    stop(
      sprintf("WIOD13 SEA workbook lacks columns: %s", paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

wiots_manifest <- wiodr13_download_manifest$wiots
wlv_download_verified(
  url = wiots_manifest$url,
  destination = wiots_manifest$destination,
  expected_size = wiots_manifest$size,
  expected_hash = wiots_manifest$hash,
  hash_algorithm = wiots_manifest$hash_algorithm,
  validator = function(path) wlv_validate_zip_members(path, wiodr13_mat_members)
)

sea_manifest <- wiodr13_download_manifest$sea
wlv_download_verified(
  url = sea_manifest$url,
  destination = sea_manifest$destination,
  expected_size = sea_manifest$size,
  expected_hash = sea_manifest$hash,
  hash_algorithm = sea_manifest$hash_algorithm,
  validator = wlv_validate_wiodr13_sea_workbook
)

message("Converting WIOD13 files...")

# Convert SEA data.
sea <- as.data.frame(
  readxl::read_excel(
    sea_manifest$destination,
    sheet = "DATA",
    col_names = TRUE,
    na = "NA"
  )
)
colnames(sea) <- tolower(gsub("_", "", colnames(sea), fixed = TRUE))

required_sea_columns <- c(
  "country", "variable", "description", "code", as.character(1995:2009)
)
missing_sea_columns <- setdiff(required_sea_columns, colnames(sea))
if (length(missing_sea_columns)) {
  stop(
    sprintf("Prepared WIOD13 SEA data lacks columns: %s", paste(missing_sea_columns, collapse = ", ")),
    call. = FALSE
  )
}
if (anyNA(sea[c("country", "variable", "description", "code")])) {
  stop("WIOD13 SEA identifiers contain missing values.", call. = FALSE)
}
if (anyDuplicated(sea[c("country", "variable", "code")])) {
  stop("WIOD13 SEA contains duplicate country-variable-sector rows.", call. = FALSE)
}
sea_year_columns <- as.character(1995:2009)
sea_missing_by_year <- vapply(
  sea[sea_year_columns],
  function(values) sum(is.na(values)),
  integer(1)
)
expected_missing_by_year <- c(rep(371L, 13L), 1861L, 2073L)
names(expected_missing_by_year) <- sea_year_columns
sea_missing_values <- sum(sea_missing_by_year)
if (!identical(sea_missing_by_year, expected_missing_by_year)) {
  stop(
    sprintf(
      paste0(
        "WIOD13 SEA missing-observation profile differs from the official workbook: ",
        "%s."
      ),
      paste(names(sea_missing_by_year), sea_missing_by_year, sep = "=", collapse = ", ")
    ),
    call. = FALSE
  )
}
message(
  sprintf(
    "WIOD13 SEA: replacing %s missing observations with zero for 1995-2009 (%s).",
    sea_missing_values,
    paste(names(sea_missing_by_year), sea_missing_by_year, sep = "=", collapse = ", ")
  )
)
for (year_column in sea_year_columns) {
  sea[[year_column]][is.na(sea[[year_column]])] <- 0
}

lists <- NULL
lists$years <- as.character(1995:2009)
lists$countries <- unique(sea$country)
lists$sea_variables <- unique(sea$variable)
lists$sectors <- unique(sea$code)

if (
  length(lists$countries) != 40L ||
  length(lists$sea_variables) != 25L ||
  length(lists$sectors) != 36L ||
  !identical(lists$sectors[[1]], "TOT")
) {
  stop(
    "WIOD13 SEA dimensions differ from the expected 40 countries, 25 variables and 36 sectors.",
    call. = FALSE
  )
}

# Add SEA variables obtained from the WIOTs and the Rest of the World.
lists$sea_variables <- c(lists$sea_variables, "VA_USD", "GO_USD")
lists$countries <- c(lists$countries, "ROW")

nums <- NULL
nums$years <- length(lists$years)
nums$sea_variables <- length(lists$sea_variables)
nums$countries <- length(lists$countries)
nums$sectors <- length(lists$sectors)

sea_source <- array(
  NA_real_,
  dim = c(nums$years, nums$sea_variables, nums$sectors, nums$countries),
  dimnames = list(
    lists$years,
    lists$sea_variables,
    lists$sectors,
    lists$countries
  )
)

x <- seq_len(nums$years)
for (y in seq_len(nrow(sea))) {
  sea_source[x, sea$variable[[y]], sea$code[[y]], sea$country[[y]]] <-
    as.matrix(sea[y, x + 4L])
}

# Exclude the aggregate `TOT` sector.
lists$sectors <- lists$sectors[-1L]
nums$sectors <- length(lists$sectors)
sea_source <- sea_source[, , lists$sectors, , drop = FALSE]

# Convert WIOT matrices.
utils::unzip(
  wiots_manifest$destination,
  files = wiodr13_mat_members,
  exdir = "source_data/wiodr13",
  overwrite = TRUE
)
wiodr13_mat_paths <- file.path("source_data/wiodr13", wiodr13_mat_members)
missing_mat_paths <- wiodr13_mat_paths[!file.exists(wiodr13_mat_paths)]
if (length(missing_mat_paths)) {
  stop(
    sprintf("WIOD13 extraction failed for: %s", paste(missing_mat_paths, collapse = ", ")),
    call. = FALSE
  )
}

wiot_1 <- as.matrix(R.matlab::readMat(wiodr13_mat_paths[[1]])$WIOT95.00)
wiot_2 <- as.matrix(R.matlab::readMat(wiodr13_mat_paths[[2]])$WIOT01.05)
wiot_3 <- as.matrix(R.matlab::readMat(wiodr13_mat_paths[[3]])$WIOT06.09)
wiot_4 <- as.matrix(R.matlab::readMat(wiodr13_mat_paths[[4]])$WIOT08.11)

wlv_assert_wiot_dimensions <- function(value, expected, label) {
  if (!identical(dim(value), as.integer(expected))) {
    stop(
      sprintf(
        "%s has dimensions %s; expected %s.",
        label,
        paste(dim(value), collapse = " x "),
        paste(expected, collapse = " x ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}
wlv_assert_wiot_dimensions(wiot_1, c(1443, 1641 * 6), "WIOT95_00.mat")
wlv_assert_wiot_dimensions(wiot_2, c(1443, 1641 * 5), "WIOT01_05.mat")
wlv_assert_wiot_dimensions(wiot_3, c(1443, 1641 * 4), "WIOT06_09.mat")
wlv_assert_wiot_dimensions(wiot_4, c(1443, 1641 * 4), "WIOT08_11.mat")

# Concatenate 1995-2009 and use the later WIOT release for 2008-2009.
m_io <- cbind(wiot_1, wiot_2, wiot_3)
dim(m_io) <- c(1443, 1641, 15)
m_io[, , 14:15] <- wiot_4[seq_len(1443), seq_len(1641 * 2)]
m_io <- aperm(m_io, c(3, 1, 2))

# Create final-demand, input and output labels.
lists$demand <- paste0("c", c(37, 38, 39, 41, 42))
nums$demand <- length(lists$demand)

lists$input <- paste0(
  rep(lists$countries, each = nums$sectors),
  ".",
  rep(lists$sectors, times = nums$countries)
)
nums$input <- length(lists$input)

lists$output <- c(
  lists$input,
  paste0(
    rep(lists$countries, each = nums$demand),
    ".",
    rep(lists$demand, times = nums$countries)
  )
)
nums$output <- length(lists$output)

# Add gross output and value added from the WIOTs to SEA.
sea_source[, "VA_USD", , ] <- m_io[, 1441, seq_len(nums$input)]
sea_source[, "GO_USD", , ] <- m_io[, 1443, seq_len(nums$input)]

m_io <- m_io[, seq_len(nums$input), seq_len(nums$output), drop = FALSE]
dimnames(m_io) <- list(lists$years, lists$input, lists$output)

if (!identical(dim(m_io), c(15L, 1435L, 1640L))) {
  stop("Prepared WIOD13 input-output matrix has unexpected dimensions.", call. = FALSE)
}
if (!identical(dim(sea_source), c(15L, 27L, 35L, 41L))) {
  stop("Prepared WIOD13 SEA array has unexpected dimensions.", call. = FALSE)
}

wlv_write_fst_array_atomic(
  m_io,
  "source_data/wiodr13/m_io.fst",
  writer = write_fst_array
)
wlv_write_fst_array_atomic(
  sea_source,
  "source_data/wiodr13/sea.fst",
  writer = write_fst_array
)

utils::write.table(
  lists$demand,
  "source_data/wiodr13/demand.csv",
  row.names = FALSE,
  col.names = "demand",
  sep = ";"
)
utils::write.table(
  lists$countries,
  "source_data/wiodr13/countries.csv",
  row.names = FALSE,
  col.names = "country.source",
  sep = ";"
)
utils::write.table(
  lists$sectors,
  "source_data/wiodr13/sectors.csv",
  row.names = FALSE,
  col.names = "sector.source",
  sep = ";"
)

# Keep the verified source downloads, but remove the large extracted matrices.
unlink(wiodr13_mat_paths, force = TRUE)

rm(
  lists, nums, sea, sea_source, wiot_1, wiot_2, wiot_3, wiot_4, m_io,
  x, y, wiots_manifest, sea_manifest, wiodr13_mat_members,
  wiodr13_download_manifest, wiodr13_mat_paths, missing_mat_paths,
  required_sea_columns, missing_sea_columns, wlv_assert_wiot_dimensions,
  wlv_validate_wiodr13_sea_workbook, sea_year_columns, sea_missing_values,
  sea_missing_by_year, expected_missing_by_year, year_column
)
gc()

sys.source("R/utils/prepare_euklems_data.R", envir = environment())
