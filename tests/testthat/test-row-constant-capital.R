row_capital_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "row_capital.R"),
  envir = row_capital_environment
)

test_that("WIOD16 configurations resolve the intended native ROW assumption", {
  runtime <- wlv_test_load_runtime()
  for (method in c("wiodr16", "zerodep_2")) {
    resolved <- runtime$wlv_resolve_module_config(
      wlv_test_root,
      method,
      "wiodr16"
    )
    expect_identical(
      resolved$module_id[resolved$instance_id == "assumption.row"],
      "assumption.row.standard"
    )
  }
  version_09 <- runtime$wlv_resolve_module_config(
    wlv_test_root,
    "wiodr16v09",
    "wiodr16"
  )
  expect_identical(
    version_09$module_id[version_09$instance_id == "assumption.row"],
    "assumption.row.v09"
  )
})

test_that("ROW constant capital is finite, non-negative and base-year identical", {
  rebuild <- row_capital_environment$wlv_row_constant_capital_stock
  current <- matrix(
    c(100, 0, 200, 0),
    nrow = 2L,
    byrow = TRUE,
    dimnames = list(c("2000", "2001"), c("A", "M73"))
  )
  exchange <- matrix(
    c(1, 1, 1.2, 1.2),
    nrow = 2L,
    byrow = TRUE,
    dimnames = dimnames(current)
  )
  price <- matrix(
    c(1, 1, 1.5, 1.5),
    nrow = 2L,
    byrow = TRUE,
    dimnames = dimnames(current)
  )

  result <- rebuild(
    current,
    exchange,
    price,
    expected_zero_sectors = "M73"
  )

  result_values <- result
  attr(result_values, "wlv.row_constant_capital_zeroes") <- NULL
  expect_equal(
    unname(result_values),
    matrix(c(100, 0, 160, 0), nrow = 2L, byrow = TRUE)
  )
  expect_true(all(is.finite(result)))
  expect_true(all(result >= 0))
  expect_identical(result["2000", ], current["2000", ])
  expect_identical(result[, "M73"], c(`2000` = 0, `2001` = 0))

  zeroes <- attr(result, "wlv.row_constant_capital_zeroes", exact = TRUE)
  expect_identical(zeroes$year, c("2000", "2001"))
  expect_identical(zeroes$country, rep("ROW", 2L))
  expect_identical(zeroes$sector, rep("M73", 2L))
  expect_identical(zeroes$value, c(0, 0))
  expect_identical(
    unique(zeroes$action),
    "preserve_zero_row_constant_capital"
  )
})

test_that("ROW constant capital rejects invalid indices, shapes and base identity", {
  rebuild <- row_capital_environment$wlv_row_constant_capital_stock
  current <- matrix(
    c(100, 0, 200, 0),
    nrow = 2L,
    byrow = TRUE,
    dimnames = list(c("2000", "2001"), c("A", "M73"))
  )
  exchange <- matrix(1, 2L, 2L, dimnames = dimnames(current))
  price <- matrix(1, 2L, 2L, dimnames = dimnames(current))

  zero_price <- price
  zero_price["2001", "A"] <- 0
  expect_error(
    rebuild(current, exchange, zero_price, expected_zero_sectors = "M73"),
    "strictly positive",
    fixed = TRUE
  )

  drifted_exchange <- exchange
  drifted_exchange["2000", "A"] <- 2
  expect_error(
    rebuild(current, drifted_exchange, price, expected_zero_sectors = "M73"),
    "exchange-rate index must equal 1 in base year 2000",
    fixed = TRUE
  )

  offsetting_exchange <- exchange
  offsetting_exchange["2000", ] <- 2
  offsetting_price <- price
  offsetting_price["2000", ] <- 2
  expect_error(
    rebuild(
      current,
      offsetting_exchange,
      offsetting_price,
      expected_zero_sectors = "M73"
    ),
    "exchange-rate index must equal 1 in base year 2000",
    fixed = TRUE
  )

  drifted_price <- price
  drifted_price["2000", "M73"] <- 1.01
  expect_error(
    rebuild(current, exchange, drifted_price, expected_zero_sectors = "M73"),
    "output-price index must equal 1 in base year 2000",
    fixed = TRUE
  )

  expect_error(
    rebuild(current, exchange[, "A", drop = FALSE], price),
    "identical dimensions",
    fixed = TRUE
  )

  unexpected_zero <- current
  unexpected_zero["2001", "A"] <- 0
  expect_error(
    rebuild(unexpected_zero, exchange, price, expected_zero_sectors = "M73"),
    "zero pattern differs",
    fixed = TRUE
  )
})

