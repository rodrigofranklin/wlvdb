semantic_resource_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "module_runtime.R"),
  envir = semantic_resource_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "semantic_resources.R"),
  envir = semantic_resource_environment
)
sys.source(
  file.path(wlv_test_root, "R", "modules", "native", "contracts.R"),
  envir = semantic_resource_environment
)

wlv_semantic_test_value <- function() {
  array(
    c(1, NA_real_, NA_real_, 4),
    dim = c(2L, 2L),
    dimnames = list(
      year = c("2001", "2000"),
      country = c("B", "A")
    )
  )
}

wlv_semantic_test_states <- function(value = wlv_semantic_test_value()) {
  result <- array(
    "finite",
    dim = dim(value),
    dimnames = dimnames(value)
  )
  result["2000", "B"] <- "source_missing"
  result["2001", "A"] <- "not_applicable"
  result["2001", "B"] <- "uncomputed"
  result
}

wlv_semantic_test_anomalies <- function(years = c("2001", "2000")) {
  data.frame(
    artifact = rep("sea_sectors", length(years)),
    indicator = rep("test.indicator", length(years)),
    checkpoint = rep("after_stage_1", length(years)),
    stage = rep("1", length(years)),
    module = rep("test.module", length(years)),
    year = years,
    country = rep("ROW", length(years)),
    sector = rep("S1", length(years)),
    output = rep(NA_character_, length(years)),
    original_value = rep("NA", length(years)),
    policy_id = rep("test.policy", length(years)),
    action = rep("persist_state", length(years)),
    stringsAsFactors = FALSE
  )
}

test_that("semantic resource definitions have function-only top-level RHS", {
  path <- file.path(wlv_test_root, "R", "lib", "semantic_resources.R")
  expressions <- parse(path, keep.source = FALSE)
  is_function_definition <- vapply(expressions, function(expression) {
    is.call(expression) && identical(expression[[1L]], as.name("<-")) &&
      length(expression) == 3L && is.call(expression[[3L]]) &&
      identical(expression[[3L]][[1L]], as.name("function"))
  }, logical(1L))
  expect_true(all(is_function_definition))
})

test_that("stateful keys use a closed allowlist and parallel state key", {
  semantic <- semantic_resource_environment
  expect_true(semantic$wlv_semantic_is_stateful_key("source/sea"))
  expect_true(semantic$wlv_semantic_is_stateful_key("io/values"))
  expect_true(semantic$wlv_semantic_is_stateful_key("sea/sector/test.indicator"))
  expect_false(semantic$wlv_semantic_is_stateful_key("metadata/indicators"))
  expect_false(semantic$wlv_semantic_is_stateful_key("sea/sector/a/b"))
  expect_identical(
    semantic$wlv_semantic_state_key("sea/sector/test.indicator"),
    "semantic_state/sea/sector/test.indicator"
  )
  expect_identical(
    semantic$wlv_semantic_state_target_key(
      "semantic_state/sea/sector/test.indicator"
    ),
    "sea/sector/test.indicator"
  )
  expect_error(
    semantic$wlv_semantic_state_key("metadata/indicators"),
    "not stateful",
    class = "wlv_semantic_resource_error"
  )
})

test_that("sparse state codec is canonical and preserves finite-cell states", {
  semantic <- semantic_resource_environment
  value <- wlv_semantic_test_value()
  states <- wlv_semantic_test_states(value)
  resource <- semantic$wlv_semantic_state_encode(
    value,
    states,
    "sea/sector/test.indicator",
    c("year", "country")
  )

  expect_s3_class(resource, "wlv_semantic_state")
  expect_identical(
    names(attributes(resource)),
    c("names", "class", "row.names", "target_key", "axes", "version")
  )
  expect_identical(names(resource), c("year", "country", "state"))
  expect_identical(resource$year, c("2000", "2001", "2001"))
  expect_identical(resource$country, c("B", "A", "B"))
  expect_identical(
    resource$state,
    c("source_missing", "not_applicable", "uncomputed")
  )
  expect_identical(
    attr(resource, "target_key", exact = TRUE),
    "sea/sector/test.indicator"
  )
  expect_identical(
    attr(resource, "axes", exact = TRUE),
    c("year", "country")
  )
  expect_identical(
    attr(resource, "version", exact = TRUE),
    semantic$wlv_semantic_state_version()
  )
  expect_invisible(semantic$wlv_semantic_state_validate(
    resource,
    value,
    target_key = "sea/sector/test.indicator",
    axes = c("year", "country"),
    state_key = "semantic_state/sea/sector/test.indicator"
  ))
  expect_identical(
    semantic$wlv_semantic_state_expand(resource, value),
    states
  )
})

