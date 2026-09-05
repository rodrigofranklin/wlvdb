exchange_contract_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "missingness.R"),
  envir = exchange_contract_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "result_contracts.R"),
  envir = exchange_contract_environment
)

wlv_exchange_test_fixture <- function() {
  labels <- list(
    year = c("2000", "2001"),
    sector = c("A", "B", "C"),
    country = c("JPN", "USA", "ROW")
  )
  numerator <- array(NA_real_, dim = c(2L, 3L, 3L), dimnames = labels)
  denominator <- numerator

  denominator[, , "JPN"] <- rbind(c(1, 2, 1), c(2, 1, 3))
  numerator[, , "JPN"] <- rbind(c(100, 100, 20), c(200, 80, 50))

  denominator[, , "USA"] <- rbind(c(10, 20, 30), c(4, 16, 20))
  numerator[, , "USA"] <- rbind(c(11, 18, 31), c(5, 15, 20))

  denominator[, , "ROW"] <- 1
  numerator[, , "ROW"] <- 999
  list(numerator = numerator, denominator = denominator)
}

wlv_read_exchange_source <- function(path) {
  metadata <- readRDS(paste0(path, ".meta"))
  value <- fst::read_fst(path)[[1L]]
  dim(value) <- metadata$dim
  dimnames(value) <- metadata[seq_len(length(metadata$dim)) + 1L]
  value
}

test_that("country-year exchange rates use ratios of totals and exact broadcasting", {
  fixture <- wlv_exchange_test_fixture()
  result <- exchange_contract_environment$wlv_exchange_rate_by_country(
    fixture$numerator,
    fixture$denominator
  )

  expect_identical(dimnames(result), dimnames(fixture$numerator))
  for (year in dimnames(result)[[1L]]) {
    expected <-
      sum(fixture$numerator[year, , "JPN"]) /
      sum(fixture$denominator[year, , "JPN"])
    expect_identical(as.numeric(result[year, , "JPN"]), rep(expected, 3L))
  }
  expect_identical(as.numeric(result[, , "USA"]), rep(1, 6L))
  expect_true(all(is.na(result[, , "ROW"])))
})

test_that("invalid exchange-rate aggregates abort without a fallback", {
  fixture <- wlv_exchange_test_fixture()

  unlabelled_numerator <- fixture$numerator
  unlabelled_denominator <- fixture$denominator
  dimnames(unlabelled_numerator)[[2L]] <- NULL
  dimnames(unlabelled_denominator)[[2L]] <- NULL
  expect_error(
    exchange_contract_environment$wlv_exchange_rate_by_country(
      unlabelled_numerator,
      unlabelled_denominator
    ),
    "fully labelled year-sector-country arrays",
    fixed = TRUE
  )

  missing <- fixture$numerator
  missing["2000", "A", "JPN"] <- NA_real_
  expect_error(
    exchange_contract_environment$wlv_exchange_rate_by_country(
      missing,
      fixture$denominator
    ),
    "unexpectedly missing outside ROW",
    fixed = TRUE
  )

  invalid_numerator <- fixture$numerator
  invalid_numerator["2000", , "JPN"] <- 0
  expect_error(
    exchange_contract_environment$wlv_exchange_rate_by_country(
      invalid_numerator,
      fixture$denominator
    ),
    "numerator total is not positive and finite for JPN in 2000",
    fixed = TRUE
  )

  invalid_denominator <- fixture$denominator
  invalid_denominator["2000", , "JPN"] <- 0
  expect_error(
    exchange_contract_environment$wlv_exchange_rate_by_country(
      fixture$numerator,
      invalid_denominator
    ),
    "denominator total is not positive and finite for JPN in 2000",
    fixed = TRUE
  )

  non_finite <- fixture$numerator
  non_finite["2000", "A", "JPN"] <- Inf
  expect_error(
    exchange_contract_environment$wlv_exchange_rate_by_country(
      non_finite,
      fixture$denominator
    ),
    "contain NaN or infinite values",
    fixed = TRUE
  )

  invalid_usa <- fixture$numerator
  invalid_usa["2000", , "USA"] <- invalid_usa["2000", , "USA"] * 2
  expect_error(
    exchange_contract_environment$wlv_exchange_rate_by_country(
      invalid_usa,
      fixture$denominator
    ),
    "USA aggregate exchange rate differs from 1 USD/USD in 2000",
    fixed = TRUE
  )

  expect_error(
    exchange_contract_environment$wlv_exchange_rate_by_country(
      fixture$numerator,
      fixture$denominator,
      usa_tolerance = 0
    ),
    "`usa_tolerance` must be one positive finite number",
    fixed = TRUE
  )
})

