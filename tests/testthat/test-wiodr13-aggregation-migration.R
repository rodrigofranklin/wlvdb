wiodr13_aggregation_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "aggregation_specs.R"),
  envir = wiodr13_aggregation_environment
)

wlv_read_wiodr13_contract <- function(version = "v2") {
  utils::read.csv2(
    file.path(
      wlv_test_root,
      "contracts",
      "units",
      sprintf("wiodr13_%s-aggregations.csv", version)
    ),
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL
  )
}

wlv_wiodr13_contract_row <- function(indicator, level = "sector_to_country") {
  contract <- wlv_read_wiodr13_contract()
  selected <- contract$indicator == indicator & contract$level == level
  stopifnot(sum(selected) == 1L)
  contract[selected, , drop = FALSE]
}

wlv_wiodr13_spec <- function(row) {
  strategy <- if (identical(row$strategy[[1L]], "mean")) {
    "legacy_mean"
  } else {
    row$strategy[[1L]]
  }
  zero <- row$zero_denominator[[1L]]
  if (!nzchar(zero)) zero <- NULL
  wiodr13_aggregation_environment$wlv_aggregation_spec(
    strategy = strategy,
    level = row$level[[1L]],
    missing = "available",
    zero_denominator = zero
  )
}

wlv_wiodr13_array <- function(value, role = "sector") {
  array(
    value,
    dim = c(year = 1L, length(value)),
    dimnames = setNames(list("2000", paste0(substr(role, 1L, 1L), seq_along(value))), c("year", role))
  )
}

wlv_wiodr13_weighted <- function(indicator, value, weight) {
  row <- wlv_wiodr13_contract_row(indicator)
  wiodr13_aggregation_environment$wlv_aggregate(
    wlv_wiodr13_spec(row),
    value = wlv_wiodr13_array(value),
    weight = wlv_wiodr13_array(weight)
  )
}

test_that("WIOD13 v2 preserves indicator shape while versioning the science", {
  v1_units <- utils::read.csv2(
    file.path(wlv_test_root, "contracts", "units", "wiodr13_v1-units.csv"),
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL
  )
  v2_units <- utils::read.csv2(
    file.path(wlv_test_root, "contracts", "units", "wiodr13_v2-units.csv"),
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL
  )
  v1 <- wlv_read_wiodr13_contract("v1")
  v2 <- wlv_read_wiodr13_contract("v2")

  expect_identical(v2_units$indicator, v1_units$indicator)
  expect_identical(v2$indicator, v1$indicator)
  expect_identical(v2$level, v1$level)
  expect_equal(nrow(v2_units), 58L)
  expect_equal(nrow(v2), 116L)
  expect_equal(length(unique(paste(v2$indicator, v2$level))), 116L)

  catalog <- utils::read.csv2(
    file.path(wlv_test_root, "catalog", "sources.csv"),
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL
  )
  expect_identical(
    catalog$unit_contract[catalog$source == "wiodr13"],
    "wiodr13_units_v2"
  )
})

test_that("WIOD13 v2 declares the scientific dependencies at both levels", {
  contract <- wlv_read_wiodr13_contract()
  both <- function(indicator) {
    contract[contract$indicator == indicator, , drop = FALSE]
  }

  compensation_shares <- c(
    "compensation.empe_hs.r.pc",
    "compensation.empe_ms.r.pc",
    "compensation.empe_ls.r.pc"
  )
  hour_shares <- c(
    "hours_worked.empe_hs.r.pc",
    "hours_worked.empe_ms.r.pc",
    "hours_worked.empe_ls.r.pc"
  )
  expect_true(all(unlist(lapply(compensation_shares, function(indicator) {
    rows <- both(indicator)
    rows$strategy == "weighted_mean" &
      rows$weight == "compensation.empe.s.us" &
      rows$zero_denominator == "not_applicable"
  }))))
  expect_true(all(unlist(lapply(hour_shares, function(indicator) {
    rows <- both(indicator)
    rows$strategy == "weighted_mean" &
      rows$weight == "hours_worked.empe.s.hr" &
      rows$zero_denominator == "not_applicable"
  }))))

  value <- both("value.m.mv")
  expect_identical(value$strategy, rep("ratio_of_sums", 2L))
  expect_identical(value$numerator, rep("gross_output.s.mv", 2L))
  expect_identical(value$denominator, rep("gross_output.s.us", 2L))
  expect_identical(value$zero_denominator, rep("not_applicable", 2L))

  employees <- both("complex_labour_multiplier.empe.r.un")
  persons <- both("complex_labour_multiplier.emp.r.un")
  expect_identical(employees$weight, rep("hours_worked.empe.s.hr", 2L))
  expect_identical(persons$weight, rep("hours_worked.emp.s.hr", 2L))
})

