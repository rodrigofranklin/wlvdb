test_that("the synthetic fixture completes the real calculation pipeline", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)

  run <- NULL
  expect_no_error(
    suppressMessages(run <- wlv_run_synthetic_calculation(fixture, workers = 1L))
  )
  expect_identical(run$result, fixture$method)

  result_path <- file.path("results", fixture$method)
  expected_files <- c(
    "m_io2000-2001.fst", "m_io2000-2001.fst.meta",
    "m_countries.fst", "m_countries.fst.meta",
    "sea_sectors.fst", "sea_sectors.fst.meta",
    "sea_countries.fst", "sea_countries.fst.meta",
    "meta_indicators.RDS"
  )
  expect_true(all(file.exists(file.path(fixture$root, result_path, expected_files))))

  m_io <- wlv_read_fixture_array(fixture, result_path, "m_io2000-2001.fst")
  m_countries <- wlv_read_fixture_array(fixture, result_path, "m_countries.fst")
  sea_sectors <- wlv_read_fixture_array(fixture, result_path, "sea_sectors.fst")
  sea_countries <- wlv_read_fixture_array(fixture, result_path, "sea_countries.fst")

  expect_identical(
    unname(lapply(dimnames(m_io), unname)),
    list(
      c("2000", "2001"),
      c("k_depreciation", "values", "transfers_values"),
      c("A.S", "B.S"),
      c("A.S", "B.S", "A.HH", "B.HH")
    )
  )
  expect_identical(
    unname(lapply(dimnames(m_countries), unname)),
    list(
      c("2000", "2001"),
      c("exports_values", "transfers_values"),
      c("A", "B"),
      c("A", "B")
    )
  )
  expect_identical(
    unname(lapply(dimnames(sea_sectors), unname)),
    list(
      c("2000", "2001"),
      c(
        "abstract_labour.emp.s.mv", "gross_output.s.us",
        "price.marker", "value.m.mv", "gross_output.s.mv"
      ),
      "S",
      c("A", "B")
    )
  )

  expected_sectors <- fixture$expected$sea_sectors
  for (index in seq_len(nrow(expected_sectors))) {
    expected <- expected_sectors[index, ]
    coordinates <- list(
      as.character(expected$year),
      expected$sector,
      expected$country
    )
    expect_equal(
      sea_sectors[coordinates[[1]], "value.m.mv", coordinates[[2]], coordinates[[3]]],
      expected$value.m.mv,
      tolerance = 1e-14
    )
    expect_equal(
      sea_sectors[
        coordinates[[1]], "gross_output.s.mv", coordinates[[2]], coordinates[[3]]
      ],
      expected$gross_output.s.mv,
      tolerance = 1e-12
    )
  }

  expect_equal(
    as.vector(sea_sectors[, "price.marker", "S", ]),
    c(2, 4, 3, 5)
  )

  expected_trade <- fixture$expected$trade
  for (index in seq_len(nrow(expected_trade))) {
    expected <- expected_trade[index, ]
    year <- as.character(expected$year)
    expect_equal(
      m_countries[year, "exports_values", expected$origin, expected$destination],
      expected$exports_values,
      tolerance = 1e-12
    )
    expect_equal(
      m_countries[year, "transfers_values", expected$origin, expected$destination],
      expected$transfers_values,
      tolerance = 1e-12
    )
  }

  for (year in c("2000", "2001")) {
    expect_equal(
      unname(rowSums(m_io[year, "values", , ])),
      as.vector(sea_sectors[year, "gross_output.s.mv", "S", ]),
      tolerance = 1e-12
    )
    expect_equal(sum(m_countries[year, "transfers_values", , ]), 0, tolerance = 1e-12)
    expect_equal(
      unname(diag(m_countries[year, "exports_values", , ])),
      c(0, 0)
    )
    expect_equal(
      unname(diag(m_countries[year, "transfers_values", , ])),
      c(0, 0),
      tolerance = 1e-12
    )
  }

  expect_equal(
    sea_countries[, , c("A", "B")],
    aperm(sea_sectors[, , "S", ], c(1, 2, 3)),
    tolerance = 1e-12
  )
  sum_variables <- c(
    "abstract_labour.emp.s.mv", "gross_output.s.us", "gross_output.s.mv"
  )
  expect_equal(
    sea_countries[, sum_variables, "WWW"],
    apply(
      sea_countries[, sum_variables, c("A", "B"), drop = FALSE],
      c(1, 2),
      sum
    ),
    tolerance = 1e-12
  )
  expect_equal(
    sea_countries[, "value.m.mv", "WWW"],
    apply(
      sea_countries[, "value.m.mv", c("A", "B"), drop = FALSE],
      1,
      mean
    ),
    tolerance = 1e-14
  )
  expect_equal(
    sea_countries[, "price.marker", "WWW"],
    apply(
      sea_countries[, "price.marker", c("A", "B"), drop = FALSE],
      1,
      mean
    )
  )
  expect_true(all(is.finite(m_io[, "values", , ])))
  expect_true(all(is.finite(m_io[, "transfers_values", , ])))
  expect_true(all(is.finite(m_io[, "k_depreciation", , c("A.S", "B.S")])))
  expect_true(all(is.finite(m_countries)))
  expect_true(all(is.finite(sea_sectors)))
  expect_true(all(is.finite(sea_countries)))
})

test_that("recalculation repairs a selected result and preserves the others", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  run <- suppressMessages(wlv_run_synthetic_calculation(fixture, workers = 1L))

  result_path <- file.path("results", fixture$method)
  result_file <- file.path(result_path, "sea_sectors.fst")
  original <- wlv_read_fixture_array(fixture, result_file)
  corrupted <- original
  corrupted[, "gross_output.s.mv", , ] <- -999
  wlv_write_fixture_array(fixture, corrupted, result_file)

  expect_no_error(
    suppressMessages(
      wlv_recalculate_synthetic_fixture(
        fixture,
        runtime = run$runtime,
        at_stage = 4L,
        sea_vars = "gross_output.s.mv",
        workers = 1L
      )
    )
  )
  repaired <- wlv_read_fixture_array(fixture, result_file)
  expect_equal(
    repaired[, "gross_output.s.mv", , ],
    original[, "gross_output.s.mv", , ],
    tolerance = 1e-12
  )
  preserved <- setdiff(dimnames(original)[[2]], "gross_output.s.mv")
  expect_identical(repaired[, preserved, , ], original[, preserved, , ])

  expect_no_error(
    suppressMessages(
      wlv_recalculate_synthetic_fixture(
        fixture,
        runtime = run$runtime,
        at_stage = 5L,
        workers = 1L
      )
    )
  )
})

test_that("the fixture inputs and outputs stay outside the checkout", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)

  checkout <- normalizePath(wlv_test_root, winslash = "/", mustWork = TRUE)
  expect_false(startsWith(fixture$root, paste0(checkout, "/")))

  before <- system2(
    "git",
    c("-C", shQuote(checkout), "status", "--porcelain"),
    stdout = TRUE,
    stderr = TRUE
  )
  suppressMessages(wlv_run_synthetic_calculation(fixture, workers = 1L))
  after <- system2(
    "git",
    c("-C", shQuote(checkout), "status", "--porcelain"),
    stdout = TRUE,
    stderr = TRUE
  )

  expect_identical(after, before)
  expect_true(dir.exists(file.path(fixture$root, "results", fixture$method)))
})
