wiodr16_functions_environment <- new.env(parent = globalenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "functions.R"),
  envir = wiodr16_functions_environment
)

wlv_wiodr16_sectors <- function(method = "wiodr16") {
  utils::read.csv2(
    file.path(wlv_test_root, "methods", method, "_sectors.csv"),
    stringsAsFactors = FALSE
  )
}

wlv_read_china_hours_fixture <- function(path = file.path(
    wlv_test_root,
    "complementar",
    "wiodr16",
    "china_hours_per_worker.csv"
  ), method = "wiodr16") {
  sectors <- wlv_wiodr16_sectors(method)
  wiodr16_functions_environment$wlv_read_wiodr16_china_hours_per_worker(
    path,
    expected_codes = sectors$sector.source,
    expected_names = sectors$sector,
    expected_years = as.character(2000:2014)
  )
}

test_that("the three WIOD16 methods preserve their scientific sector contracts", {
  standard <- wlv_wiodr16_sectors("wiodr16")
  version_09 <- wlv_wiodr16_sectors("wiodr16v09")
  zero_depreciation <- wlv_wiodr16_sectors("zerodep_2")

  expect_identical(version_09$sector.source, standard$sector.source)
  expect_identical(zero_depreciation$sector.source, standard$sector.source)
  expect_identical(standard$wiod, seq_len(56L))
  expect_identical(version_09$wiod, seq_len(56L))
  expect_identical(zero_depreciation$wiod, seq_len(56L))
  expect_identical(sum(standard$productive), 39L)
  expect_identical(sum(version_09$productive), 32L)
  expect_identical(sum(zero_depreciation$productive), 33L)
  expect_identical(
    standard$sector.source[standard$productive != version_09$productive],
    c("H52", "H53", "I", "J62_J63", "M71", "M74_M75", "R_S")
  )
  expect_identical(
    standard$sector.source[standard$productive != zero_depreciation$productive],
    c("H52", "H53", "J62_J63", "M71", "M74_M75", "R_S")
  )
  expect_identical(
    standard$sector.source[version_09$productive != zero_depreciation$productive],
    "I"
  )
})

test_that("WIOD16 countries follow the EU KLEMS country-code conventions", {
  expect_identical(
    wiodr16_functions_environment$wlv_wiodr16_euklems_country_codes(
      c("GBR", "GRC", "USA", "ROW")
    ),
    c("UK", "EL", "US", NA_character_)
  )
  expect_error(
    wiodr16_functions_environment$wlv_wiodr16_euklems_country_codes(
      c("GBR", NA_character_)
    ),
    "non-empty ISO3 country codes",
    fixed = TRUE
  )

  labels <- c("GBR.S", "GRC.S", "ROW.S", "GBR.c60", "GRC.c60", "ROW.c60")
  expect_identical(
    wiodr16_functions_environment$wlv_wiodr16_gfcf_columns(
      labels,
      c("GBR", "GRC", "ROW")
    ),
    4:6
  )
  expect_error(
    wiodr16_functions_environment$wlv_wiodr16_gfcf_columns(
      c(labels, "GBR.c60"),
      c("GBR", "GRC", "ROW")
    ),
    "exactly one GFCF column",
    fixed = TRUE
  )
  expect_error(
    wiodr16_functions_environment$wlv_wiodr16_gfcf_columns(
      sub("ROW.c60", "ROW.c41", labels, fixed = TRUE),
      c("GBR", "GRC", "ROW")
    ),
    "ROW.c60 (0 found)",
    fixed = TRUE
  )
})

test_that("the restored China hours coefficients have exact labels, years and units", {
  # Restored from historical Git blob 41d50475500bf41a9ee022a6b33cd3e7625eb0d4.
  source_path <- file.path(
    wlv_test_root,
    "complementar",
    "wiodr16",
    "china_hours_per_worker.csv"
  )
  source_bytes <- readBin(
    source_path,
    what = "raw",
    n = file.info(source_path)$size
  )
  git_blob_payload <- c(
    charToRaw(sprintf("blob %s", length(source_bytes))),
    as.raw(0L),
    source_bytes
  )
  expect_identical(
    paste0(openssl::sha1(git_blob_payload)),
    "41d50475500bf41a9ee022a6b33cd3e7625eb0d4"
  )

  for (method in c("wiodr16", "wiodr16v09", "zerodep_2")) {
    hours <- wlv_read_china_hours_fixture(method = method)
    sectors <- wlv_wiodr16_sectors(method)

    expect_identical(dim(hours), c(15L, 56L))
    expect_identical(rownames(hours), as.character(2000:2014))
    expect_identical(colnames(hours), sectors$sector.source)
    expect_true(all(is.finite(hours)))
    expect_true(all(hours >= 0 & hours <= 8.784))
  }

  hours <- wlv_read_china_hours_fixture()
  expect_equal(hours["2000", "A01"], 1.415830823)
  expect_equal(hours["2008", "A01"], 1.580154735)
  expect_identical(hours["2009", ], hours["2014", ])
  expect_identical(hours["2008", ], hours["2009", ])
})

