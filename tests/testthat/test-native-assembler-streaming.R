test_that("matrix assembler preserves buffered semantics while streaming resources", {
  runtime <- wlv_test_load_runtime()
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
  io_alpha["2001", "I1", "O2"] <- NaN
  country_beta["2002", "BB", "AA"] <- Inf
  country_omega["2000", "AA", "BB"] <- -Inf
  module_inputs <- list(
    lists = list(
      years = years,
      input = inputs,
      output = outputs,
      countries = countries
    ),
    `io.alpha` = split_periods(io_alpha),
    `io.zeta` = split_periods(io_zeta),
    `country.omega` = split_periods(country_omega),
    `country.beta` = split_periods(country_beta)
  )
  arguments <- list(
    io_resources = c("zeta", "alpha"),
    country_resources = c("beta", "omega")
  )
  make_context <- function(values) {
    runtime$wlv_runtime_context(
      inputs = values,
      input_names = names(values),
      args = arguments,
      argument_names = names(arguments),
      services = list(),
      service_names = character(),
      partition = NULL,
      instance_id = "assembler.matrices.test"
    )
  }

  result <- runtime$wlv_native_matrix_assembler_spec$run(
    make_context(module_inputs)
  )
  expected_io <- array(
    NA_real_,
    dim = c(length(years), 2L, length(inputs), length(outputs)),
    dimnames = list(
      year = years,
      variable = c("zeta", "alpha"),
      input = inputs,
      output = outputs
    )
  )
  expected_io[, "zeta", , ] <- io_zeta
  expected_io[, "alpha", , ] <- io_alpha
  expected_countries <- array(
    NA_real_,
    dim = c(length(years), 2L, length(countries), length(countries)),
    dimnames = list(
      year = years,
      variable = c("beta", "omega"),
      origin = countries,
      destination = countries
    )
  )
  expected_countries[, "beta", , ] <- country_beta
  expected_countries[, "omega", , ] <- country_omega

  expect_s3_class(result, "wlv_module_result")
  expect_identical(result$outputs$m_io, expected_io)
  expect_identical(result$outputs$m_countries, expected_countries)

  incomplete <- module_inputs
  incomplete[["io.zeta"]] <- list(
    early = io_zeta["2000", , , drop = FALSE],
    late = io_zeta["2002", , , drop = FALSE]
  )
  expect_error(
    runtime$wlv_native_matrix_assembler_spec$run(make_context(incomplete)),
    "Assembler coverage for `io/zeta` is not exact .*missing=2001"
  )
})
