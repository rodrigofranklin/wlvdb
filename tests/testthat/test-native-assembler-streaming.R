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
