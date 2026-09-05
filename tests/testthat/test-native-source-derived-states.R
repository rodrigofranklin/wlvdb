test_that("exchange modules publish policy-bound sparse states", {
  runtime <- wlv_test_load_runtime()
  years <- c("2000", "2001")
  sectors <- c("A", "B")
  countries <- c("JPN", "USA", "ROW")
  source <- array(
    1,
    dim = c(2L, 2L, 2L, 3L),
    dimnames = list(
      year = years,
      variable = c("VA", "VA_USD"),
      sector = sectors,
      country = countries
    )
  )
  source[, "VA", , "JPN"] <- c(100, 120, 80, 90)
  source[, "VA_USD", , "JPN"] <- c(1, 2, 1, 2)
  source[, "VA", , "USA"] <- c(1, 2, 3, 4)
  source[, "VA_USD", , "USA"] <- c(1, 2, 3, 4)
  source[, "VA", , "ROW"] <- 999
  source[, "VA_USD", , "ROW"] <- 1
  source_contract <- runtime$wlv_native_source_sea_contract()
  source_state <- runtime$wlv_semantic_state_encode(
    source,
    runtime$wlv_semantic_state_array(source, source_contract$axes),
    "source/sea",
    source_contract$axes
  )
  controls <- list(
    runtime$wlv_seed_resource(
      "request/method", "wiodr13",
      runtime$wlv_native_control_contract("character")
    ),
    runtime$wlv_seed_resource(
      "request/source", "wiodr13",
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
        method = "wiodr13",
        source = "wiodr13",
        years = years
      ),
      runtime$wlv_native_control_contract("list")
    )
  )
  store <- runtime$wlv_new_resource_store(c(
    list(
      runtime$wlv_seed_resource("source/sea", source, source_contract),
      runtime$wlv_seed_resource(
        "semantic_state/source/sea",
        source_state,
        runtime$wlv_native_semantic_state_contract(source_contract)
      ),
      runtime$wlv_seed_resource(
        "dimensions/lists",
        list(years = years, sectors = sectors, countries = countries),
        runtime$wlv_resource_contract(scope = "run", value_type = "list")
      )
    ),
    controls
  ))
  instance <- runtime$wlv_module_instance(
    "indicator.exchange.r.us",
    "indicator.exchange.r.us.wiod"
  )
  plan <- runtime$wlv_compile_module_plan(
    runtime$wlv_module_registry(list(
      runtime$wlv_indicator_exchange_r_us_wiod_spec()
    )),
    list(instance),
    store
  )
  result <- runtime$wlv_run_module_plan(plan, store)
  value_contract <- runtime$wlv_native_indicator_contract("exchange.r.us")
  value <- runtime$wlv_store_read(
    result$store,
    runtime$wlv_resource_ref(
      "sea/sector/exchange.r.us",
      value_contract,
      producer = instance$instance_id
    )
  )
  state <- runtime$wlv_store_read(
    result$store,
    runtime$wlv_resource_ref(
      "semantic_state/sea/sector/exchange.r.us",
      runtime$wlv_native_semantic_state_contract(value_contract),
      producer = instance$instance_id
    )
  )

  expect_true(all(is.na(value[, , "ROW"])))
  expect_identical(nrow(state), length(years) * length(sectors))
  expect_true(all(state$country == "ROW"))
  expect_true(all(state$state == "source_missing"))
  expect_silent(runtime$wlv_semantic_state_validate(
    state,
    value = value,
    target_key = "sea/sector/exchange.r.us",
    axes = value_contract$axes,
    state_key = "semantic_state/sea/sector/exchange.r.us"
  ))
})

