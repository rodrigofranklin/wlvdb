aggregation_dimension_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "bootstrap.R"),
  envir = aggregation_dimension_environment
)
aggregation_dimension_environment <-
  aggregation_dimension_environment$wlv_load_runtime(wlv_test_root)

wlv_dimension_unit_row <- function(
    indicator,
    canonical_unit,
    currency,
    price_basis = "not_applicable",
    base_year = NA_character_,
    index_base = NA_real_,
    quantity_kind = switch(
      canonical_unit,
      usd = "monetary",
      local_currency = "monetary",
      local_currency_per_usd = "ratio",
      person = "count",
      hour = "duration",
      abstract_labour_hour = "labour_value",
      abstract_labour_hour_per_person = "ratio",
      abstract_labour_hour_per_usd = "ratio",
      ratio = "ratio",
      multiplier = "multiplier",
      index = "index"
    )) {
  data.frame(
    indicator = indicator,
    quantity_kind = quantity_kind,
    canonical_unit = canonical_unit,
    currency = currency,
    price_basis = price_basis,
    base_year = base_year,
    index_base = index_base,
    stringsAsFactors = FALSE
  )
}

wlv_dimension_aggregation_row <- function(
    indicator,
    level,
    strategy,
    numerator = "",
    denominator = "",
    weight = "") {
  data.frame(
    indicator = indicator,
    level = level,
    strategy = strategy,
    numerator = numerator,
    denominator = denominator,
    weight = weight,
    stringsAsFactors = FALSE
  )
}

test_that("canonical unit rows map to symbolic dimensions", {
  rows <- rbind(
    wlv_dimension_unit_row("usd", "usd", "usd", "current"),
    wlv_dimension_unit_row(
      "lcu_per_usd",
      "local_currency_per_usd",
      "local_currency",
      "current"
    ),
    wlv_dimension_unit_row("person", "person", "none"),
    wlv_dimension_unit_row("hour", "hour", "none"),
    wlv_dimension_unit_row("labour", "abstract_labour_hour", "none"),
    wlv_dimension_unit_row(
      "labour_person",
      "abstract_labour_hour_per_person",
      "none"
    ),
    wlv_dimension_unit_row(
      "labour_usd",
      "abstract_labour_hour_per_usd",
      "mixed",
      "current"
    ),
    wlv_dimension_unit_row("ratio", "ratio", "none"),
    wlv_dimension_unit_row("multiplier", "multiplier", "none"),
    wlv_dimension_unit_row(
      "index",
      "index",
      "none",
      base_year = "2000",
      index_base = 100
    )
  )
  registry <- aggregation_dimension_environment$wlv_unit_dimension_registry(rows)

  expect_identical(
    registry[["labour_usd"]]$exponents,
    c(USD = -1L, LCU = 0L, person = 0L, hour = 0L, labour_value = 1L)
  )
  expect_identical(registry[["lcu_per_usd"]]$currency_scope, "country")
  expect_identical(registry[["index"]]$kind, "index")
  expect_identical(registry[["index"]]$index_base, 100)
})

test_that("ratio dimensions are derived independently from their references", {
  units <- rbind(
    wlv_dimension_unit_row("labour", "abstract_labour_hour", "none"),
    wlv_dimension_unit_row("money", "usd", "usd", "current"),
    wlv_dimension_unit_row(
      "target",
      "abstract_labour_hour_per_usd",
      "mixed",
      "current"
    )
  )
  aggregation <- wlv_dimension_aggregation_row(
    "target",
    "sector_to_country",
    "ratio_of_sums",
    numerator = "labour",
    denominator = "money"
  )
  expect_invisible(
    aggregation_dimension_environment$wlv_validate_aggregation_dimensions(
      units,
      aggregation
    )
  )

  invalid <- units
  invalid[invalid$indicator == "target", c(
    "quantity_kind", "canonical_unit", "currency", "price_basis"
  )] <- c("count", "person", "none", "not_applicable")
  expect_error(
    aggregation_dimension_environment$wlv_validate_aggregation_dimensions(
      invalid,
      aggregation
    ),
    "numerator/denominator imply",
    fixed = TRUE
  )

  contradictory <- units
  contradictory$quantity_kind[contradictory$indicator == "target"] <-
    "duration"
  expect_error(
    aggregation_dimension_environment$wlv_validate_aggregation_dimensions(
      contradictory,
      aggregation
    ),
    "requires quantity_kind `ratio`",
    fixed = TRUE
  )
})

