test_that("direct gross-output prices declare each semantic input once", {
  runtime <- wlv_test_load_runtime()
  years <- c("2000", "2001")
  sectors <- c("S1", "S2")
  countries <- c("AAA", "BBB")
  labels <- list(year = years, sector = sectors, country = countries)
  gross_output_mv <- array(2, dim = c(2L, 2L, 2L), dimnames = labels)
  gross_output_us <- array(4, dim = c(2L, 2L, 2L), dimnames = labels)

  stateful_seed <- function(indicator, value) {
    contract <- runtime$wlv_native_indicator_contract(indicator)
    runtime$wlv_native_stateful_seed_pair(
      runtime$wlv_seed_resource(
        runtime$wlv_native_indicator_key(indicator),
        value,
        contract,
        producer = runtime$wlv_runtime_seed_producer()
      ),
      states = runtime$wlv_semantic_state_array(value, contract$axes)
    )
  }
  store <- runtime$wlv_new_resource_store(c(
    stateful_seed("gross_output.s.mv", gross_output_mv),
    stateful_seed("gross_output.s.us", gross_output_us),
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
  ))
  spec <- runtime$wlv_indicator_gross_output_s_du_spec()
  instance <- runtime$wlv_module_instance(
    "indicator.gross_output.s.du",
    spec$id
  )
  plan <- runtime$wlv_compile_module_plan(
    runtime$wlv_module_registry(list(spec)),
    list(instance),
    store
  )
  result <- runtime$wlv_run_module_plan(plan, store)
  value_contract <- runtime$wlv_native_indicator_contract("gross_output.s.du")
  value <- runtime$wlv_store_read(
    result$store,
    runtime$wlv_resource_ref(
      "sea/sector/gross_output.s.du",
      value_contract,
      producer = instance$instance_id
    )
  )
  state <- runtime$wlv_store_read(
    result$store,
    runtime$wlv_resource_ref(
      "semantic_state/sea/sector/gross_output.s.du",
      runtime$wlv_native_semantic_state_contract(value_contract),
      producer = instance$instance_id
    )
  )

  expect_identical(plan$order, instance$instance_id)
  expect_identical(value, gross_output_mv * 2)
  expect_s3_class(state, "wlv_semantic_state")
  expect_identical(nrow(state), 0L)
  expect_silent(runtime$wlv_semantic_state_validate(
    state,
    value = value,
    target_key = "sea/sector/gross_output.s.du",
    axes = value_contract$axes,
    state_key = "semantic_state/sea/sector/gross_output.s.du"
  ))

  resolved <- plan$modules[[instance$instance_id]]
  gross_mv_inputs <- vapply(resolved$requires, function(ref) {
    identical(ref$key, "sea/sector/gross_output.s.mv")
  }, logical(1L))
  gross_mv_states <- vapply(resolved$requires, function(ref) {
    identical(ref$key, "semantic_state/sea/sector/gross_output.s.mv")
  }, logical(1L))
  expect_identical(sum(gross_mv_inputs), 1L)
  expect_identical(
    names(resolved$requires)[gross_mv_inputs],
    "base"
  )
  expect_identical(sum(gross_mv_states), 1L)
  expect_identical(
    names(resolved$requires)[gross_mv_states],
    "semantic_state__base"
  )
})
