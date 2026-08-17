test_that("the synthetic fixture completes the real calculation pipeline", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)

  run <- NULL
  expect_no_error(
    suppressMessages(run <- wlv_run_synthetic_calculation(fixture, workers = 1L))
  )
  expect_identical(run$result, fixture$method)

  result_path <- file.path("results", fixture$method)
  expected_files <- c(
    "m_io2000-2001.fst", "m_io2000-2001.fst.meta",
    "m_countries.fst", "m_countries.fst.meta",
    "sea_sectors.fst", "sea_sectors.fst.meta",
    "sea_countries.fst", "sea_countries.fst.meta",
    "meta_indicators.RDS", "_anomalies.csv", "_states.csv",
    "_unit_contract.csv", "_source_provenance.csv"
  )
  expect_true(all(file.exists(file.path(fixture$root, result_path, expected_files))))
  method_metadata <- readRDS(
    file.path(fixture$root, result_path, "meta_indicators.RDS")
  )
  expect_true(all(
    c(
      "canonical_unit", "display_unit", "display_multiplier",
      "index_base_year", "index_storage_base"
    ) %in% names(method_metadata)
  ))
  panel_metadata <- utils::read.csv2(
    file.path(fixture$root, "results", "meta_indicators.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expect_identical(
    names(panel_metadata),
    c("value", "groups", "type", "reverted")
  )
  anomaly_report <- utils::read.csv2(
    file.path(fixture$root, result_path, "_anomalies.csv"),
    stringsAsFactors = FALSE
  )
  expect_identical(
    names(anomaly_report),
    c(
      "artifact", "indicator", "checkpoint", "stage", "module", "year",
      "country", "sector", "output", "original_value", "policy_id", "action"
    )
  )
  unit_contract <- utils::read.csv2(
    file.path(fixture$root, result_path, "_unit_contract.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expect_equal(nrow(unit_contract), 10L)
  expect_identical(unique(unit_contract$contract), "synthetic_units_v1")
  expect_identical(unique(unit_contract$schema_version), 1L)
  expect_identical(
    unique(unit_contract$indicator),
    c(
      "abstract_labour.emp.s.mv", "gross_output.s.us", "price.marker",
      "value.m.mv", "gross_output.s.mv"
    )
  )
  expect_identical(
    unit_contract$level[seq.int(1L, nrow(unit_contract), by = 2L)],
    rep("sector_to_country", 5L)
  )
  expect_equal(
    unit_contract$source_scale[unit_contract$indicator == "gross_output.s.us"],
    rep(1, 2L)
  )

  m_io <- wlv_read_fixture_array(fixture, result_path, "m_io2000-2001.fst")
  m_countries <- wlv_read_fixture_array(fixture, result_path, "m_countries.fst")
  sea_sectors <- wlv_read_fixture_array(fixture, result_path, "sea_sectors.fst")
  sea_countries <- wlv_read_fixture_array(fixture, result_path, "sea_countries.fst")

  expect_identical(
    unname(lapply(dimnames(m_io), unname)),
    list(
      c("2000", "2001"),
      c("k_depreciation", "values", "transfers_values"),
      c("A.S", "B.S"),
      c("A.S", "B.S", "A.HH", "B.HH")
    )
  )
  expect_identical(
    unname(lapply(dimnames(m_countries), unname)),
    list(
      c("2000", "2001"),
      c("exports_values", "transfers_values"),
      c("A", "B"),
      c("A", "B")
    )
  )
  expect_identical(
    unname(lapply(dimnames(sea_sectors), unname)),
    list(
      c("2000", "2001"),
      c(
        "abstract_labour.emp.s.mv", "gross_output.s.us",
        "price.marker", "value.m.mv", "gross_output.s.mv"
      ),
      "S",
      c("A", "B")
    )
  )

  expected_sectors <- fixture$expected$sea_sectors
  for (index in seq_len(nrow(expected_sectors))) {
    expected <- expected_sectors[index, ]
    coordinates <- list(
      as.character(expected$year),
      expected$sector,
      expected$country
    )
    expect_equal(
      sea_sectors[coordinates[[1]], "value.m.mv", coordinates[[2]], coordinates[[3]]],
      expected$value.m.mv,
      tolerance = 1e-14
    )
    expect_equal(
      sea_sectors[
        coordinates[[1]], "gross_output.s.mv", coordinates[[2]], coordinates[[3]]
      ],
      expected$gross_output.s.mv,
      tolerance = 1e-12
    )
  }

  expect_equal(
    as.vector(sea_sectors[, "price.marker", "S", ]),
    c(2, 4, 3, 5)
  )

  expected_trade <- fixture$expected$trade
  for (index in seq_len(nrow(expected_trade))) {
    expected <- expected_trade[index, ]
    year <- as.character(expected$year)
    expect_equal(
      m_countries[year, "exports_values", expected$origin, expected$destination],
      expected$exports_values,
      tolerance = 1e-12
    )
    expect_equal(
      m_countries[year, "transfers_values", expected$origin, expected$destination],
      expected$transfers_values,
      tolerance = 1e-12
    )
  }

  for (year in c("2000", "2001")) {
    expect_equal(
      unname(rowSums(m_io[year, "values", , ])),
      as.vector(sea_sectors[year, "gross_output.s.mv", "S", ]),
      tolerance = 1e-12
    )
    expect_equal(sum(m_countries[year, "transfers_values", , ]), 0, tolerance = 1e-12)
    expect_equal(
      unname(diag(m_countries[year, "exports_values", , ])),
      c(0, 0)
    )
    expect_equal(
      unname(diag(m_countries[year, "transfers_values", , ])),
      c(0, 0),
      tolerance = 1e-12
    )
  }

  expect_equal(
    sea_countries[, , c("A", "B")],
    aperm(sea_sectors[, , "S", ], c(1, 2, 3)),
    tolerance = 1e-12
  )
  sum_variables <- c(
    "abstract_labour.emp.s.mv", "gross_output.s.us", "gross_output.s.mv"
  )
  expect_equal(
    sea_countries[, sum_variables, "WWW"],
    apply(
      sea_countries[, sum_variables, c("A", "B"), drop = FALSE],
      c(1, 2),
      sum
    ),
    tolerance = 1e-12
  )
  expect_equal(
    sea_countries[, "value.m.mv", "WWW"],
    apply(
      sea_countries[, "value.m.mv", c("A", "B"), drop = FALSE],
      1,
      mean
    ),
    tolerance = 1e-14
  )
  expect_equal(
    sea_countries[, "price.marker", "WWW"],
    apply(
      sea_countries[, "price.marker", c("A", "B"), drop = FALSE],
      1,
      mean
    )
  )
  expect_true(all(is.finite(m_io[, "values", , ])))
  expect_true(all(is.finite(m_io[, "transfers_values", , ])))
  expect_true(all(is.finite(m_io[, "k_depreciation", , c("A.S", "B.S")])))
  expect_true(all(is.finite(m_countries)))
  expect_true(all(is.finite(sea_sectors)))
  expect_true(all(is.finite(sea_countries)))
})

test_that("calculation reads labels from the manifested normalized generation", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)

  raw_countries_path <- file.path(
    fixture$root,
    "source_data",
    "synthetic",
    "countries.csv"
  )
  raw_countries <- utils::read.csv2(
    raw_countries_path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  utils::write.table(
    raw_countries[rev(seq_len(nrow(raw_countries))), , drop = FALSE],
    raw_countries_path,
    row.names = FALSE,
    quote = FALSE,
    sep = ";",
    fileEncoding = "UTF-8"
  )

  expect_no_error(
    suppressMessages(wlv_run_synthetic_calculation(fixture, workers = 1L))
  )
  sea_countries <- wlv_read_fixture_array(
    fixture,
    file.path("results", fixture$method),
    "sea_countries.fst"
  )
  expect_identical(dimnames(sea_countries)[[3L]], c("A", "B", "WWW"))
})

