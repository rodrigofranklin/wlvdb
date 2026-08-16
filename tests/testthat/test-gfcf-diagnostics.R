gfcf_diagnostic_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "gfcf_diagnostics.R"),
  envir = gfcf_diagnostic_environment
)

test_that("negative GFCF diagnostics preserve every transformation and unit", {
  observed <- data.frame(
    year = c("2001", "2000", "2000"),
    input = c("USA.E37-E39", "MLT.C24", "CYP.C22"),
    output = c("USA.c60", "MLT.c60", "CYP.c60"),
    value = c(-76000000, -2000000, -1000000),
    policy_id = rep("wiodr16_negative_gfcf_v1", 3L),
    action = rep("truncate_allowlisted_negative_gfcf", 3L),
    stringsAsFactors = FALSE
  )
  artifacts <-
    gfcf_diagnostic_environment$wlv_gfcf_diagnostic_artifacts(
      observed,
      method = "wiodr16",
      input_unit = "usd"
    )

  expect_identical(
    names(artifacts),
    c("_gfcf_negative_cells.csv", "_gfcf_negative_summary.csv")
  )
  cells <- artifacts[["_gfcf_negative_cells.csv"]]
  expect_identical(cells$absolute_rank, 1:3)
  expect_equal(cells$original_million_usd, c(-76, -2, -1))
  expect_equal(cells$applied_million_usd, rep(0, 3L))
  expect_equal(cells$delta_million_usd, c(76, 2, 1))
  expect_identical(cells$supplying_country, c("USA", "MLT", "CYP"))
  expect_identical(cells$supplying_sector, c("E37-E39", "C24", "C22"))
  expect_identical(cells$investing_country, c("USA", "MLT", "CYP"))

  summary <- artifacts[["_gfcf_negative_summary.csv"]]
  total <- summary[summary$scope == "total", , drop = FALSE]
  expect_identical(total$cell_count, 3L)
  expect_equal(total$original_total_million_usd, -79)
  expect_equal(total$removed_mass_million_usd, 79)
  expect_equal(total$largest_negative_cell_million_usd, -76)
  expect_setequal(
    summary$scope,
    c(
      "total", "year", "investing_country", "supplying_country",
      "supplying_sector"
    )
  )

  expect_no_error(
    gfcf_diagnostic_environment$wlv_validate_gfcf_diagnostic_artifacts(
      artifacts,
      method = "wiodr16",
      profile_validator = function(...) invisible(TRUE)
    )
  )
  changed <- artifacts
  changed[["_gfcf_negative_cells.csv"]]$delta_million_usd[[1L]] <- 75
  expect_error(
    gfcf_diagnostic_environment$wlv_validate_gfcf_diagnostic_artifacts(
      changed,
      method = "wiodr16",
      profile_validator = function(...) invisible(TRUE)
    ),
    "differ from the pinned profile",
    fixed = TRUE
  )
})

test_that("negative GFCF diagnostics reject nonnegative or malformed inputs", {
  observed <- data.frame(
    year = "2000",
    input = "USA.E37-E39",
    output = "USA.c60",
    value = 1,
    policy_id = "wiodr16_negative_gfcf_v1",
    action = "truncate_allowlisted_negative_gfcf",
    stringsAsFactors = FALSE
  )
  expect_error(
    gfcf_diagnostic_environment$wlv_gfcf_diagnostic_artifacts(
      observed,
      "wiodr16"
    ),
    "finite negative values",
    fixed = TRUE
  )
  observed$value <- -1
  observed$output <- "USA.other"
  expect_error(
    gfcf_diagnostic_environment$wlv_gfcf_diagnostic_artifacts(
      observed,
      "wiodr16"
    ),
    "invalid WIOD labels",
    fixed = TRUE
  )

  missing_dir <- tempfile("wlv-missing-gfcf-sidecars-")
  dir.create(missing_dir)
  on.exit(unlink(missing_dir, recursive = TRUE, force = TRUE), add = TRUE)
  expect_error(
    gfcf_diagnostic_environment$wlv_load_gfcf_diagnostic_artifacts(
      missing_dir,
      "wiodr16"
    ),
    "Run a full calculation first",
    fixed = TRUE
  )
})