test_that("modern ROW assumptions rebuild and register two years of constant capital", {
  environment <- new.env(parent = globalenv())
  for (script in c("missingness.R", "result_contracts.R", "gfcf_contracts.R")) {
    sys.source(
      file.path(wlv_test_root, "R", "lib", script),
      envir = environment
    )
  }
  sys.source(
    file.path(wlv_test_root, "R", "lib", "row_capital.R"),
    envir = environment
  )
  environment$`%>%` <- magrittr::`%>%`
  environment$source_version <- "wiodr16"
  environment$parameters <- data.frame(
    description = "Synthetic calculation. ",
    stringsAsFactors = FALSE
  )
  environment$meta_indicators <- data.frame(
    observation = "Synthetic constant capital.",
    stringsAsFactors = FALSE,
    row.names = "capital_stock.s.cu"
  )
  environment$lists <- list(
    years = c("2000", "2001"),
    sectors = c("A", "M73"),
    countries = c("USA", "IND", "ROW")
  )
  environment$nums <- list(
    years = 2L,
    sectors = 2L,
    countries = 3L,
    countries_sectors = 6L
  )
  environment$rows <- data.frame(
    country = rep(environment$lists$countries, each = 2L),
    sector = rep(environment$lists$sectors, times = 3L),
    country_sector = paste(
      rep(environment$lists$countries, each = 2L),
      rep(environment$lists$sectors, times = 3L),
      sep = "."
    ),
    stringsAsFactors = FALSE
  )
  environment$read.csv2 <- function(...) {
    data.frame(
      X2000 = 100,
      X2001 = 120,
      row.names = "wiodr16",
      check.names = FALSE
    )
  }

  variables <- c(
    "gdp.s.us", "emp.s.un", "hours_worked.emp.s.hr",
    "capital_stock.s.us", "capital_stock.s.cu", "exchange.r.id",
    "go_price.r.id"
  )
  environment$sea_sectors <- array(
    NA_real_,
    dim = c(2L, length(variables), 2L, 3L),
    dimnames = list(
      environment$lists$years,
      variables,
      environment$lists$sectors,
      environment$lists$countries
    )
  )
  set_country_indicator <- function(indicator, country, value) {
    environment$sea_sectors[, indicator, , country] <- matrix(
      value,
      nrow = 2L,
      byrow = TRUE
    )
  }
  for (country in c("USA", "IND")) {
    set_country_indicator("gdp.s.us", country, c(50, 10, 50, 10))
    set_country_indicator("emp.s.un", country, rep(10, 4L))
    set_country_indicator("hours_worked.emp.s.hr", country, rep(10, 4L))
  }
  set_country_indicator("gdp.s.us", "ROW", c(100, 0, 100, 0))
  set_country_indicator("capital_stock.s.us", "USA", c(100, 20, 100, 20))
  set_country_indicator("capital_stock.s.us", "IND", c(20, 5, 20, 5))
  set_country_indicator("exchange.r.id", "USA", c(1, 1, 1.2, 1.2))
  set_country_indicator("exchange.r.id", "IND", c(1, 1, 1.2, 1.2))
  set_country_indicator("exchange.r.id", "ROW", c(1, 1, 1.2, 1.2))
  set_country_indicator("go_price.r.id", "USA", c(1, 1, 1.25, 1.25))
  set_country_indicator("go_price.r.id", "IND", c(1, 1, 1.25, 1.25))

  environment$wlv_contract_runtime <- wlv_test_contract_runtime(
    environment,
    method = "synthetic",
    source = "synthetic",
    policy = environment$wlv_strict_missingness_policy(
      source = "synthetic",
      policy_id = "synthetic_strict"
    )
  )

  old_working_directory <- setwd(wlv_test_root)
  on.exit(setwd(old_working_directory), add = TRUE)
  expect_no_error(sys.source(
    file.path(
      wlv_test_root,
      "R", "modules", "assumptions", "row", "row.R"
    ),
    envir = environment
  ))

  current <- environment$sea_sectors[
    , "capital_stock.s.us", , "ROW", drop = TRUE
  ]
  constant <- environment$sea_sectors[
    , "capital_stock.s.cu", , "ROW", drop = TRUE
  ]
  expect_equal(unname(current), matrix(c(200, 0, 240, 0), 2L, byrow = TRUE))
  expect_equal(unname(constant), matrix(c(200, 0, 230.4, 0), 2L, byrow = TRUE))
  expect_identical(constant["2000", ], current["2000", ])
  expect_identical(constant[, "M73"], c(`2000` = 0, `2001` = 0))
  expect_match(
    environment$meta_indicators["capital_stock.s.cu", "observation"],
    "For the Rest of the World",
    fixed = TRUE
  )

  zero_events <- environment$wlv_contract_runtime$anomalies
  zero_events <- zero_events[
    zero_events$indicator == "capital_stock.s.cu",
    ,
    drop = FALSE
  ]
  expect_identical(zero_events$year, c("2000", "2001"))
  expect_identical(zero_events$country, rep("ROW", 2L))
  expect_identical(zero_events$sector, rep("M73", 2L))
  expect_identical(
    zero_events$action,
    rep("preserve_zero_row_constant_capital", 2L)
  )
})
