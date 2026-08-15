test_that("a structurally valid WIOD13 fixture passes its accounting identity", {
  fixture <- wlv_make_wiodr13_validation_fixture()

  result <- wlv_validate_wiodr13_fixture(fixture)

  expect_identical(result$years, fixture$years)
  expect_identical(
    result$inputs,
    c("A.S1", "A.S2", "B.S1", "B.S2", "ROW.S1", "ROW.S2")
  )
  expect_identical(
    result$outputs,
    c(
      "A.S1", "A.S2", "B.S1", "B.S2", "ROW.S1", "ROW.S2",
      "A.HH", "A.INV", "B.HH", "B.INV", "ROW.HH", "ROW.INV"
    )
  )
  expect_equal(result$maximum_absolute_gross_output_residual, 0)
  expect_identical(result$expected_row_na_count, 4L)
  expect_identical(result$observed_row_na_count, 4L)
  expect_lt(fixture$m_io["2000", "A.S1", "A.INV"], 0)
  expect_identical(fixture$m_io["2001", "B.S2", "B.INV"], 0)
})

test_that("country-major input and final-demand ordering is enforced", {
  fixture <- wlv_make_wiodr13_validation_fixture()
  fixture$m_io <- fixture$m_io[
    , c("A.S1", "B.S1", "A.S2", "B.S2", "ROW.S1", "ROW.S2"), , drop = FALSE
  ]

  expect_error(wlv_validate_wiodr13_fixture(fixture), "unexpected inputs dimnames", fixed = TRUE)

  fixture <- wlv_make_wiodr13_validation_fixture()
  fixture$m_io <- fixture$m_io[, , rev(dimnames(fixture$m_io)[[3L]]), drop = FALSE]
  expect_error(wlv_validate_wiodr13_fixture(fixture), "unexpected outputs dimnames", fixed = TRUE)
})

test_that("years and SEA dimension order must agree exactly", {
  fixture <- wlv_make_wiodr13_validation_fixture()
  fixture$sea <- fixture$sea[rev(fixture$years), , , , drop = FALSE]
  expect_error(wlv_validate_wiodr13_fixture(fixture), "unexpected years dimnames", fixed = TRUE)

  fixture <- wlv_make_wiodr13_validation_fixture()
  fixture$sea <- fixture$sea[, , rev(fixture$sectors), , drop = FALSE]
  expect_error(wlv_validate_wiodr13_fixture(fixture), "unexpected sectors dimnames", fixed = TRUE)
})

test_that("missing, infinite and NaN values are distinct from legitimate zeros", {
  fixture <- wlv_make_wiodr13_validation_fixture()
  expect_no_error(wlv_validate_wiodr13_fixture(fixture))

  for (non_finite in list(NA_real_, NaN, Inf, -Inf)) {
    broken <- fixture
    broken$m_io["2000", "B.S1", "A.HH"] <- non_finite
    expect_error(
      wlv_validate_wiodr13_fixture(broken),
      "`m_io` contains 1 non-finite value",
      fixed = TRUE
    )
  }

  broken <- fixture
  broken$sea["2001", "VA_USD", "S2", "B"] <- NA_real_
  expect_error(
    wlv_validate_wiodr13_fixture(broken),
    "requires finite VA_USD and GO_USD",
    fixed = TRUE
  )

  broken <- fixture
  broken$sea["2000", "LAB", "S1", "A"] <- NA_real_
  expect_error(wlv_validate_wiodr13_fixture(broken), "requires finite values outside ROW", fixed = TRUE)

  broken <- fixture
  broken$sea["2000", "LAB", "S1", "ROW"] <- Inf
  expect_error(wlv_validate_wiodr13_fixture(broken), "NaN or infinite value", fixed = TRUE)

  broken <- fixture
  broken$sea["2000", "LAB", "S1", "ROW"] <- 0
  expect_error(wlv_validate_wiodr13_fixture(broken), "expects missing ROW observations", fixed = TRUE)
})

test_that("gross output must equal the complete row of intermediate and final uses", {
  fixture <- wlv_make_wiodr13_validation_fixture()
  fixture$sea["2000", "GO_USD", "S1", "A"] <-
    fixture$sea["2000", "GO_USD", "S1", "A"] + 1

  expect_error(
    wlv_validate_wiodr13_fixture(fixture),
    "gross-output identity failed in 1 country-sector-year cell",
    fixed = TRUE
  )
})

