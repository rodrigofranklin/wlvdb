test_that("complete IO periods reuse the assembled artifact", {
  runtime <- wlv_test_load_runtime()
  years <- c("2000", "2001", "2002")
  value <- array(
    as.double(seq_len(3L * 2L * 2L * 2L)),
    dim = c(3L, 2L, 2L, 2L),
    dimnames = list(
      year = years,
      variable = c("a", "b"),
      input = c("i1", "i2"),
      output = c("o1", "o2")
    )
  )

  skip_if_not(capabilities("profmem"))
  original_address <- tracemem(value)
  on.exit(untracemem(value), add = TRUE)
  complete <- runtime$wlv_native_select_io_years(value, years)
  expect_identical(tracemem(complete), original_address)

  subset <- runtime$wlv_native_select_io_years(value, years[c(1L, 3L)])
  expect_false(identical(tracemem(subset), original_address))
  expect_identical(
    subset,
    value[years[c(1L, 3L)], , , , drop = FALSE]
  )
})

test_that("native result retention keeps only post-run deliverables", {
  runtime <- wlv_test_load_runtime()
  catalog <- data.frame(
    locator_id = paste0("locator-", seq_len(17L)),
    key = c(
      "configuration/parameters",
      "configuration/sectors",
      "metadata/indicators",
      "intermediate/lambda",
      "semantic_state/intermediate/lambda",
      "artifact/sea_sectors",
      "semantic_state/artifact/sea_sectors",
      "io/1995-2009",
      "semantic_state/io/1995-2009",
      "sea/sector/value",
      "sea/country/value",
      "semantic_state/sea/sector/value",
      "semantic_state/sea/country/value",
      "module/anomaly",
      "module/metadata",
      "module/diagnostic",
      "intermediate/dead"
    ),
    role = c(
      rep("value", 13L),
      "anomaly",
      "metadata",
      "diagnostic",
      "value"
    ),
    stringsAsFactors = FALSE
  )
  module_plan <- new.env(parent = emptyenv())
  module_plan$terminal_catalog <- catalog
  class(module_plan) <- "wlv_module_plan"
  lockEnvironment(module_plan, bindings = TRUE)

  retained <- runtime$wlv_native_result_locator_ids(module_plan)

  expect_identical(retained, catalog$locator_id[-17L])
  expect_false(catalog$locator_id[[17L]] %in% retained)
})
