wlv_test_native_anomaly_targets <- function(runtime, spec, args = list(),
                                            instance_id = spec$id) {
  instance <- runtime$wlv_module_instance(
    instance_id,
    spec$id,
    args = args
  )
  provides <- spec$provides(args, instance)
  anomaly <- provides[vapply(provides, function(output) {
    identical(output$ref$contract$role, "anomaly")
  }, logical(1L))]
  expect_identical(length(anomaly), 1L)
  runtime$wlv_native_anomaly_targets(anomaly[[1L]])
}

test_that("native anomaly targets default only from explicit SEA outputs", {
  runtime <- wlv_test_load_runtime()
  spec <- runtime$wlv_native_module_spec(
    id = "test.anomaly.defaults",
    checkpoint = 5L,
    provides = c(
      runtime$wlv_native_indicator_output("sector.output", alias = "sector"),
      runtime$wlv_native_indicator_output(
        "country.output",
        alias = "country",
        level = "country"
      ),
      runtime$wlv_native_run_output(
        "artifact/unrelated",
        alias = "artifact",
        value_type = "list"
      )
    ),
    run = function(ctx) {
      runtime$wlv_module_result(outputs = list())
    }
  )
  instance <- runtime$wlv_module_instance(
    "test.anomaly.defaults.instance",
    spec$id
  )
  provides <- spec$provides(list(), instance)
  anomaly <- provides$semantic_anomaly
  targets <- runtime$wlv_native_anomaly_targets(anomaly)

  expect_s3_class(targets, "wlv_native_anomaly_target_contract")
  expect_identical(
    names(targets),
    c("artifact", "indicator", "stage", "module", "producer_id", "action")
  )
  expect_identical(targets$artifact, c("sea_countries", "sea_sectors"))
  expect_identical(targets$indicator, c("country.output", "sector.output"))
  expect_identical(targets$stage, rep(5L, 2L))
  expect_identical(targets$module, rep(spec$id, 2L))
  expect_identical(targets$producer_id, rep(spec$id, 2L))
  expect_identical(targets$action, rep("replace", 2L))
  expect_false(any(grepl("[.](numerator|denominator)$", targets$indicator)))
  expect_false(runtime$wlv_runtime_contains_reference(targets))

  changed <- targets
  changed$action[[1L]] <- "preserve"
  expect_identical(
    runtime$wlv_native_anomaly_targets(anomaly)$action,
    rep("replace", 2L)
  )

  empty_spec <- runtime$wlv_native_module_spec(
    id = "test.anomaly.empty",
    checkpoint = 1L,
    provides = runtime$wlv_native_run_output(
      "artifact/only",
      value_type = "list"
    ),
    run = function(ctx) runtime$wlv_module_result(outputs = list())
  )
  empty <- wlv_test_native_anomaly_targets(runtime, empty_spec)
  expect_identical(nrow(empty), 0L)
  expect_identical(names(empty), runtime$wlv_native_anomaly_target_columns())
})

test_that("explicit anomaly bindings are typed and override one exact default", {
  runtime <- wlv_test_load_runtime()
  spec <- runtime$wlv_native_module_spec(
    id = "test.anomaly.explicit",
    checkpoint = "after_price_normalization",
    parameters = list(
      indicator = runtime$wlv_module_parameter("character")
    ),
    provides = function(args) {
      runtime$wlv_native_indicator_output(args$indicator)
    },
    anomaly_bindings = function(args, instance) {
      expect_identical(instance$module_id, "test.anomaly.explicit")
      list(runtime$wlv_native_anomaly_binding(
        "sea_sectors",
        args$indicator,
        action = "preserve",
        record_module = "legacy/scientific.R"
      ))
    },
    run = function(ctx) runtime$wlv_module_result(outputs = list())
  )
  targets <- wlv_test_native_anomaly_targets(
    runtime,
    spec,
    args = list(indicator = "go_price.r.id")
  )
  expect_identical(nrow(targets), 1L)
  expect_identical(targets$artifact, "sea_sectors")
  expect_identical(targets$indicator, "go_price.r.id")
  expect_identical(targets$stage, 4L)
  expect_identical(targets$module, "legacy/scientific.R")
  expect_identical(targets$producer_id, spec$id)
  expect_identical(targets$action, "preserve")

  invalid <- runtime$wlv_native_module_spec(
    id = "test.anomaly.invalid",
    checkpoint = 1L,
    provides = runtime$wlv_native_indicator_output("invalid"),
    anomaly_bindings = list(list(
      artifact = "sea_sectors",
      indicator = "invalid",
      action = "replace"
    )),
    run = function(ctx) runtime$wlv_module_result(outputs = list())
  )
  expect_error(
    wlv_test_native_anomaly_targets(runtime, invalid),
    "created with wlv_native_anomaly_binding",
    fixed = TRUE
  )
})

