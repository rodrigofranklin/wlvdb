test_that("panel slices equal cleaned terminal indicator generations", {
  runtime <- wlv_test_load_runtime()
  request <- runtime$wlv_validate_request(
    "alternative_1",
    mode = "calculate",
    at_stage = 1L,
    root = wlv_test_root,
    allow_experimental = TRUE,
    catalog = runtime$wlv_runtime_catalog()
  )
  years <- c("2000", "2001")
  sectors <- c("A", "B")
  countries <- c("USA", "ROW")
  value <- array(
    c(1, 1.1, 1, 1.2, 1, 1.1, 1, 1.2),
    dim = c(2L, 2L, 2L),
    dimnames = list(year = years, sector = sectors, country = countries)
  )
  contract <- runtime$wlv_native_indicator_contract("go_price.r.id")
  states <- runtime$wlv_semantic_state_array(value, contract$axes)
  states[, , "ROW"] <- "source_missing"
  seeds <- c(
    runtime$wlv_native_stateful_seed_pair(
      runtime$wlv_seed_resource(
        "sea/sector/go_price.r.id",
        value,
        contract,
        producer = "assumption.row"
      ),
      states = states
    ),
    list(
      runtime$wlv_seed_resource(
        "dimensions/lists",
        list(years = years, sectors = sectors, countries = countries),
        runtime$wlv_resource_contract(scope = "run", value_type = "list")
      ),
      runtime$wlv_seed_resource(
        "request/method",
        "alternative_1",
        runtime$wlv_native_control_contract("character")
      ),
      runtime$wlv_seed_resource(
        "request/source",
        "wiodr13",
        runtime$wlv_native_control_contract("character")
      ),
      runtime$wlv_seed_resource(
        "configuration/missingness_policy",
        runtime$wlv_wiodr13_missingness_policy(),
        runtime$wlv_native_control_contract("list")
      ),
      runtime$wlv_seed_resource(
        "configuration/scientific_profile",
        wlv_test_scientific_profile(
          runtime,
          method = "alternative_1",
          source = "wiodr13",
          years = years
        ),
        runtime$wlv_native_control_contract("list")
      )
    )
  )
  aggregation_registry <- request$aggregation_registries$alternative_1
  normalizer <- runtime$wlv_module_instance(
    "normalize.indicator.go_price.r.id",
    "indicator.price_index.normalize",
    args = list(
      indicator = "go_price.r.id",
      predecessor = "assumption.row",
      base_year = "2000",
      copy_usa_to_row = TRUE
    )
  )
  aggregation <- runtime$wlv_native_aggregation_instance(
    aggregation_registry,
    "go_price.r.id",
    all_indicators = "go_price.r.id"
  )
  assembler <- runtime$wlv_module_instance(
    "assembler.panel",
    "assembler.panel",
    args = list(indicators = list("go_price.r.id"))
  )
  registry <- runtime$wlv_module_registry(list(
    runtime$wlv_indicator_price_index_normalize_spec(),
    runtime$wlv_native_aggregation_spec(),
    runtime$wlv_native_panel_assembler_spec()
  ))
  store <- runtime$wlv_new_resource_store(seeds)
  plan <- runtime$wlv_compile_module_plan(
    registry,
    list(normalizer, aggregation, assembler),
    store
  )
  result <- runtime$wlv_run_module_plan(plan, store)
  terminal <- runtime$wlv_runtime_snapshot_terminal(
    result$store,
    "sea/sector/go_price.r.id",
    NULL,
    contract
  )
  provenance <- runtime$wlv_runtime_snapshot_panel_provenance(result$store)

  expect_null(attr(terminal$value, "wlv_state", exact = TRUE))
  expect_null(attr(terminal$value, "wlv_actions", exact = TRUE))
  expect_null(attr(terminal$value, "wlv_aggregation_state", exact = TRUE))
  expect_identical(nrow(provenance), 2L)
  expect_identical(
    provenance$producer,
    c("normalize.indicator.go_price.r.id", "aggregation.direct")
  )
  expect_identical(provenance$state_producer, provenance$producer)
})
