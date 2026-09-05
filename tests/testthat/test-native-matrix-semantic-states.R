test_that("matrix transformation publishes a canonical lambda state", {
  runtime <- wlv_test_load_runtime()
  partition <- "2000-2000"
  years <- "2000"
  inputs <- "AAA.S1"
  source_io <- array(
    0.2,
    dim = c(1L, 1L, 1L),
    dimnames = list(year = years, input = inputs, output = inputs)
  )
  depreciation <- array(
    0.1,
    dim = dim(source_io),
    dimnames = dimnames(source_io)
  )
  sector_labels <- list(year = years, sector = "S1", country = "AAA")
  abstract_labour <- array(0.5, dim = c(1L, 1L, 1L), dimnames = sector_labels)
  gross_output <- array(1, dim = c(1L, 1L, 1L), dimnames = sector_labels)

  stateful_seed <- function(key, value, contract, partition = NULL) {
    runtime$wlv_native_stateful_seed_pair(
      runtime$wlv_seed_resource(
        key,
        value,
        contract,
        partition = partition,
        producer = runtime$wlv_runtime_seed_producer()
      ),
      states = runtime$wlv_semantic_state_array(value, contract$axes)
    )
  }
  source_contract <- runtime$wlv_native_source_io_contract()
  depreciation_contract <- runtime$wlv_native_io_contract("k_depreciation")
  labour_contract <- runtime$wlv_native_indicator_contract(
    "abstract_labour.emp.s.mv"
  )
  output_contract <- runtime$wlv_native_indicator_contract("gross_output.s.us")
  seeds <- c(
    stateful_seed("source/io", source_io, source_contract, partition),
    stateful_seed(
      "io/k_depreciation",
      depreciation,
      depreciation_contract,
      partition
    ),
    stateful_seed(
      "sea/sector/abstract_labour.emp.s.mv",
      abstract_labour,
      labour_contract
    ),
    stateful_seed(
      "sea/sector/gross_output.s.us",
      gross_output,
      output_contract
    ),
    list(
      runtime$wlv_seed_resource(
        "dimensions/lists",
        list(
          years = years,
          sectors = "S1",
          countries = "AAA",
          input = inputs,
          output = inputs
        ),
        runtime$wlv_resource_contract(scope = "run", value_type = "list")
      ),
      runtime$wlv_seed_resource(
        "dimensions/nums",
        list(years = 1L, input = 1L, output = 1L),
        runtime$wlv_resource_contract(scope = "run", value_type = "list")
      ),
      runtime$wlv_seed_resource(
        "dimensions/rows",
        data.frame(productive = TRUE, row.names = inputs),
        runtime$wlv_resource_contract(scope = "run", value_type = "data.frame")
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
  store <- runtime$wlv_new_resource_store(seeds)
  instance <- runtime$wlv_module_instance(
    "matrix.values",
    "matrix.transformation",
    partition = partition
  )
  plan <- runtime$wlv_compile_module_plan(
    runtime$wlv_module_registry(list(runtime$wlv_matrix_transformation_spec())),
    list(instance),
    store,
    partitions = partition
  )
  result <- runtime$wlv_run_module_plan(plan, store)
  lambda_contract <- runtime$wlv_native_intermediate_contract(
    "lambda",
    c("year", "input")
  )
  lambda <- runtime$wlv_store_read(
    result$store,
    runtime$wlv_resource_ref(
      "intermediate/lambda",
      lambda_contract,
      producer = instance$instance_id,
      partition = partition
    )
  )
  lambda_state <- runtime$wlv_store_read(
    result$store,
    runtime$wlv_resource_ref(
      "semantic_state/intermediate/lambda",
      runtime$wlv_native_semantic_state_contract(lambda_contract),
      producer = instance$instance_id,
      partition = partition
    )
  )

  expect_identical(names(dimnames(lambda)), c("year", "input"))
  expect_null(attr(lambda, "wlv_state", exact = TRUE))
  expect_true(all(is.finite(lambda)))
  expect_equal(unname(lambda), matrix(0.5 / 0.7, nrow = 1L), tolerance = 1e-15)
  expect_s3_class(lambda_state, "wlv_semantic_state")
  expect_identical(nrow(lambda_state), 0L)
  expect_silent(runtime$wlv_semantic_state_validate(
    lambda_state,
    value = lambda,
    target_key = "intermediate/lambda",
    axes = c("year", "input"),
    state_key = "semantic_state/intermediate/lambda"
  ))
})