test_that("direct aggregate depreciation rates are not added twice", {
  add_component <-
    wiodr16_functions_environment$wlv_add_synthetic_depreciation_component
  aggregate_rate <- matrix(
    c(0.136, 0),
    nrow = 1L,
    dimnames = list("aggregate", c("direct_R_S", "synthetic_D_E"))
  )
  direct_rate_provided <- matrix(
    c(TRUE, FALSE),
    nrow = 1L,
    dimnames = dimnames(aggregate_rate)
  )
  aggregate_stock <- matrix(c(100, 100), nrow = 1L)

  for (component_stock in c(60, 40)) {
    aggregate_rate <- add_component(
      aggregate_rate = aggregate_rate,
      component_rate = matrix(c(0.136, 0.094), nrow = 1L),
      component_stock = matrix(rep(component_stock, 2L), nrow = 1L),
      aggregate_stock = aggregate_stock,
      direct_rate_provided = direct_rate_provided
    )
  }

  expect_equal(aggregate_rate[, "direct_R_S"], 0.136)
  expect_equal(aggregate_rate[, "synthetic_D_E"], 0.094)
})

test_that("China hours corruption is rejected instead of being silently reordered", {
  source_path <- file.path(
    wlv_test_root,
    "complementar",
    "wiodr16",
    "china_hours_per_worker.csv"
  )
  value <- utils::read.csv2(
    source_path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  write_fixture <- function(value) {
    path <- tempfile(fileext = ".csv")
    utils::write.table(
      value,
      path,
      row.names = FALSE,
      quote = TRUE,
      sep = ";",
      dec = ","
    )
    path
  }

  reordered <- value[c(2L, 1L, 3:nrow(value)), ]
  expect_error(
    wlv_read_china_hours_fixture(write_fixture(reordered)),
    "sector codes or their order",
    fixed = TRUE
  )

  wrong_year_order <- value[c("setor", "code", "2001", "2000", as.character(2002:2014))]
  expect_error(
    wlv_read_china_hours_fixture(write_fixture(wrong_year_order)),
    "columns must be exactly",
    fixed = TRUE
  )

  non_finite <- value
  non_finite[1L, "2000"] <- NA_real_
  expect_error(
    wlv_read_china_hours_fixture(write_fixture(non_finite)),
    "must all be finite",
    fixed = TRUE
  )

  wrong_unit <- value
  wrong_unit[1L, "2000"] <- wrong_unit[1L, "2000"] * 1000
  expect_error(
    wlv_read_china_hours_fixture(write_fixture(wrong_unit)),
    "thousand hours per person",
    fixed = TRUE
  )
})

test_that("the China assumption converts thousands of hours and mirrors employee data", {
  sectors <- wlv_wiodr16_sectors()
  years <- as.character(2000:2014)
  variables <- c(
    "emp.s.un",
    "empe.s.un",
    "hours_worked.emp.s.hr",
    "hours_worked.empe.s.hr"
  )
  environment <- new.env(parent = globalenv())
  sys.source(
    file.path(wlv_test_root, "R", "lib", "functions.R"),
    envir = environment
  )
  sys.source(
    file.path(wlv_test_root, "R", "lib", "wiodr16_allocation.R"),
    envir = environment
  )
  environment$parameters <- data.frame(description = "")
  environment$lists <- list(years = years)
  environment$sectors <- sectors
  environment$sea_sectors <- array(
    0,
    dim = c(15L, 4L, 56L, 1L),
    dimnames = list(years, variables, sectors$sector.source, "CHN")
  )
  environment$sea_sectors[, "emp.s.un", , "CHN"] <- 2

  old_working_directory <- setwd(wlv_test_root)
  on.exit(setwd(old_working_directory), add = TRUE)
  sys.source(
    file.path(
      wlv_test_root,
      "R", "modules", "assumptions", "china", "china_wiodr16.R"
    ),
    envir = environment
  )

  coefficients <- wlv_read_china_hours_fixture()
  expect_equal(
    environment$sea_sectors[, "hours_worked.emp.s.hr", , "CHN"],
    coefficients * 2000
  )
  expect_identical(
    environment$sea_sectors[, "empe.s.un", , "CHN"],
    environment$sea_sectors[, "emp.s.un", , "CHN"]
  )
  expect_identical(
    environment$sea_sectors[, "hours_worked.empe.s.hr", , "CHN"],
    environment$sea_sectors[, "hours_worked.emp.s.hr", , "CHN"]
  )
  expect_match(environment$parameters$description, "H_EMP/EMP", fixed = TRUE)
})

test_that("WIOD16 capital allocation handles UK, Greece, fallback and zero weights", {
  root <- tempfile("wiodr16-matrix-")
  euklems_dir <- file.path(root, "source_data", "euklems")
  dir.create(euklems_dir, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  ek_k <- data.frame(
    country = c("UK", "EL", "MD"),
    sector = "A",
    K_ONE = c(1, 2, 3)
  )
  ek_depreciation <- ek_k[3:1, ]
  ek_depreciation$K_ONE <- c(0.3, 0.2, 0.1)
  fst::write_fst(ek_k, file.path(euklems_dir, "ekk_2000.fst"))
  fst::write_fst(ek_depreciation, file.path(euklems_dir, "ekdeprate_2001.fst"))

  countries <- c("GBR", "GRC", "ROW")
  inputs <- paste0(countries, ".S")
  outputs <- c(inputs, paste0(countries, ".c60"))
  environment <- new.env(parent = globalenv())
  sys.source(
    file.path(wlv_test_root, "R", "lib", "functions.R"),
    envir = environment
  )
  sys.source(
    file.path(wlv_test_root, "R", "lib", "wiodr16_allocation.R"),
    envir = environment
  )
  environment$lists <- list(
    years = "2000",
    countries = countries,
    input = inputs
  )
  environment$nums <- list(input = 3L, sectors = 1L, countries = 3L)
  environment$sectors <- data.frame(
    euklems.sector = "A",
    euklems.capital = "K_ONE"
  )
  environment$rows <- data.frame(country = countries)
  environment$columns <- data.frame(
    sector = c(rep("S", 3L), rep("c60", 3L)),
    country_sector = outputs
  )
  environment$sea_sectors <- array(
    0,
    dim = c(1L, 2L, 1L, 3L),
    dimnames = list("2000", c("gdp.s.us", "capital_stock.s.us"), "S", countries)
  )
  environment$sea_sectors[, "gdp.s.us", , ] <- 1
  environment$sea_sectors[, "capital_stock.s.us", , ] <- c(10, 0, 30)
  environment$m_io_source <- array(
    0,
    dim = c(1L, 3L, 6L),
    dimnames = list("2000", inputs, outputs)
  )
  environment$m_io_source["2000", , paste0(countries, ".c60")] <- matrix(
    c(1, 1, 1, 0, 0, 0, 1, 2, 3),
    nrow = 3L
  )
  environment$m_io <- array(
    NA_real_,
    dim = c(1L, 2L, 3L, 6L),
    dimnames = list(
      "2000",
      c("k_composition", "k_depreciation"),
      inputs,
      outputs
    )
  )

  old_working_directory <- setwd(root)
  on.exit(setwd(old_working_directory), add = TRUE)
  expect_no_error(
    sys.source(
      file.path(
        wlv_test_root,
        "R", "modules", "matrices", "wiodr16", "euklems.R"
      ),
      envir = environment
    )
  )

  composition <- environment$m_io[
    "2000", "k_composition", inputs, inputs, drop = TRUE
  ]
  depreciation <- environment$m_io[
    "2000", "k_depreciation", inputs, inputs, drop = TRUE
  ]
  expect_true(all(is.finite(composition)))
  expect_true(all(is.finite(depreciation)))
  expect_equal(unname(colSums(composition)), c(10, 0, 30))
  expect_equal(unname(composition[, 2L]), c(0, 0, 0))
  expect_equal(
    depreciation,
    sweep(composition, 2L, c(0.1, 0.2, 0.3), "*")
  )
})
