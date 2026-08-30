test_that("matrix assembler preserves buffered semantics while streaming resources", {
  runtime <- wlv_test_load_runtime()
  expect_identical(
    attr(
      runtime$wlv_native_matrix_assembler_spec(),
      "wlv_semantic_input_mode",
      exact = TRUE
    ),
    "explicit"
  )
  years <- c("2000", "2001", "2002")
  inputs <- c("I2", "I1")
  outputs <- c("O1", "O2")
  countries <- c("BB", "AA")

  make_array <- function(offset, labels) {
    dimensions <- vapply(labels, length, integer(1L))
    array(
      as.double(offset + seq_len(prod(dimensions))),
      dim = dimensions,
      dimnames = labels
    )
  }
  split_periods <- function(value) {
    list(
      late = value["2002", , , drop = FALSE],
      early = value[c("2000", "2001"), , , drop = FALSE]
    )
  }

  io_zeta <- make_array(100, list(
    year = years,
    input = inputs,
    output = outputs
  ))
  io_alpha <- make_array(200, list(
    year = years,
    input = inputs,
    output = outputs
  ))
  country_beta <- make_array(300, list(
    year = years,
    origin = countries,
    destination = countries
  ))
  country_omega <- make_array(400, list(
    year = years,
    origin = countries,
    destination = countries
  ))
  io_zeta["2000", "I2", "O1"] <- NA_real_
  io_alpha["2001", "I1", "O2"] <- NA_real_
  country_beta["2002", "BB", "AA"] <- NA_real_
  country_omega["2000", "AA", "BB"] <- NA_real_
  module_inputs <- list(
    lists = list(
      years = years,
      input = inputs,
      output = outputs,
      countries = countries
    ),
    `io.k_composition` = split_periods(io_alpha),
    `io.values` = split_periods(io_zeta),
    `country.exports_mp` = split_periods(country_omega),
    `country.exports_values` = split_periods(country_beta)
  )
  state_partitions <- function(values, target_key) {
    lapply(values, function(value) {
      axes <- names(dimnames(value))
      states <- runtime$wlv_semantic_state_array(value, axes)
      states[is.na(value)] <- "source_missing"
      runtime$wlv_semantic_state_encode(
        value,
        states,
        target_key,
        axes
      )
    })
  }
  module_inputs[["semantic_state__io.k_composition"]] <- state_partitions(
    module_inputs[["io.k_composition"]],
    "io/k_composition"
  )
  module_inputs[["semantic_state__io.values"]] <- state_partitions(
    module_inputs[["io.values"]],
    "io/values"
  )
  module_inputs[["semantic_state__country.exports_mp"]] <- state_partitions(
    module_inputs[["country.exports_mp"]],
    "country_matrix/exports_mp"
  )
  module_inputs[["semantic_state__country.exports_values"]] <- state_partitions(
    module_inputs[["country.exports_values"]],
    "country_matrix/exports_values"
  )
  arguments <- list(
    io_resources = c("values", "k_composition"),
    country_resources = c("exports_values", "exports_mp")
  )
  make_context <- function(values) {
    runtime$wlv_runtime_context(
      inputs = values,
      input_names = names(values),
      args = arguments,
      argument_names = names(arguments),
      services = list(module_contract = function(value) value),
      service_names = "module_contract",
      partition = NULL,
      instance_id = "assembler.matrices.test"
    )
  }

  result <- runtime$wlv_native_matrix_assembler_spec()$run(
    make_context(module_inputs)
  )
  expected_io <- array(
    NA_real_,
    dim = c(length(years), 2L, length(inputs), length(outputs)),
    dimnames = list(
      year = years,
      variable = c("values", "k_composition"),
      input = inputs,
      output = outputs
    )
  )
  expected_io[, "values", , ] <- io_zeta
  expected_io[, "k_composition", , ] <- io_alpha
  expected_countries <- array(
    NA_real_,
    dim = c(length(years), 2L, length(countries), length(countries)),
    dimnames = list(
      year = years,
      variable = c("exports_values", "exports_mp"),
      origin = countries,
      destination = countries
    )
  )
  expected_countries[, "exports_values", , ] <- country_beta
  expected_countries[, "exports_mp", , ] <- country_omega

  expect_s3_class(result, "wlv_module_result")
  expect_identical(result$outputs$m_io, expected_io)
  expect_identical(result$outputs$m_countries, expected_countries)
  expanded_io_state <- runtime$wlv_semantic_state_expand(
    result$outputs$semantic_state__m_io,
    result$outputs$m_io
  )
  expected_io_state <- runtime$wlv_semantic_state_array(
    expected_io,
    names(dimnames(expected_io))
  )
  expected_io_state[is.na(expected_io)] <- "source_missing"
  expect_identical(expanded_io_state, expected_io_state)
  expanded_country_state <- runtime$wlv_semantic_state_expand(
    result$outputs$semantic_state__m_countries,
    result$outputs$m_countries
  )
  expected_country_state <- runtime$wlv_semantic_state_array(
    expected_countries,
    names(dimnames(expected_countries))
  )
  expected_country_state[is.na(expected_countries)] <- "source_missing"
  expect_identical(expanded_country_state, expected_country_state)

  incomplete <- module_inputs
  incomplete[["io.values"]] <- list(
    early = io_zeta["2000", , , drop = FALSE],
    late = io_zeta["2002", , , drop = FALSE]
  )
  incomplete[["semantic_state__io.values"]] <- state_partitions(
    incomplete[["io.values"]],
    "io/values"
  )
  expect_error(
    runtime$wlv_native_matrix_assembler_spec()$run(make_context(incomplete)),
    "Assembler coverage for `io/values` is not exact .*missing=2001"
  )
})

