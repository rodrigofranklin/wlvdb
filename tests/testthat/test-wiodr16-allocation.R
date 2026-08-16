wiodr16_allocation_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "wiodr16_allocation.R"),
  envir = wiodr16_allocation_environment
)

test_that("WIOD16 source anomalies are exact and value-pinned", {
  expected_va <-
    wiodr16_allocation_environment$wlv_wiodr16_expected_source_va_exception()
  expect_identical(nrow(expected_va), 26L)
  expect_identical(
    anyDuplicated(expected_va[c("year", "variable", "sector", "country")]),
    0L
  )
  expect_equal(
    expected_va$value[
      expected_va$year == "2007" & expected_va$sector == "J58" &
        expected_va$country == "ROU"
    ],
    -17.404439964866128
  )

  years <- c("2007", "2012", "2013", "2014")
  variables <- c("K", "VA_USD")
  sectors <- c("C33", "J58")
  countries <- c("PRT", "ROU")
  sea <- array(
    1,
    dim = c(4L, 2L, 2L, 2L),
    dimnames = list(years, variables, sectors, countries)
  )
  sea[cbind(c("2012", "2013", "2014"), "K", "C33", "PRT")] <-
    c(-313.147, -554.413, -873.203)
  sea["2007", "VA_USD", "J58", "ROU"] <- -17.404439964866128

  validate <- wiodr16_allocation_environment$wlv_wiodr16_validate_source_negative_k
  validate_va <-
    wiodr16_allocation_environment$wlv_wiodr16_validate_source_va_exception
  expect_no_error(validate(sea))
  expect_no_error(validate_va(sea))

  canonical_sea <- sea
  canonical_sea[, c("K", "VA_USD"), , ] <-
    canonical_sea[, c("K", "VA_USD"), , ] * 1000000
  expect_no_error(validate(canonical_sea, input_unit = "usd"))
  expect_no_error(validate_va(canonical_sea, input_unit = "usd"))

  canonical_drift <- canonical_sea
  canonical_drift["2013", "K", "C33", "PRT"] <-
    canonical_drift["2013", "K", "C33", "PRT"] + 1000
  expect_error(
    validate(canonical_drift, input_unit = "usd"),
    "values differ",
    fixed = TRUE
  )

  extra <- sea
  extra["2007", "K", "J58", "ROU"] <- -1
  expect_error(validate(extra), "unexpected", fixed = TRUE)

  drifted <- sea
  drifted["2013", "K", "C33", "PRT"] <- -555
  expect_error(validate(drifted), "values differ", fixed = TRUE)

  drifted_va <- sea
  drifted_va["2007", "VA_USD", "J58", "ROU"] <- -18
  expect_error(validate_va(drifted_va), "values differ", fixed = TRUE)

  extra_va <- sea
  extra_va["2007", "VA_USD", "C33", "PRT"] <- -1
  expect_error(validate_va(extra_va), "unexpected", fixed = TRUE)
})

test_that("all 21 known EU KLEMS negatives, including 2015, are exact", {
  expected <-
    wiodr16_allocation_environment$wlv_wiodr16_expected_negative_euklems_weights()
  expect_identical(sum(expected$year %in% as.character(2000:2014)), 19L)
  expect_identical(sum(expected$year == "2015"), 2L)
  validate <-
    wiodr16_allocation_environment$wlv_wiodr16_validate_negative_euklems_weights
  sanitize <-
    wiodr16_allocation_environment$wlv_wiodr16_sanitize_euklems_weights

  tables <- lapply(unique(expected$year), function(year) {
    anomaly <- expected[expected$year == year, , drop = FALSE]
    keys <- unique(anomaly[c("country", "sector")])
    value <- keys
    for (variable in unique(anomaly$variable)) value[[variable]] <- 0
    for (index in seq_len(nrow(anomaly))) {
      row <- which(
        value$country == anomaly$country[[index]] &
          value$sector == anomaly$sector[[index]]
      )
      value[row, anomaly$variable[[index]]] <- anomaly$value[[index]]
    }
    expect_no_error(validate(value, year))
    cleaned <- sanitize(value, year)
    expect_true(all(as.matrix(cleaned[vapply(cleaned, is.numeric, logical(1))]) >= 0))
    expect_identical(
      nrow(attr(cleaned, "wlv.truncated_negative_weights")),
      nrow(anomaly)
    )
    expect_identical(
      unique(attr(cleaned, "wlv.truncated_negative_weights")$policy_id),
      "wiodr16_negative_euklems_weights_v1"
    )
    expect_identical(
      unique(attr(cleaned, "wlv.truncated_negative_weights")$action),
      "truncate_allowlisted_negative_euklems_weight"
    )
    value
  })
  names(tables) <- unique(expected$year)
  expect_identical(
    nrow(attr(sanitize(tables[["2015"]], "2015"), "wlv.truncated_negative_weights")),
    2L
  )

  missing <- tables[["2012"]]
  first_negative <- which(as.matrix(missing[vapply(missing, is.numeric, logical(1))]) < 0,
                          arr.ind = TRUE)[1L, ]
  numeric_names <- names(missing)[vapply(missing, is.numeric, logical(1))]
  missing[first_negative[[1L]], numeric_names[[first_negative[[2L]]]]] <- 0
  expect_error(validate(missing, "2012"), "missing", fixed = TRUE)

  extra <- tables[["2010"]]
  extra$K_OTHER <- 0
  extra$K_OTHER[[1L]] <- -1
  expect_error(validate(extra, "2010"), "unexpected", fixed = TRUE)
})