test_that("recalculation repairs a selected result and preserves the others", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  run <- suppressMessages(wlv_run_synthetic_calculation(fixture, workers = 1L))

  result_path <- file.path("results", fixture$method)
  result_file <- file.path(result_path, "sea_sectors.fst")
  solutions_file <- file.path(
    fixture$root, result_path, "_method_solutions.csv"
  )
  parameters_file <- file.path(
    fixture$root, result_path, "_parameters.csv"
  )
  published_parameters <- utils::read.csv2(
    parameters_file,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  published_parameters$description <- paste0(
    "Assumption-derived metadata. ",
    published_parameters$description
  )
  run$runtime$wlv_write_result_csv(published_parameters, parameters_file)
  parameters_before <- readBin(
    parameters_file,
    what = "raw",
    n = file.info(parameters_file)$size
  )
  solutions_before <- readBin(
    solutions_file,
    what = "raw",
    n = file.info(solutions_file)$size
  )
  original <- wlv_read_fixture_array(fixture, result_file)
  corrupted <- original
  corrupted[, "gross_output.s.mv", , ] <- -999
  wlv_write_fixture_array(fixture, corrupted, result_file)

  expect_no_error(
    suppressMessages(
      wlv_recalculate_synthetic_fixture(
        fixture,
        runtime = run$runtime,
        at_stage = 4L,
        sea_vars = "gross_output.s.mv",
        workers = 1L
      )
    )
  )
  repaired <- wlv_read_fixture_array(fixture, result_file)
  expect_equal(
    repaired[, "gross_output.s.mv", , ],
    original[, "gross_output.s.mv", , ],
    tolerance = 1e-12
  )
  preserved <- setdiff(dimnames(original)[[2]], "gross_output.s.mv")
  expect_identical(repaired[, preserved, , ], original[, preserved, , ])
  solutions_after <- readBin(
    solutions_file,
    what = "raw",
    n = file.info(solutions_file)$size
  )
  expect_identical(solutions_after, solutions_before)
  parameters_after <- readBin(
    parameters_file,
    what = "raw",
    n = file.info(parameters_file)$size
  )
  expect_identical(parameters_after, parameters_before)

  expect_no_error(
    suppressMessages(
      wlv_recalculate_synthetic_fixture(
        fixture,
        runtime = run$runtime,
        at_stage = 5L,
        workers = 1L
      )
    )
  )

  configured_parameters_file <- file.path(
    fixture$root, "methods", fixture$method, "_parameters.csv"
  )
  configured_parameters <- utils::read.csv2(
    configured_parameters_file,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  configured_parameters$name <- "Changed current name"
  run$runtime$wlv_write_result_csv(
    configured_parameters,
    configured_parameters_file
  )
  result_parameters_before_failure <- readBin(
    parameters_file,
    what = "raw",
    n = file.info(parameters_file)$size
  )
  expect_error(
    suppressMessages(
      wlv_recalculate_synthetic_fixture(
        fixture,
        runtime = run$runtime,
        at_stage = 5L,
        workers = 1L
      )
    ),
    "Current method parameters differ"
  )
  expect_identical(
    readBin(
      parameters_file,
      what = "raw",
      n = file.info(parameters_file)$size
    ),
    result_parameters_before_failure
  )
})

test_that("selective recalculation rejects no-op indicator requests", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  run <- suppressMessages(wlv_run_synthetic_calculation(fixture, workers = 1L))

  expect_error(
    suppressMessages(
      wlv_recalculate_synthetic_fixture(
        fixture,
        runtime = run$runtime,
        at_stage = 5L,
        sea_vars = "typo.metric",
        workers = 1L
      )
    ),
    "Unknown `sea_vars` for method `synthetic`: typo.metric",
    fixed = TRUE
  )
  expect_error(
    suppressMessages(
      wlv_recalculate_synthetic_fixture(
        fixture,
        runtime = run$runtime,
        at_stage = 5L,
        sea_vars = "price.marker",
        workers = 1L
      )
    ),
    "price.marker (stage 0)",
    fixed = TRUE
  )
})