test_that("partition collector reuses a canonical single partition", {
  runtime <- wlv_test_load_runtime()
  registry <- runtime$wlv_module_registry(list(
    runtime$wlv_native_matrix_assembler_spec()
  ))
  resolved <- runtime$wlv_runtime_resolve_instance(
    registry,
    runtime$wlv_module_instance(
      "assembler.matrices.test",
      "assembler.matrices",
      args = list(
        io_resources = list("values"),
        country_resources = list("exports_values")
      )
    ),
    operation = "calculate",
    partitions = "period"
  )
  expect_identical(resolved$semantic_input_mode, "explicit")
  value <- array(
    as.double(seq_len(12L)),
    dim = c(3L, 2L, 2L),
    dimnames = list(
      year = c("2000", "2001", "2002"),
      input = c("I1", "I2"),
      output = c("O1", "O2")
    )
  )

  observed <- runtime$wlv_native_collect_partitioned_resource(
    list(period = value),
    dimnames(value)$year,
    dimnames(value)[-1L],
    "io/values"
  )
  expect_identical(observed, value)
  if (isTRUE(capabilities("profmem"))) {
    expect_identical(tracemem(observed), tracemem(value))
    untracemem(observed)
    untracemem(value)
  }
  dense_state <- runtime$wlv_semantic_state_array(
    value,
    names(dimnames(value))
  )
  state <- runtime$wlv_semantic_state_encode(
    value,
    dense_state,
    "io/values",
    names(dimnames(value))
  )
  observed_state <- runtime$wlv_native_collect_partitioned_state(
    list(period = state),
    list(period = value),
    value
  )
  expect_identical(observed_state, state)
  if (isTRUE(capabilities("profmem"))) {
    expect_identical(tracemem(observed_state), tracemem(state))
    untracemem(observed_state)
    untracemem(state)
  }

  reversed <- value[c("2002", "2001", "2000"), , , drop = FALSE]
  reordered <- runtime$wlv_native_collect_partitioned_resource(
    list(period = reversed),
    dimnames(value)$year,
    dimnames(value)[-1L],
    "io/values"
  )
  expect_identical(as.vector(reordered), as.vector(value))
  expect_identical(unname(dim(reordered)), dim(value))
  expect_identical(dimnames(reordered), dimnames(value))
})