test_that("only productive-surplus modules declare aggregate ratio bindings", {
  runtime <- wlv_test_load_runtime()
  cases <- list(
    runtime$wlv_indicator_surplus_value_emp_p_r_pc_spec(),
    runtime$wlv_indicator_surplus_value_empe_p_r_pc_spec()
  )
  for (spec in cases) {
    output <- sub("^indicator[.]", "", spec$id)
    targets <- wlv_test_native_anomaly_targets(runtime, spec)
    expect_identical(targets$artifact, c(
      "sea_countries", "sea_countries", "sea_countries", "sea_sectors"
    ))
    expect_identical(targets$indicator, c(
      output,
      paste0(output, ".denominator"),
      paste0(output, ".numerator"),
      output
    ))
    expect_identical(targets$stage, rep(5L, 4L))
    expect_identical(targets$module, rep(spec$id, 4L))
    expect_identical(targets$producer_id, rep(spec$id, 4L))
    expect_identical(targets$action, rep("replace", 4L))
  }

  independent <- runtime$wlv_indicator_abstract_labour_empe_m_mv_spec()
  independent_targets <- wlv_test_native_anomaly_targets(runtime, independent)
  expect_false(any(grepl(
    "[.](numerator|denominator)$",
    independent_targets$indicator
  )))
})

test_that("stage-four go-price normalization preserves its exact owner", {
  runtime <- wlv_test_load_runtime()
  spec <- runtime$wlv_indicator_price_index_normalize_spec()
  go_price <- wlv_test_native_anomaly_targets(
    runtime,
    spec,
    args = list(
      indicator = "go_price.r.id",
      predecessor = "indicator.go_price.r.id"
    ),
    instance_id = "normalize.indicator.go_price.r.id"
  )
  expect_identical(nrow(go_price), 3L)
  expect_identical(go_price$artifact, rep("sea_sectors", 3L))
  expect_setequal(go_price$indicator, c(
    "go_price.r.id",
    "go_price.r.id.numerator",
    "go_price.r.id.denominator"
  ))
  expect_identical(go_price$stage, rep(4L, 3L))
  expect_identical(
    go_price$module,
    rep("indicator.price_index.normalize", 3L)
  )
  expect_identical(
    go_price$producer_id,
    rep("indicator.price_index.normalize", 3L)
  )
  expect_identical(go_price$action, rep("preserve", 3L))

  basket_price <- wlv_test_native_anomaly_targets(
    runtime,
    spec,
    args = list(
      indicator = "basket_price.r.pc",
      predecessor = "indicator.basket_price.r.pc"
    ),
    instance_id = "normalize.indicator.basket_price.r.pc"
  )
  expect_identical(nrow(basket_price), 1L)
  expect_identical(basket_price$indicator, "basket_price.r.pc")
  expect_identical(basket_price$action, "replace")
})

test_that("matrix anomaly targets separate native producers from public labels", {
  runtime <- wlv_test_load_runtime()
  transformation <- wlv_test_native_anomaly_targets(
    runtime,
    runtime$wlv_matrix_transformation_spec(),
    instance_id = "matrix.transformation.2000-2000"
  )
  leontief <- transformation[
    transformation$indicator == "leontief_input_ratio",
    ,
    drop = FALSE
  ]
  expect_identical(leontief$artifact, "m_io")
  expect_identical(leontief$module, "transformation.R")
  expect_identical(leontief$producer_id, "matrix.transformation")

  capital <- wlv_test_native_anomaly_targets(
    runtime,
    runtime$wlv_matrix_capital_wiodr13_spec(),
    instance_id = "matrix.capital.2000-2000"
  )
  expect_true(all(capital$artifact == "m_io"))
  expect_true(all(capital$module == "wiodr13/euklems.R"))
  expect_true(all(capital$producer_id == "matrix.capital.wiodr13"))
})
