test_that("native scientific arrays declare their semantic-state companions", {
  runtime <- wlv_test_load_runtime()
  semantic_contracts <- list(
    source_sea = runtime$wlv_native_source_sea_contract(),
    source_io = runtime$wlv_native_source_io_contract(),
    sea_sector = runtime$wlv_native_indicator_contract("demo"),
    sea_country = runtime$wlv_native_indicator_contract("demo", level = "country"),
    io_matrix = runtime$wlv_native_io_contract("values"),
    country_matrix = runtime$wlv_native_country_matrix_contract("transfers"),
    lambda = runtime$wlv_native_intermediate_contract(
      "lambda", c("year", "input")
    ),
    balance = runtime$wlv_native_intermediate_contract("balance_factor", "year"),
    basket_zero = runtime$wlv_native_intermediate_contract(
      "basket_zero", c("input", "output"), scope = "run"
    ),
    lambda_zero = runtime$wlv_native_intermediate_contract(
      "lambda_zero", "input", scope = "run"
    ),
    m_io = runtime$wlv_native_artifact_array_contract(
      "m_io", c("year", "variable", "input", "output")
    ),
    m_countries = runtime$wlv_native_artifact_array_contract(
      "m_countries", c("year", "variable", "origin", "destination")
    ),
    sea_sectors = runtime$wlv_native_artifact_array_contract(
      "sea_sectors", c("year", "indicator", "sector", "country")
    ),
    sea_countries = runtime$wlv_native_artifact_array_contract(
      "sea_countries", c("year", "indicator", "country")
    )
  )

  expect_true(all(vapply(
    semantic_contracts,
    function(contract) {
      identical(contract$role, "value") && isTRUE(contract$semantic_state)
    },
    logical(1L)
  )))
})

test_that("native semantic-state opt-in is exact and excludes controls", {
  runtime <- wlv_test_load_runtime()
  non_semantic_contracts <- list(
    generic_array = runtime$wlv_native_array_contract(
      axes = c("year", "value")
    ),
    other_intermediate = runtime$wlv_native_intermediate_contract(
      "diagnostic", "year"
    ),
    other_artifact = runtime$wlv_native_artifact_array_contract(
      "diagnostic", c("year", "value")
    ),
    filters = runtime$wlv_native_filters_contract(),
    parameters = runtime$wlv_native_parameters_contract(),
    indicator_metadata = runtime$wlv_native_indicator_metadata_contract()
  )

  expect_false(any(vapply(
    non_semantic_contracts,
    function(contract) isTRUE(contract$semantic_state),
    logical(1L)
  )))
  expect_identical(non_semantic_contracts$filters$role, "control")
  expect_identical(non_semantic_contracts$parameters$role, "value")
  expect_identical(non_semantic_contracts$indicator_metadata$role, "metadata")
  expect_error(
    runtime$wlv_native_array_contract(
      axes = "year",
      role = "metadata",
      semantic_state = TRUE
    ),
    "Only value resources"
  )
})

test_that("native module wrapper declares semantic pairs, controls, and bundles", {
  runtime <- wlv_test_load_runtime()
  spec <- runtime$wlv_source_indicator_spec()
  instance <- runtime$wlv_module_instance(
    "source_indicator.test",
    "source_indicator",
    args = list(indicator = "EMP", source_variable = "EMP")
  )
  requires <- spec$requires(instance$args, instance)
  provides <- spec$provides(instance$args, instance)

  expect_setequal(
    spec$services,
    c("contract_runtime", "module_contract")
  )
  expect_identical(
    requires$semantic_state__source$key,
    "semantic_state/source/sea"
  )
  expect_identical(
    requires$semantic_state__source$producer,
    requires$source$producer
  )
  expect_identical(
    requires$semantic_state__source$contract,
    runtime$wlv_native_semantic_state_contract(requires$source$contract)
  )
  control_keys <- vapply(
    requires[grep("^semantic_control_", names(requires))],
    function(ref) ref$key,
    character(1L)
  )
  expect_setequal(control_keys, c(
    "request/method",
    "request/source",
    "configuration/missingness_policy",
    "configuration/scientific_profile"
  ))
  expect_true(all(vapply(
    requires[names(control_keys)],
    function(ref) identical(ref$contract$role, "control"),
    logical(1L)
  )))
  expect_identical(
    provides$semantic_state__value$ref$key,
    "semantic_state/sea/sector/EMP"
  )
  expect_identical(
    provides$semantic_anomaly$ref$key,
    "anomaly/source_indicator.test"
  )
  expect_identical(
    provides$semantic_diagnostic$ref$key,
    "diagnostic/source_indicator.test"
  )
  expect_identical(provides$semantic_anomaly$ref$contract$role, "anomaly")
  expect_identical(
    provides$semantic_diagnostic$ref$contract$role,
    "diagnostic"
  )
})

test_that("native module wrapper accepts instance-aware factories and finalizes run", {
  runtime <- wlv_test_load_runtime()
  called <- new.env(parent = emptyenv())
  called$result <- NULL
  spec <- runtime$wlv_native_module_spec(
    id = "test.native.wrapper",
    checkpoint = 1L,
    parameters = list(name = runtime$wlv_module_parameter("character")),
    requires = function(args, instance) {
      runtime$wlv_native_run_ref(
        paste0("metadata/", args$name),
        "metadata",
        value_type = "list"
      )
    },
    provides = function(args, instance) {
      runtime$wlv_native_run_output(
        paste0("artifact/", instance$instance_id, ".", args$name),
        value_type = "list"
      )
    },
    run = function(ctx) runtime$wlv_module_result(list(value = list(ok = TRUE)))
  )
  instance <- runtime$wlv_module_instance(
    "test.native.wrapper.instance",
    "test.native.wrapper",
    args = list(name = "demo")
  )
  requires <- spec$requires(instance$args, instance)
  provides <- spec$provides(instance$args, instance)
  expect_identical(requires$metadata$key, "metadata/demo")
  expect_identical(
    provides$value$ref$key,
    "artifact/test.native.wrapper.instance.demo"
  )
  expect_identical(
    provides$semantic_anomaly$ref$key,
    "anomaly/test.native.wrapper.instance"
  )

  context <- list(service = function(name) {
    expect_identical(name, "module_contract")
    function(result) {
      called$result <- result
      structure(result, finalized = TRUE)
    }
  })
  result <- spec$run(context)
  expect_s3_class(called$result, "wlv_module_result")
  expect_true(isTRUE(attr(result, "finalized")))
})