test_that("the ROU value-added ratio is the only negative ratio made absolute", {
  sanitize <- wiodr16_allocation_environment$wlv_wiodr16_sanitize_va_ratios
  expected <-
    wiodr16_allocation_environment$wlv_wiodr16_expected_negative_va_ratios()
  result <- sanitize(c(1, expected$value, 0), "2007", c("A.S1", "ROU.J58", "B.S2"))
  expect_equal(as.numeric(result), c(1, abs(expected$value), 0))
  expect_identical(nrow(attr(result, "wlv.absolute_va_ratios")), 1L)
  expect_identical(
    attr(result, "wlv.absolute_va_ratios")[
      1L, c("country", "sector", "policy_id", "action")
    ],
    data.frame(
      country = "ROU",
      sector = "J58",
      policy_id = "wiodr16_negative_va_ratio_v1",
      action = "absolute_allowlisted_negative_va_ratio",
      stringsAsFactors = FALSE
    )
  )

  expect_error(
    sanitize(c(-0.1, expected$value), "2007", c("A.S1", "ROU.J58")),
    "unexpected",
    fixed = TRUE
  )

  zero_ratio <- sanitize(
    c(NaN, 1),
    "2007",
    c("A.ZERO", "B.S2"),
    numerator = c(0, 1),
    denominator = c(0, 1)
  )
  expect_equal(as.numeric(zero_ratio), c(0, 1))
  expect_identical(attr(zero_ratio, "wlv.zero_va_ratios"), 1L)
  expect_error(
    sanitize(
      c(Inf, 1),
      "2007",
      c("A.BAD", "B.S2"),
      numerator = c(1, 1),
      denominator = c(0, 1)
    ),
    "unexpected missing or non-finite",
    fixed = TRUE
  )
})

test_that("WIOD16 allocation truncates known stock and uses only exact GFCF fallbacks", {
  sanitize_stock <-
    wiodr16_allocation_environment$wlv_wiodr16_sanitize_capital_stock
  allocate <- wiodr16_allocation_environment$wlv_wiodr16_allocate_capital
  fallbacks <-
    wiodr16_allocation_environment$wlv_wiodr16_expected_gfcf_fallbacks()
  expect_identical(nrow(fallbacks), 120L)
  expect_identical(
    as.integer(table(factor(fallbacks$year, levels = as.character(2000:2014)))),
    c(7L, rep(8L, 11L), 9L, 8L, 8L)
  )
  labels <- c("PRT.C33", "MEX.T")
  stock <- sanitize_stock(c(-5, 20), "2012", labels)
  expect_equal(as.numeric(stock), c(0, 20))
  expect_equal(attr(stock, "wlv.truncated_negative_stock")$value, -5)
  expect_identical(
    attr(stock, "wlv.truncated_negative_stock")[
      1L, c("country", "sector", "policy_id", "action")
    ],
    data.frame(
      country = "PRT",
      sector = "C33",
      policy_id = "wiodr16_negative_capital_stock_v1",
      action = "truncate_allowlisted_negative_capital_stock",
      stringsAsFactors = FALSE
    )
  )

  weights <- matrix(c(1, 0, 0, 0), nrow = 2L)
  fallback <- matrix(c(1, 0, 3, 1), nrow = 2L)
  result <- allocate(weights, stock, fallback, "2012", labels)
  expect_equal(unname(result[, 2L]), c(15, 5))
  expect_equal(unname(colSums(result)), c(0, 20))
  expect_identical(attr(result, "wlv.gfcf_fallbacks")$input, "MEX.T")

  estonian_result <- allocate(
    matrix(c(0, 0, 0, 1), nrow = 2L),
    c(12, 4),
    matrix(c(1, 3, 0, 1), nrow = 2L),
    "2012",
    c("EST.H51", "A.S1")
  )
  expect_equal(as.numeric(estonian_result[, 1L]), c(3, 9))
  expect_equal(as.numeric(colSums(estonian_result)), c(12, 4))
  expect_identical(
    attr(estonian_result, "wlv.gfcf_fallbacks")$input,
    "EST.H51"
  )

  expect_error(
    allocate(matrix(0, 2L, 2L), c(0, 10), matrix(1, 2L, 2L),
             "2012", c("A.S1", "B.S2")),
    "unexpected",
    fixed = TRUE
  )
  expect_error(
    allocate(weights, stock, matrix(0, 2L, 2L), "2012", labels),
    "lacks positive allocation weights",
    fixed = TRUE
  )
  zero_result <- allocate(
    matrix(0, 2L, 2L),
    c(0, 0),
    matrix(0, 2L, 2L),
    "2012",
    c("A.S1", "B.S2")
  )
  expect_equal(as.numeric(zero_result), rep(0, 4L))
  expect_error(
    allocate(weights, stock, fallback, "2012", c("MEX.T", "MEX.T")),
    "unique",
    fixed = TRUE
  )
  expect_error(
    allocate(weights, stock, fallback, "2012", labels, tolerance = -1),
    "finite non-negative",
    fixed = TRUE
  )
})

