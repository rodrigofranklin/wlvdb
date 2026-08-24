preflight_bootstrap <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "bootstrap.R"),
  envir = preflight_bootstrap
)
preflight_environment <- preflight_bootstrap$wlv_load_runtime(wlv_test_root)

test_that("request validation rejects invalid scalar inputs before execution", {
  runtime <- preflight_environment
  catalog <- runtime$wlv_runtime_catalog()
  invalid_workers <- list(NULL, 0, -1, 1.5, NA_real_, Inf, "2", c(1, 2))
  for (workers in invalid_workers) {
    expect_error(
      runtime$wlv_validate_request(
        "wiodr13",
        workers = workers,
        root = wlv_test_root,
        catalog = catalog
      ),
      "workers"
    )
  }
  expect_error(
    runtime$wlv_validate_request(
      "unknown_method",
      root = wlv_test_root,
      catalog = catalog
    ),
    "Unknown method"
  )
  expect_error(
    runtime$wlv_validate_request(
      "wiodr13",
      channel = "Invalid Channel",
      root = wlv_test_root,
      catalog = catalog
    ),
    "channel"
  )
})

test_that("experimental methods require explicit opt-in", {
  runtime <- preflight_environment
  catalog <- runtime$wlv_runtime_catalog()
  expect_error(
    runtime$wlv_validate_request(
      "alternative_1",
      root = wlv_test_root,
      catalog = catalog
    ),
    "experimental"
  )
  expect_s3_class(
    runtime$wlv_validate_request(
      "alternative_1",
      root = wlv_test_root,
      allow_experimental = TRUE,
      catalog = catalog
    ),
    "wlv_run_plan"
  )
})

test_that("recalculation checkpoints and selections are validated preflight", {
  runtime <- preflight_environment
  catalog <- runtime$wlv_runtime_catalog()
  expect_error(
    runtime$wlv_validate_request(
      "wiodr13",
      mode = "recalculate",
      at_stage = 2L,
      root = wlv_test_root,
      catalog = catalog
    ),
    "implemented checkpoints"
  )
  expect_error(
    runtime$wlv_validate_request(
      "wiodr13",
      mode = "recalculate",
      at_stage = 1L,
      sea_vars = "value.m.mv",
      root = wlv_test_root,
      catalog = catalog
    ),
    "unsafe at stage 1"
  )
  expect_error(
    runtime$wlv_validate_request(
      "wiodr13",
      mode = "recalculate",
      at_stage = 4L,
      sea_vars = "not.configured",
      root = wlv_test_root,
      catalog = catalog
    ),
    "Unknown `sea_vars`"
  )
})

test_that("the twelve executable methods compile deterministic native DAGs", {
  runtime <- preflight_environment
  catalog <- runtime$wlv_runtime_catalog()
  methods <- runtime$wlv_catalog_method_table(catalog)
  methods <- methods$method[methods$can_calculate | methods$can_recalculate]
  plan <- runtime$wlv_validate_request(
    methods,
    root = wlv_test_root,
    allow_experimental = TRUE,
    catalog = catalog
  )

  expect_length(methods, 12L)
  for (method in methods) {
    instances <- runtime$wlv_native_plan_instances(
      registry = plan$native_registry,
      config = plan$configuration[[method]],
      aggregation_registry = plan$aggregation_registries[[method]],
      indicators = plan$indicators[[method]],
      partitions = "synthetic-period",
      mode = "calculate"
    )
    graph <- runtime$wlv_native_preflight_plan(
      plan$native_registry,
      instances,
      "synthetic-period",
      "calculate",
      source = plan$methods$source[match(method, plan$methods$method)],
      at_stage = 1L,
      indicators = plan$indicators[[method]]
    )
    expect_s3_class(graph, "wlv_module_plan")
    expect_setequal(graph$order, names(graph$modules))
    expect_identical(anyDuplicated(graph$order), 0L)
  }
})

test_that("paper support is a native registered preflight decision", {
  runtime <- preflight_environment
  catalog <- runtime$wlv_runtime_catalog()
  supported <- runtime$wlv_validate_request(
    "wiodr13",
    papern = 0L,
    prepaper = TRUE,
    root = wlv_test_root,
    catalog = catalog
  )
  expect_s3_class(supported$paper_task, "wlv_paper_spec")
  expect_named(supported$publication_inputs, "wiodr13")
  expect_no_error(runtime$wlv_assert_plan_publication_inputs_unchanged(supported))
  for (paper in c(3L, 4L)) {
    expect_error(
      runtime$wlv_validate_request(
        "wiodr13",
        papern = paper,
        prepaper = TRUE,
        root = wlv_test_root,
        catalog = catalog
      ),
      "unsupported"
    )
  }
})

test_that("paper 0 rejects incompatible sources and accepts reordered profiles", {
  runtime <- preflight_environment
  catalog <- runtime$wlv_runtime_catalog()
  expect_error(
    runtime$wlv_validate_request(
      c("wiodr13", "wiodr16"),
      papern = 0L,
      prepaper = TRUE,
      root = wlv_test_root,
      catalog = catalog
    ),
    "different source contracts",
    fixed = TRUE
  )

  compatible <- runtime$wlv_validate_request(
    c("alternative_1", "zerodep_1"),
    papern = 0L,
    prepaper = TRUE,
    root = wlv_test_root,
    allow_experimental = TRUE,
    catalog = catalog
  )
  expect_identical(compatible$method_names, c("alternative_1", "zerodep_1"))
  expect_setequal(
    compatible$indicators$alternative_1,
    compatible$indicators$zerodep_1
  )
  expect_false(identical(
    compatible$indicators$alternative_1,
    compatible$indicators$zerodep_1
  ))

  expect_error(
    runtime$wlv_validate_request(
      "wiodr16",
      papern = 0L,
      prepaper = TRUE,
      root = wlv_test_root,
      catalog = catalog
    ),
    "requires missing output indicator",
    fixed = TRUE
  )
  expect_error(
    runtime$wlv_validate_request(
      c("wiodr16", "zerodep_2"),
      papern = 0L,
      prepaper = TRUE,
      root = wlv_test_root,
      allow_experimental = TRUE,
      catalog = catalog
    ),
    "requires missing output indicator",
    fixed = TRUE
  )
})

test_that("native preflight never creates the publication lock", {
  runtime <- preflight_environment
  catalog <- runtime$wlv_runtime_catalog()
  lock <- file.path(wlv_test_root, "results", ".lock-results")
  before <- dir.exists(lock)
  invisible(runtime$wlv_validate_request(
    c("wiodr13", "wiodr16"),
    root = wlv_test_root,
    catalog = catalog
  ))
  expect_identical(dir.exists(lock), before)
})