test_that("WIOD13 asymmetric golden values distinguish typed aggregation", {
  golden <- utils::read.csv2(
    file.path(wlv_test_root, "tests", "fixtures", "wiodr13-aggregation-golden.csv"),
    stringsAsFactors = FALSE,
    dec = ".",
    check.names = FALSE
  )

  typed <- c(
    compensation_share = as.numeric(wlv_wiodr13_weighted(
      "compensation.empe_hs.r.pc", c(0.9, 0.1), c(10, 90)
    )),
    hours_share = as.numeric(wlv_wiodr13_weighted(
      "hours_worked.empe_hs.r.pc", c(0.8, 0.2), c(25, 75)
    )),
    go_price = as.numeric(wlv_wiodr13_weighted(
      "go_price.r.id", c(0.8, 1.2), c(10, 90)
    )),
    complex_employees = as.numeric(wlv_wiodr13_weighted(
      "complex_labour_multiplier.empe.r.un", c(1, 3), c(90, 10)
    ))
  )
  value_row <- wlv_wiodr13_contract_row("value.m.mv")
  typed <- c(
    typed,
    value_per_usd = as.numeric(wiodr13_aggregation_environment$wlv_aggregate(
      wlv_wiodr13_spec(value_row),
      numerator = wlv_wiodr13_array(c(8, 90)),
      denominator = wlv_wiodr13_array(c(2, 30))
    ))
  )
  legacy <- c(
    compensation_share = mean(c(0.9, 0.1)),
    hours_share = mean(c(0.8, 0.2)),
    go_price = mean(c(0.8, 1.2)),
    complex_employees = mean(c(1, 3)),
    value_per_usd = sum(c(8 / 2, 90 / 30))
  )

  expect_identical(names(typed), golden$case)
  expect_equal(unname(typed), golden$typed, tolerance = 1e-15)
  expect_equal(unname(legacy), golden$legacy, tolerance = 1e-15)
  expect_true(all(abs(typed - legacy) > 0.01))
})

test_that("WIOD13 currency and national indices reject meaningless worlds", {
  contract <- wlv_read_wiodr13_contract()
  national <- c(
    "exchange.r.us",
    "basket_price.r.pc",
    "exchange.r.id",
    "basket_value.r.pc"
  )
  for (indicator in national) {
    sector <- contract[
      contract$indicator == indicator &
        contract$level == "sector_to_country",
      ,
      drop = FALSE
    ]
    world <- contract[
      contract$indicator == indicator &
        contract$level == "country_to_world",
      ,
      drop = FALSE
    ]
    expect_identical(sector$strategy, "invariant", info = indicator)
    expect_identical(world$strategy, "not_applicable", info = indicator)

    invariant <- wiodr13_aggregation_environment$wlv_aggregate(
      wlv_wiodr13_spec(sector),
      value = wlv_wiodr13_array(c(1.25, 1.25))
    )
    expect_equal(as.numeric(invariant), 1.25, info = indicator)
    expect_error(
      wiodr13_aggregation_environment$wlv_aggregate(
        wlv_wiodr13_spec(sector),
        value = wlv_wiodr13_array(c(1.25, 1.5))
      ),
      "Invariant aggregation differs",
      info = indicator
    )

    absent <- wiodr13_aggregation_environment$wlv_aggregate(
      wlv_wiodr13_spec(world),
      value = wlv_wiodr13_array(c(1, 2), role = "country")
    )
    expect_true(is.na(as.numeric(absent)), info = indicator)
    expect_identical(
      as.vector(wiodr13_aggregation_environment$wlv_aggregation_state(absent)),
      "not_applicable",
      info = indicator
    )
  }

  go_world <- wlv_wiodr13_contract_row("go_price.r.id", "country_to_world")
  expect_identical(go_world$strategy, "not_applicable")
})

test_that("WIOD13 weighted zero totals have an explicit state", {
  value <- wlv_wiodr13_weighted(
    "compensation.empe_hs.r.pc",
    c(0.9, 0.1),
    c(0, 0)
  )
  expect_true(is.na(as.numeric(value)))
  expect_identical(
    as.vector(wiodr13_aggregation_environment$wlv_aggregation_state(value)),
    "not_applicable"
  )
})

test_that("WIOD13 canonical index calculations and labels use base one", {
  units <- utils::read.csv2(
    file.path(wlv_test_root, "contracts", "units", "wiodr13_v2-units.csv"),
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL
  )
  indices <- c(
    "basket_price.r.pc",
    "exchange.r.id",
    "basket_value.r.pc",
    "go_price.r.id"
  )
  selected <- units[match(indices, units$indicator), , drop = FALSE]
  expect_identical(selected$base_year, rep("2000", length(indices)))
  expect_identical(selected$index_base, rep("1", length(indices)))

  modules <- c("basket_price.r.pc.R", "basket_value.r.pc.R")
  for (module in modules) {
    text <- readLines(
      file.path(
        wlv_test_root,
        "R",
        "modules",
        "variables",
        "wiodr13",
        module
      ),
      warn = FALSE,
      encoding = "UTF-8"
    )
    expect_false(any(grepl("/100", text, fixed = TRUE)), info = module)
    expect_true(any(grepl("2000 = 1", text, fixed = TRUE)), info = module)
    expect_false(any(grepl("2000 = 100", text, fixed = TRUE)), info = module)
  }
})
