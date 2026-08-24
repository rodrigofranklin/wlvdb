scientific_validation_environment <- new.env(parent = globalenv())
for (script in c(
  "missingness.R", "gfcf_contracts.R", "gfcf_diagnostics.R",
  "leontief_diagnostics.R", "scientific_validation.R", "result_contracts.R"
)) {
  sys.source(
    file.path(wlv_test_root, "R", "lib", script),
    envir = scientific_validation_environment
  )
}

wlv_scientific_test_profile <- function(
    method = "demo",
    source = "demo",
    years = "2000",
    signed_counts = rep(0L, length(years))) {
  scientific_validation_environment$wlv_scientific_profile_contract(
    id = paste0(method, "_scientific_v1"),
    method = method,
    source = source,
    output_profile = paste0(method, "_output"),
    leontief_zero = list(
      id = paste0(method, "_zero_v1"),
      exception_count = 0L,
      coordinate_md5 = "d41d8cd98f00b204e9800998ecf8427e",
      counts = data.frame(
        year = character(), output = character(),
        exception_count = integer(), stringsAsFactors = FALSE
      )
    ),
    leontief_signed = list(
      id = paste0(method, "_signed_v1"),
      rows = data.frame(
        year = years,
        coefficient_negative_count = as.integer(signed_counts),
        certificate_type = ifelse(
          signed_counts > 0L,
          "absolute_convergence_signed",
          "productivity_nonnegative"
        ),
        stringsAsFactors = FALSE
      )
    ),
    nonfinite_resolution = list(
      id = "nonfinite_none_v1",
      action = "reject",
      expected_count = 0L,
      groups = data.frame(
        binding = character(), indicator = character(),
        kind = character(), module = character(),
        expected_count = integer(), coordinate_sha256 = character(),
        stringsAsFactors = FALSE
      ),
      rules = data.frame(
        artifact = character(), indicator = character(),
        year = character(), country = character(), sector = character(),
        from = character(), to = character(), stringsAsFactors = FALSE
      )
    )
  )
}

test_that("signed Leontief diagnostics are selected by explicit profile", {
  e <- scientific_validation_environment
  profile <- wlv_scientific_test_profile(
    method = "demo",
    source = "demo",
    years = c("2005", "2006", "2007"),
    signed_counts = c(0L, 397L, 0L)
  )
  observed <- profile$leontief_signed$rows
  expect_identical(
    e$wlv_scientific_validate_leontief_signed_profile(
      observed,
      profile,
      "demo"
    ),
    "2006"
  )

  wrong_count <- observed
  wrong_count$coefficient_negative_count[[2L]] <- 396L
  expect_error(
    e$wlv_scientific_validate_leontief_signed_profile(
      wrong_count,
      profile,
      "demo"
    ),
    "differs from explicit profile"
  )

  wrong_certificate <- observed
  wrong_certificate$certificate_type[[2L]] <- "productivity_nonnegative"
  expect_error(
    e$wlv_scientific_validate_leontief_signed_profile(
      wrong_certificate,
      profile,
      "demo"
    ),
    "differs from explicit profile"
  )

  zero_profile <- wlv_scientific_test_profile(
    method = "zerodep_1",
    source = "wiodr13",
    years = c("2005", "2006", "2007")
  )
  expect_error(
    e$wlv_scientific_validate_leontief_signed_profile(
      observed,
      zero_profile,
      "zerodep_1"
    ),
    "differs from explicit profile"
  )
})