test_that("recalculation rejects result-schema contraction explicitly", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  run <- suppressMessages(wlv_run_synthetic_calculation(fixture, workers = 1L))

  result_file <- file.path(
    fixture$root,
    "results",
    fixture$method,
    "sea_sectors.fst"
  )
  result_before <- readBin(
    result_file,
    what = "raw",
    n = file.info(result_file)$size
  )
  solutions_path <- file.path(
    fixture$root,
    "parameters",
    "common_ground",
    "_common_solutions.csv"
  )
  solutions <- utils::read.csv2(
    solutions_path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  solutions <- solutions[
    solutions$names != "gross_output.s.mv",
    ,
    drop = FALSE
  ]
  utils::write.table(
    solutions,
    solutions_path,
    sep = ";",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE,
    fileEncoding = "UTF-8"
  )

  expect_error(
    suppressMessages(
      wlv_recalculate_synthetic_fixture(
        fixture,
        runtime = run$runtime,
        at_stage = 5L,
        workers = 1L
      )
    ),
    paste0(
      "Cannot recalculate after removing published indicator(s): ",
      "gross_output.s.mv"
    ),
    fixed = TRUE
  )
  expect_identical(
    readBin(
      result_file,
      what = "raw",
      n = file.info(result_file)$size
    ),
    result_before
  )
})

