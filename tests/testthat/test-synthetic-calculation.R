test_that("the native fixture completes a typed calculation DAG", {
  fixture <- wlv_make_native_calculation_fixture()
  execution <- wlv_run_native_test_calculation(fixture)
  artifacts <- wlv_native_test_artifacts(fixture, execution$result)

  expect_identical(
    execution$plan$order,
    c("indicator.gross", "indicator.productivity", "assembler.panel")
  )
  expect_identical(
    dimnames(artifacts$sea_sectors),
    list(
      year = fixture$labels$year,
      indicator = fixture$indicators,
      sector = fixture$labels$sector,
      country = fixture$labels$country
    )
  )
  expect_identical(
    dimnames(artifacts$sea_countries),
    list(
      year = fixture$labels$year,
      indicator = fixture$indicators,
      country = c(fixture$labels$country, "WWW")
    )
  )
  expect_identical(
    unname(artifacts$sea_sectors[, "gross_output.s.mv", , ]),
    unname(fixture$gross)
  )
  expect_equal(
    unname(artifacts$sea_sectors[, "labour_productivity.r.id", , ]),
    unname(fixture$gross / fixture$labour),
    tolerance = 0
  )

  expected_country <- wlv_native_test_country_total(fixture$gross)
  expect_identical(
    unname(artifacts$sea_countries[, "gross_output.s.mv", ]),
    unname(expected_country)
  )
  expect_identical(
    artifacts$sea_countries[, "gross_output.s.mv", "WWW"],
    rowSums(expected_country[, fixture$labels$country, drop = FALSE])
  )
  diagnostics <- fixture$runtime$wlv_runtime_terminal_entries(
    execution$result$store,
    "diagnostic/indicator.gross"
  )
  expect_length(diagnostics, 1L)
  expect_named(diagnostics[[1L]]$value, "_native_test_gross.csv")
})

test_that("native planning is deterministic rather than row ordered", {
  fixture <- wlv_make_native_calculation_fixture()
  forward <- wlv_run_native_test_calculation(fixture)
  reversed <- wlv_run_native_test_calculation(
    fixture,
    reverse_instances = TRUE
  )

  expect_identical(reversed$plan$order, forward$plan$order)
  expect_identical(
    wlv_native_test_artifacts(fixture, reversed$result),
    wlv_native_test_artifacts(fixture, forward$result)
  )
  expect_identical(reversed$result$trace$sequence, 1:3)
})

test_that("selective native recalculation replaces only its declared target", {
  fixture <- wlv_make_native_calculation_fixture()
  parent <- wlv_run_native_test_calculation(fixture)
  before <- wlv_native_test_artifacts(fixture, parent$result)
  child <- wlv_run_native_test_selective_recalculation(
    fixture,
    parent,
    gross = fixture$gross * 2
  )
  after <- wlv_native_test_artifacts(fixture, child$result)

  expect_identical(child$plan$order, c("recalc.gross", "assembler.panel"))
  expect_identical(
    unname(after$sea_sectors[, "gross_output.s.mv", , ]),
    unname(fixture$gross * 2)
  )
  expect_identical(
    after$sea_sectors[, "labour_productivity.r.id", , ],
    before$sea_sectors[, "labour_productivity.r.id", , ]
  )
  expect_identical(
    after$sea_countries[, "labour_productivity.r.id", ],
    before$sea_countries[, "labour_productivity.r.id", ]
  )
})

test_that("full native recalculation refreshes dependent indicators", {
  fixture <- wlv_make_native_calculation_fixture()
  parent <- wlv_run_native_test_calculation(fixture)
  child <- wlv_run_native_test_calculation(
    fixture,
    gross = fixture$gross * 2
  )
  before <- wlv_native_test_artifacts(fixture, parent$result)
  after <- wlv_native_test_artifacts(fixture, child$result)

  expect_equal(
    unname(after$sea_sectors[, "labour_productivity.r.id", , ]),
    2 * unname(before$sea_sectors[, "labour_productivity.r.id", , ]),
    tolerance = 0
  )
  expect_equal(
    unname(after$sea_countries[, "labour_productivity.r.id", ]),
    2 * unname(before$sea_countries[, "labour_productivity.r.id", ]),
    tolerance = 0
  )
})

