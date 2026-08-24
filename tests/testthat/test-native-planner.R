native_planner_environment <- new.env(parent = globalenv())
for (path in c(
  "R/lib/catalog.R",
  "R/lib/unit_dimensions.R",
  "R/lib/aggregation_specs.R",
  "R/lib/module_config.R",
  "R/lib/native_aggregation_registry.R",
  "R/lib/module_runtime.R",
  "R/modules/native/contracts.R",
  "R/modules/native/source_modules.R",
  "R/modules/native/matrix_modules.R",
  "R/modules/native/capital_matrix_modules.R",
  "R/modules/native/reduced_matrix_modules.R",
  "R/modules/native/indicator_helpers.R",
  "R/modules/native/indicator_common_modules.R",
  "R/modules/native/indicator_source_derived_modules.R",
  "R/modules/native/indicator_stage4_collector.R",
  "R/modules/native/indicator_reduction_modules.R",
  "R/modules/native/zz_indicator_registry.R",
  "R/modules/native/assumption_modules.R",
  "R/modules/native/aggregation_modules.R",
  "R/modules/native/assembler_modules.R",
  "R/lib/native_registry.R",
  "R/lib/native_planner.R"
)) {
  sys.source(file.path(wlv_test_root, path), envir = native_planner_environment)
}

wlv_test_native_planner_inputs <- function(method) {
  e <- native_planner_environment
  catalog <- e$wlv_load_catalog(wlv_test_root)
  methods <- e$wlv_catalog_method_table(catalog)
  record <- methods[methods$method == method, , drop = FALSE]
  stopifnot(nrow(record) == 1L)
  aggregation <- e$wlv_native_aggregation_registry(
    wlv_test_root,
    catalog,
    method
  )
  list(
    catalog = catalog,
    record = record,
    config = e$wlv_resolve_module_config(
      wlv_test_root,
      method,
      record$source[[1L]]
    ),
    aggregation = aggregation,
    indicators = unique(aggregation$rows$indicator)
  )
}

test_that("all twelve executable methods compile deterministic native DAGs", {
  e <- native_planner_environment
  catalog <- e$wlv_load_catalog(wlv_test_root)
  methods <- e$wlv_catalog_method_table(catalog)
  methods <- methods[methods$can_calculate, , drop = FALSE]
  expect_identical(nrow(methods), 12L)
  registry <- e$wlv_native_registry()

  plans <- lapply(methods$method, function(method) {
    inputs <- wlv_test_native_planner_inputs(method)
    expect_false("legacy" %in% names(inputs$aggregation))
    instances <- e$wlv_native_plan_instances(
      registry,
      inputs$config,
      inputs$aggregation,
      inputs$indicators,
      partitions = "fixture",
      mode = "calculate"
    )
    e$wlv_native_preflight_plan(
      registry,
      instances,
      partitions = "fixture",
      mode = "calculate",
      source = inputs$record$source[[1L]],
      at_stage = 1L,
      indicators = inputs$indicators
    )
  })
  names(plans) <- methods$method
  expect_true(all(vapply(plans, function(plan) length(plan$order) > 0L, logical(1L))))

  inputs <- wlv_test_native_planner_inputs("wiodr13")
  reversed <- inputs$config[rev(seq_len(nrow(inputs$config))), , drop = FALSE]
  normal_instances <- e$wlv_native_plan_instances(
    registry, inputs$config, inputs$aggregation, inputs$indicators,
    "fixture", mode = "calculate"
  )
  reversed_instances <- e$wlv_native_plan_instances(
    registry, reversed, inputs$aggregation, inputs$indicators,
    "fixture", mode = "calculate"
  )
  normal <- e$wlv_native_preflight_plan(
    registry, normal_instances, "fixture", "calculate",
    source = inputs$record$source[[1L]],
    at_stage = 1L,
    indicators = inputs$indicators
  )
  reordered <- e$wlv_native_preflight_plan(
    registry, reversed_instances, "fixture", "calculate",
    source = inputs$record$source[[1L]],
    at_stage = 1L,
    indicators = inputs$indicators
  )
  expect_identical(normal$order, reordered$order)
})

