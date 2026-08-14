wiodr16_preparation_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "utils", "wiodr16_preparation.R"),
  envir = wiodr16_preparation_environment
)

wlv_make_wiodr16_sea_fixture <- function() {
  countries <- c("AAA", "CHN")
  variables <- c("EMPE", "H_EMPE", "LAB")
  sectors <- c("S1", "S2")
  years <- c("2000", "2001")
  rows <- do.call(rbind, lapply(countries, function(country) {
    do.call(rbind, lapply(variables, function(variable) {
      data.frame(
        country = country,
        variable = variable,
        description = paste(variable, sectors),
        code = sectors,
        stringsAsFactors = FALSE
      )
    }))
  }))
  rownames(rows) <- NULL
  rows[[years[[1]]]] <- seq_len(nrow(rows))
  rows[[years[[2]]]] <- seq_len(nrow(rows)) + 1
  documented_missing <-
    rows$country == "CHN" & rows$variable %in% c("EMPE", "H_EMPE")
  rows[documented_missing, years] <- NA_real_
  list(
    data = rows,
    countries = countries,
    variables = variables,
    sectors = sectors,
    years = years
  )
}

wlv_make_wiodr16_wiot_fixture <- function() {
  countries <- c("AAA", "ROW")
  sectors <- c("S1", "S2")
  demand <- c("c3", "c4")
  supplementary <- c("VA", "GO")
  industry_rows <- as.vector(vapply(
    countries,
    function(country) paste(country, sectors, sep = "."),
    character(length(sectors))
  ))
  row_labels <- c(industry_rows, paste("TOT", supplementary, sep = "."))
  source_columns <- c(
    as.vector(vapply(
      countries,
      function(country) paste0(country, seq_along(sectors)),
      character(length(sectors))
    )),
    as.vector(vapply(
      countries,
      function(country) paste0(country, length(sectors) + seq_along(demand)),
      character(length(demand))
    )),
    "TOT"
  )
  values <- matrix(
    seq_len(length(row_labels) * length(source_columns)),
    nrow = length(row_labels),
    dimnames = list(NULL, source_columns)
  )
  split_rows <- strsplit(row_labels, ".", fixed = TRUE)
  wiot <- data.frame(
    IndustryCode = vapply(split_rows, `[[`, character(1), 2L),
    IndustryDescription = paste("Description", row_labels),
    Country = vapply(split_rows, `[[`, character(1), 1L),
    RNr = seq_along(row_labels),
    Year = rep(2000, length(row_labels)),
    values,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  list(
    data = wiot,
    countries = countries,
    sectors = sectors,
    demand = demand,
    supplementary = supplementary,
    industry_rows = industry_rows,
    source_columns = source_columns
  )
}

test_that("WIOD16 official download manifest is pinned", {
  manifest <- wiodr16_preparation_environment$wiodr16_download_manifest

  expect_identical(manifest$wiots$size, 641578409)
  expect_identical(
    manifest$wiots$hash,
    "51efc2a6c0358cff485e24d6b4b96ffe27f4e23a"
  )
  expect_identical(manifest$sea$size, 5536437)
  expect_identical(
    manifest$sea$hash,
    "821bba29c42f3a42009eb1b14dbdaa2922d01236"
  )
  expect_identical(
    wiodr16_preparation_environment$wiodr16_rdata_members,
    sprintf("WIOT%d_October16_ROW.RData", 2000:2014)
  )
})

test_that("WIOD16 WIOT archive validator enforces the exact non-empty members", {
  validate <-
    wiodr16_preparation_environment$wlv_validate_wiodr16_wiots_archive
  members <- wiodr16_preparation_environment$wiodr16_rdata_members
  listing <- data.frame(
    Name = rev(members),
    Length = seq_along(members),
    stringsAsFactors = FALSE
  )
  expect_no_error(validate("unused.zip", unzip_list = function(path) listing))

  missing <- listing[-1L, ]
  expect_error(
    validate("unused.zip", unzip_list = function(path) missing),
    "members differ"
  )

  extra <- rbind(listing, data.frame(Name = "README.txt", Length = 1L))
  expect_error(
    validate("unused.zip", unzip_list = function(path) extra),
    "unexpected: README.txt"
  )

  empty <- listing
  empty$Length[[1]] <- 0L
  expect_error(
    validate("unused.zip", unzip_list = function(path) empty),
    "members are empty"
  )
})

test_that("WIOD16 workbook validator requires the official sheet and columns", {
  required_columns <- c(
    "country", "variable", "description", "code", as.character(2000:2014)
  )
  fake_reader <- function(path, sheet, n_max) {
    setNames(as.data.frame(matrix(nrow = 0L, ncol = length(required_columns))),
             required_columns)
  }
  validate <- wiodr16_preparation_environment$wlv_validate_wiodr16_sea_workbook

  expect_no_error(validate(
    "unused.xlsx",
    excel_sheets = function(path) c("Notes", "DATA"),
    read_excel = fake_reader
  ))
  expect_error(validate(
    "unused.xlsx",
    excel_sheets = function(path) "Notes",
    read_excel = fake_reader
  ), "lacks the `DATA` sheet")
  expect_error(validate(
    "unused.xlsx",
    excel_sheets = function(path) "DATA",
    read_excel = function(...) data.frame(country = character())
  ), "lacks columns")
})

test_that("WIOD16 SEA validator accepts only documented China missingness", {
  fixture <- wlv_make_wiodr16_sea_fixture()
  validate <- function(value) {
    wiodr16_preparation_environment$wlv_validate_wiodr16_sea_data(
      value,
      years = fixture$years,
      countries = fixture$countries,
      variables = fixture$variables,
      sectors = fixture$sectors
    )
  }

  result <- validate(fixture$data)
  expect_identical(result$missing_by_year, c(`2000` = 4, `2001` = 4))

  unexpected_missing <- fixture$data
  unexpected_missing[1L, "2000"] <- NA_real_
  expect_error(validate(unexpected_missing), "missing-observation profile")

  incomplete <- fixture$data[-nrow(fixture$data), ]
  expect_error(validate(incomplete), "rows; expected")

  reordered <- fixture$data[nrow(fixture$data):1L, ]
  expect_error(validate(reordered), "country labels or their order")
})

test_that("WIOD16 WIOT converter preserves source ordering and factor rows", {
  fixture <- wlv_make_wiodr16_wiot_fixture()
  convert <- function(value, year = 2000) {
    wiodr16_preparation_environment$wlv_convert_wiodr16_wiot(
      value,
      year = year,
      countries = fixture$countries,
      sectors = fixture$sectors,
      demand = fixture$demand,
      supplementary_rows = fixture$supplementary
    )
  }

  result <- convert(fixture$data)
  expected_outputs <- c(
    fixture$industry_rows,
    "AAA.c3", "AAA.c4", "ROW.c3", "ROW.c4"
  )
  expect_identical(dim(result$m_io), c(4L, 8L))
  expect_identical(rownames(result$m_io), fixture$industry_rows)
  expect_identical(colnames(result$m_io), expected_outputs)
  expect_equal(
    unname(result$value_added),
    unname(as.numeric(fixture$data[5L, fixture$source_columns[1:4]]))
  )
  expect_equal(
    unname(result$gross_output),
    unname(as.numeric(fixture$data[6L, fixture$source_columns[1:4]]))
  )

  wrong_year <- fixture$data
  wrong_year$Year[[1]] <- 1999
  expect_error(convert(wrong_year), "year metadata")

  wrong_order <- fixture$data[c(2L, 1L, 3:nrow(fixture$data)), ]
  expect_error(convert(wrong_order), "row labels or their order")

  non_finite <- fixture$data
  non_finite[[fixture$source_columns[[1]]]][[1]] <- Inf
  expect_error(convert(non_finite), "missing or non-finite")
})

test_that("WIOD16 RData loader rejects unexpected objects", {
  fixture <- wlv_make_wiodr16_wiot_fixture()
  root <- tempfile("wiodr16-rdata-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  path <- file.path(root, "wiot.RData")
  wiot <- fixture$data
  save(wiot, file = path)

  result <- wiodr16_preparation_environment$wlv_load_wiodr16_wiot(
    path,
    year = 2000,
    countries = fixture$countries,
    sectors = fixture$sectors,
    demand = fixture$demand,
    supplementary_rows = fixture$supplementary
  )
  expect_identical(dim(result$m_io), c(4L, 8L))

  extra <- TRUE
  save(wiot, extra, file = path)
  expect_error(
    wiodr16_preparation_environment$wlv_load_wiodr16_wiot(
      path,
      year = 2000,
      countries = fixture$countries,
      sectors = fixture$sectors,
      demand = fixture$demand,
      supplementary_rows = fixture$supplementary
    ),
    "expected only `wiot`"
  )
})