test_that("the historical exchange helper retains sector-level v0.9 values", {
  fixture <- wlv_exchange_test_fixture()
  result <- exchange_contract_environment$wlv_exchange_rate_by_sector_v09(
    fixture$numerator,
    fixture$denominator
  )

  expect_identical(
    as.numeric(result["2000", , "JPN"]),
    c(100, 50, 20)
  )
  expect_gt(length(unique(result["2000", , "JPN"])), 1L)

  runtime <- wlv_test_contract_runtime(
    exchange_contract_environment,
    method = "wiodr13v09",
    source = "wiodr13",
    policy = exchange_contract_environment$wlv_strict_missingness_policy(
      source = "wiodr13",
      policy_id = "exchange_v09_test"
    )
  )
  invalid <- fixture$numerator
  invalid["2000", "A", "JPN"] <- 0
  exchange_contract_environment$wlv_exchange_rate_by_sector_v09(
    invalid,
    fixture$denominator,
    runtime = runtime
  )
  expect_identical(
    unique(runtime$anomalies$module),
    "indicator.exchange.r.us.v09"
  )
})

test_that("v0.9 methods explicitly replace the native exchange modules", {
  runtime <- wlv_test_load_runtime()

  expected <- list(
    wiodr13v09 = c(
      "indicator.exchange.r.us.v09",
      "indicator.exchange.r.id.v09"
    ),
    wiodr16v09 = c(
      "indicator.exchange.r.us.v09",
      "indicator.exchange.r.id.v09"
    ),
    wiodr13 = c(
      "indicator.exchange.r.us.wiod",
      "indicator.exchange.r.id.wiod"
    ),
    wiodr16 = c(
      "indicator.exchange.r.us.wiod",
      "indicator.exchange.r.id.wiod"
    )
  )

  for (method in names(expected)) {
    source <- sub("v09$", "", method)
    resolved <- runtime$wlv_resolve_module_config(
      root = wlv_test_root,
      method = method,
      source = source
    )
    rows <- resolved[match(
      c("indicator.exchange.r.us", "indicator.exchange.r.id"),
      resolved$instance_id
    ), , drop = FALSE]

    expect_false(anyNA(rows$instance_id), info = method)
    expect_identical(rows$module_id, unname(expected[[method]]), info = method)
    expect_true(all(rows$action == "add"), info = method)
    expect_no_error(
      runtime$wlv_native_assert_registry_covers_config(
        runtime$wlv_native_registry(),
        resolved
      )
    )
  }
})

