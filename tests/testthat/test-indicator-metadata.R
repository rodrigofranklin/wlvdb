indicator_metadata_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "scripts", "lib", "indicator_metadata.R"),
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

test_that("unit contracts fill display metadata before checking overrides", {
  units <- wlv_read_wiodr16_v2_units()
  metadata <- data.frame(
    code = c("go_price.r.id", "gross_output.s.us"),
    name = c("Price", "Output"),
    stringsAsFactors = FALSE
  )

  completed <- indicator_metadata_environment$wlv_complete_indicator_metadata(
    metadata,
    units = units
  )

  expect_identical(completed$display_multiplier, c(100, 1))
  expect_identical(completed$canonical_unit, c("index", "usd"))
  expect_identical(completed$index_base_year, c("2000", NA_character_))

  metadata$display_multiplier <- c(1, NA_real_)
  expect_error(
    indicator_metadata_environment$wlv_complete_indicator_metadata(
      metadata,
      units = units
    ),
    "display_multiplier",
    fixed = TRUE
  )
})

test_that("stable unit contracts fully project into fresh result metadata", {
  for (contract in c("wiodr13_v2", "wiodr16_v2")) {
    units <- utils::read.csv2(
      file.path(
        wlv_test_root,
        "contracts", "units", paste0(contract, "-units.csv")
      ),
      stringsAsFactors = FALSE,
      colClasses = "character",
      check.names = FALSE,
      na.strings = ""
    )
    expected <- indicator_metadata_environment$wlv_contract_indicator_metadata(
      units
    )
    metadata <- data.frame(
      code = units$indicator,
      name = NA_character_,
      stringsAsFactors = FALSE
    )
    completed <- indicator_metadata_environment$wlv_complete_indicator_metadata(
      metadata,
      units = units
    )

    expect_identical(completed[, names(expected)], expected)
    expect_identical(
      indicator_metadata_environment$wlv_complete_indicator_metadata(
        completed,
        units = units
      )[, names(expected)],
      expected
    )
  }
})

test_that("WIOD16 gross-output prices are stored at base one and displayed once", {
  environment <- new.env(parent = globalenv())
  sys.source(
    file.path(wlv_test_root, "scripts", "lib", "functions.R"),
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
      "scripts", "modules", "variables", "wiodr16", "go_price.r.id.R"
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
  expect_identical(stored * metadata$display_multiplier[[1L]], c(100, 150))
  expect_identical(stored, c(1, 1.5))
})

test_that("effective unit sidecars expose unambiguous index storage metadata", {
  catalog_environment <- new.env(parent = baseenv())
  sys.source(
    file.path(wlv_test_root, "scripts", "lib", "catalog.R"),
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

test_that("contracts distinguish constant compensation and percent display", {
  contracts <- list(
    wiodr13_v1 = c(
      "surplus_value.empe_hs.r.pc", "surplus_value.empe_ms.r.pc",
      "surplus_value.empe_ls.r.pc", "surplus_value.empe.r.pc",
      "appropriated_profit.r.pc", "trade_transfers.p.m.pc",
      "surplus_value.emp.r.pc", "surplus_value.emp_p.r.pc",
      "surplus_value.empe_p.r.pc"
    ),
    wiodr13_v2 = c(
      "surplus_value.empe_hs.r.pc", "surplus_value.empe_ms.r.pc",
      "surplus_value.empe_ls.r.pc", "surplus_value.empe.r.pc",
      "appropriated_profit.r.pc", "trade_transfers.p.m.pc",
      "surplus_value.emp.r.pc", "surplus_value.emp_p.r.pc",
      "surplus_value.empe_p.r.pc"
    ),
    wiodr16_v1 = c(
      "surplus_value.empe.r.pc", "appropriated_profit.r.pc",
      "trade_transfers.p.m.pc", "surplus_value.emp.r.pc",
      "surplus_value.emp_p.r.pc", "surplus_value.empe_p.r.pc"
    ),
    wiodr16_v2 = c(
      "surplus_value.empe.r.pc", "appropriated_profit.r.pc",
      "trade_transfers.p.m.pc", "surplus_value.emp.r.pc",
      "surplus_value.emp_p.r.pc", "surplus_value.empe_p.r.pc"
    )
  )

  for (contract in names(contracts)) {
    units <- utils::read.csv2(
      file.path(
        wlv_test_root,
        "contracts", "units", paste0(contract, "-units.csv")
      ),
      stringsAsFactors = FALSE,
      colClasses = "character",
      check.names = FALSE,
      na.strings = ""
    )
    percent <- units$indicator %in% contracts[[contract]]
    expect_setequal(units$indicator[percent], contracts[[contract]])
    expect_true(all(units$display_unit[percent] == "percent"))
    expect_true(all(units$display_multiplier[percent] == "100"))

    compensation <- units$indicator %in% c(
      "compensation.emp.s.cu", "compensation.empe.s.cu"
    )
    expect_identical(
      units$source_unit[compensation], rep("usd", 2L)
    )
    expect_identical(units$canonical_unit[compensation], rep("usd", 2L))
    expect_identical(units$display_unit[compensation], rep("usd", 2L))
    expect_identical(units$currency[compensation], rep("usd", 2L))
    expect_identical(units$price_basis[compensation], rep("constant", 2L))
    expect_identical(units$base_year[compensation], rep("2000", 2L))

    aggregations <- utils::read.csv2(
      file.path(
        wlv_test_root,
        "contracts", "units", paste0(contract, "-aggregations.csv")
      ),
      stringsAsFactors = FALSE,
      colClasses = "character",
      check.names = FALSE,
      na.strings = NULL
    )
    world_compensation <- aggregations$indicator %in% c(
      "compensation.emp.s.cu", "compensation.empe.s.cu"
    ) & aggregations$level == "country_to_world"
    expect_identical(
      aggregations$strategy[world_compensation],
      rep("sum", 2L)
    )
  }
})

test_that("shared index labels separate storage from presentation", {
  modules <- file.path(
    wlv_test_root,
    "scripts", "modules", "variables", "wiodr13",
    c(
      "basket_price.r.pc.R", "basket_value.r.pc.R", "exchange.r.id.R",
      "exchange.r.id.v09.R"
    )
  )
  for (module in modules) {
    source <- readLines(module, encoding = "UTF-8", warn = FALSE)
    name_line <- grep(
      'meta_indicators\\[code,[[:space:]]*"name"\\]',
      source,
      value = TRUE
    )
    expect_length(name_line, 1L)
    expect_false(grepl("2000", name_line, fixed = TRUE))
    expect_true(any(grepl(
      "presentation scale is defined",
      tolower(source),
      fixed = TRUE
    )))
  }
})
