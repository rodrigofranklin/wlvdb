wiodr16_aggregation_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "scripts", "lib", "aggregation_specs.R"),
  envir = wiodr16_aggregation_environment
)

wlv_wiodr16_v2_aggregations <- utils::read.csv2(
  file.path(
    wlv_test_root,
    "contracts", "units", "wiodr16_v2-aggregations.csv"
  ),
  stringsAsFactors = FALSE,
  colClasses = "character",
  check.names = FALSE,
  na.strings = NULL
)

wlv_wiodr16_contract_spec <- function(indicator, level) {
  row <- wlv_wiodr16_v2_aggregations[
    wlv_wiodr16_v2_aggregations$indicator == indicator &
      wlv_wiodr16_v2_aggregations$level == level,
    ,
    drop = FALSE
  ]
  stopifnot(nrow(row) == 1L, row$strategy != "formula")
  wiodr16_aggregation_environment$wlv_aggregation_spec(
    strategy = row$strategy,
    level = row$level,
    missing = "error",
    zero_denominator = if (
      row$strategy %in% c("ratio_of_sums", "weighted_mean")
    ) {
      row$zero_denominator
    } else {
      NULL
    }
  )
}

wlv_wiodr16_asymmetric_array <- function(values) {
  array(
    values,
    dim = c(1L, 2L, 2L),
    dimnames = list(
      year = "2000",
      sector = c("S1", "S2"),
      country = c("A", "B")
    )
  )
}

test_that("WIOD16 v2 declares every migrated scientific aggregation", {
  rows <- wlv_wiodr16_v2_aggregations
  expected <- list(
    exchange.r.us = c("invariant", "not_applicable"),
    basket_price.r.pc = c("invariant", "not_applicable"),
    exchange.r.id = c("invariant", "not_applicable"),
    basket_value.r.pc = c("invariant", "not_applicable"),
    go_price.r.id = c("weighted_mean", "not_applicable"),
    value.m.mv = c("ratio_of_sums", "ratio_of_sums"),
    complex_labour_multiplier.empe.r.un = rep("weighted_mean", 2L),
    complex_labour_multiplier.emp.r.un = rep("weighted_mean", 2L)
  )
  for (indicator in names(expected)) {
    selected <- rows[rows$indicator == indicator, , drop = FALSE]
    expect_identical(selected$strategy, expected[[indicator]], info = indicator)
  }
  go_price <- rows[
    rows$indicator == "go_price.r.id" &
      rows$level == "sector_to_country",
    ,
    drop = FALSE
  ]
  expect_identical(go_price$weight, "gross_output.s.us")
  value <- rows[rows$indicator == "value.m.mv", , drop = FALSE]
  expect_true(all(value$numerator == "gross_output.s.mv"))
  expect_true(all(value$denominator == "gross_output.s.us"))
})

test_that("asymmetric golden uses output weights and ratio of sums", {
  price <- wlv_wiodr16_asymmetric_array(c(1, 3, 2, 4))
  output <- wlv_wiodr16_asymmetric_array(c(10, 30, 5, 15))
  weighted <- wiodr16_aggregation_environment$wlv_aggregate(
    wlv_wiodr16_contract_spec("go_price.r.id", "sector_to_country"),
    value = price,
    weight = output
  )
  expect_equal(as.numeric(weighted), c(2.5, 3.5), tolerance = 1e-14)
  expect_false(isTRUE(all.equal(as.numeric(weighted), c(2, 3))))

  labour_value <- wlv_wiodr16_asymmetric_array(c(20, 120, 5, 45))
  sector_ratio <- wiodr16_aggregation_environment$wlv_aggregate(
    wlv_wiodr16_contract_spec("value.m.mv", "sector_to_country"),
    numerator = labour_value,
    denominator = output
  )
  expect_equal(as.numeric(sector_ratio), c(3.5, 2.5), tolerance = 1e-14)

  country_labour <- array(
    c(140, 50),
    dim = c(1L, 2L),
    dimnames = list(year = "2000", country = c("A", "B"))
  )
  country_output <- array(
    c(40, 20),
    dim = c(1L, 2L),
    dimnames = dimnames(country_labour)
  )
  world_ratio <- wiodr16_aggregation_environment$wlv_aggregate(
    wlv_wiodr16_contract_spec("value.m.mv", "country_to_world"),
    numerator = country_labour,
    denominator = country_output
  )
  expect_equal(as.numeric(world_ratio), 190 / 60, tolerance = 1e-14)
  expect_false(isTRUE(all.equal(as.numeric(world_ratio), mean(c(3.5, 2.5)))))
})