test_that("non-finite sidecars pin module identity and every profiled group", {
  e <- scientific_validation_environment
  base_profile <- wlv_scientific_test_profile()
  coordinate_sha256 <- e$wlv_nonfinite_coordinate_sha256("2000|AAA|S1")
  profile <- e$wlv_scientific_profile_contract(
    id = "demo_nonfinite_scientific_v1",
    method = "demo",
    source = "demo",
    output_profile = "demo_output",
    leontief_zero = base_profile$leontief_zero,
    leontief_signed = base_profile$leontief_signed,
    nonfinite_resolution = list(
      id = "demo_nonfinite_v1",
      action = "replace_nan_with_zero",
      expected_count = 1L,
      groups = data.frame(
        binding = "skill",
        indicator = "skill",
        kind = "NaN",
        module = "module.skill",
        expected_count = 1L,
        coordinate_sha256 = coordinate_sha256,
        stringsAsFactors = FALSE
      ),
      rules = data.frame(
        artifact = "sea_sectors",
        indicator = "skill",
        year = "2000",
        country = "AAA",
        sector = "S1",
        from = "NaN",
        to = "0",
        stringsAsFactors = FALSE
      )
    )
  )
  diagnostic <- data.frame(
    method = "demo",
    scientific_profile = "demo_nonfinite_scientific_v1",
    nonfinite_resolution_profile = "demo_nonfinite_v1",
    action = "replace_nan_with_zero",
    module = "module.skill",
    binding = "skill",
    indicator = "skill",
    kind = "NaN",
    resolved_count = 1L,
    coordinate_sha256 = coordinate_sha256,
    stringsAsFactors = FALSE
  )[e$wlv_nonfinite_resolution_diagnostic_columns()]
  diagnostics <- list(
    `_nonfinite_resolution_diagnostics.csv` = diagnostic
  )
  check <- e$wlv_scientific_validate_nonfinite_resolution(
    diagnostics,
    profile,
    "demo"
  )
  expect_identical(check$observations, 1L)

  wrong_module <- diagnostics
  wrong_module[[1L]]$module <- "module.other"
  expect_error(
    e$wlv_scientific_validate_nonfinite_resolution(
      wrong_module,
      profile,
      "demo"
    ),
    "published transitions differ from explicit profile"
  )
  expect_error(
    e$wlv_scientific_validate_nonfinite_resolution(list(), profile, "demo"),
    "requires the non-finite resolution sidecar"
  )
  expect_error(
    e$wlv_scientific_validate_nonfinite_resolution(
      diagnostics,
      base_profile,
      "demo"
    ),
    "strict profile published an undeclared resolution sidecar"
  )
})

