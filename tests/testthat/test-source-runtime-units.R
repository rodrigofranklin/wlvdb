wlv_source_runtime_fixture <- function(solution) {
  environment <- new.env(parent = baseenv())
  environment$stage <- 1L
  environment$source_version <- "fixture"
  environment$lists <- list(
    years = "2000",
    sectors = "S1",
    countries = "C1"
  )
  environment$sea_variables <- data.frame(
    names = "indicator",
    sector_solution = solution,
    country_solution = "sum",
    stage = 0L,
    order = NA_integer_,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  environment$sea_source <- array(
    7,
    dim = c(1L, 1L, 1L, 1L),
    dimnames = list(
      year = "2000",
      variable = "RAW",
      sector = "S1",
      country = "C1"
    )
  )
  environment$sea_sectors <- array(
    NA_real_,
    dim = c(1L, 1L, 1L, 1L),
    dimnames = list(
      year = "2000",
      indicator = "indicator",
      sector = "S1",
      country = "C1"
    )
  )
  environment$meta_indicators <- data.frame(
    observation = NA_character_,
    row.names = "indicator",
    stringsAsFactors = FALSE
  )
  environment
}

test_that("canonical SEA variables are copied without runtime scaling", {
  environment <- wlv_source_runtime_fixture("RAW")

  sys.source(
    file.path(wlv_test_root, "R", "modules", "variables", "sea_sectors.R"),
    envir = environment
  )

  expect_identical(
    unname(environment$sea_sectors[, "indicator", "S1", "C1"]),
    7
  )
})

test_that("legacy scaled SEA expressions fail before data are copied", {
  environment <- wlv_source_runtime_fixture("RAW*1000")

  expect_error(
    sys.source(
      file.path(wlv_test_root, "R", "modules", "variables", "sea_sectors.R"),
      envir = environment
    ),
    "Legacy scaled SEA source expressions"
  )
  expect_true(is.na(environment$sea_sectors[, "indicator", "S1", "C1"]))
})

test_that("native stable output profiles contain identifiers instead of code", {
  paths <- c(
    file.path("config", "outputs", "sources", "wiodr13.csv"),
    file.path("config", "outputs", "sources", "wiodr16.csv")
  )

  for (path in paths) {
    outputs <- utils::read.csv2(
      file.path(wlv_test_root, path),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    expect_identical(names(outputs), "indicator", info = path)
    expect_true(all(grepl("^[a-z][a-z0-9_.]*$", outputs$indicator)), info = path)
    expect_false(any(grepl("[/\\\\]|[.]R$", outputs$indicator)), info = path)
  }
})
