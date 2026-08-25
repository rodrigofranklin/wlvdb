test_that("negative-GFCF contributions reconcile by scientific cell identity", {
  runtime <- wlv_test_load_runtime()
  observed <- data.frame(
    year = c("2000", "2001"),
    input = c("USA.s1", "ROW.s2"),
    output = c("USA.c41", "ROW.c60"),
    value = c(-2, -3),
    policy_id = rep("wiodr13_negative_gfcf_v1", 2L),
    action = rep("truncate_allowlisted_negative_gfcf", 2L),
    stringsAsFactors = FALSE
  )
  expected <- runtime$wlv_gfcf_diagnostic_artifacts(
    observed,
    method = "wiodr13",
    input_unit = "million_usd"
  )
  left <- runtime$wlv_gfcf_diagnostic_artifacts(
    observed[1L, , drop = FALSE],
    method = "wiodr13",
    input_unit = "million_usd"
  )
  right <- runtime$wlv_gfcf_diagnostic_artifacts(
    observed[2L, , drop = FALSE],
    method = "wiodr13",
    input_unit = "million_usd"
  )
  contributions <- list(
    runtime$wlv_native_gfcf_contribution(left, node_id = "capital.2000"),
    runtime$wlv_native_gfcf_contribution(right, node_id = "capital.2001")
  )

  expect_identical(
    runtime$wlv_native_merge_gfcf_contributions(contributions),
    expected
  )
  expect_identical(
    runtime$wlv_native_merge_gfcf_contributions(c(
      contributions,
      list(runtime$wlv_native_gfcf_contribution(
        expected,
        node_id = "capital.full"
      ))
    )),
    expected
  )
})

test_that("negative-GFCF overlap conflicts and broken summaries fail closed", {
  runtime <- wlv_test_load_runtime()
  observed <- data.frame(
    year = "2000",
    input = "USA.s1",
    output = "USA.c41",
    value = -2,
    policy_id = "wiodr13_negative_gfcf_v1",
    action = "truncate_allowlisted_negative_gfcf",
    stringsAsFactors = FALSE
  )
  bundle <- runtime$wlv_gfcf_diagnostic_artifacts(
    observed,
    method = "wiodr13",
    input_unit = "million_usd"
  )
  broken <- bundle
  broken[["_gfcf_negative_summary.csv"]]$cell_count[[1L]] <- 2L
  expect_error(
    runtime$wlv_native_gfcf_contribution(broken, node_id = "capital.broken"),
    "not internally reproducible",
    fixed = TRUE
  )

  first <- runtime$wlv_native_gfcf_contribution(bundle)
  second <- first
  second$cells$original_million_usd[[1L]] <- -4
  expect_error(
    runtime$wlv_native_merge_gfcf_contributions(list(first, second)),
    "contributions conflict",
    fixed = TRUE
  )
})

test_that("scientific diagnostic dispatch rejects undeclared artifact ids", {
  runtime <- wlv_test_load_runtime()
  expect_error(
    runtime$wlv_native_normalize_scientific_diagnostics(
      list(`_unknown.csv` = data.frame(value = 1)),
      method = "wiodr13",
      source = "wiodr13",
      expected_years = "2000",
      context = "Test"
    ),
    "undeclared artifact",
    fixed = TRUE
  )
})

test_that("module diagnostic registry closes IDs, ownership, and visibility", {
  runtime <- wlv_test_load_runtime()
  registry <- runtime$wlv_native_diagnostic_contract_registry()
  expect_identical(
    runtime$wlv_native_published_diagnostic_ids(),
    c(
      "_leontief_diagnostics.csv",
      "_nonfinite_resolution_diagnostics.csv",
      "_gfcf_negative_cells.csv",
      "_gfcf_negative_summary.csv"
    )
  )
  expect_identical(registry$indicator_count$visibility, "internal")
  expect_identical(registry$indicator_count$owners, "aggregation.direct")
  expect_identical(
    registry[["_nonfinite_resolution_diagnostics.csv"]]$owner_rule,
    "self"
  )

  unknown <- list(
    module_id = "aggregation.direct",
    value = runtime$wlv_semantic_diagnostic_bundle(list(
      indicator_counnt = 1L
    ))
  )
  expect_error(
    runtime$wlv_native_validate_diagnostic_contribution_owner(unknown),
    "undeclared diagnostic ID",
    fixed = TRUE
  )

  internal <- list(
    module_id = "aggregation.direct",
    value = runtime$wlv_semantic_diagnostic_bundle(list(
      indicator_count = 1L,
      direct_count = 1L,
      formula_count = 0L
    ))
  )
  expect_no_error(
    runtime$wlv_native_validate_diagnostic_contribution_owner(internal)
  )
  internal$module_id <- "indicator.foreign"
  expect_error(
    runtime$wlv_native_validate_diagnostic_contribution_owner(internal),
    "is not an owner",
    fixed = TRUE
  )
})