test_that("state validation is fail-closed for values, coverage and metadata", {
  semantic <- semantic_resource_environment
  value <- wlv_semantic_test_value()
  states <- wlv_semantic_test_states(value)
  resource <- semantic$wlv_semantic_state_encode(
    value,
    states,
    "sea/sector/test.indicator",
    c("year", "country")
  )

  incomplete <- states
  incomplete["2000", "B"] <- "finite"
  expect_error(
    semantic$wlv_semantic_state_encode(
      value,
      incomplete,
      "sea/sector/test.indicator",
      c("year", "country")
    ),
    "Every ordinary NA"
  )

  duplicate <- resource
  duplicate$year[[2L]] <- duplicate$year[[1L]]
  duplicate$country[[2L]] <- duplicate$country[[1L]]
  expect_error(
    semantic$wlv_semantic_state_validate(duplicate),
    "duplicate coordinates"
  )

  unordered <- resource[c(3L, 2L, 1L), , drop = FALSE]
  expect_error(
    semantic$wlv_semantic_state_validate(unordered),
    "canonical order"
  )

  unknown <- resource
  unknown$country[[1L]] <- "UNKNOWN"
  expect_error(
    semantic$wlv_semantic_state_validate(unknown, value),
    "unknown coordinates"
  )

  wrong_target <- resource
  attr(wrong_target, "target_key") <- "sea/country/test.indicator"
  expect_error(
    semantic$wlv_semantic_state_validate(
      wrong_target,
      target_key = "sea/sector/test.indicator"
    ),
    "target_key"
  )

  extra_attribute <- resource
  attr(extra_attribute, "unexpected") <- TRUE
  expect_error(
    semantic$wlv_semantic_state_validate(extra_attribute),
    "metadata attributes"
  )

  nan_value <- value
  nan_value[[1L]] <- NaN
  expect_error(
    semantic$wlv_semantic_assert_value(nan_value, c("year", "country")),
    "NaN"
  )
  infinite_value <- value
  infinite_value[[1L]] <- Inf
  expect_error(
    semantic$wlv_semantic_assert_value(infinite_value, c("year", "country")),
    "infinite"
  )
})

test_that("capture reads only a local runtime and strips transient attributes", {
  semantic <- semantic_resource_environment
  value <- wlv_semantic_test_value()
  states <- wlv_semantic_test_states(value)
  attr(value, "wlv_actions") <- wlv_semantic_test_anomalies("2000")

  runtime <- new.env(parent = emptyenv())
  runtime$states <- new.env(parent = emptyenv())
  legacy_key <- paste("sea_sectors", "test.indicator", sep = "\034")
  assign(legacy_key, states, envir = runtime$states)
  bundle <- semantic$wlv_semantic_capture_value_state(
    value,
    "sea/sector/test.indicator",
    c("year", "country"),
    runtime = runtime
  )

  expect_s3_class(bundle, "wlv_value_state_bundle")
  expect_null(attr(bundle$value, "wlv_actions", exact = TRUE))
  expect_identical(
    semantic$wlv_semantic_state_expand(bundle$state, bundle$value),
    states
  )
  expect_identical(get(legacy_key, envir = runtime$states), states)

  missing_without_state <- value
  attr(missing_without_state, "wlv_actions") <- NULL
  expect_error(
    semantic$wlv_semantic_capture_value_state(
      missing_without_state,
      "sea/sector/test.indicator",
      c("year", "country")
    ),
    "Every ordinary NA"
  )
})