test_that("WIOD16 price normalization publishes policy-bound sparse states", {
  runtime <- wlv_test_load_runtime()
  years <- c("2000", "2001")
  sectors <- c("A", "B")
  countries <- c("JPN", "USA", "ROW")
  source <- array(
    c(100, 110, 100, 120, 100, 105, 100, 115, rep(NA_real_, 4L)),
    dim = c(2L, 1L, 2L, 3L),
    dimnames = list(
      year = years,
      variable = "GO_PI",
      sector = sectors,
      country = countries
    )
  )
  source_contract <- runtime$wlv_native_source_sea_contract()
  source_states <- runtime$wlv_semantic_state_array(
    source,
    source_contract$axes
  )
  source_states[is.na(source)] <- "source_missing"
  source_state <- runtime$wlv_semantic_state_encode(
    source,
    source_states,
    "source/sea",
    source_contract$axes
  )
  controls <- list(
    runtime$wlv_seed_resource(
      "request/method", "wiodr16",
      runtime$wlv_native_control_contract("character")
    ),
    runtime$wlv_seed_resource(
      "request/source", "wiodr16",
      runtime$wlv_native_control_contract("character")
    ),
    runtime$wlv_seed_resource(
      "configuration/missingness_policy",
      runtime$wlv_wiodr16_missingness_policy(),
      runtime$wlv_native_control_contract("list")
    ),
    runtime$wlv_seed_resource(
      "configuration/scientific_profile",
      wlv_test_scientific_profile(
        runtime,
        method = "wiodr16",
        source = "wiodr16",
        years = years
      ),
      runtime$wlv_native_control_contract("list")
    )
  )
  store <- runtime$wlv_new_resource_store(c(
    list(
      runtime$wlv_seed_resource("source/sea", source, source_contract),
      runtime$wlv_seed_resource(
        "semantic_state/source/sea",
        source_state,
        runtime$wlv_native_semantic_state_contract(source_contract)
      ),
      runtime$wlv_seed_resource(
        "dimensions/lists",
        list(years = years, sectors = sectors, countries = countries),
        runtime$wlv_resource_contract(scope = "run", value_type = "list")
      )
    ),
    controls
  ))
  instance <- runtime$wlv_module_instance(
    "indicator.go_price.r.id",
    "indicator.go_price.r.id.wiodr16"
  )
  plan <- runtime$wlv_compile_module_plan(
    runtime$wlv_module_registry(list(
      runtime$wlv_indicator_go_price_r_id_wiodr16_spec()
    )),
    list(instance),
    store
  )
  result <- runtime$wlv_run_module_plan(plan, store)
  value_contract <- runtime$wlv_native_indicator_contract("go_price.r.id")
  value <- runtime$wlv_store_read(
    result$store,
    runtime$wlv_resource_ref(
      "sea/sector/go_price.r.id",
      value_contract,
      producer = instance$instance_id
    )
  )
  state <- runtime$wlv_store_read(
    result$store,
    runtime$wlv_resource_ref(
      "semantic_state/sea/sector/go_price.r.id",
      runtime$wlv_native_semantic_state_contract(value_contract),
      producer = instance$instance_id
    )
  )

  expect_true(all(value["2000", , c("JPN", "USA")] == 1))
  expect_true(all(is.na(value[, , "ROW"])))
  expect_identical(nrow(state), length(years) * length(sectors))
  expect_true(all(state$country == "ROW"))
  expect_true(all(state$state == "source_missing"))
  expect_silent(runtime$wlv_semantic_state_validate(
    state,
    value = value,
    target_key = "sea/sector/go_price.r.id",
    axes = value_contract$axes,
    state_key = "semantic_state/sea/sector/go_price.r.id"
  ))

  unexpected <- source
  unexpected["2001", "GO_PI", "A", "JPN"] <- NA_real_
  unexpected_states <- runtime$wlv_semantic_state_array(
    unexpected,
    source_contract$axes
  )
  unexpected_states[is.na(unexpected)] <- "source_missing"
  unexpected_state <- runtime$wlv_semantic_state_encode(
    unexpected,
    unexpected_states,
    "source/sea",
    source_contract$axes
  )
  unexpected_store <- runtime$wlv_new_resource_store(c(
    list(
      runtime$wlv_seed_resource("source/sea", unexpected, source_contract),
      runtime$wlv_seed_resource(
        "semantic_state/source/sea",
        unexpected_state,
        runtime$wlv_native_semantic_state_contract(source_contract)
      ),
      runtime$wlv_seed_resource(
        "dimensions/lists",
        list(years = years, sectors = sectors, countries = countries),
        runtime$wlv_resource_contract(scope = "run", value_type = "list")
      )
    ),
    controls
  ))
  unexpected_plan <- runtime$wlv_compile_module_plan(
    runtime$wlv_module_registry(list(
      runtime$wlv_indicator_go_price_r_id_wiodr16_spec()
    )),
    list(instance),
    unexpected_store
  )
  expect_error(
    runtime$wlv_run_module_plan(unexpected_plan, unexpected_store),
    "Every ordinary NA must have exactly one sparse semantic state.",
    fixed = TRUE
  )
})
