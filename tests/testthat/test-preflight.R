preflight_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "wiodr13_validation.R"),
  envir = preflight_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "wiodr16_allocation.R"),
  envir = preflight_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "wiodr16_validation.R"),
  envir = preflight_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "execution.R"),
  envir = preflight_environment
)

wlv_touch_with_metadata <- function(path, years = "2000") {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  file.create(path)
  saveRDS(
    list(
      dim = c(length(years), 1L, 1L),
      as.character(years),
      "row",
      "column"
    ),
    paste0(path, ".meta")
  )
  invisible(path)
}

wlv_make_preflight_fixture <- function() {
  root <- tempfile("wlv-preflight-")
  method <- "demo"
  source <- "fixture_source"

  dir.create(file.path(root, "methods", method), recursive = TRUE)
  dir.create(file.path(root, "R", "utils", "papers"), recursive = TRUE)
  dir.create(file.path(root, "parameters", source), recursive = TRUE)
  dir.create(file.path(root, "parameters", "common_ground"), recursive = TRUE)
  dir.create(file.path(root, "R", "modules", "assumptions"), recursive = TRUE)
  dir.create(file.path(root, "R", "modules", "matrices"), recursive = TRUE)
  dir.create(file.path(root, "R", "modules", "reduced_matrices"), recursive = TRUE)
  dir.create(file.path(root, "R", "modules", "variables", "fixture"), recursive = TRUE)
  dir.create(file.path(root, "source_data", source), recursive = TRUE)
  dir.create(file.path(root, "results", method), recursive = TRUE)

  writeLines(
    c(
      "source;code;name;description",
      paste(source, "demo", "Fixture method", "", sep = ";")
    ),
    file.path(root, "methods", method, "_parameters.csv")
  )
  writeLines(
    c("sector;include", "fixture;1"),
    file.path(root, "methods", method, "_sectors.csv")
  )
  writeLines(
    "invisible(NULL)",
    file.path(root, "R", "utils", paste0("prepare_", source, "_data.R"))
  )
  writeLines(
    "invisible(NULL)",
    file.path(root, "R", "utils", "papers", "paper_0_selection.R")
  )

  writeLines(
    c("names;computation;order", "fixture_assumption;fixture-assumption.R;1"),
    file.path(root, "parameters", source, "_source_assumptions.csv")
  )
  writeLines(
    c("names;computation;order", "fixture_matrix;fixture-matrix.R;1"),
    file.path(root, "parameters", source, "_source_matrices.csv")
  )
  writeLines(
    c(
      "names;sector_solution;country_solution;stage;order",
      "fixture_value;fixture/sector.R;fixture/country.R;1;1"
    ),
    file.path(root, "parameters", source, "_source_solutions.csv")
  )
  writeLines(
    c("names;computation;order", "fixture_matrix;missing-placeholder;1"),
    file.path(root, "parameters", "common_ground", "_common_matrices.csv")
  )
  writeLines(
    c("names;computation", "fixture_reduced;fixture-reduced.R"),
    file.path(root, "parameters", "common_ground", "_common_reduced_matrices.csv")
  )
  for (script in c(
    file.path(root, "R", "modules", "assumptions", "fixture-assumption.R"),
    file.path(root, "R", "modules", "matrices", "fixture-matrix.R"),
    file.path(root, "R", "modules", "reduced_matrices", "fixture-reduced.R"),
    file.path(root, "R", "modules", "variables", "fixture", "sector.R"),
    file.path(root, "R", "modules", "variables", "fixture", "country.R")
  )) {
    writeLines("invisible(NULL)", script)
  }

  source_path <- file.path(root, "source_data", source)
  writeLines("country", file.path(source_path, "countries.csv"))
  writeLines("demand", file.path(source_path, "demand.csv"))
  wlv_touch_with_metadata(file.path(source_path, "sea.fst"))
  wlv_touch_with_metadata(file.path(source_path, "m_io-source.fst"))

  results_path <- file.path(root, "results", method)
  wlv_touch_with_metadata(file.path(results_path, "m_countries.fst"))
  wlv_touch_with_metadata(file.path(results_path, "sea_sectors.fst"))
  wlv_touch_with_metadata(file.path(results_path, "m_io-result.fst"))

  list(
    root = root,
    method = method,
    source = source,
    source_path = source_path,
    results_path = results_path
  )
}