test_that("source rules distinguish source missingness and structural IO cells", {
  semantic <- semantic_resource_environment
  sea <- array(
    c(NA_real_, 1),
    dim = c(1L, 1L, 1L, 2L),
    dimnames = list(
      year = "2000",
      variable = "EMP",
      sector = "S1",
      country = c("ROW", "AAA")
    )
  )
  sea_bundle <- semantic$wlv_semantic_capture_value_state(
    sea,
    "source/sea",
    c("year", "variable", "sector", "country")
  )
  expect_identical(sea_bundle$state$state, "source_missing")

  source_io <- array(
    c(1, NA_real_, NA_real_, NA_real_),
    dim = c(1L, 2L, 2L),
    dimnames = list(
      year = "2000",
      input = c("I1", "I2"),
      output = c("I1", "FD")
    )
  )
  io_bundle <- semantic$wlv_semantic_capture_value_state(
    source_io,
    "source/io",
    c("year", "input", "output")
  )
  expanded <- semantic$wlv_semantic_state_expand(io_bundle$state, source_io)
  expect_identical(expanded["2000", "I2", "I1"], "source_missing")
  expect_identical(expanded["2000", "I1", "FD"], "not_applicable")
  expect_identical(expanded["2000", "I2", "FD"], "not_applicable")
})

test_that("hydration and partition merge are deterministic", {
  semantic <- semantic_resource_environment
  make_partition <- function(year, state) {
    value <- array(
      NA_real_,
      dim = c(1L, 1L),
      dimnames = list(year = year, country = "ROW")
    )
    states <- array(
      state,
      dim = dim(value),
      dimnames = dimnames(value)
    )
    list(
      value = value,
      state = semantic$wlv_semantic_state_encode(
        value,
        states,
        "sea/country/test.indicator",
        c("year", "country")
      )
    )
  }
  p1 <- make_partition("2000", "source_missing")
  p2 <- make_partition("2001", "not_applicable")

  merged <- semantic$wlv_semantic_state_merge(
    resources = list(p2 = p2$state, p1 = p1$state),
    values = list(p2 = p2$value, p1 = p1$value),
    partition_axis = "year"
  )
  reversed <- semantic$wlv_semantic_state_merge(
    resources = list(p1 = p1$state, p2 = p2$state),
    values = list(p1 = p1$value, p2 = p2$value),
    partition_axis = "year"
  )
  expect_identical(merged, reversed)
  expect_identical(merged$year, c("2000", "2001"))

  hydrated <- semantic$wlv_semantic_hydrate_states(
    resources = stats::setNames(
      list(p1$state),
      "semantic_state/sea/country/test.indicator"
    ),
    values = stats::setNames(
      list(p1$value),
      "sea/country/test.indicator"
    )
  )
  expect_identical(
    hydrated[["sea/country/test.indicator"]],
    semantic$wlv_semantic_state_expand(p1$state, p1$value)
  )

  expect_error(
    semantic$wlv_semantic_state_merge(
      resources = list(p1 = p1$state, p2 = p1$state)
    ),
    "duplicate coordinates"
  )
  expect_error(
    semantic$wlv_semantic_state_merge(
      resources = list(p1 = p1$state, p2 = p2$state),
      partition_axis = "year",
      partition_labels = list(p1 = "1999", p2 = "2001")
    ),
    "outside its labels"
  )
})

test_that("anomaly resources retain the exact 12-column schema", {
  semantic <- semantic_resource_environment
  resource <- semantic$wlv_semantic_new_anomaly_resource(
    wlv_semantic_test_anomalies(),
    producer_id = "native.producer"
  )
  expect_s3_class(resource, "wlv_anomaly_resource")
  expect_identical(names(resource), semantic$wlv_semantic_anomaly_columns())
  expect_length(names(resource), 12L)
  expect_identical(resource$year, c("2001", "2000"))
  expect_invisible(semantic$wlv_semantic_anomaly_validate(
    resource,
    producer_id = "native.producer"
  ))

  first <- semantic$wlv_semantic_new_anomaly_resource(
    wlv_semantic_test_anomalies(c("2001", "2001")),
    producer_id = "first.producer"
  )
  second_rows <- wlv_semantic_test_anomalies("2000")
  second_rows$module <- "second.module"
  second <- semantic$wlv_semantic_new_anomaly_resource(
    second_rows,
    producer_id = "second.producer"
  )
  merged <- semantic$wlv_semantic_anomaly_merge(list(A = first, B = second))
  expect_identical(merged$year, c("2001", "2001", "2000"))
  expect_identical(
    merged$module,
    c("test.module", "test.module", "second.module")
  )
})