test_that("schema 2 rejects cross-country LCU except not-applicable", {
  units <- wlv_dimension_unit_row(
    "exchange",
    "local_currency_per_usd",
    "local_currency",
    "current"
  )
  mean_row <- wlv_dimension_aggregation_row(
    "exchange",
    "country_to_world",
    "mean"
  )
  expect_invisible(
    aggregation_dimension_environment$wlv_validate_aggregation_dimensions(
      units,
      mean_row,
      strict_cross_country = FALSE
    )
  )
  expect_error(
    aggregation_dimension_environment$wlv_validate_aggregation_dimensions(
      units,
      mean_row,
      strict_cross_country = TRUE
    ),
    "Cannot aggregate LCU units across countries",
    fixed = TRUE
  )

  not_applicable <- mean_row
  not_applicable$strategy <- "not_applicable"
  expect_invisible(
    aggregation_dimension_environment$wlv_validate_aggregation_dimensions(
      units,
      not_applicable,
      strict_cross_country = TRUE
    )
  )
  formula <- mean_row
  formula$strategy <- "formula"
  expect_error(
    aggregation_dimension_environment$wlv_validate_aggregation_dimensions(
      units,
      formula,
      strict_cross_country = TRUE
    ),
    "not dimensionally aggregable across countries",
    fixed = TRUE
  )
})

test_that("stable registries resolve dimensionally before a result lock", {
  catalog <- aggregation_dimension_environment$wlv_load_catalog(wlv_test_root)
  plan <- aggregation_dimension_environment$wlv_validate_request(
    methods = c("wiodr13", "wiodr16"),
    workers = 1L,
    mode = "calculate",
    root = wlv_test_root,
    catalog = catalog
  )
  expect_named(plan$aggregation_registries, c("wiodr13", "wiodr16"))
  expect_identical(
    vapply(plan$aggregation_registries, function(registry) {
      length(registry$bindings)
    }, integer(1L)),
    c(wiodr13 = 116L, wiodr16 = 100L)
  )
  for (method in plan$method_names) {
    registry <- plan$aggregation_registries[[method]]
    method_row <- plan$methods[plan$methods$method == method, , drop = FALSE]
    sidecar <- aggregation_dimension_environment$
      wlv_catalog_unit_contract_sidecar(
        plan$catalog,
        method_row$unit_contract[[1L]],
        indicators = plan$indicators[[method]],
        resolved_aggregations = registry$rows
      )
    routes <- aggregation_dimension_environment$
      wlv_reconcile_aggregation_registry_sidecar(
        registry,
        sidecar
      )
    published <- aggregation_dimension_environment$
      wlv_aggregation_sidecar_rows(sidecar)
    expect_identical(routes, published, info = method)
  }

  contract <- catalog$sources$unit_contract[
    catalog$sources$source == "wiodr13"
  ][[1L]]
  lcu_indicators <- catalog$unit_definitions[[contract]]$indicator[
    catalog$unit_definitions[[contract]]$currency == "local_currency"
  ]
  world_lcu <- catalog$unit_aggregations[[contract]]$indicator %in%
    lcu_indicators &
    catalog$unit_aggregations[[contract]]$level == "country_to_world"
  expect_identical(
    catalog$unit_contracts$schema_version[
      catalog$unit_contracts$contract == contract
    ],
    "2"
  )
  contradictory <- catalog
  exchange <- contradictory$unit_definitions[[contract]]$indicator ==
    "exchange.r.us"
  contradictory$unit_definitions[[contract]]$quantity_kind[exchange] <-
    "duration"
  expect_error(
    aggregation_dimension_environment$wlv_validate_request(
      methods = "wiodr13",
      workers = 1L,
      mode = "calculate",
      root = wlv_test_root,
      catalog = contradictory
    ),
    "requires quantity_kind `ratio`",
    fixed = TRUE
  )
  catalog$unit_aggregations[[contract]]$strategy[world_lcu] <- "sum"
  expect_error(
    aggregation_dimension_environment$wlv_validate_request(
      methods = "wiodr13",
      workers = 1L,
      mode = "calculate",
      root = wlv_test_root,
      catalog = catalog
    ),
    "not dimensionally aggregable across countries",
    fixed = TRUE
  )

  catalog$unit_aggregations[[contract]]$strategy[world_lcu] <-
    "not_applicable"
  migrated <- expect_no_error(
    aggregation_dimension_environment$wlv_validate_request(
      methods = "wiodr13",
      workers = 1L,
      mode = "calculate",
      root = wlv_test_root,
      catalog = catalog
    )
  )
  expect_s3_class(migrated, "wlv_run_plan")
})