test_that("published diagnostic contributions enforce producer ownership", {
  runtime <- wlv_test_load_runtime()
  leontief <- runtime$wlv_solve_leontief(
    coefficient_matrix = matrix(
      0,
      nrow = 1L,
      ncol = 1L,
      dimnames = list("USA.s1", "USA.s1")
    ),
    labour_requirements = c("USA.s1" = 1),
    gross_output = c("USA.s1" = 1),
    method = "wiodr13",
    year = "2000"
  )$diagnostics
  contribution <- list(
    module_id = "indicator.not_an_owner",
    value = runtime$wlv_semantic_diagnostic_bundle(list(
      `_leontief_diagnostics.csv` = leontief
    ))
  )
  expect_error(
    runtime$wlv_native_validate_diagnostic_contribution_owner(contribution),
    "is not an owner",
    fixed = TRUE
  )
  contribution$module_id <- "matrix.transformation"
  expect_no_error(
    runtime$wlv_native_validate_diagnostic_contribution_owner(contribution)
  )

  nonfinite <- data.frame(
    method = "wiodr13",
    binding = "test",
    indicator = "test.indicator",
    kind = "NaN",
    module = "indicator.foreign",
    expected_count = 1L,
    observed_count = 1L,
    coordinate_sha256 = paste(rep("0", 64L), collapse = ""),
    policy_id = "test_policy",
    action = "test_action",
    stringsAsFactors = FALSE
  )
  contribution <- list(
    module_id = "indicator.owner",
    value = runtime$wlv_semantic_diagnostic_bundle(list(
      `_nonfinite_resolution_diagnostics.csv` = nonfinite
    ))
  )
  expect_error(
    runtime$wlv_native_validate_diagnostic_contribution_owner(contribution),
    "owned by",
    fixed = TRUE
  )
})

test_that("recalculation diagnostics inherit exactly and reject owner gaps", {
  runtime <- wlv_test_load_runtime()
  source_sea <- tempfile("wlv-diagnostic-source-")
  metadata_path <- paste0(source_sea, ".meta")
  on.exit(unlink(metadata_path, force = TRUE), add = TRUE)
  saveRDS(
    list(c(1L, 1L, 1L, 1L), "2000", "GO", "S1", "USA"),
    metadata_path
  )
  leontief <- runtime$wlv_solve_leontief(
    coefficient_matrix = matrix(
      0,
      nrow = 1L,
      ncol = 1L,
      dimnames = list("USA.s1", "USA.s1")
    ),
    labour_requirements = c("USA.s1" = 1),
    gross_output = c("USA.s1" = 1),
    method = "wiodr13",
    year = "2000"
  )$diagnostics
  parent <- list(`_leontief_diagnostics.csv` = leontief)
  run_data <- list(
    source_sea = source_sea,
    parent_scientific_diagnostics = parent
  )
  module_plan <- function(module_id) {
    plan <- new.env(parent = emptyenv())
    plan$modules <- list(active = list(module_id = module_id))
    class(plan) <- "wlv_module_plan"
    lockEnvironment(plan, bindings = TRUE)
    plan
  }

  expect_identical(
    runtime$wlv_native_merge_recalculation_diagnostics(
      run_data = run_data,
      current = list(),
      module_plan = module_plan("indicator.test"),
      method = "wiodr13",
      source = "wiodr13"
    ),
    parent
  )
  expect_error(
    runtime$wlv_native_merge_recalculation_diagnostics(
      run_data = run_data,
      current = parent,
      module_plan = module_plan("indicator.test"),
      method = "wiodr13",
      source = "wiodr13"
    ),
    "without their owning module",
    fixed = TRUE
  )
  expect_error(
    runtime$wlv_native_merge_recalculation_diagnostics(
      run_data = run_data,
      current = list(),
      module_plan = module_plan("matrix.transformation"),
      method = "wiodr13",
      source = "wiodr13"
    ),
    "omitted its diagnostic artifact",
    fixed = TRUE
  )
})