test_that("value added is required but no invalid reduced column identity is imposed", {
  fixture <- wlv_make_wiodr13_validation_fixture()
  fixture$sea[, "VA_USD", , ] <- 0
  expect_no_error(wlv_validate_wiodr13_fixture(fixture))

  fixture <- wlv_make_wiodr13_validation_fixture()
  fixture$sea <- fixture$sea[, setdiff(dimnames(fixture$sea)[[2L]], "VA_USD"), , , drop = FALSE]
  expect_error(wlv_validate_wiodr13_fixture(fixture), "lacks required variable(s): VA_USD", fixed = TRUE)
})

test_that("duplicate labels and invalid tolerances fail explicitly", {
  fixture <- wlv_make_wiodr13_validation_fixture()
  fixture$countries <- c("A", "A")
  expect_error(wlv_validate_wiodr13_fixture(fixture), "duplicate labels: A", fixed = TRUE)

  fixture <- wlv_make_wiodr13_validation_fixture()
  expect_error(
    wlv_validate_wiodr13_fixture(fixture, relative_tolerance = -1),
    "tolerances must be finite, non-negative",
    fixed = TRUE
  )
})

test_that("the post-preparation wrapper validates the serialized source directory", {
  fixture <- wlv_make_wiodr13_validation_fixture()
  source_dir <- tempfile("wiodr13-prepared-")
  dir.create(source_dir)
  on.exit(unlink(source_dir, recursive = TRUE, force = TRUE), add = TRUE)
  wlv_materialize_wiodr13_validation_fixture(fixture, source_dir)

  result <- wiodr13_validation_environment$wlv_validate_wiodr13_prepared(
    source_dir = source_dir,
    expected_years = fixture$years
  )

  expect_identical(result$dimensions$m_io, c(2L, 6L, 12L))
  expect_identical(result$dimensions$sea, c(2L, 3L, 2L, 3L))
})

test_that("WIOD country codes follow the EU KLEMS conventions", {
  functions_environment <- new.env(parent = baseenv())
  sys.source(
    file.path(wlv_test_root, "R", "lib", "functions.R"),
    envir = functions_environment
  )

  expect_identical(
    functions_environment$wlv_wiodr13_euklems_country_codes(
      c("GBR", "GRC", "USA", "ROW")
    ),
    c("UK", "EL", "US", NA_character_)
  )

  weights <- matrix(c(1, 3, 0, 0), nrow = 2L)
  expect_error(
    functions_environment$wlv_distribute_capital_stock(
      weights,
      capital_stock = c(20, 10)
    ),
    "fallback matrix",
    fixed = TRUE
  )
  distributed <- functions_environment$wlv_distribute_capital_stock(
    weights,
    capital_stock = c(20, 10),
    fallback_weights = matrix(c(0, 0, 2, 3), nrow = 2L)
  )
  expect_equal(distributed[, 1L], c(5, 15))
  expect_equal(distributed[, 2L], c(4, 6))
  expect_identical(attr(distributed, "wlv.fallback_columns"), 2L)
  expect_equal(colSums(distributed), c(20, 10))

  intermediate <- matrix(c(4, 2, 1, 3), nrow = 2L)
  depreciation <- matrix(c(NA, 0.5, 0, 1), nrow = 2L)
  structural_missing <- is.na(depreciation)
  expect_equal(
    functions_environment$wlv_sum_input_flows(
      intermediate,
      depreciation,
      structural_missing = structural_missing
    ),
    intermediate + matrix(c(0, 0.5, 0, 1), nrow = 2L)
  )
  expect_error(
    functions_environment$wlv_sum_input_flows(intermediate, depreciation),
    "undeclared missing",
    fixed = TRUE
  )
  depreciation[1L, 1L] <- NaN
  expect_error(
    functions_environment$wlv_sum_input_flows(
      intermediate,
      depreciation,
      structural_missing = structural_missing
    ),
    "NaN or infinite",
    fixed = TRUE
  )
})

