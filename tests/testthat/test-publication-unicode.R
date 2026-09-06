test_that("published CSV text survives non-UTF-8 locales without changing numbers", {
  runtime <- wlv_test_load_runtime()
  original_locale <- Sys.getlocale("LC_CTYPE")
  on.exit(Sys.setlocale("LC_CTYPE", original_locale), add = TRUE)
  paths <- c(tempfile(fileext = ".csv"), tempfile(fileext = ".csv"))
  on.exit(unlink(paths), add = TRUE)
  # Escapes make the fixture independent of the encoding used to parse tests.
  label <- paste0("\u00cdndice; \"produ\u00e7\u00e3o\" \u2014 \u4e2d\u6587")
  column_name <- "descri\u00e7\u00e3o"
  original <- data.frame(
    id = c("present", "missing", "factor"),
    label = c(label, NA_character_, "line\nnext"),
    category = factor(c("a\u00e7\u00e3o", NA, "other")),
    amount = c(1234.25, NA_real_, -0.000125),
    flag = c(TRUE, NA, FALSE), stringsAsFactors = FALSE
  )
  names(original)[[2L]] <- column_name
  locales <- unique(c(original_locale, "C"))
  for (locale in locales) {
    expect_identical(Sys.setlocale("LC_CTYPE", locale), locale)
    immutable <- serialize(original, NULL)
    runtime$wlv_write_result_csv(original, paths[[1L]])
    bytes <- runtime$wlv_read_file_raw(paths[[1L]])
    decoded <- rawToChar(bytes)
    Encoding(decoded) <- "UTF-8"
    expect_true(grepl(label, gsub('""', '"', decoded, fixed = TRUE), fixed = TRUE))
    expect_false(grepl("<U+", decoded, fixed = TRUE))
    observed <- runtime$wlv_read_panel_result_csv(paths[[1L]], names(original))
    expect_identical(names(observed), names(original))
    expect_identical(observed[[column_name]], original[[column_name]])
    expect_identical(observed$category, as.character(original$category))
    expect_identical(observed$amount, original$amount)
    expect_identical(observed$flag, original$flag)
    expect_identical(serialize(original, NULL), immutable)
    runtime$wlv_write_result_csv(original[FALSE, ], paths[[2L]])
    expect_identical(names(runtime$wlv_read_panel_result_csv(paths[[2L]],
      names(original))), names(original))
  }
})

test_that("published CSV retains legacy ASCII bytes and numeric formatting", {
  runtime <- wlv_test_load_runtime()
  paths <- c(tempfile(fileext = ".csv"), tempfile(fileext = ".csv"))
  on.exit(unlink(paths), add = TRUE)
  original <- data.frame(
    label = c("plain", 'quote " and ; separator', "line\nnext", NA, ""),
    category = factor(c("x", "y", "x", NA, "y")),
    amount = c(1.234567890123456, -0.000125, 1e20, NA, 0),
    integer = c(1L, -1L, NA_integer_, 0L, 7L),
    flag = c(TRUE, FALSE, NA, TRUE, FALSE), stringsAsFactors = FALSE
  )
  utils::write.csv2(original, paths[[1L]], row.names = FALSE,
    na = "", fileEncoding = "UTF-8")
  runtime$wlv_write_result_csv(original, paths[[2L]])
  expect_identical(runtime$wlv_read_file_raw(paths[[2L]]),
    runtime$wlv_read_file_raw(paths[[1L]]))
})

test_that("published CSV rejects invalid Unicode before writing", {
  runtime <- wlv_test_load_runtime()
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  expect_error(runtime$wlv_write_result_csv(data.frame(label = "\ufffd"), path),
    "invalid UTF-8", fixed = TRUE)
  expect_false(file.exists(path))
})