test_that("structural IO derivation publishes a first-class Cartesian codec", {
  runtime <- wlv_test_load_runtime()
  partition <- "2000-2001"
  axes <- c("year", "input", "output")
  source <- array(
    1,
    dim = c(2L, 2L, 3L),
    dimnames = list(
      year = c("2000", "2001"),
      input = c("AAA.S1", "BBB.S1"),
      output = c("AAA.S1", "BBB.S1", "FD")
    )
  )
  source_seeds <- runtime$wlv_native_stateful_seed_pair(
    runtime$wlv_seed_resource(
      "source/io",
      source,
      runtime$wlv_native_source_io_contract(),
      partition = partition
    )
  )
  expect_s3_class(source_seeds[[2L]]$value, "wlv_semantic_state")
  expect_identical(nrow(source_seeds[[2L]]$value), 0L)
  structural_source <- source
  structural_source[, , "FD"] <- NA_real_
  structural_state <- runtime$wlv_semantic_capture_value_state(
    structural_source,
    "source/io",
    axes
  )$state
  expect_s3_class(
    structural_state,
    "wlv_runtime_semantic_state_codec"
  )
  expect_identical(structural_state$state, "not_applicable")
  expect_identical(structural_state$row_count, 4)
  mixed_source <- structural_source
  mixed_source["2000", "AAA.S1", "AAA.S1"] <- NA_real_
  mixed_state <- runtime$wlv_semantic_capture_value_state(
    mixed_source,
    "source/io",
    axes
  )$state
  expect_s3_class(mixed_state, "wlv_semantic_state")
  expect_setequal(
    unique(mixed_state$state),
    c("source_missing", "not_applicable")
  )
  controls <- list(
    runtime$wlv_seed_resource(
      "request/method",
      "wiodr13",
      runtime$wlv_native_control_contract("character")
    ),
    runtime$wlv_seed_resource(
      "request/source",
      "wiodr13",
      runtime$wlv_native_control_contract("character")
    ),
    runtime$wlv_seed_resource(
      "configuration/missingness_policy",
      list(id = "test"),
      runtime$wlv_native_control_contract("list")
    ),
    runtime$wlv_seed_resource(
      "configuration/scientific_profile",
      list(id = "test"),
      runtime$wlv_native_control_contract("list")
    )
  )
  make_spec <- function(id, unresolved = FALSE) {
    runtime$wlv_native_module_spec(
      id = id,
      scope = "io_period",
      checkpoint = 3L,
      operations = "calculate",
      requires = runtime$wlv_native_source_io_ref(),
      provides = runtime$wlv_native_io_output("k_composition"),
      run = local({
        add_unresolved <- unresolved
        function(ctx) {
          value <- ctx$input("source_io")
          value[, , "FD"] <- NA_real_
          if (add_unresolved) {
            value["2000", "AAA.S1", "AAA.S1"] <- NA_real_
          }
          runtime$wlv_module_result(outputs = list(value = value))
        }
      })
    )
  }
  execute <- function(spec) {
    store <- runtime$wlv_new_resource_store(c(source_seeds, controls))
    instance <- runtime$wlv_module_instance(
      spec$id,
      spec$id,
      partition = partition
    )
    plan <- runtime$wlv_compile_module_plan(
      runtime$wlv_module_registry(list(spec)),
      list(instance),
      store,
      partitions = partition
    )
    runtime$wlv_run_module_plan(plan, store)
  }

  result <- execute(make_spec("test.structural.codec"))
  contract <- runtime$wlv_native_io_contract("k_composition")
  value <- runtime$wlv_store_read(
    result$store,
    runtime$wlv_resource_ref(
      "io/k_composition",
      contract,
      producer = "test.structural.codec",
      partition = partition
    )
  )
  state <- runtime$wlv_store_read(
    result$store,
    runtime$wlv_resource_ref(
      "semantic_state/io/k_composition",
      runtime$wlv_native_semantic_state_contract(contract),
      producer = "test.structural.codec",
      partition = partition
    )
  )
  expect_s3_class(state, "wlv_runtime_semantic_state_codec")
  expect_identical(state$encoding, "cartesian")
  expect_identical(state$row_count, 4)
  expect_identical(
    state$selectors,
    list(
      year = c("2000", "2001"),
      input = c("AAA.S1", "BBB.S1"),
      output = "FD"
    )
  )
  expect_identical(state$state, "not_applicable")
  expect_invisible(runtime$wlv_semantic_state_resource_validate(
    state,
    value,
    "io/k_composition",
    axes,
    "semantic_state/io/k_composition"
  ))
  expanded <- runtime$wlv_semantic_state_expand(state, value)
  expect_true(all(expanded[, , "FD"] == "not_applicable"))
  expect_true(all(expanded[, , c("AAA.S1", "BBB.S1")] == "finite"))

  expect_error(
    execute(make_spec("test.structural.unresolved", unresolved = TRUE)),
    "Declared input states do not cover 1 missing output cells"
  )
})

test_that("matrix state lifting combines codecs and preserves row fallback", {
  runtime <- wlv_test_load_runtime()
  axes <- c("year", "input", "output")
  selectors <- list(
    year = c("2000", "2001"),
    input = c("AAA.S1", "BBB.S1"),
    output = "FD"
  )
  codec <- function(key, state = "not_applicable") {
    runtime$wlv_runtime_snapshot_new_state_codec(
      encoding = "cartesian",
      target_key = key,
      axes = axes,
      state_version = runtime$wlv_semantic_state_version(),
      row_count = 4,
      selectors = selectors,
      state = state
    )
  }
  labels <- c(
    "k_composition", "k_depreciation", "values",
    "transfers_values", "consumption_basket"
  )
  resources <- list(
    codec("io/k_composition"),
    codec("io/k_depreciation"),
    runtime$wlv_semantic_empty_state("io/values", axes),
    runtime$wlv_semantic_empty_state("io/transfers_values", axes),
    codec("io/consumption_basket")
  )
  lifted <- runtime$wlv_native_lift_semantic_states(
    resources,
    labels,
    "variable",
    "artifact/m_io",
    c("year", "variable", "input", "output"),
    prefer_compact = TRUE
  )
  expect_s3_class(lifted, "wlv_runtime_semantic_state_codec")
  expect_identical(lifted$row_count, 12)
  expect_identical(
    lifted$selectors$variable,
    c("consumption_basket", "k_composition", "k_depreciation")
  )

  mixed <- resources
  mixed[[2L]] <- codec("io/k_depreciation", "source_missing")
  fallback <- runtime$wlv_native_lift_semantic_states(
    mixed,
    labels,
    "variable",
    "artifact/m_io",
    c("year", "variable", "input", "output"),
    prefer_compact = TRUE
  )
  expect_s3_class(fallback, "wlv_semantic_state")
  expect_identical(nrow(fallback), 12L)
  expect_setequal(
    unique(fallback$state),
    c("not_applicable", "source_missing")
  )
})