wlv_scientific_test_arrays <- function(method = "demo") {
  years <- "2000"
  indicators <- c(
    "capital_stock.s.us", "capital_depreciation.s.us",
    "gross_output.s.us", "gross_output.s.mv", "value.m.mv"
  )
  sectors <- c("S1", "S2")
  countries <- c("A", "B")
  sea_sectors <- array(
    0,
    dim = c(1L, length(indicators), 2L, 2L),
    dimnames = list(years, indicators, sectors, countries)
  )
  sea_sectors[1L, "capital_stock.s.us", , ] <- matrix(
    c(10, 20, 30, 40), nrow = 2L
  )
  sea_sectors[1L, "capital_depreciation.s.us", , ] <- matrix(
    c(1, 2, 3, 4), nrow = 2L
  )
  sea_sectors[1L, "gross_output.s.us", , ] <- matrix(
    c(100, 200, 300, 400), nrow = 2L
  )
  sea_sectors[1L, "gross_output.s.mv", , ] <- matrix(
    c(4, 6, 8, 10), nrow = 2L
  )
  sea_sectors[1L, "value.m.mv", , ] <- matrix(
    c(0.4, 0.6, 0.8, 1), nrow = 2L
  )

  operations <- c("sum", "sum", "sum", "sum", "mean")
  solutions <- data.frame(
    names = indicators,
    country_solution = operations,
    stringsAsFactors = FALSE
  )
  aggregations <- do.call(rbind, lapply(seq_along(indicators), function(index) {
    data.frame(
      indicator = indicators[[index]],
      level = c("sector_to_country", "country_to_world"),
      strategy = operations[[index]],
      module = "",
      numerator = "",
      denominator = "",
      weight = "",
      zero_denominator = "",
      notes = "",
      stringsAsFactors = FALSE
    )
  }))
  sea_countries <- array(
    0,
    dim = c(1L, length(indicators), 3L),
    dimnames = list(years, indicators, c(countries, "WWW"))
  )
  for (index in seq_along(indicators)) {
    indicator <- indicators[[index]]
    operation <- operations[[index]]
    aggregator <- if (operation == "sum") sum else mean
    for (country in countries) {
      sea_countries[1L, indicator, country] <- aggregator(
        sea_sectors[1L, indicator, , country]
      )
    }
    sea_countries[1L, indicator, "WWW"] <- aggregator(
      sea_countries[1L, indicator, countries]
    )
  }

  bilateral <- c(
    "exports_values", "transfers_values", "transfers_productive_values"
  )
  m_countries <- array(
    0,
    dim = c(1L, length(bilateral), 2L, 2L),
    dimnames = list(years, bilateral, countries, countries)
  )
  m_countries[1L, "exports_values", "A", "B"] <- 5
  m_countries[1L, "exports_values", "B", "A"] <- 2
  m_countries[1L, "transfers_values", "A", "B"] <- 7
  m_countries[1L, "transfers_values", "B", "A"] <- 3
  m_countries[1L, "transfers_productive_values", "A", "B"] <- 2
  m_countries[1L, "transfers_productive_values", "B", "A"] <- -2

  inputs <- c("A.S1", "A.S2", "B.S1", "B.S2")
  outputs <- c(inputs, "A.HH", "B.HH")
  m_io <- array(
    0,
    dim = c(1L, 3L, length(inputs), length(outputs)),
    dimnames = list(
      years,
      c("k_composition", "k_depreciation", "values"),
      inputs,
      outputs
    )
  )
  diag(m_io[1L, "k_composition", inputs, inputs]) <-
    as.vector(sea_sectors[1L, "capital_stock.s.us", , ])
  diag(m_io[1L, "k_depreciation", inputs, inputs]) <-
    as.vector(sea_sectors[1L, "capital_depreciation.s.us", , ])
  diag(m_io[1L, "values", inputs, inputs]) <-
    as.vector(sea_sectors[1L, "gross_output.s.mv", , ])

  list(
    method = method,
    sea_sectors = sea_sectors,
    sea_countries = sea_countries,
    m_countries = m_countries,
    m_io = m_io,
    solutions = solutions,
    aggregations = aggregations
  )
}

test_that("critical scientific identities pass and detect targeted corruption", {
  values <- wlv_scientific_test_arrays()
  expect_no_error(scientific_validation_environment$
    wlv_scientific_validate_result_arrays(
      values$method,
      values$sea_sectors,
      values$sea_countries,
      values$m_countries,
      values$solutions,
      values$aggregations
    ))
  expect_no_error(scientific_validation_environment$
    wlv_scientific_validate_io_array(
      values$method,
      values$m_io,
      values$sea_sectors
    ))

  broken_values <- values$m_io
  broken_values[1L, "values", "A.S1", "A.S1"] <-
    broken_values[1L, "values", "A.S1", "A.S1"] + 1
  expect_error(
    scientific_validation_environment$wlv_scientific_validate_io_array(
      values$method, broken_values, values$sea_sectors
    ),
    class = "wlv_scientific_validation_error"
  )

  broken_capital <- values$m_io
  broken_capital[1L, "k_composition", "A.S1", "A.S1"] <- 9
  expect_error(
    scientific_validation_environment$wlv_scientific_validate_io_array(
      values$method, broken_capital, values$sea_sectors
    ),
    "capital_stock_conservation",
    fixed = TRUE
  )

  broken_aggregation <- values$sea_countries
  broken_aggregation[1L, "gross_output.s.us", "A"] <- 999
  expect_error(
    scientific_validation_environment$wlv_scientific_validate_result_arrays(
      values$method,
      values$sea_sectors,
      broken_aggregation,
      values$m_countries,
      values$solutions,
      values$aggregations
    ),
    "sector_to_country",
    fixed = TRUE
  )

  broken_transfer <- values$m_countries
  broken_transfer[1L, "transfers_productive_values", "A", "B"] <- 3
  expect_error(
    scientific_validation_environment$wlv_scientific_validate_result_arrays(
      values$method,
      values$sea_sectors,
      values$sea_countries,
      broken_transfer,
      values$solutions,
      values$aggregations
    ),
    "productive_transfer_conservation",
    fixed = TRUE
  )
})