test_that("the fixture inputs and outputs stay outside the checkout", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)

  checkout <- normalizePath(wlv_test_root, winslash = "/", mustWork = TRUE)
  expect_false(startsWith(fixture$root, paste0(checkout, "/")))

  before <- system2(
    "git",
    c("-C", shQuote(checkout), "status", "--porcelain"),
    stdout = TRUE,
    stderr = TRUE
  )
  suppressMessages(wlv_run_synthetic_calculation(fixture, workers = 1L))
  after <- system2(
    "git",
    c("-C", shQuote(checkout), "status", "--porcelain"),
    stdout = TRUE,
    stderr = TRUE
  )

  expect_identical(after, before)
  expect_true(dir.exists(file.path(fixture$root, "results", fixture$method)))
})

test_that("stage contracts reject omitted and non-finite modules transactionally", {
  cases <- c(omitted = "", missing = "NA_real_", nan = "NaN", infinite = "Inf")

  for (case_name in names(cases)) {
    local({
      fixture <- wlv_make_synthetic_calculation_fixture()
      on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
      result_dir <- file.path(fixture$root, "results", fixture$method)
      dir.create(result_dir, recursive = TRUE, showWarnings = FALSE)
      sentinel <- file.path(result_dir, "existing-result.txt")
      writeLines("preserve me", sentinel, useBytes = TRUE)

      module <- file.path(
        fixture$root,
        "R", "modules", "variables", "common", "gross_output.s.mv.R"
      )
      replacement <- if (case_name == "omitted") {
        "# Intentionally omitted by the contract regression test."
      } else {
        sprintf(
          "sea_sectors[lists$years, 'gross_output.s.mv', , ] <- %s",
          cases[[case_name]]
        )
      }
      writeLines(replacement, module, useBytes = TRUE)

      caught <- tryCatch(
        suppressMessages(wlv_run_synthetic_calculation(fixture, workers = 1L)),
        wlv_contract_error = identity
      )
      expect_s3_class(caught, "wlv_contract_error")
      expect_match(conditionMessage(caught), "gross_output.s.mv", fixed = TRUE)
      expect_match(conditionMessage(caught), "after_stage_4", fixed = TRUE)
      expect_true(all(c("year", "country", "sector") %in% names(caught$anomalies)))
      expect_true(file.exists(sentinel), info = case_name)
      expect_identical(readLines(sentinel, warn = FALSE), "preserve me")
      expect_false(file.exists(file.path(result_dir, "sea_sectors.fst")))
      expect_length(
        list.files(
          file.path(fixture$root, "results"),
          pattern = "^\\.staging-",
          all.files = TRUE
        ),
        0L
      )
      expect_true(
        length(list.files(
          file.path(fixture$root, "results", "diagnostics"),
          pattern = "failed\\.csv$"
        )) >= 1L,
        info = case_name
      )
    })
  }
})

