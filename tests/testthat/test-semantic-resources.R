semantic_resource_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "scripts", "lib", "module_runtime.R"),
  envir = semantic_resource_environment
)
sys.source(
  file.path(wlv_test_root, "scripts", "lib", "semantic_resources.R"),
  envir = semantic_resource_environment
)
sys.source(
  file.path(wlv_test_root, "scripts", "modules", "native", "contracts.R"),
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
  path <- file.path(wlv_test_root, "scripts", "lib", "semantic_resources.R")
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
  row.names(unordered) <- NULL
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

  custom_row_names <- resource
  row.names(custom_row_names) <- paste0("custom-", seq_len(nrow(resource)))
  expect_error(
    semantic$wlv_semantic_state_validate(custom_row_names),
    "row names are not canonical"
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

test_that("capture validates canonical sparse state without dense hydration", {
  semantic <- semantic_resource_environment
  value <- wlv_semantic_test_value()
  states <- wlv_semantic_test_states(value)
  resource <- semantic$wlv_semantic_state_encode(
    value,
    states,
    "sea/sector/test.indicator",
    c("year", "country")
  )

  bundle <- semantic$wlv_semantic_capture_value_state(
    value,
    "sea/sector/test.indicator",
    c("year", "country"),
    states = resource
  )
  expect_identical(bundle$value, value)
  expect_identical(bundle$state, resource)
  if (isTRUE(capabilities("profmem"))) {
    expect_identical(tracemem(bundle$value), tracemem(value))
    expect_identical(tracemem(bundle$state), tracemem(resource))
    untracemem(bundle$value)
    untracemem(value)
    untracemem(bundle$state)
    untracemem(resource)
  }

  changed <- bundle$value
  changed[[1L]] <- 99
  expect_false(identical(changed, value))
  expect_identical(value, wlv_semantic_test_value())

  wrong_target <- resource
  attr(wrong_target, "target_key") <- "sea/country/test.indicator"
  expect_error(
    semantic$wlv_semantic_capture_value_state(
      value,
      "sea/sector/test.indicator",
      c("year", "country"),
      states = wrong_target
    ),
    "target_key"
  )
  expect_error(
    semantic$wlv_semantic_capture_value_state(
      value,
      "sea/sector/test.indicator",
      c("year", "country"),
      states = resource,
      source_rule = list(default = "source_missing", structural = NULL)
    ),
    "Source-state rules can only be used for source resources"
  )
})

test_that("explicit semantic-input runtime validates without retaining dense states", {
  semantic <- semantic_resource_environment
  value <- wlv_semantic_test_value()
  state <- semantic$wlv_semantic_state_encode(
    value,
    wlv_semantic_test_states(value),
    "sea/sector/test.indicator",
    c("year", "country")
  )
  value_contract <- semantic$wlv_resource_contract(
    axes = c("year", "country"),
    value_type = "array",
    unit = "test_unit_v1",
    missingness = "typed_v1",
    semantic_state = TRUE
  )
  state_contract <- semantic$wlv_resource_contract(
    value_type = "data.frame",
    unit = "semantic_state:test_unit_v1",
    missingness = "semantic_state_v1",
    role = "semantic_state"
  )
  module <- list(
    module_id = "test.explicit",
    instance_id = "test.explicit",
    partition = NULL,
    requires = list(
      value = semantic$wlv_resource_ref(
        "sea/sector/test.indicator",
        value_contract
      ),
      state = semantic$wlv_resource_ref(
        "semantic_state/sea/sector/test.indicator",
        state_contract
      )
    ),
    provides = list()
  )
  local_runtime <- semantic$wlv_semantic_module_runtime(
    list(value = value, state = state),
    module,
    semantic_input_mode = "explicit"
  )

  expect_identical(local_runtime$semantic_input_mode, "explicit")
  expect_length(local_runtime$semantic_states, 0L)
  expect_identical(ls(local_runtime$states, all.names = TRUE), character())

  invalid_state <- state
  invalid_state$country[[1L]] <- "UNKNOWN"
  expect_error(
    semantic$wlv_semantic_module_runtime(
      list(value = value, state = invalid_state),
      module,
      semantic_input_mode = "explicit"
    ),
    "unknown coordinates"
  )
})

test_that("hydrated module states use copy-on-write isolation", {
  semantic <- semantic_resource_environment
  target_key <- "sea/sector/test.indicator"
  value <- wlv_semantic_test_value()
  states <- wlv_semantic_test_states(value)
  state <- semantic$wlv_semantic_state_encode(
    value,
    states,
    target_key,
    c("year", "country")
  )
  value_contract <- semantic$wlv_resource_contract(
    axes = c("year", "country"),
    value_type = "array",
    semantic_state = TRUE
  )
  state_contract <- semantic$wlv_resource_contract(
    value_type = "data.frame",
    role = "semantic_state"
  )
  module <- list(
    module_id = "test.copy.on.write",
    instance_id = "test.copy.on.write",
    partition = NULL,
    requires = list(
      value = semantic$wlv_resource_ref(target_key, value_contract),
      state = semantic$wlv_resource_ref(
        semantic$wlv_semantic_state_key(target_key),
        state_contract
      )
    ),
    provides = list()
  )
  local_runtime <- semantic$wlv_semantic_module_runtime(
    list(value = value, state = state),
    module
  )
  expected <- semantic$wlv_semantic_detach(
    local_runtime$semantic_states[[target_key]]
  )
  input_snapshot <- semantic$wlv_semantic_detach(value)
  legacy_key <- semantic$wlv_semantic_legacy_runtime_state_key(target_key)
  expect_identical(
    get(legacy_key, envir = local_runtime$states, inherits = FALSE),
    expected
  )

  semantic_changed <- local_runtime$semantic_states[[target_key]]
  semantic_changed[[1L]] <- "not_applicable"
  dimnames(semantic_changed)[[1L]][[1L]] <- "semantic-changed"
  local_runtime$semantic_states[[target_key]] <- semantic_changed
  expect_identical(
    get(legacy_key, envir = local_runtime$states, inherits = FALSE),
    expected
  )
  expect_identical(value, input_snapshot)

  local_runtime$semantic_states[[target_key]] <-
    semantic$wlv_semantic_detach(expected)
  registered <- get(legacy_key, envir = local_runtime$states, inherits = FALSE)
  registered[[1L]] <- "source_missing"
  dimnames(registered)[[1L]][[1L]] <- "legacy-changed"
  assign(legacy_key, registered, envir = local_runtime$states)
  expect_identical(local_runtime$semantic_states[[target_key]], expected)
  expect_identical(value, input_snapshot)

  returned <- semantic$wlv_semantic_runtime_state(local_runtime, target_key)
  returned[[1L]] <- "finite"
  dimnames(returned)[[1L]][[1L]] <- "returned-changed"
  expect_identical(local_runtime$semantic_states[[target_key]], expected)

  legacy_runtime <- list(
    semantic_states = stats::setNames(list(), character()),
    states = local_runtime$states
  )
  legacy_expected <- semantic$wlv_semantic_detach(get(
    legacy_key,
    envir = local_runtime$states,
    inherits = FALSE
  ))
  legacy <- semantic$wlv_semantic_runtime_state(legacy_runtime, target_key)
  legacy[[1L]] <- "not_applicable"
  dimnames(legacy)[[1L]][[1L]] <- "legacy-returned-changed"
  expect_identical(
    get(legacy_key, envir = local_runtime$states, inherits = FALSE),
    legacy_expected
  )
  expect_error(
    semantic$wlv_semantic_share_copy_on_write(list(reference = new.env())),
    "mutable references"
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

test_that("intrinsic finalizers expose only declared immutable resources", {
  runtime <- semantic_resource_environment
  scalar <- runtime$wlv_resource_contract(
    scope = "run",
    axes = character(),
    value_type = "double",
    unit = "test_unit_v1",
    missingness = "strict_v1"
  )
  seed_ref <- runtime$wlv_resource_ref(
    "input/value",
    scalar,
    producer = runtime$wlv_runtime_seed_producer()
  )
  mutation_rejected <- FALSE
  exposed_locators <- character()
  finalizer_environment_names <- character()
  finalizer_parent_is_empty <- FALSE
  complete_store_reachable <- TRUE
  spec <- runtime$wlv_module_spec(
    id = "sealed.finalizer",
    checkpoint = 1L,
    services = runtime$wlv_runtime_intrinsic_service_names(),
    requires = list(input = seed_ref),
    provides = list(output = runtime$wlv_resource_output(
      runtime$wlv_resource_ref("output/value", scalar)
    )),
    run = function(ctx) {
      finalizer <- ctx$service("module_contract")
      get_environment <- methods::getFunction("environment")
      get_parent <- methods::getFunction("parent.env")
      finalizer_environment <- get_environment(finalizer)
      finalizer_environment_names <<- ls(
        finalizer_environment,
        all.names = TRUE
      )
      finalizer_parent_is_empty <<- identical(
        get_parent(finalizer_environment),
        emptyenv()
      )
      complete_store_reachable <<- exists(
        "store",
        envir = finalizer_environment,
        inherits = TRUE
      )
      leaked <- finalizer_environment$input_store
      exposed_locators <<- names(leaked$entries)
      locator_id <- names(leaked$entries)[[1L]]
      mutation <- try(
        leaked$entries[[locator_id]]$value <- 99,
        silent = TRUE
      )
      mutation_rejected <<- inherits(mutation, "try-error")
      finalizer(runtime$wlv_module_result(list(
        output = ctx$input("input") + 1
      )))
    }
  )
  store <- runtime$wlv_new_resource_store(list(
    runtime$wlv_seed_resource("input/value", 1, scalar),
    runtime$wlv_seed_resource("secret/undeclared", 41, scalar)
  ))
  plan <- runtime$wlv_compile_module_plan(
    runtime$wlv_module_registry(list(spec)),
    list(runtime$wlv_module_instance("sealed.finalizer", "sealed.finalizer")),
    store
  )
  result <- runtime$wlv_run_module_plan(
    plan,
    store,
    retain_history = TRUE
  )

  expect_true(mutation_rejected)
  expect_true(finalizer_parent_is_empty)
  expect_false(complete_store_reachable)
  expect_setequal(
    finalizer_environment_names,
    c(
      "input_store", "module_inputs", "module_runtime", "resolved_module",
      "wlv_semantic_finalize_module_result"
    )
  )
  expect_identical(
    exposed_locators,
    runtime$wlv_runtime_locator_id(
      "input/value",
      NULL,
      runtime$wlv_runtime_seed_producer()
    )
  )
  expect_false(any(grepl("secret/undeclared", exposed_locators, fixed = TRUE)))
  expect_identical(runtime$wlv_store_read(result$store, seed_ref), 1)
  expect_identical(
    runtime$wlv_store_read(
      result$store,
      runtime$wlv_resource_ref("output/value", scalar)
    ),
    2
  )
})