test_that("anomaly emissions bind producer, partition, and scientific tuple", {
  semantic <- semantic_resource_environment
  anomaly_contract <- semantic$wlv_resource_contract(
    scope = "io_period",
    value_type = "data.frame",
    role = "anomaly"
  )
  output <- semantic$wlv_resource_output(semantic$wlv_resource_ref(
    "anomaly/matrix.transformation",
    anomaly_contract
  ))
  attr(output, "wlv_native_anomaly_targets") <-
    semantic$wlv_native_anomaly_target_contract(
      list(semantic$wlv_native_anomaly_binding(
        "m_io",
        "leontief_input_ratio",
        record_module = "transformation.R"
      )),
      checkpoint = 3L,
      module_id = "matrix.transformation"
    )
  rows <- wlv_semantic_test_anomalies("2000")
  rows$artifact <- "m_io"
  rows$indicator <- "leontief_input_ratio"
  rows$checkpoint <- "after_matrices"
  rows$stage <- "3"
  rows$module <- "transformation.R"
  resource <- semantic$wlv_semantic_new_anomaly_resource(
    rows,
    producer_id = "matrix.transformation",
    partition = "2000-2000"
  )
  expect_invisible(semantic$wlv_semantic_validate_anomaly_emission(
    resource,
    output,
    producer_id = "matrix.transformation",
    partition = "2000-2000",
    checkpoint = 3L
  ))

  wrong_producer <- semantic$wlv_semantic_new_anomaly_resource(
    rows,
    producer_id = "matrix.foreign",
    partition = "2000-2000"
  )
  expect_error(
    semantic$wlv_semantic_validate_anomaly_emission(
      wrong_producer,
      output,
      producer_id = "matrix.transformation",
      partition = "2000-2000",
      checkpoint = 3L
    ),
    "producer_id does not match"
  )
  expect_error(
    semantic$wlv_semantic_validate_anomaly_emission(
      resource,
      output,
      producer_id = "matrix.transformation",
      partition = "2001-2001",
      checkpoint = 3L
    ),
    "partition does not match"
  )

  mutations <- list(
    artifact = "sea_sectors",
    indicator = "foreign_indicator",
    stage = "4",
    module = "foreign.R"
  )
  for (field in names(mutations)) {
    foreign_rows <- rows
    foreign_rows[[field]] <- mutations[[field]]
    foreign <- semantic$wlv_semantic_new_anomaly_resource(
      foreign_rows,
      producer_id = "matrix.transformation",
      partition = "2000-2000"
    )
    expect_error(
      semantic$wlv_semantic_validate_anomaly_emission(
        foreign,
        output,
        producer_id = "matrix.transformation",
        partition = "2000-2000",
        checkpoint = 3L
      ),
      "is not declared by producer"
    )
  }
})

test_that("diagnostic bundles are named, detached and reference-free", {
  semantic <- semantic_resource_environment
  diagnostic <- data.frame(metric = "condition", value = "1", stringsAsFactors = FALSE)
  bundle <- semantic$wlv_semantic_diagnostic_bundle(list(
    zeta = diagnostic,
    alpha = list(count = 1L)
  ))
  diagnostic$value[[1L]] <- "changed"

  expect_s3_class(bundle, "wlv_diagnostic_bundle")
  expect_identical(names(bundle), c("alpha", "zeta"))
  expect_identical(bundle$zeta$value, "1")
  expect_invisible(semantic$wlv_semantic_diagnostic_bundle_validate(bundle))
  expect_error(
    semantic$wlv_semantic_diagnostic_bundle(list(reference = new.env())),
    "mutable references"
  )
  expect_error(
    semantic$wlv_semantic_diagnostic_bundle(list(callback = function() TRUE)),
    "mutable references"
  )
})

