native_execution_bootstrap <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "bootstrap.R"),
  envir = native_execution_bootstrap
)
native_execution_runtime <- native_execution_bootstrap$wlv_load_runtime(
  wlv_test_root
)

test_that("all executable methods resolve only typed native execution inputs", {
  runtime <- native_execution_runtime
  catalog <- runtime$wlv_runtime_catalog()
  methods <- runtime$wlv_catalog_method_table(catalog)
  methods <- methods$method[methods$can_calculate | methods$can_recalculate]
  plan <- runtime$wlv_validate_request(
    methods,
    root = wlv_test_root,
    allow_experimental = TRUE,
    catalog = catalog
  )

  expect_s3_class(plan, "wlv_run_plan")
  expect_identical(plan$method_names, methods)
  expect_true(all(vapply(
    plan$configuration,
    inherits,
    logical(1L),
    "wlv_module_config"
  )))
  expect_true(all(vapply(plan$configuration, function(configuration) {
    all(configuration$module_id %in% names(plan$native_registry$specs))
  }, logical(1L))))
  expect_true(all(vapply(plan$aggregation_registries, function(registry) {
    !"legacy" %in% names(registry) &&
      all(vapply(registry$bindings, function(binding) {
        !"legacy" %in% names(binding)
      }, logical(1L)))
  }, logical(1L))))
  expect_true(all(vapply(plan$method_names, function(method) {
    identical(
      unname(plan$indicators[[method]]),
      unname(runtime$wlv_native_output_indicators(
        wlv_test_root,
        catalog,
        method,
        plan$aggregation_registries[[method]]
      ))
    )
  }, logical(1L))))
})

test_that("selective recalculation is checked against native checkpoint ranks", {
  runtime <- native_execution_runtime
  catalog <- runtime$wlv_runtime_catalog()
  plan <- runtime$wlv_validate_request(
    "wiodr13",
    mode = "recalculate",
    at_stage = 4L,
    root = wlv_test_root,
    catalog = catalog
  )
  method <- "wiodr13"
  partitions <- "1995-2009"
  stages <- runtime$wlv_native_indicator_stage_map(
    plan$native_registry,
    plan$configuration[[method]],
    plan$aggregation_registries[[method]],
    plan$indicators[[method]],
    partitions
  )

  expect_error(
    runtime$wlv_native_validate_selected_stages(
      stages,
      "emp.s.un",
      4L,
      method
    ),
    "cannot be recalculated from checkpoint stage 4"
  )
  expect_no_error(runtime$wlv_native_validate_selected_stages(
    stages,
    "value.m.mv",
    4L,
    method
  ))
})

test_that("unsupported papers fail before calculation starts", {
  runtime <- native_execution_runtime
  catalog <- runtime$wlv_runtime_catalog()
  expect_error(
    runtime$wlv_validate_request(
      "wiodr13",
      papern = 3L,
      prepaper = TRUE,
      root = wlv_test_root,
      catalog = catalog
    ),
    "Paper `3` is unsupported"
  )
  expect_error(
    runtime$wlv_validate_request(
      "wiodr13",
      papern = 4L,
      prepaper = FALSE,
      root = wlv_test_root,
      catalog = catalog
    ),
    "Paper `4` is unsupported"
  )
})

test_that("selective recalculation refreshes only recomputed indicator metadata", {
  runtime <- native_execution_runtime
  indicators <- c("kept", "target")
  parent <- data.frame(
    code = indicators,
    name = c("parent kept", "parent target"),
    stringsAsFactors = FALSE,
    row.names = indicators
  )
  current <- data.frame(
    code = indicators,
    name = c("current kept", "current target"),
    stringsAsFactors = FALSE,
    row.names = indicators
  )
  contract <- runtime$wlv_resource_contract(
    scope = "run",
    value_type = "double"
  )
  resolved <- list(list(provides = list(runtime$wlv_resource_output(
    runtime$wlv_resource_ref("sea/sector/target", contract),
    action = "create"
  ))))

  merged <- runtime$wlv_native_merge_recalculation_metadata(
    parent,
    current,
    resolved,
    indicators
  )

  expect_identical(merged["kept", "name"], "parent kept")
  expect_identical(merged["target", "name"], "current target")
  expect_identical(row.names(merged), indicators)
})

test_that("recalculation rejects a parent with a contracted indicator schema", {
  skip_if_not_installed("fst")
  runtime <- native_execution_runtime
  parent <- tempfile("wlv-parent-schema-")
  dir.create(parent)
  on.exit(unlink(parent, recursive = TRUE, force = TRUE), add = TRUE)

  sector <- array(
    seq_len(2L),
    dim = c(1L, 2L, 1L, 1L),
    dimnames = list(
      year = "2000",
      indicator = c("kept", "removed"),
      sector = "S1",
      country = "A"
    )
  )
  country <- array(
    seq_len(2L),
    dim = c(1L, 2L, 1L),
    dimnames = list(
      year = "2000",
      indicator = c("kept", "removed"),
      country = "A"
    )
  )
  runtime$write_fst_array(sector, file.path(parent, "sea_sectors.fst"))
  runtime$write_fst_array(country, file.path(parent, "sea_countries.fst"))

  expect_error(
    runtime$wlv_native_parent_indicator_seeds(
      parent,
      indicators = "kept",
      resolved = list()
    ),
    "indicator schema differs",
    fixed = TRUE
  )
})

test_that("public arrays preserve labels while omitting internal axis names", {
  runtime <- native_execution_runtime
  value <- array(
    seq_len(4L),
    dim = c(2L, 2L),
    dimnames = list(year = c("2000", "2001"), country = c("A", "B"))
  )

  public <- runtime$wlv_native_public_array(value)

  expect_identical(unname(dimnames(public)), unname(dimnames(value)))
  expect_null(names(dimnames(public)))
  expect_identical(names(dimnames(value)), c("year", "country"))
})

test_that("execution definition has no legacy executor or dynamic escape", {
  path <- file.path(wlv_test_root, "R", "lib", "execution.R")
  violations <- native_execution_runtime$wlv_runtime_static_scan_file(
    path,
    root = wlv_test_root
  )
  text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  expect_identical(nrow(violations), 0L)
  expect_false(grepl("computations[.]R|re_computations[.]R", text))
  expect_false(grepl("_method_(assumptions|matrices|solutions)[.]csv", text))
  expect_false(grepl("_source_(assumptions|matrices|solutions)[.]csv", text))
  expect_false(grepl("_common_(assumptions|matrices|solutions)[.]csv", text))
})
