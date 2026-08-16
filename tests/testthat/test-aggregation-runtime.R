aggregation_runtime_environment <- new.env(parent = globalenv())
for (script in c("missingness.R", "aggregation_specs.R", "result_contracts.R")) {
  sys.source(
    file.path(wlv_test_root, "R", "lib", script),
    envir = aggregation_runtime_environment
  )
}

wlv_aggregation_runtime_row <- function(
    indicator,
    level,
    strategy,
    zero_denominator = "") {
  data.frame(
    indicator = indicator,
    level = level,
    strategy = strategy,
    module = "",
    numerator = "",
    denominator = "",
    weight = "",
    zero_denominator = zero_denominator,
    notes = "",
    stringsAsFactors = FALSE
  )
}

test_that("SEA runtime dispatches independent specifications at each level", {
  environment <- new.env(parent = aggregation_runtime_environment)
  rows <- rbind(
    wlv_aggregation_runtime_row("metric", "sector_to_country", "sum"),
    wlv_aggregation_runtime_row("metric", "country_to_world", "mean")
  )
  environment$wlv_aggregation_registry <- aggregation_runtime_environment$
    wlv_resolve_aggregation_registry(
      aggregations = rows,
      solutions = data.frame(
        names = "metric",
        country_solution = "sum",
        stringsAsFactors = FALSE
      ),
      method = "typed_demo",
      stable = TRUE
    )
  environment$sea_variables <- data.frame(
    names = "metric",
    country_solution = "sum",
    stringsAsFactors = FALSE
  )
  environment$lists <- list(countries = c("A", "B"))
  environment$sea_sectors <- array(
    c(1, 3, 5, 7),
    dim = c(1L, 1L, 2L, 2L),
    dimnames = list(
      year = "2000",
      indicator = "metric",
      sector = c("S1", "S2"),
      country = c("A", "B")
    )
  )
  environment$sea_countries <- array(
    NA_real_,
    dim = c(1L, 1L, 3L),
    dimnames = list(
      year = "2000",
      indicator = "metric",
      country = c("A", "B", "WWW")
    )
  )

  expect_output(
    sys.source(
      file.path(
        wlv_test_root,
        "R",
        "modules",
        "variables",
        "sea_countries.R"
      ),
      envir = environment
    ),
    "sum -> legacy_mean",
    fixed = TRUE
  )
  expect_equal(
    as.numeric(environment$sea_countries[1L, 1L, ]),
    c(4, 12, 8)
  )
})

test_that("typed states and anomalies flow through missingness runtime", {
  row <- wlv_aggregation_runtime_row(
    "metric",
    "sector_to_country",
    "sum"
  )
  binding <- aggregation_runtime_environment$wlv_aggregation_binding_from_row(
    row,
    missing = "available"
  )
  value <- array(
    c(1, NA, NA, NA),
    dim = c(1L, 2L, 2L),
    dimnames = list(
      year = "2000",
      sector = c("S1", "S2"),
      country = c("A", "B")
    )
  )
  allowed <- array(
    "finite",
    dim = dim(value),
    dimnames = dimnames(value)
  )
  allowed[is.na(value)] <- "source_missing"
  runtime <- aggregation_runtime_environment$wlv_new_contract_runtime(
    method = "typed_demo",
    source = "typed_demo",
    policy = aggregation_runtime_environment$wlv_strict_missingness_policy(
      source = "typed_demo",
      policy_id = "typed_demo_v1"
    )
  )
  result <- aggregation_runtime_environment$wlv_contract_aggregate_spec_runtime(
    runtime,
    binding,
    values = list(metric = value),
    margin = c(1L, 3L),
    artifact = "sea_countries",
    indicator = "metric",
    checkpoint = "after_country_aggregation",
    stage = 5L,
    module = "sea_countries.R",
    axes = c(year = 1L, sector = 2L, country = 3L),
    allowed_missing = list(metric = allowed)
  )

  expect_equal(as.numeric(result), c(1, NA_real_))
  expect_identical(
    as.vector(attr(result, "wlv_aggregation_state", exact = TRUE)),
    c("partial", "missing")
  )
  expect_identical(
    as.vector(attr(result, "wlv_state", exact = TRUE)),
    c("finite", "source_missing")
  )
  expect_setequal(
    unique(runtime$anomalies$action),
    c("aggregate_available", "preserve_all_missing")
  )
})
