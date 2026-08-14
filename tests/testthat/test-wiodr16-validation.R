test_that("a valid WIOD16 fixture satisfies structure, missingness and accounting", {
  fixture <- wlv_make_wiodr16_validation_fixture()

  result <- wlv_validate_wiodr16_fixture(fixture)

  expect_identical(result$years, fixture$years)
  expect_identical(
    result$inputs,
    c("A.S1", "A.S2", "CHN.S1", "CHN.S2", "ROW.S1", "ROW.S2")
  )
  expect_identical(
    result$outputs,
    c(
      "A.S1", "A.S2", "CHN.S1", "CHN.S2", "ROW.S1", "ROW.S2",
      "A.c57", "A.c58", "CHN.c57", "CHN.c58", "ROW.c57", "ROW.c58"
    )
  )
  expect_identical(result$expected_china_na_count, 8L)
  expect_identical(result$observed_china_na_count, 8L)
  expect_identical(result$expected_row_na_count, 16L)
  expect_identical(result$observed_row_na_count, 16L)
  expect_identical(result$expected_total_na_count, 24L)
  expect_identical(result$observed_total_na_count, 24L)
  expect_equal(result$maximum_absolute_gross_output_residual, 0)
})

test_that("WIOD16 enforces source cardinalities and final-demand labels", {
  fixture <- wlv_make_wiodr16_validation_fixture()
  expect_error(
    wlv_validate_wiodr16_fixture(fixture, expected_country_count = 44L),
    "requires 44 countries",
    fixed = TRUE
  )
  expect_error(
    wlv_validate_wiodr16_fixture(
      fixture,
      expected_countries = c("B", "CHN", "ROW")
    ),
    "country labels/order must be",
    fixed = TRUE
  )
  expect_error(
    wlv_validate_wiodr16_fixture(fixture, expected_sector_count = 56L),
    "requires 56 sectors",
    fixed = TRUE
  )
  expect_error(
    wlv_validate_wiodr16_fixture(fixture, expected_demand_count = 5L),
    "requires 5 final-demand categories",
    fixed = TRUE
  )
  expect_error(
    wlv_validate_wiodr16_fixture(fixture, expected_raw_variable_count = 16L),
    "requires 16 raw SEA variables",
    fixed = TRUE
  )
  renamed <- fixture
  dimnames(renamed$sea)[[2L]][dimnames(renamed$sea)[[2L]] == "COMP"] <- "WAGES"
  renamed$raw_variables[renamed$raw_variables == "COMP"] <- "WAGES"
  expect_error(
    wlv_validate_wiodr16_fixture(
      renamed,
      expected_raw_variables = fixture$raw_variables
    ),
    "raw SEA variable labels/order must be",
    fixed = TRUE
  )
  reordered <- fixture
  reordered$sea <- reordered$sea[
    , c("COMP", "EMP", "EMPE", "H_EMPE", "VA_USD", "GO_USD"), , ,
    drop = FALSE
  ]
  expect_error(
    wlv_validate_wiodr16_fixture(reordered),
    "raw SEA variable labels/order must be",
    fixed = TRUE
  )
  expect_error(
    wlv_validate_wiodr16_fixture(fixture, expected_demands = c("c57", "c61")),
    "final-demand labels must be",
    fixed = TRUE
  )
})

test_that("WIOD16 enforces country-major input and final-demand order", {
  fixture <- wlv_make_wiodr16_validation_fixture()
  fixture$m_io <- fixture$m_io[
    , c("A.S1", "CHN.S1", "A.S2", "CHN.S2", "ROW.S1", "ROW.S2"), , drop = FALSE
  ]
  expect_error(
    wlv_validate_wiodr16_fixture(fixture),
    "unexpected inputs dimnames",
    fixed = TRUE
  )

  fixture <- wlv_make_wiodr16_validation_fixture()
  fixture$m_io <- fixture$m_io[, , rev(dimnames(fixture$m_io)[[3L]]), drop = FALSE]
  expect_error(
    wlv_validate_wiodr16_fixture(fixture),
    "unexpected outputs dimnames",
    fixed = TRUE
  )
})