test_that("exchange modules publish direction, units and a base-one index", {
  fixture <- wlv_exchange_test_fixture()
  module_environment <- new.env(parent = exchange_contract_environment)
  module_environment$lists <- list(
    years = dimnames(fixture$numerator)[[1L]],
    sectors = dimnames(fixture$numerator)[[2L]],
    countries = dimnames(fixture$numerator)[[3L]]
  )
  module_environment$sea_source <- array(
    NA_real_,
    dim = c(2L, 2L, 3L, 3L),
    dimnames = list(
      module_environment$lists$years,
      c("VA", "VA_USD"),
      module_environment$lists$sectors,
      module_environment$lists$countries
    )
  )
  module_environment$sea_source[, "VA", , ] <- fixture$numerator
  module_environment$sea_source[, "VA_USD", , ] <- fixture$denominator
  module_environment$sea_sectors <- array(
    NA_real_,
    dim = c(2L, 2L, 3L, 3L),
    dimnames = list(
      module_environment$lists$years,
      c("exchange.r.us", "exchange.r.id"),
      module_environment$lists$sectors,
      module_environment$lists$countries
    )
  )
  module_environment$meta_indicators <- data.frame(
    code = c("exchange.r.us", "exchange.r.id"),
    name = NA_character_,
    description = NA_character_,
    observation = NA_character_,
    group = NA_character_,
    type = NA_character_,
    reverted = NA,
    stringsAsFactors = FALSE,
    row.names = c("exchange.r.us", "exchange.r.id")
  )

  sys.source(
    file.path(
      wlv_test_root,
      "R", "modules", "variables", "wiodr13", "exchange.r.us.R"
    ),
    envir = module_environment
  )
  sys.source(
    file.path(
      wlv_test_root,
      "R", "modules", "variables", "wiodr13", "exchange.r.id.R"
    ),
    envir = module_environment
  )

  metadata <- module_environment$meta_indicators
  expect_match(metadata["exchange.r.us", "description"], "LCU/USD", fixed = TRUE)
  expect_match(
    metadata["exchange.r.us", "observation"],
    "total Value Added in local currency divided by total Value Added in current USD",
    fixed = TRUE
  )
  expect_identical(
    metadata["exchange.r.id", "name"],
    "Exchange rate index"
  )
  expect_match(metadata["exchange.r.id", "description"], "Unitless", fixed = TRUE)
  expect_match(
    metadata["exchange.r.id", "observation"],
    "The presentation scale is defined by method-specific unit metadata",
    fixed = TRUE
  )
  expect_identical(
    as.numeric(module_environment$sea_sectors["2000", "exchange.r.id", , ]),
    rep(1, 9L)
  )
})

test_that("prepared WIOD exchange rates satisfy the country-year identity", {
  paths <- file.path(
    wlv_test_root,
    "source_data",
    c("wiodr13", "wiodr16"),
    "sea.fst"
  )
  skip_if_not_installed("fst")
  skip_if_not(
    all(file.exists(paths) & file.exists(paste0(paths, ".meta"))),
    "Prepared WIOD source arrays are not available."
  )

  expected_groups <- c(wiodr13 = 600L, wiodr16 = 645L)
  for (method in names(expected_groups)) {
    source <- wlv_read_exchange_source(
      file.path(wlv_test_root, "source_data", method, "sea.fst")
    )
    numerator <- source[, "VA", , ]
    denominator <- source[, "VA_USD", , ]
    result <- exchange_contract_environment$wlv_exchange_rate_by_country(
      numerator,
      denominator
    )
    countries <- setdiff(dimnames(result)[[3L]], "ROW")
    years <- dimnames(result)[[1L]]

    expect_identical(length(years) * length(countries), expected_groups[[method]])
    expect_true(all(is.na(result[, , "ROW"])))
    expect_identical(as.numeric(result[, , "USA"]), rep(1, length(result[, , "USA"])))
    expected <- matrix(
      NA_real_,
      nrow = length(years),
      ncol = length(countries),
      dimnames = list(year = years, country = countries)
    )
    for (year in years) {
      for (country in countries) {
        expected[year, country] <-
          sum(numerator[year, , country]) /
          sum(denominator[year, , country])
        if (country == "USA") {
          expected[year, country] <- 1
        }
      }
    }
    expect_identical(
      unname(result[, 1L, countries]),
      unname(expected)
    )
    expect_true(all(vapply(
      seq_len(dim(result)[[2L]]),
      function(sector) {
        identical(
          unname(result[, sector, countries]),
          unname(result[, 1L, countries])
        )
      },
      logical(1L)
    )))

    if (method == "wiodr16") {
      expect_equal(
        result["2005", 1L, "JPN"],
        110.00095729346776,
        tolerance = 1e-13
      )
    }
  }
})