test_that("typed scientific aggregation is an independent reference", {
  reference <- scientific_validation_environment$
    wlv_scientific_reference_aggregate
  expect_equal(
    reference(
      "ratio_of_sums",
      numerator = c(1, 90),
      denominator = c(1, 10),
      zero_denominator = "error"
    ),
    91 / 11
  )
  expect_equal(
    reference(
      "weighted_mean",
      value = c(1, 9),
      weight = c(1, 3),
      zero_denominator = "error"
    ),
    7
  )
  expect_equal(reference("invariant", value = c(4, 4)), 4)
  expect_true(is.na(reference("not_applicable", value = c(1, 2))))
  expect_identical(
    reference(
      "weighted_mean",
      value = c(1, 2),
      weight = c(0, 0),
      zero_denominator = "zero"
    ),
    0
  )
  expect_false(any(grepl(
    "wlv_aggregate",
    deparse(body(reference)),
    fixed = TRUE
  )))

  values <- wlv_scientific_test_arrays()
  target <- values$aggregations$indicator == "value.m.mv"
  country <- target &
    values$aggregations$level == "sector_to_country"
  world <- target &
    values$aggregations$level == "country_to_world"
  values$aggregations$strategy[country] <- "ratio_of_sums"
  values$aggregations$numerator[country] <- "gross_output.s.mv"
  values$aggregations$denominator[country] <- "gross_output.s.us"
  values$aggregations$zero_denominator[country] <- "error"
  values$aggregations$strategy[world] <- "weighted_mean"
  values$aggregations$weight[world] <- "gross_output.s.us"
  values$aggregations$zero_denominator[world] <- "error"
  values$sea_countries[1L, "value.m.mv", "A"] <- 10 / 300
  values$sea_countries[1L, "value.m.mv", "B"] <- 18 / 700
  values$sea_countries[1L, "value.m.mv", "WWW"] <- 28 / 1000

  expect_no_error(scientific_validation_environment$
    wlv_scientific_validate_result_arrays(
      values$method,
      values$sea_sectors,
      values$sea_countries,
      values$m_countries,
      values$solutions,
      values$aggregations
    ))
  values$sea_countries[1L, "value.m.mv", "WWW"] <- 0.5
  expect_error(
    scientific_validation_environment$wlv_scientific_validate_result_arrays(
      values$method,
      values$sea_sectors,
      values$sea_countries,
      values$m_countries,
      values$solutions,
      values$aggregations
    ),
    "country_to_world",
    fixed = TRUE
  )
})

test_that("scientific validation accepts only complete typed routes", {
  values <- wlv_scientific_test_arrays()
  checks <- scientific_validation_environment$
    wlv_scientific_validate_result_arrays(
      values$method,
      values$sea_sectors,
      values$sea_countries,
      values$m_countries,
      values$solutions,
      values$aggregations
    )
  contract_check <- checks$check_id == "aggregation_contract"
  expect_identical(
    checks$observations[contract_check],
    as.integer(nrow(values$aggregations))
  )
  routed <- checks$check_id %in% c("sector_to_country", "country_to_world")
  expect_false(any(grepl("legacy", checks$scope[routed], fixed = TRUE)))

  expect_error(
    scientific_validation_environment$wlv_scientific_validate_result_arrays(
      values$method,
      values$sea_sectors,
      values$sea_countries,
      values$m_countries,
      values$solutions,
      values$aggregations[FALSE, , drop = FALSE]
    ),
    "typed routes must be supported",
    fixed = TRUE
  )

  unsupported <- values$aggregations
  unsupported$strategy[[1L]] <- "unsupported"
  expect_error(
    scientific_validation_environment$wlv_scientific_validate_result_arrays(
      values$method,
      values$sea_sectors,
      values$sea_countries,
      values$m_countries,
      values$solutions,
      unsupported
    ),
    "typed routes must be supported",
    fixed = TRUE
  )
})