test_that("WIOD16 preserves exactly the official China and structural ROW missingness", {
  fixture <- wlv_make_wiodr16_validation_fixture()
  fixture$sea["2000", "EMPE", "S1", "CHN"] <- 0
  expect_error(
    wlv_validate_wiodr16_fixture(fixture),
    "expects official/structural missing values",
    fixed = TRUE
  )

  fixture <- wlv_make_wiodr16_validation_fixture()
  fixture$sea["2000", "EMP", "S1", "A"] <- NA_real_
  expect_error(
    wlv_validate_wiodr16_fixture(fixture),
    "unexpected missing value",
    fixed = TRUE
  )

  fixture <- wlv_make_wiodr16_validation_fixture()
  fixture$sea["2000", "COMP", "S1", "ROW"] <- Inf
  expect_error(
    wlv_validate_wiodr16_fixture(fixture),
    "NaN or infinite value",
    fixed = TRUE
  )

  fixture <- wlv_make_wiodr16_validation_fixture()
  fixture$sea["2000", "GO_USD", "S1", "ROW"] <- NA_real_
  expect_error(
    wlv_validate_wiodr16_fixture(fixture),
    "unexpected missing value",
    fixed = TRUE
  )
})

test_that("WIOD16 rejects non-finite flows and broken gross-output identities", {
  fixture <- wlv_make_wiodr16_validation_fixture()
  fixture$m_io["2000", "A.S1", "A.c57"] <- NaN
  expect_error(
    wlv_validate_wiodr16_fixture(fixture),
    "`m_io` contains 1 non-finite value",
    fixed = TRUE
  )

  fixture <- wlv_make_wiodr16_validation_fixture()
  fixture$sea["2000", "GO_USD", "S1", "A"] <-
    fixture$sea["2000", "GO_USD", "S1", "A"] + 1
  expect_error(
    wlv_validate_wiodr16_fixture(fixture),
    "gross-output identity failed in 1 country-sector-year cell",
    fixed = TRUE
  )
})

test_that("the WIOD16 prepared-data wrapper validates serialized arrays", {
  fixture <- wlv_make_wiodr16_validation_fixture()
  source_dir <- tempfile("wiodr16-prepared-")
  dir.create(source_dir)
  on.exit(unlink(source_dir, recursive = TRUE, force = TRUE), add = TRUE)
  wlv_materialize_wiodr16_validation_fixture(fixture, source_dir)

  result <- wiodr16_validation_environment$wlv_validate_wiodr16_prepared(
    source_dir = source_dir,
    expected_years = fixture$years,
    expected_country_count = length(fixture$countries),
    expected_countries = fixture$countries,
    expected_sector_count = length(fixture$sectors),
    expected_demand_count = length(fixture$demands),
    expected_demands = fixture$demands,
    expected_raw_variables = fixture$raw_variables,
    expected_raw_variable_count = length(fixture$raw_variables)
  )

  expect_identical(result$dimensions$m_io, c(2L, 6L, 12L))
  expect_identical(result$dimensions$sea, c(2L, 6L, 2L, 3L))
})

test_that("WIOD16 EU KLEMS validation requires fallback countries and complete keys", {
  root <- tempfile("wiodr16-euklems-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  path <- file.path(root, "ekk_2000.fst")
  value <- expand.grid(
    country = c("UK", "EL", "MD"),
    sector = c("A", "B"),
    stringsAsFactors = FALSE
  )
  value$K_ONE <- seq_len(nrow(value))
  fst::write_fst(value, path)

  validate <- function() {
    wiodr16_validation_environment$wlv_validate_wiodr16_euklems(
      path,
      required_variables = "K_ONE",
      required_sectors = c("A", "B")
    )
  }
  expect_no_error(validate())

  fst::write_fst(value[value$country != "MD", ], path)
  expect_error(validate(), "lacks required countries: MD", fixed = TRUE)

  value <- value[-1L, ]
  fst::write_fst(value, path)
  expect_error(validate(), "lacks required country-sector keys", fixed = TRUE)
})

test_that("WIOD16 EU KLEMS capital and depreciation pairs have identical keys", {
  root <- tempfile("wiodr16-euklems-pair-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  paths <- file.path(root, c("ekk_2000.fst", "ekdeprate_2001.fst"))
  value <- expand.grid(
    country = c("UK", "EL", "MD"),
    sector = c("A", "B"),
    stringsAsFactors = FALSE
  )
  value$K_ONE <- seq_len(nrow(value))
  fst::write_fst(value, paths[[1L]])
  fst::write_fst(value, paths[[2L]])

  validate <- function() {
    wiodr16_validation_environment$wlv_validate_wiodr16_euklems(
      paths,
      required_variables = "K_ONE",
      required_sectors = c("A", "B")
    )
  }
  expect_no_error(validate())

  extra <- value[value$country == "UK", ]
  extra$country <- "US"
  fst::write_fst(rbind(value, extra), paths[[2L]])
  expect_error(validate(), "key coverage differs", fixed = TRUE)
})