test_that("native preflight rejects invented seeds and incompatible seed contracts", {
  e <- native_planner_environment
  base_registry <- e$wlv_native_registry()
  output_contract <- e$wlv_resource_contract(
    scope = "run",
    axes = character(),
    value_type = "character"
  )
  make_probe <- function(id, key, contract) {
    e$wlv_module_spec(
      id = id,
      scope = "run",
      checkpoint = 1L,
      requires = list(value = e$wlv_resource_ref(
        key,
        contract,
        producer = e$wlv_runtime_seed_producer
      )),
      provides = list(value = e$wlv_resource_output(e$wlv_resource_ref(
        paste0("artifact/", id),
        output_contract
      ))),
      run = function(ctx) e$wlv_module_result(list(value = "unused"))
    )
  }
  invented <- make_probe(
    "test.invented.seed",
    "source/does_not_exist",
    e$wlv_resource_contract(scope = "run", value_type = "data.frame")
  )
  incompatible <- make_probe(
    "test.incompatible.seed",
    "request/method",
    e$wlv_resource_contract(scope = "run", value_type = "data.frame")
  )
  inputs <- wlv_test_native_planner_inputs("wiodr13")
  preflight <- function(spec) {
    registry <- e$wlv_module_registry(c(unname(base_registry$specs), list(spec)))
    e$wlv_native_preflight_plan(
      registry,
      list(e$wlv_module_instance(spec$id, spec$id)),
      partitions = "fixture",
      mode = "calculate",
      source = "wiodr13",
      at_stage = 1L,
      indicators = inputs$indicators
    )
  }
  expect_error(preflight(invented), "undeclared dependency")
  expect_error(preflight(incompatible), "incompatible contract")
})

test_that("native recalculation DAGs compile at public checkpoints", {
  e <- native_planner_environment
  registry <- e$wlv_native_registry()
  for (method in c("wiodr13", "wiodr16")) {
    inputs <- wlv_test_native_planner_inputs(method)
    for (stage in c(1L, 4L, 5L)) {
      instances <- e$wlv_native_plan_instances(
        registry,
        inputs$config,
        inputs$aggregation,
        inputs$indicators,
        partitions = c("first", "second"),
        mode = "recalculate",
        at_stage = stage
      )
      expect_silent(e$wlv_native_preflight_plan(
        registry,
        instances,
        partitions = c("first", "second"),
        mode = "recalculate",
        source = inputs$record$source[[1L]],
        at_stage = stage,
        indicators = inputs$indicators
      ))
    }

    direct <- inputs$aggregation$rows$indicator[
      inputs$aggregation$rows$level == "sector_to_country" &
        inputs$aggregation$rows$strategy != "formula"
    ][[1L]]
    formula <- inputs$aggregation$rows$indicator[
      inputs$aggregation$rows$level == "sector_to_country" &
        inputs$aggregation$rows$strategy == "formula"
    ][[1L]]
    for (stage in c(4L, 5L)) {
      for (indicator in c(direct, formula)) {
        instances <- e$wlv_native_plan_instances(
          registry,
          inputs$config,
          inputs$aggregation,
          inputs$indicators,
          partitions = c("first", "second"),
          mode = "recalculate",
          at_stage = stage,
          sea_vars = indicator
        )
        expect_silent(e$wlv_native_preflight_plan(
          registry,
          instances,
          partitions = c("first", "second"),
          mode = "recalculate",
          source = inputs$record$source[[1L]],
          at_stage = stage,
          indicators = inputs$indicators
        ))
      }
    }
  }
})

test_that("ROW ownership selects the exact go-price predecessor", {
  e <- native_planner_environment
  standard <- wlv_test_native_planner_inputs("wiodr13")
  no_row <- wlv_test_native_planner_inputs("norow_w13")
  expect_identical(
    e$wlv_native_go_price_predecessor(standard$config, "calculate", 1L),
    "assumption.row"
  )
  expect_identical(
    e$wlv_native_go_price_predecessor(no_row$config, "calculate", 1L),
    "assumption.row"
  )
  expect_identical(
    e$wlv_native_go_price_predecessor(standard$config, "recalculate", 4L),
    "indicator.go_price.r.id"
  )
})