wlv_fixture_request <- function(fixture, mode = "calculate", ...) {
  preflight_environment$wlv_validate_request(
    methods = fixture$method,
    mode = mode,
    root = fixture$root,
    ...
  )
}

test_that("request validation rejects unknown methods and traversal", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  for (method in c("missing", "../demo", "demo/../../outside")) {
    expect_error(
      preflight_environment$wlv_validate_request(
        methods = method,
        root = fixture$root
      ),
      "[Mm]ethod"
    )
  }
})

test_that("request validation checks the selected data preparer", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  unlink(file.path(
    fixture$root,
    "R",
    "utils",
    paste0("prepare_", fixture$source, "_data.R")
  ))

  expect_error(
    wlv_fixture_request(fixture, repeat_pp = TRUE),
    "[Pp]repar"
  )
})

test_that("request validation checks an explicitly selected paper", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  expect_error(
    wlv_fixture_request(fixture, prepaper = TRUE, papern = 99L),
    "[Pp]aper"
  )
})

test_that("request validation resolves overrides before checking modules", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  plan <- wlv_fixture_request(fixture)
  expect_identical(
    plan$configuration[[fixture$method]]$matrices$computation,
    "fixture-matrix.R"
  )

  unlink(file.path(fixture$root, "R", "modules", "matrices", "fixture-matrix.R"))
  expect_error(wlv_fixture_request(fixture), "fixture-matrix\\.R")
})

test_that("missing input data fails before cluster creation", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  unlink(file.path(fixture$source_path, "demand.csv"))
  starts <- 0L

  expect_error({
    plan <- wlv_fixture_request(fixture)
    plan <- preflight_environment$wlv_validate_data(plan)
    preflight_environment$wlv_with_cluster(
      workers = 2L,
      run = function(cluster) invisible(NULL),
      make_cluster = function(workers) {
        starts <<- starts + 1L
        structure(list(), class = "wlv_test_cluster")
      }
    )
  }, "[Mm]issing|[Aa]usente|demand\\.csv")

  expect_identical(starts, 0L)
})

test_that("WIOD13 scientific validation fails before cluster creation", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  starts <- 0L
  validations <- 0L

  writeLines(
    c("sector.source;sector", "fixture;Fixture sector"),
    file.path(fixture$root, "methods", fixture$method, "_sectors.csv")
  )
  plan <- wlv_fixture_request(fixture)
  plan$methods$source <- "wiodr13"

  expect_error({
    plan <- preflight_environment$wlv_validate_data(
      plan,
      wiodr13_validator = function(source_dir) {
        validations <<- validations + 1L
        stop("scientific validation sentinel", call. = FALSE)
      }
    )
    preflight_environment$wlv_with_cluster(
      workers = 2L,
      run = function(cluster) invisible(NULL),
      make_cluster = function(workers) {
        starts <<- starts + 1L
        structure(list(), class = "wlv_test_cluster")
      }
    )
  }, "scientific validation sentinel", fixed = TRUE)

  expect_identical(validations, 1L)
  expect_identical(starts, 0L)
})

test_that("WIOD13 source sector labels must match the selected method", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  writeLines(
    c("sector.source;sector", "method_sector;Fixture sector"),
    file.path(fixture$root, "methods", fixture$method, "_sectors.csv")
  )
  plan <- wlv_fixture_request(fixture)
  plan$methods$source <- "wiodr13"

  expect_error(
    preflight_environment$wlv_validate_data(
      plan,
      wiodr13_validator = function(source_dir) list(sectors = "source_sector")
    ),
    "source sectors do not match method",
    fixed = TRUE
  )
})

test_that("WIOD16 scientific validation and sector matching happen before execution", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  validations <- 0L

  writeLines(
    c("sector.source;sector", "fixture;Fixture sector"),
    file.path(fixture$root, "methods", fixture$method, "_sectors.csv")
  )
  plan <- wlv_fixture_request(fixture)
  plan$methods$source <- "wiodr16"

  validated <- preflight_environment$wlv_validate_data(
    plan,
    wiodr16_validator = function(source_dir) {
      validations <<- validations + 1L
      list(sectors = "fixture")
    }
  )
  expect_s3_class(validated, "wlv_run_plan")
  expect_identical(validations, 1L)

  expect_error(
    preflight_environment$wlv_validate_data(
      plan,
      wiodr16_validator = function(source_dir) list(sectors = "different")
    ),
    "WIOD16 source sectors do not match method",
    fixed = TRUE
  )
})