test_that("invalid native output is rejected before atomic publication", {
  fixture <- wlv_make_native_calculation_fixture()
  store <- wlv_native_test_base_store(fixture)
  instances <- wlv_native_test_calculation_instances(
    fixture,
    failure = "shape"
  )
  plan <- fixture$runtime$wlv_compile_module_plan(
    fixture$registry,
    instances,
    store,
    operation = "calculate"
  )
  catalog_before <- fixture$runtime$wlv_store_catalog(store)

  caught <- tryCatch(
    fixture$runtime$wlv_run_module_plan(plan, store),
    error = identity
  )
  expect_s3_class(caught, "wlv_module_execution_error")
  expect_match(
    conditionMessage(caught),
    "A stateful value must be a numeric array with declared axes.",
    fixed = TRUE
  )
  expect_identical(fixture$runtime$wlv_store_catalog(store), catalog_before)
  expect_error(
    fixture$runtime$wlv_store_read(
      store,
      fixture$runtime$wlv_native_indicator_ref(
        "gross_output.s.mv",
        alias = "value"
      )[[1L]]
    ),
    "0 terminal generations",
    fixed = TRUE
  )
})

test_that("native module warnings remain observable to the orchestrator", {
  fixture <- wlv_make_native_calculation_fixture()
  warning_text <- "Aviso nativo com acentuação"
  observed <- character()
  expect_no_error(withCallingHandlers(
    wlv_run_native_test_calculation(fixture, warning = warning_text),
    warning = function(condition) {
      observed <<- c(observed, conditionMessage(condition))
      invokeRestart("muffleWarning")
    }
  ))
  observed <- fixture$runtime$wlv_restore_publication_warning_unicode(observed)
  expect_identical(
    charToRaw(enc2utf8(observed[[1L]])),
    charToRaw(enc2utf8(warning_text))
  )
})

test_that("native stage selection rejects unknown and unreachable targets", {
  runtime <- wlv_test_load_runtime()
  stages <- c(
    "gross_output.s.mv" = 4L,
    "labour_productivity.r.id" = 5L
  )

  expect_error(
    runtime$wlv_native_validate_selected_stages(
      stages,
      "unknown.metric",
      at_stage = 4L,
      method = "native_test"
    ),
    "Unknown `sea_vars`",
    fixed = TRUE
  )
  expect_error(
    runtime$wlv_native_validate_selected_stages(
      stages,
      "gross_output.s.mv",
      at_stage = 5L,
      method = "native_test"
    ),
    "cannot be recalculated from checkpoint stage 5",
    fixed = TRUE
  )
  expect_no_error(runtime$wlv_native_validate_selected_stages(
    stages,
    "labour_productivity.r.id",
    at_stage = 5L,
    method = "native_test"
  ))
})

test_that("native test execution neither reads nor writes the checkout", {
  checkout <- normalizePath(wlv_test_root, winslash = "/", mustWork = TRUE)
  before <- system2(
    "git",
    c("-C", shQuote(checkout), "status", "--porcelain"),
    stdout = TRUE,
    stderr = TRUE
  )
  fixture <- wlv_make_native_calculation_fixture()
  expect_no_error(wlv_run_native_test_calculation(fixture))
  after <- system2(
    "git",
    c("-C", shQuote(checkout), "status", "--porcelain"),
    stdout = TRUE,
    stderr = TRUE
  )

  expect_identical(after, before)
})

test_that("native execution tests contain no legacy executor fixture", {
  paths <- c(
    file.path(wlv_test_root, "tests", "testthat", "test-synthetic-calculation.R"),
    file.path(wlv_test_root, "tests", "testthat", "helper-synthetic-fixture.R")
  )
  text <- paste(unlist(lapply(paths, readLines, warn = FALSE)), collapse = "\n")

  expect_false(grepl("computations[.]R|re_computations[.]R", text))
  legacy_names <- paste0(
    "wlv_run_", "script", "|wlv_effective_parameter_", "group"
  )
  expect_false(grepl(legacy_names, text))
  expect_false(grepl("sys[.]source[(].*main[.]R", text))
})