test_that("invariant and not-applicable rules preserve their semantics", {
  exchange <- wlv_wiodr16_asymmetric_array(c(2, 2, 5, 5))
  country <- wiodr16_aggregation_environment$wlv_aggregate(
    wlv_wiodr16_contract_spec("exchange.r.us", "sector_to_country"),
    value = exchange
  )
  expect_identical(as.numeric(country), c(2, 5))

  world <- wiodr16_aggregation_environment$wlv_aggregate(
    wlv_wiodr16_contract_spec("exchange.r.us", "country_to_world"),
    value = country
  )
  expect_true(is.na(as.numeric(world)))
  expect_identical(
    as.character(wiodr16_aggregation_environment$wlv_aggregation_state(world)),
    "not_applicable"
  )

  exchange[1L, 2L, "A"] <- 2.1
  expect_error(
    wiodr16_aggregation_environment$wlv_aggregate(
      wlv_wiodr16_contract_spec("exchange.r.us", "sector_to_country"),
      value = exchange
    ),
    "Invariant aggregation differs",
    fixed = TRUE
  )
})

test_that("selective recalculation normalizes only selected price indices", {
  normalize <- function(sea_vars = NULL, expose_selection = TRUE) {
    environment <- new.env(parent = globalenv())
    sys.source(
      file.path(wlv_test_root, "scripts", "lib", "functions.R"),
      envir = environment
    )
    environment$`%>%` <- magrittr::`%>%`
    environment$nums <- list(years = 2L, sectors = 1L, countries = 1L)
    environment$sea_sectors <- array(
      NA_real_,
      dim = c(2L, 2L, 1L, 1L),
      dimnames = list(
        year = c("2000", "2001"),
        indicator = c("basket_price.r.pc", "go_price.r.id"),
        sector = "S1",
        country = "A"
      )
    )
    environment$sea_sectors[, "basket_price.r.pc", , ] <- c(2, 4)
    environment$sea_sectors[, "go_price.r.id", , ] <- c(5, 10)
    if (expose_selection) {
      environment$sea_vars <- sea_vars
    }
    sys.source(
      file.path(
        wlv_test_root,
        "scripts", "modules", "variables", "wiodr13",
        "normalize_price_indices.R"
      ),
      envir = environment
    )
    environment$sea_sectors
  }

  untouched <- normalize("unrelated.metric")
  expect_identical(
    as.numeric(untouched[, "basket_price.r.pc", , ]),
    c(2, 4)
  )
  expect_identical(
    as.numeric(untouched[, "go_price.r.id", , ]),
    c(5, 10)
  )

  basket_only <- normalize("basket_price.r.pc")
  expect_identical(
    as.numeric(basket_only[, "basket_price.r.pc", , ]),
    c(1, 2)
  )
  expect_identical(
    as.numeric(basket_only[, "go_price.r.id", , ]),
    c(5, 10)
  )

  all_indices <- normalize(expose_selection = FALSE)
  expect_identical(
    as.numeric(all_indices[, "basket_price.r.pc", , ]),
    c(1, 2)
  )
  expect_identical(
    as.numeric(all_indices[, "go_price.r.id", , ]),
    c(1, 2)
  )
})