test_that("recalculation reads every prior result from its isolated snapshot", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  run <- suppressMessages(wlv_run_synthetic_calculation(fixture, workers = 1L))

  script <- file.path(fixture$root, "R", "lib", "re_computations.R")
  original <- readLines(script, warn = FALSE, encoding = "UTF-8")
  snapshot_guard <- c(
    "if (!startsWith(basename(wlv_existing_result_dir), '.staging-')) stop('live result directory used')",
    paste0(
      "if (length(wlv_data$result_io) && any(",
      "normalizePath(dirname(wlv_data$result_io), winslash = '/', mustWork = TRUE) != ",
      "normalizePath(wlv_existing_result_dir, winslash = '/', mustWork = TRUE))) ",
      "stop('live result matrix used')"
    )
  )
  writeLines(c(snapshot_guard, original), script, useBytes = TRUE)

  expect_no_error(
    suppressMessages(
      wlv_recalculate_synthetic_fixture(
        fixture,
        runtime = run$runtime,
        at_stage = 4L,
        sea_vars = "gross_output.s.mv",
        workers = 1L
      )
    )
  )

})

test_that("stage 1 recalculation preserves source-matrix USD indicators", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)

  solutions_path <- file.path(
    fixture$root,
    "parameters", "common_ground", "_common_solutions.csv"
  )
  writeLines(
    c(
      readLines(solutions_path, warn = FALSE, encoding = "UTF-8"),
      "exports.s.us;common/exports.s.us.R;sum;4;3",
      "imports.s.us;common/imports.s.us.R;sum;4;4",
      "trade_balance.s.us;common/trade_balance.s.us.R;sum;5;5"
    ),
    solutions_path,
    useBytes = TRUE
  )

  run <- NULL
  expect_warning(
    run <- suppressMessages(
      wlv_run_synthetic_calculation(
        fixture,
        workers = 1L,
        warn_legacy = TRUE
      )
    ),
    "adapted legacy aggregations"
  )
  result_dir <- file.path("results", fixture$method)
  sectors_before <- wlv_read_fixture_array(
    fixture,
    result_dir,
    "sea_sectors.fst"
  )
  countries_before <- wlv_read_fixture_array(
    fixture,
    result_dir,
    "sea_countries.fst"
  )

  expect_warning(
    suppressMessages(
      wlv_recalculate_synthetic_fixture(
        fixture,
        runtime = run$runtime,
        at_stage = 1L,
        workers = 1L,
        warn_legacy = TRUE
      )
    ),
    "adapted legacy aggregations"
  )

  sectors_after <- wlv_read_fixture_array(
    fixture,
    result_dir,
    "sea_sectors.fst"
  )
  countries_after <- wlv_read_fixture_array(
    fixture,
    result_dir,
    "sea_countries.fst"
  )
  source_matrix_indicators <- c(
    "exports.s.us", "imports.s.us", "trade_balance.s.us"
  )
  expect_identical(
    sectors_after[, source_matrix_indicators, , ],
    sectors_before[, source_matrix_indicators, , ]
  )
  expect_identical(
    countries_after[, source_matrix_indicators, ],
    countries_before[, source_matrix_indicators, ]
  )
})