test_that("ranges are method-specific and zero depreciation is exact", {
  expect_equal(
    nrow(scientific_validation_environment$wlv_scientific_range_rules("demo")),
    0L
  )
  expect_no_error(scientific_validation_environment$wlv_scientific_check_range(
    -1,
    method = "demo",
    artifact = "sea_sectors",
    indicator = "unprofiled",
    minimum = -Inf,
    maximum = Inf
  ))
  expect_no_error(scientific_validation_environment$wlv_scientific_check_range(
    c(0, 0),
    method = "zerodep_2",
    artifact = "m_io",
    indicator = "k_depreciation",
    minimum = 0,
    maximum = 0,
    exact_zero = TRUE
  ))
  expect_error(
    scientific_validation_environment$wlv_scientific_check_range(
      c(0, 1e-300),
      method = "zerodep_2",
      artifact = "m_io",
      indicator = "k_depreciation",
      minimum = 0,
      maximum = 0,
      exact_zero = TRUE
    ),
    "outside the method-specific range",
    fixed = TRUE
  )
  expect_no_error(scientific_validation_environment$wlv_scientific_check_range(
    c(1e15, -1e-15),
    method = "wiodr16",
    artifact = "sea_sectors",
    indicator = "capital_stock.s.us",
    minimum = 0,
    maximum = Inf
  ))
  expect_error(
    scientific_validation_environment$wlv_scientific_check_range(
      c(1e15, -1),
      method = "wiodr16",
      artifact = "sea_sectors",
      indicator = "capital_stock.s.us",
      minimum = 0,
      maximum = Inf
    ),
    "outside the method-specific range",
    fixed = TRUE
  )
})

test_that("the WIOD13 signed SEA exception is required, not merely allowed", {
  signed_stock <- array(
    -75458950528.278488,
    dim = c(1L, 1L, 1L, 1L),
    dimnames = list("2006", "capital_stock.s.us", "23", "GBR")
  )
  check <- scientific_validation_environment$wlv_scientific_check_range(
    signed_stock,
    method = "wiodr13",
    artifact = "sea_sectors",
    indicator = "capital_stock.s.us",
    minimum = 0,
    maximum = Inf
  )
  expect_identical(check$status, "warning")

  missing_pin <- signed_stock
  missing_pin[] <- 0
  expect_error(
    scientific_validation_environment$wlv_scientific_check_range(
      missing_pin,
      method = "wiodr13",
      artifact = "sea_sectors",
      indicator = "capital_stock.s.us",
      minimum = 0,
      maximum = Inf
    ),
    "negative cells differ from the single pinned signed-domain exception",
    fixed = TRUE
  )
})