test_that("module execution failures retain the module-local anomaly audit", {
  runtime <- wlv_test_load_runtime()
  anomaly <- data.frame(
    artifact = "sea_sectors",
    indicator = "test.indicator",
    checkpoint = "after_test",
    stage = "5",
    module = "indicator.test",
    year = "2000",
    country = "USA",
    sector = "S1",
    output = "",
    original_value = "NaN",
    policy_id = "test_policy",
    action = "abort_non_finite",
    stringsAsFactors = FALSE
  )[runtime$wlv_contract_anomaly_columns()]
  module_runtime <- new.env(parent = emptyenv())
  module_runtime$anomalies <- rbind(anomaly, anomaly)
  error <- runtime$wlv_new_contract_error("contract failed", anomaly)

  condition <- runtime$wlv_runtime_module_execution_condition(
    error,
    "indicator.test.one",
    module_runtime
  )
  expect_s3_class(condition, "wlv_module_contract_error")
  expect_s3_class(condition, "wlv_contract_error")
  expect_s3_class(condition, "wlv_runtime_error")
  expect_identical(condition$node_id, "indicator.test.one")
  expect_identical(condition$anomalies, module_runtime$anomalies)
  expect_identical(nrow(condition$anomalies), 2L)
})

test_that("output validation failures retain the module-local anomaly audit", {
  runtime <- wlv_test_load_runtime()
  module_id <- "test.output.validation"
  anomaly <- data.frame(
    artifact = "sea_sectors",
    indicator = "test.indicator",
    checkpoint = "after_test",
    stage = "5",
    module = module_id,
    year = "2000",
    country = "USA",
    sector = "S1",
    output = "",
    original_value = "NaN",
    policy_id = "test_policy",
    action = "abort_non_finite",
    stringsAsFactors = FALSE
  )[runtime$wlv_contract_anomaly_columns()]
  value_contract <- runtime$wlv_resource_contract(
    axes = character(),
    value_type = "double"
  )
  seed_contract <- runtime$wlv_resource_contract(
    axes = character(),
    value_type = "character"
  )
  anomaly_contract <- runtime$wlv_resource_contract(
    value_type = "data.frame",
    role = "anomaly"
  )
  anomaly_output <- runtime$wlv_resource_output(runtime$wlv_resource_ref(
    paste0("anomaly/", module_id),
    anomaly_contract
  ))
  attr(anomaly_output, "wlv_native_anomaly_targets") <-
    runtime$wlv_native_anomaly_target_contract(
      list(runtime$wlv_native_anomaly_binding(
        "sea_sectors",
        "test.indicator"
      )),
      checkpoint = 5L,
      module_id = module_id
    )
  spec <- runtime$wlv_module_spec(
    id = module_id,
    checkpoint = 5L,
    services = runtime$wlv_runtime_intrinsic_service_names(),
    requires = list(seed = runtime$wlv_resource_ref(
      "seed/output_validation",
      seed_contract,
      producer = runtime$wlv_runtime_seed_producer()
    )),
    provides = list(
      value = runtime$wlv_resource_output(runtime$wlv_resource_ref(
        "artifact/invalid_value",
        value_contract
      )),
      anomaly = anomaly_output
    ),
    run = function(ctx) {
      module_runtime <- ctx$service("contract_runtime")
      module_runtime$anomalies <- anomaly
      ctx$service("module_contract")(runtime$wlv_module_result(list(
        value = "not a double"
      )))
    }
  )
  registry <- runtime$wlv_module_registry(list(spec))
  store <- runtime$wlv_new_resource_store(list(runtime$wlv_seed_resource(
    "seed/output_validation",
    "seed",
    seed_contract
  )))
  plan <- runtime$wlv_compile_module_plan(
    registry,
    list(runtime$wlv_module_instance(module_id, module_id)),
    store
  )

  condition <- tryCatch(
    runtime$wlv_run_module_plan(plan, store),
    error = identity
  )
  expect_s3_class(condition, "wlv_module_contract_error")
  expect_s3_class(condition, "wlv_contract_error")
  expect_s3_class(condition, "wlv_runtime_error")
  expect_match(conditionMessage(condition), "does not satisfy value type")
  expect_identical(condition$node_id, module_id)
  expect_identical(condition$anomalies, anomaly)
  expect_true("wlv_result_error" %in% condition$cause_class)
  expect_identical(nrow(runtime$wlv_store_catalog(store)), 1L)
})