test_that("source fst files require sidecar metadata", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  unlink(file.path(fixture$source_path, "sea.fst.meta"))

  plan <- wlv_fixture_request(fixture)
  expect_error(
    preflight_environment$wlv_validate_data(plan),
    "[Mm]eta|sea\\.fst\\.meta"
  )
})

test_that("WIOD13 EUKLEMS inputs fail before cluster creation", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  starts <- 0L

  saveRDS(
    list(dim = c(2L, 1L, 1L), c("1999", "2000"), "row", "column"),
    file.path(fixture$source_path, "m_io-source.fst.meta")
  )

  plan <- wlv_fixture_request(fixture)
  plan$configuration[[fixture$method]]$matrices$computation <-
    "wiodr13/euklems.R"
  expected_files <- c(
    "ekk_1999.fst", "ekk_2000.fst",
    "ekdeprate_2000.fst", "ekdeprate_2001.fst"
  )
  expect_setequal(
    basename(preflight_environment$wlv_wiodr13_euklems_files(
      fixture$root,
      file.path(fixture$source_path, "m_io-source.fst"),
      "wiodr13/euklems.R"
    )),
    expected_files
  )

  expect_error({
    plan <- preflight_environment$wlv_validate_data(plan)
    preflight_environment$wlv_with_cluster(
      workers = 2L,
      run = function(cluster) invisible(NULL),
      make_cluster = function(workers) {
        starts <<- starts + 1L
        structure(list(), class = "wlv_test_cluster")
      }
    )
  }, "EUKLEMS|ekk_1999\\.fst|ekdeprate_2001\\.fst")
  expect_identical(starts, 0L)

  euklems_dir <- file.path(fixture$root, "source_data", "euklems")
  dir.create(euklems_dir, recursive = TRUE)
  file.create(file.path(euklems_dir, expected_files))
  expect_no_error(preflight_environment$wlv_validate_data(plan))

  recalculate_plan <- wlv_fixture_request(
    fixture,
    mode = "recalculate",
    at_stage = 5L
  )
  recalculate_plan$configuration[[fixture$method]]$matrices$computation <-
    "wiodr13/euklems.R"
  unlink(euklems_dir, recursive = TRUE, force = TRUE)
  expect_no_error(preflight_environment$wlv_validate_data(recalculate_plan))
})

test_that("WIOD13 reduction inputs use same-year depreciation data", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  starts <- 0L

  saveRDS(
    list(dim = c(2L, 1L, 1L), c("1999", "2000"), "row", "column"),
    file.path(fixture$source_path, "m_io-source.fst.meta")
  )

  plan <- wlv_fixture_request(fixture)
  plan$configuration[[fixture$method]]$matrices$computation <-
    "wiodr13/euklems-reduction_problem.R"
  expected_files <- c(
    "ekk_1999.fst", "ekk_2000.fst",
    "ekdeprate_1999.fst", "ekdeprate_2000.fst"
  )
  expect_setequal(
    basename(preflight_environment$wlv_wiodr13_euklems_files(
      fixture$root,
      file.path(fixture$source_path, "m_io-source.fst"),
      "wiodr13/euklems-reduction_problem.R"
    )),
    expected_files
  )

  expect_error({
    plan <- preflight_environment$wlv_validate_data(plan)
    preflight_environment$wlv_with_cluster(
      workers = 2L,
      run = function(cluster) invisible(NULL),
      make_cluster = function(workers) {
        starts <<- starts + 1L
        structure(list(), class = "wlv_test_cluster")
      }
    )
  }, "EUKLEMS|ekdeprate_1999\\.fst")
  expect_identical(starts, 0L)

  euklems_dir <- file.path(fixture$root, "source_data", "euklems")
  dir.create(euklems_dir, recursive = TRUE)
  file.create(file.path(euklems_dir, expected_files))
  expect_no_error(preflight_environment$wlv_validate_data(plan))
})

