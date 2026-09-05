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

test_that("deferred experimental methods remain non-executable after opt-in", {
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
  expect_error(
    runtime$wlv_validate_request(
      "alternative_1",
      root = wlv_test_root,
      allow_experimental = TRUE,
      catalog = catalog
    ),
    "does not support operation(s): calculate",
    fixed = TRUE
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

test_that("the two executable methods compile deterministic native DAGs", {
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

  expect_length(methods, 2L)
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

test_that("removed paper arguments remain passive only at their defaults", {
  runtime <- preflight_environment
  catalog <- runtime$wlv_runtime_catalog()
  plan <- runtime$wlv_validate_request(
    "wiodr13",
    papern = 0L,
    prepaper = FALSE,
    root = wlv_test_root,
    catalog = catalog
  )
  expect_identical(plan$papern, 0L)
  expect_false(plan$prepaper)
  expect_false("paper_task" %in% names(plan))
  expect_length(grep("paper", ls(runtime, all.names = TRUE), ignore.case = TRUE), 0L)

  expect_error(
    runtime$wlv_validate_request(
      "wiodr13",
      papern = 0L,
      prepaper = TRUE,
      root = wlv_test_root,
      catalog = catalog
    ),
    "Paper tooling has been removed",
    fixed = TRUE
  )
  expect_error(
    runtime$wlv_validate_request(
      "wiodr13",
      papern = 1L,
      prepaper = FALSE,
      root = wlv_test_root,
      catalog = catalog
    ),
    "Paper tooling has been removed",
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