test_that("WIOD16 stock modules preserve structural missing values before assumptions", {
  environment <- new.env(parent = globalenv())
  sys.source(
    file.path(wlv_test_root, "R", "lib", "functions.R"),
    envir = environment
  )
  sys.source(
    file.path(wlv_test_root, "R", "lib", "wiodr16_allocation.R"),
    envir = environment
  )
  sys.source(
    file.path(wlv_test_root, "R", "lib", "missingness.R"),
    envir = environment
  )
  sys.source(
    file.path(wlv_test_root, "R", "lib", "result_contracts.R"),
    envir = environment
  )
  sys.source(
    file.path(wlv_test_root, "R", "lib", "gfcf_contracts.R"),
    envir = environment
  )
  environment$wlv_contract_runtime <- environment$wlv_new_contract_runtime(
    method = "wiodr16",
    source = "wiodr16",
    policy = environment$wlv_wiodr16_missingness_policy()
  )
  environment$`%>%` <- magrittr::`%>%`
  environment$lists <- list(
    years = "2012",
    sectors = "C33",
    countries = c("PRT", "ROW"),
    input = c("PRT.C33", "ROW.C33")
  )
  environment$nums <- list(years = 1L, sectors = 1L, countries = 2L)
  environment$sea_source <- array(
    c(-313.147, NA_real_),
    dim = c(1L, 1L, 1L, 2L),
    dimnames = list("2012", "K", "C33", c("PRT", "ROW"))
  )
  variables <- c(
    "exchange.r.us", "go_price.r.id", "capital_stock.s.us", "capital_stock.s.cu"
  )
  environment$sea_sectors <- array(
    0,
    dim = c(1L, 4L, 1L, 2L),
    dimnames = list("2012", variables, "C33", c("PRT", "ROW"))
  )
  environment$sea_sectors[, "exchange.r.us", , ] <- c(1, 0)
  environment$sea_sectors[, "go_price.r.id", , ] <- c(100, 0)
  environment$meta_indicators <- data.frame(
    name = rep("", 2L),
    description = rep("", 2L),
    observation = rep("", 2L),
    type = rep("", 2L),
    group = rep("", 2L),
    reverted = rep(FALSE, 2L),
    row.names = c("capital_stock.s.us", "capital_stock.s.cu"),
    stringsAsFactors = FALSE
  )

  expect_equal(
    environment$wlv_wiodr16_clean_structural_nonfinite_stock(
      c(1, NA_real_),
      c("PRT.C33", "ROW.C33")
    ),
    c(1, NA_real_)
  )
  expect_error(
    environment$wlv_wiodr16_clean_structural_nonfinite_stock(
      c(Inf, NA_real_),
      c("PRT.C33", "ROW.C33")
    ),
    "NaN or infinite",
    fixed = TRUE
  )

  for (script in c("capital_stock.s.us.R", "capital_stock.s.cu.R")) {
    expect_no_error(sys.source(
      file.path(
        wlv_test_root,
        "R", "modules", "variables", "wiodr16", script
      ),
      envir = environment
    ))
  }
  expect_equal(
    as.numeric(environment$sea_sectors[, variables[3:4], , ]),
    c(0, 0, NA_real_, NA_real_)
  )
  stock_events <- environment$wlv_contract_runtime$anomalies
  expect_identical(nrow(stock_events), 2L)
  expect_identical(
    stock_events$indicator,
    c("capital_stock.s.us", "capital_stock.s.cu")
  )
  expect_identical(stock_events$country, rep("PRT", 2L))
  expect_identical(stock_events$sector, rep("C33", 2L))
  expect_identical(
    stock_events$action,
    rep("truncate_allowlisted_negative_capital_stock", 2L)
  )
  expect_true(all(as.numeric(stock_events$original_value) < 0))
})