test_that("the WIOD13 workbook missingness contract is positional, not count-only", {
  sea <- data.frame(
    country = c("A", "B"),
    variable = c("LAB", "LAB"),
    code = c("S1", "S1"),
    `2000` = c(NA_real_, 1),
    `2001` = c(2, NA_real_),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  signature <- wiodr13_validation_environment$
    wlv_wiodr13_workbook_missingness_signature(sea, c("2000", "2001"))
  expect_no_error(
    wiodr13_validation_environment$wlv_wiodr13_validate_workbook_missingness(
      sea,
      years = c("2000", "2001"),
      expected_by_year = c(`2000` = 1L, `2001` = 1L),
      expected_count = 2L,
      expected_md5 = signature$md5
    )
  )

  swapped <- sea
  swapped$`2000` <- rev(swapped$`2000`)
  swapped$`2001` <- rev(swapped$`2001`)
  expect_equal(unname(colSums(is.na(swapped[c("2000", "2001")]))), c(1, 1))
  expect_error(
    wiodr13_validation_environment$wlv_wiodr13_validate_workbook_missingness(
      swapped,
      years = c("2000", "2001"),
      expected_by_year = c(`2000` = 1L, `2001` = 1L),
      expected_count = 2L,
      expected_md5 = signature$md5
    ),
    "pinned coordinate signature",
    fixed = TRUE
  )
})

test_that("only complete EU KLEMS inputs used by WIOD13 pass validation", {
  root <- tempfile("wiodr13-euklems-")
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
    wiodr13_validation_environment$wlv_validate_wiodr13_euklems(
      path,
      required_variables = "K_ONE",
      required_sectors = c("A", "B")
    )
  }
  expect_no_error(validate())

  value$K_ONE[[1L]] <- NaN
  fst::write_fst(value, path)
  expect_error(validate(), "non-finite value", fixed = TRUE)

  value <- value[-1L, ]
  value$K_ONE <- seq_len(nrow(value))
  fst::write_fst(value, path)
  expect_error(validate(), "lacks required country-sector keys", fixed = TRUE)
})

test_that("productive exploitation rates include a ratio-of-totals world value", {
  years <- c("2000", "2001")
  countries <- c("A", "B")
  source_variables <- c(
    "abstract_labour.emp.s.mv",
    "labour_force_value.emp.s.mv",
    "abstract_labour.empe.s.mv",
    "labour_force_value.s.mv"
  )
  result_variables <- c(
    "surplus_value.emp_p.r.pc",
    "surplus_value.empe_p.r.pc"
  )
  sea_sectors <- array(
    0,
    dim = c(2L, 4L, 1L, 2L),
    dimnames = list(years, source_variables, "S", countries)
  )
  sea_sectors[, "abstract_labour.emp.s.mv", , ] <- matrix(c(20, 30, 40, 50), 2L)
  sea_sectors[, "labour_force_value.emp.s.mv", , ] <- matrix(c(10, 10, 10, 20), 2L)
  sea_sectors[, "abstract_labour.empe.s.mv", , ] <- matrix(c(12, 18, 20, 30), 2L)
  sea_sectors[, "labour_force_value.s.mv", , ] <- matrix(c(6, 9, 10, 10), 2L)

  environment <- new.env(parent = baseenv())
  environment$lists <- list(countries = countries)
  environment$nums <- list(years = length(years))
  environment$rows <- data.frame(productive = c(1, 1), num_country = c(1, 2))
  environment$sea_sectors <- sea_sectors
  environment$sea_countries <- array(
    NA_real_,
    dim = c(2L, 2L, 3L),
    dimnames = list(years, result_variables, c(countries, "WWW"))
  )
  sys.source(
    file.path(
      wlv_test_root,
      "R", "modules", "variables", "common",
      "surplus_value.emp_p.r.pc-country.R"
    ),
    envir = environment
  )
  sys.source(
    file.path(
      wlv_test_root,
      "R", "modules", "variables", "common",
      "surplus_value.empe_p.r.pc-country.R"
    ),
    envir = environment
  )

  expect_true(all(is.finite(environment$sea_countries)))
  expect_equal(
    unname(environment$sea_countries[, "surplus_value.emp_p.r.pc", "WWW"]),
    c((20 + 40) / (10 + 10) - 1, (30 + 50) / (10 + 20) - 1)
  )
  expect_equal(
    unname(environment$sea_countries[, "surplus_value.empe_p.r.pc", "WWW"]),
    c((12 + 20) / (6 + 10) - 1, (18 + 30) / (9 + 10) - 1)
  )
})