test_that("module runtime hydrates state aliases and finalizer materializes bundles", {
  semantic <- semantic_resource_environment
  runtime_api <- semantic_resource_environment
  value <- wlv_semantic_test_value()
  states <- wlv_semantic_test_states(value)
  state <- semantic$wlv_semantic_state_encode(
    value,
    states,
    "sea/sector/test.indicator",
    c("year", "country")
  )
  value_contract <- runtime_api$wlv_resource_contract(
    scope = "run",
    axes = c("year", "country"),
    value_type = "array",
    role = "value",
    semantic_state = TRUE
  )
  state_contract <- runtime_api$wlv_resource_contract(
    scope = "run",
    value_type = "data.frame",
    role = "semantic_state"
  )
  anomaly_contract <- runtime_api$wlv_resource_contract(
    scope = "run",
    value_type = "data.frame",
    role = "anomaly"
  )
  diagnostic_contract <- runtime_api$wlv_resource_contract(
    scope = "run",
    value_type = "list",
    role = "diagnostic"
  )
  target_ref <- runtime_api$wlv_resource_ref(
    "sea/sector/test.indicator",
    value_contract,
    producer = runtime_api$wlv_runtime_seed_producer()
  )
  state_ref <- runtime_api$wlv_resource_ref(
    "semantic_state/sea/sector/test.indicator",
    state_contract,
    producer = runtime_api$wlv_runtime_seed_producer()
  )
  module <- list(
    module_id = "test.module",
    instance_id = "test.module.instance",
    partition = NULL,
    requires = list(value_input = target_ref, state_input = state_ref),
    provides = list(
      value = runtime_api$wlv_resource_output(runtime_api$wlv_resource_ref(
        "sea/sector/test.indicator",
        value_contract
      )),
      state = runtime_api$wlv_resource_output(runtime_api$wlv_resource_ref(
        "semantic_state/sea/sector/test.indicator",
        state_contract
      )),
      anomaly = runtime_api$wlv_resource_output(runtime_api$wlv_resource_ref(
        "anomaly/test.module",
        anomaly_contract
      )),
      diagnostic = runtime_api$wlv_resource_output(runtime_api$wlv_resource_ref(
        "diagnostic/test.module",
        diagnostic_contract
      ))
    )
  )
  attr(
    module$provides$anomaly,
    "wlv_native_anomaly_targets"
  ) <- semantic$wlv_native_anomaly_target_contract(
    list(semantic$wlv_native_anomaly_binding(
      "sea_sectors",
      "test.indicator"
    )),
    checkpoint = 1L,
    module_id = "test.module"
  )
  local_runtime <- semantic$wlv_semantic_module_runtime(
    list(value_input = value, state_input = state),
    module
  )
  local_runtime$anomalies <- wlv_semantic_test_anomalies("2000")
  result <- runtime_api$wlv_module_result(
    outputs = list(value = value),
    diagnostics = list(leontief = data.frame(
      metric = "rank",
      value = "2",
      stringsAsFactors = FALSE
    ))
  )
  finalized <- semantic$wlv_semantic_finalize_module_result(
    module,
    result,
    local_runtime,
    list(value_input = value, state_input = state),
    store = NULL
  )

  expect_identical(
    names(finalized$outputs),
    c("value", "state", "anomaly", "diagnostic")
  )
  expect_identical(
    semantic$wlv_semantic_state_expand(finalized$outputs$state, value),
    states
  )
  expect_s3_class(finalized$outputs$anomaly, "wlv_anomaly_resource")
  expect_s3_class(finalized$outputs$diagnostic, "wlv_diagnostic_bundle")
  expect_identical(names(finalized$outputs$diagnostic), "leontief")
  expect_identical(finalized$diagnostics, list())
})