test_that("scientific checks and sidecar inventory are deterministic", {
  skip_if_not_installed("Matrix")
  values <- wlv_scientific_test_arrays()
  base_checks <- scientific_validation_environment$
    wlv_scientific_validate_result_arrays(
      values$method,
      values$sea_sectors,
      values$sea_countries,
      values$m_countries,
      values$solutions,
      values$aggregations
    )
  io_checks <- scientific_validation_environment$wlv_scientific_validate_io_array(
    values$method,
    values$m_io,
    values$sea_sectors
  )
  input_labels <- c("A.S1", "A.S2", "B.S1", "B.S2")
  published_lambda <- stats::setNames(
    as.numeric(values$sea_sectors["2000", "value.m.mv", , ]),
    input_labels
  )
  solved <- scientific_validation_environment$wlv_solve_leontief(
    coefficient_matrix = matrix(
      0,
      nrow = length(input_labels),
      ncol = length(input_labels),
      dimnames = list(input_labels, input_labels)
    ),
    labour_requirements = published_lambda,
    method = values$method,
    year = "2000"
  )
  diagnostics <- list(
    `_leontief_diagnostics.csv` = solved$diagnostics
  )
  scientific_profile <- wlv_scientific_test_profile(
    method = values$method,
    source = "demo",
    years = "2000"
  )
  build <- function() scientific_validation_environment$
    wlv_finalize_scientific_checks(
      checks = list(base_checks, io_checks),
      method = values$method,
      source = "demo",
      years = "2000",
      io_years = "2000",
      diagnostics = diagnostics,
      sea_sectors = values$sea_sectors,
      scientific_profile = scientific_profile
    )
  first <- build()
  second <- build()
  expect_identical(first, second)

  stale_diagnostics <- diagnostics
  stale_diagnostics[["_leontief_diagnostics.csv"]]$lambda_fingerprint <-
    scientific_validation_environment$wlv_lambda_fingerprint(
      published_lambda + c(0, 0, 0, 1e-6),
      input_labels
    )
  expect_error(
    scientific_validation_environment$wlv_finalize_scientific_checks(
      checks = list(base_checks, io_checks),
      method = values$method,
      source = "demo",
      years = "2000",
      io_years = "2000",
      diagnostics = stale_diagnostics,
      sea_sectors = values$sea_sectors,
      scientific_profile = scientific_profile
    ),
    "diagnostic fingerprint does not match",
    fixed = TRUE
  )

  result_dir <- tempfile("wlv-scientific-sidecars-")
  dir.create(result_dir)
  on.exit(unlink(result_dir, recursive = TRUE, force = TRUE), add = TRUE)
  metadata <- scientific_validation_environment$wlv_method_result_metadata(
    parameters = data.frame(name = "demo"),
    assumptions = data.frame(name = "demo"),
    matrices = data.frame(names = "values"),
    solutions = values$solutions,
    sectors = data.frame(sector = c("S1", "S2")),
    meta_indicators = data.frame(code = values$solutions$names),
    extra_csv = c(diagnostics, list(`_scientific_checks.csv` = first))
  )
  scientific_validation_environment$wlv_write_method_result_metadata(
    result_dir,
    metadata
  )
  expect_no_error(scientific_validation_environment$
    wlv_validate_method_result_metadata(result_dir, metadata))

  scientific_validation_environment$wlv_write_result_csv(
    data.frame(stale = TRUE),
    file.path(result_dir, "_scientific_stale.csv")
  )
  expect_error(
    scientific_validation_environment$wlv_validate_method_result_metadata(
      result_dir, metadata
    ),
    "unexpected scientific sidecar",
    fixed = TRUE
  )
  unlink(file.path(result_dir, "_scientific_stale.csv"))
  for (unexpected_name in c("_legacy_check.csv", "stale.csv", ".stale.csv", "_stale.CSV")) {
    unexpected_path <- file.path(result_dir, unexpected_name)
    scientific_validation_environment$wlv_write_result_csv(
      data.frame(stale = TRUE),
      unexpected_path
    )
    expect_error(
      scientific_validation_environment$wlv_validate_method_result_metadata(
        result_dir, metadata
      ),
      "unexpected scientific sidecar",
      fixed = TRUE,
      info = unexpected_name
    )
    unlink(unexpected_path)
  }
})

test_that("scientific failures leave an auditable UTF-8 report", {
  results_root <- tempfile("wlv-scientific-failure-")
  dir.create(results_root)
  on.exit(unlink(results_root, recursive = TRUE, force = TRUE), add = TRUE)
  error <- tryCatch(
    scientific_validation_environment$wlv_abort_scientific_validation(
      method = "demo",
      check_id = "example",
      artifact = "sea_sectors",
      indicator = "valor",
      reason = "viola\u00e7\u00e3o cient\u00edfica"
    ),
    error = identity
  )
  runtime <- list(
    method = "demo",
    anomalies = scientific_validation_environment$wlv_empty_contract_table()
  )
  expect_no_error(scientific_validation_environment$
    wlv_write_failed_contract_report(runtime, results_root, error))
  reports <- list.files(
    file.path(results_root, "diagnostics"),
    pattern = "scientific-.*-failed[.]csv$",
    full.names = TRUE
  )
  expect_length(reports, 1L)
  payload <- readLines(reports, encoding = "UTF-8", warn = FALSE)
  expect_true(any(grepl("viola\u00e7\u00e3o cient\u00edfica", payload, fixed = TRUE)))
  expect_false(any(grepl("\ufffd", payload, fixed = TRUE)))
})
