indicator_metadata_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "indicator_metadata.R"),
  envir = indicator_metadata_environment
)

wlv_read_wiodr16_v2_units <- function() {
  utils::read.csv2(
    file.path(
      wlv_test_root,
      "contracts", "units", "wiodr16_v2-units.csv"
    ),
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = ""
  )
}

test_that("WIOD16 v2 projects canonical and display metadata explicitly", {
  units <- wlv_read_wiodr16_v2_units()
  indicators <- c("go_price.r.id", "exchange.r.id", "gross_output.s.us")
  metadata <- indicator_metadata_environment$wlv_contract_indicator_metadata(
    units,
    indicators
  )

  expect_identical(metadata$code, indicators)
  expect_identical(
    metadata$canonical_unit,
    c("index", "index", "usd")
  )
  expect_identical(
    metadata$display_unit,
    c("index_point", "index_point", "usd")
  )
  expect_identical(metadata$display_multiplier, c(100, 100, 1))
  expect_identical(metadata$index_base_year, c("2000", "2000", NA_character_))
  expect_identical(metadata$index_storage_base, c(1, 1, NA_real_))
})

test_that("legacy result metadata remains readable without implicit rescaling", {
  legacy <- data.frame(
    code = c("go_price.r.id", "gross_output.s.us"),
    name = c("Price", "Output"),
    stringsAsFactors = FALSE
  )
  expect_warning(
    completed <- indicator_metadata_environment$wlv_complete_indicator_metadata(
      legacy
    ),
    "display_multiplier = 1",
    fixed = TRUE
  )
  expect_identical(completed$display_multiplier, c(1, 1))
  expect_warning(
    displayed <- indicator_metadata_environment$wlv_display_values(
      c(100, 250),
      legacy,
      "go_price.r.id"
    ),
    "display_multiplier = 1",
    fixed = TRUE
  )
  expect_identical(displayed, c(100, 250))
})

test_that("WIOD16 gross-output prices are stored at base one and displayed once", {
  environment <- new.env(parent = globalenv())
  sys.source(
    file.path(wlv_test_root, "R", "lib", "functions.R"),
    envir = environment
  )
  environment$`%>%` <- magrittr::`%>%`
  environment$lists <- list(
    years = c("2000", "2001"),
    sectors = "S1",
    countries = "A"
  )
  environment$nums <- list(years = 2L, sectors = 1L, countries = 1L)
  environment$sea_source <- array(
    c(2, 3),
    dim = c(2L, 1L, 1L, 1L),
    dimnames = list(c("2000", "2001"), "GO_PI", "S1", "A")
  )
  environment$sea_sectors <- array(
    NA_real_,
    dim = c(2L, 1L, 1L, 1L),
    dimnames = list(c("2000", "2001"), "go_price.r.id", "S1", "A")
  )
  environment$meta_indicators <- data.frame(
    name = "",
    description = "",
    observation = "",
    type = "",
    group = "",
    reverted = FALSE,
    stringsAsFactors = FALSE,
    row.names = "go_price.r.id"
  )

  sys.source(
    file.path(
      wlv_test_root,
      "R", "modules", "variables", "wiodr16", "go_price.r.id.R"
    ),
    envir = environment
  )
  stored <- as.numeric(environment$sea_sectors[, "go_price.r.id", , ])
  expect_identical(stored, c(1, 1.5))

  units <- wlv_read_wiodr16_v2_units()
  metadata <- indicator_metadata_environment$wlv_contract_indicator_metadata(
    units,
    "go_price.r.id"
  )
  expect_identical(
    indicator_metadata_environment$wlv_display_values(
      stored,
      metadata,
      "go_price.r.id"
    ),
    c(100, 150)
  )
  expect_identical(stored, c(1, 1.5))
})

test_that("effective unit sidecars expose unambiguous index storage metadata", {
  catalog_environment <- new.env(parent = baseenv())
  sys.source(
    file.path(wlv_test_root, "R", "lib", "catalog.R"),
    envir = catalog_environment
  )
  catalog <- catalog_environment$wlv_load_catalog(wlv_test_root)
  sidecar <- catalog_environment$wlv_catalog_unit_contract_sidecar(
    catalog,
    "wiodr16_units_v2"
  )
  row <- sidecar$indicator == "go_price.r.id"
  expect_true(all(sidecar$canonical_unit[row] == "index"))
  expect_true(all(sidecar$display_unit[row] == "index_point"))
  expect_true(all(sidecar$display_multiplier[row] == 100))
  expect_true(all(sidecar$index_base_year[row] == "2000"))
  expect_true(all(sidecar$index_storage_base[row] == 1))
})