test_that("recalculation refreshes solutions and indicator metadata", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  run <- suppressMessages(wlv_run_synthetic_calculation(fixture, workers = 1L))

  solutions_path <- file.path(
    fixture$root,
    "parameters", "common_ground", "_common_solutions.csv"
  )
  writeLines(
    c(
      readLines(solutions_path, warn = FALSE, encoding = "UTF-8"),
      "new.metric;common/new.metric.R;sum;5;1"
    ),
    solutions_path,
    useBytes = TRUE
  )
  module <- file.path(
    fixture$root,
    "R", "modules", "variables", "common", "new.metric.R"
  )
  writeLines(
    c(
      "code <- 'new.metric'",
      "meta_indicators[code, 'name'] <- 'New metric'",
      "meta_indicators[code, 'description'] <- 'Recalculation metadata test.'",
      "meta_indicators[code, 'observation'] <- ''",
      "meta_indicators[code, 'type'] <- 'quantity'",
      "meta_indicators[code, 'group'] <- 'Test'",
      "meta_indicators[code, 'reverted'] <- FALSE",
      "sea_sectors[, code, , ] <- 1"
    ),
    module,
    useBytes = TRUE
  )

  expect_warning(
    suppressMessages(
      wlv_recalculate_synthetic_fixture(
        fixture,
        runtime = run$runtime,
        at_stage = 5L,
        workers = 1L,
        warn_legacy = TRUE
      )
    ),
    "adapted legacy aggregations"
  )
  result_dir <- file.path(fixture$root, "results", fixture$method)
  solutions <- utils::read.csv2(
    file.path(result_dir, "_method_solutions.csv"),
    stringsAsFactors = FALSE
  )
  metadata <- readRDS(file.path(result_dir, "meta_indicators.RDS"))
  unit_contract <- utils::read.csv2(
    file.path(result_dir, "_unit_contract.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  scientific_checks <- utils::read.csv2(
    file.path(result_dir, "_scientific_checks.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  sea_sectors <- wlv_read_fixture_array(
    fixture,
    "results", fixture$method, "sea_sectors.fst"
  )
  expect_true("new.metric" %in% solutions$names)
  expect_true("new.metric" %in% metadata$code)
  expect_true(all(sea_sectors[, "new.metric", , ] == 1))
  expect_false("new.metric" %in% unit_contract$indicator)
  new_metric_checks <- scientific_checks[
    scientific_checks$indicator == "new.metric" &
      scientific_checks$check_id %in% c(
        "sector_to_country", "country_to_world"
      ),
    ,
    drop = FALSE
  ]
  expect_setequal(
    new_metric_checks$check_id,
    c("sector_to_country", "country_to_world")
  )
  expect_true(all(new_metric_checks$scope == "legacy_adapter:sum"))
})

test_that("result locks reject concurrent runs and are safely reusable", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  old_working_directory <- setwd(fixture$root)
  on.exit(setwd(old_working_directory), add = TRUE)
  runtime <- new.env(parent = globalenv())
  sys.source(file.path(fixture$root, "R", "main.R"), envir = runtime)

  results_root <- file.path(fixture$root, "results")
  lock <- runtime$wlv_acquire_result_lock(results_root, fixture$method)
  on.exit(
    try(runtime$wlv_release_result_lock(lock, results_root), silent = TRUE),
    add = TRUE
  )
  expect_error(
    runtime$wlv_acquire_result_lock(results_root, fixture$method),
    "already locked",
    fixed = TRUE
  )
  expect_error(
    runtime$wlv_acquire_result_lock(results_root, "another_method"),
    "already locked",
    fixed = TRUE
  )
  runtime$wlv_release_result_lock(lock, results_root)
  expect_false(dir.exists(lock))
  lock <- runtime$wlv_acquire_result_lock(results_root, fixture$method)
  expect_true(dir.exists(lock))
})