test_that("WIOD16 EU KLEMS preflight requires year and year-plus-one inputs", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  saveRDS(
    list(dim = c(2L, 1L, 1L), c("2000", "2001"), "row", "column"),
    file.path(fixture$source_path, "m_io-source.fst.meta")
  )
  expected_files <- c(
    "ekk_2000.fst", "ekk_2001.fst",
    "ekdeprate_2001.fst", "ekdeprate_2002.fst"
  )
  expect_setequal(
    basename(preflight_environment$wlv_euklems_files(
      fixture$root,
      file.path(fixture$source_path, "m_io-source.fst"),
      "wiodr16/euklems.R"
    )),
    expected_files
  )

  plan <- wlv_fixture_request(fixture)
  plan$configuration[[fixture$method]]$matrices$computation <- "wiodr16/euklems.R"
  expect_error(
    preflight_environment$wlv_validate_data(plan),
    "EUKLEMS|ekk_2000\\.fst|ekdeprate_2002\\.fst"
  )
})

test_that("WIOD16 EU KLEMS preflight validates the files used by the method", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  writeLines(
    c(
      "sector.source;sector;euklems.capital;euklems.sector",
      "fixture;Fixture sector;K_ONE;A"
    ),
    file.path(fixture$root, "methods", fixture$method, "_sectors.csv")
  )

  plan <- wlv_fixture_request(fixture)
  plan$methods$source <- "wiodr16"
  plan$configuration[[fixture$method]]$matrices$computation <- "wiodr16/euklems.R"
  euklems_dir <- file.path(fixture$root, "source_data", "euklems")
  dir.create(euklems_dir, recursive = TRUE)
  euklems <- expand.grid(
    country = c("UK", "EL", "MD"),
    sector = "A",
    stringsAsFactors = FALSE
  )
  euklems$K_ONE <- seq_len(nrow(euklems))
  fst::write_fst(euklems, file.path(euklems_dir, "ekk_2000.fst"))
  fst::write_fst(euklems, file.path(euklems_dir, "ekdeprate_2001.fst"))

  validator <- function(source_dir) list(sectors = "fixture")
  expect_no_error(
    preflight_environment$wlv_validate_data(plan, wiodr16_validator = validator)
  )

  euklems$K_ONE[[1L]] <- Inf
  fst::write_fst(euklems, file.path(euklems_dir, "ekdeprate_2001.fst"))
  expect_error(
    preflight_environment$wlv_validate_data(plan, wiodr16_validator = validator),
    "non-finite value",
    fixed = TRUE
  )
})

test_that("recalculation result files require sidecar metadata", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  unlink(file.path(fixture$results_path, "sea_sectors.fst.meta"))

  plan <- wlv_fixture_request(fixture, mode = "recalculate")
  expect_error(
    preflight_environment$wlv_validate_data(plan),
    "[Mm]eta|sea_sectors\\.fst\\.meta"
  )
})

test_that("recalculation pairs source and result matrices by metadata years", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  saveRDS(
    list(dim = c(1L, 1L, 1L), "2001", "row", "column"),
    file.path(fixture$results_path, "m_io-result.fst.meta")
  )

  plan <- wlv_fixture_request(fixture, mode = "recalculate")
  expect_error(
    preflight_environment$wlv_validate_data(plan),
    "[Pp]eriod|[Yy]ear|[Cc]orrespond|2000|2001"
  )
})

test_that("stage five recalculation does not require matrix files", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  unlink(
    c(
      list.files(
        fixture$source_path,
        pattern = "^m_io.*\\.fst(\\.meta)?$",
        full.names = TRUE
      ),
      list.files(
        fixture$results_path,
        pattern = "^m_io.*\\.fst(\\.meta)?$",
        full.names = TRUE
      )
    )
  )

  plan <- wlv_fixture_request(fixture, mode = "recalculate", at_stage = 5L)
  expect_no_error(preflight_environment$wlv_validate_data(plan))
})

test_that("complete calculate and recalculate fixtures pass preflight", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  calculate_plan <- wlv_fixture_request(fixture)
  recalculate_plan <- wlv_fixture_request(fixture, mode = "recalculate")

  expect_no_error(preflight_environment$wlv_validate_data(calculate_plan))
  expect_no_error(preflight_environment$wlv_validate_data(recalculate_plan))
})