test_that("result publication retains a rollback point until joint commit", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  old_working_directory <- setwd(fixture$root)
  on.exit(setwd(old_working_directory), add = TRUE)
  runtime <- new.env(parent = globalenv())
  sys.source(file.path(fixture$root, "R", "main.R"), envir = runtime)

  results_root <- file.path(fixture$root, "results")
  dir.create(results_root, recursive = TRUE, showWarnings = FALSE)
  final <- file.path(results_root, fixture$method)
  staging <- file.path(results_root, ".staging-manual-rollback")
  dir.create(final, recursive = TRUE)
  dir.create(staging, recursive = TRUE)
  writeLines("old", file.path(final, "generation.txt"), useBytes = TRUE)
  writeLines("new", file.path(staging, "generation.txt"), useBytes = TRUE)

  transaction <- runtime$wlv_publish_result_staging(staging, final, results_root)
  expect_identical(readLines(file.path(final, "generation.txt")), "new")
  expect_true(dir.exists(transaction$backup))
  runtime$wlv_rollback_result_staging(transaction)
  expect_identical(readLines(file.path(final, "generation.txt")), "old")
  expect_identical(readLines(file.path(staging, "generation.txt")), "new")

  transaction <- runtime$wlv_publish_result_staging(staging, final, results_root)
  runtime$wlv_finalize_result_staging(transaction)
  expect_identical(readLines(file.path(final, "generation.txt")), "new")
  expect_false(dir.exists(transaction$backup))

  staging <- file.path(results_root, ".staging-manual-failed-rollback")
  dir.create(staging, recursive = TRUE)
  writeLines("newer", file.path(staging, "generation.txt"), useBytes = TRUE)
  transaction <- runtime$wlv_publish_result_staging(staging, final, results_root)
  base_file_rename <- base::file.rename
  runtime$file.rename <- function(from, to) {
    if (identical(
      normalizePath(from, winslash = "/", mustWork = FALSE),
      normalizePath(final, winslash = "/", mustWork = FALSE)
    )) {
      return(FALSE)
    }
    base_file_rename(from, to)
  }
  expect_error(
    runtime$wlv_rollback_result_staging(transaction),
    "new results remain published",
    fixed = TRUE
  )
  expect_identical(readLines(file.path(final, "generation.txt")), "newer")
  rm("file.rename", envir = runtime)

  staging <- file.path(results_root, ".staging-manual-double-failure")
  dir.create(staging, recursive = TRUE)
  writeLines("newest", file.path(staging, "generation.txt"), useBytes = TRUE)
  backups_before <- list.dirs(results_root, recursive = FALSE, full.names = TRUE)
  rename_call <- 0L
  runtime$file.rename <- function(from, to) {
    rename_call <<- rename_call + 1L
    if (rename_call %in% c(2L, 3L)) {
      return(FALSE)
    }
    base_file_rename(from, to)
  }
  expect_error(
    runtime$wlv_publish_result_staging(staging, final, results_root),
    "manual recovery required",
    fixed = TRUE
  )
  backups_after <- list.dirs(results_root, recursive = FALSE, full.names = TRUE)
  recovery_backup <- setdiff(backups_after, backups_before)
  expect_length(recovery_backup, 1L)
  expect_identical(
    readLines(file.path(recovery_backup, "generation.txt")),
    "newer"
  )
  rm("file.rename", envir = runtime)
})

test_that("partial global metadata publication restores every prior byte", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  old_working_directory <- setwd(fixture$root)
  on.exit(setwd(old_working_directory), add = TRUE)
  runtime <- new.env(parent = globalenv())
  sys.source(file.path(fixture$root, "R", "main.R"), envir = runtime)

  for (failed_install in 1:2) {
    local({
      results_root <- file.path(fixture$root, paste0("metadata-", failed_install))
      dir.create(results_root, recursive = TRUE)
      targets <- file.path(
        results_root,
        c("indicators_en.csv", "meta_indicators.csv")
      )
      writeBin(charToRaw("old indicators\r\n"), targets[[1L]])
      writeBin(charToRaw("old metadata\r\n"), targets[[2L]])
      prior <- lapply(targets, function(path) {
        readBin(path, what = "raw", n = file.info(path)$size)
      })
      run_environment <- new.env(parent = baseenv())
      run_environment$wlv_pending_indicators_en <- data.frame(
        indicator = "new",
        stringsAsFactors = FALSE
      )
      run_environment$wlv_pending_meta_indicators <- data.frame(
        indicator = "new",
        stringsAsFactors = FALSE
      )

      base_file_rename <- base::file.rename
      install_count <- 0L
      runtime$file.rename <- function(from, to) {
        is_install <- startsWith(basename(from), ".metadata-") &&
          basename(to) %in% basename(targets)
        if (is_install) {
          install_count <<- install_count + 1L
          if (install_count == failed_install) {
            return(FALSE)
          }
        }
        base_file_rename(from, to)
      }
      on.exit(rm("file.rename", envir = runtime), add = TRUE)
      expect_error(
        runtime$wlv_begin_global_metadata_transaction(
          run_environment,
          results_root
        ),
        "Could not publish global metadata",
        fixed = TRUE
      )
      observed <- lapply(targets, function(path) {
        readBin(path, what = "raw", n = file.info(path)$size)
      })
      expect_identical(observed, prior, info = paste("install", failed_install))
      leftovers <- list.files(
        results_root,
        pattern = "^\\.(backup|metadata|rollback)-",
        all.files = TRUE
      )
      expect_length(leftovers, 0L)
    })
  }
})

test_that("method metadata validation detects every missing or stale sidecar", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  old_working_directory <- setwd(fixture$root)
  on.exit(setwd(old_working_directory), add = TRUE)
  runtime <- new.env(parent = globalenv())
  sys.source(file.path(fixture$root, "R", "main.R"), envir = runtime)

  result_dir <- file.path(fixture$root, "metadata-sidecars")
  dir.create(result_dir)
  metadata <- runtime$wlv_method_result_metadata(
    parameters = data.frame(source = "synthetic"),
    assumptions = data.frame(computation = "none"),
    matrices = data.frame(names = "values"),
    solutions = data.frame(names = "metric", stage = 5L),
    sectors = data.frame(sector = "S"),
    meta_indicators = data.frame(
      code = "metric",
      name = "Metric",
      stringsAsFactors = FALSE,
      row.names = "metric"
    ),
    extra_csv = list(
      `_diagnostic.csv` = data.frame(
        coordinate = "2000|S",
        original_value = -1,
        applied_value = 0,
        stringsAsFactors = FALSE
      )
    )
  )
  runtime$wlv_write_method_result_metadata(result_dir, metadata)
  expect_no_error(runtime$wlv_validate_method_result_metadata(result_dir, metadata))

  files <- c(names(metadata$csv), "meta_indicators.RDS")
  for (name in files) {
    local({
      path <- file.path(result_dir, name)
      bytes <- readBin(path, what = "raw", n = file.info(path)$size)
      unlink(path)
      expect_error(
        runtime$wlv_validate_method_result_metadata(result_dir, metadata),
        "missing",
        fixed = TRUE
      )
      writeBin(bytes, path)
      writeBin(charToRaw("corrupt"), path)
      expect_error(
        runtime$wlv_validate_method_result_metadata(result_dir, metadata),
        "differs|Cannot read"
      )
      writeBin(bytes, path)
    })
  }
  expect_no_error(runtime$wlv_validate_method_result_metadata(result_dir, metadata))

  unexpected_scientific <- file.path(
    result_dir,
    "_gfcf_negative_unexpected.csv"
  )
  runtime$wlv_write_result_csv(
    data.frame(value = 1),
    unexpected_scientific
  )
  expect_error(
    runtime$wlv_validate_method_result_metadata(result_dir, metadata),
    "unexpected scientific sidecar",
    fixed = TRUE
  )
  unlink(unexpected_scientific)
  expect_no_error(runtime$wlv_validate_method_result_metadata(result_dir, metadata))
})

test_that("post-commit lock cleanup cannot turn a successful run into failure", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  old_working_directory <- setwd(fixture$root)
  on.exit(setwd(old_working_directory), add = TRUE)
  runtime <- new.env(parent = globalenv())
  sys.source(file.path(fixture$root, "R", "main.R"), envir = runtime)

  release <- runtime$wlv_release_result_lock
  release_calls <- 0L
  runtime$wlv_release_result_lock <- function(...) {
    release_calls <<- release_calls + 1L
    if (release_calls == 1L) {
      stop("injected lock cleanup failure", call. = FALSE)
    }
    release(...)
  }
  result <- NULL
  capture.output(
    suppressWarnings(
      expect_message(
        result <- runtime$get_wlv(
          fixture$method,
          workers = 1L,
          allow_experimental = TRUE
        ),
        "result lock cleanup warning"
      ),
    ),
    type = "output"
  )
  expect_identical(result, fixture$method)
  expect_identical(release_calls, 2L)
  expect_false(dir.exists(file.path(fixture$root, "results", ".lock-results")))
})
