native_data_environment <- new.env(parent = globalenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "native_data.R"),
  envir = native_data_environment
)

test_that("native semicolon reader preserves the UTF-8 method label", {
  parameters <- native_data_environment$wlv_native_read_semicolon(
    file.path(wlv_test_root, "methods", "norow_w13", "_parameters.csv")
  )
  expected <- "Teste sem suposições para resto do mundo"
  expect_identical(
    charToRaw(enc2utf8(parameters$name[[1L]])),
    charToRaw(enc2utf8(expected))
  )
  expect_false(grepl("\uFFFD", parameters$name[[1L]], fixed = TRUE))
})

test_that("native semicolon reader preserves row names and rejects mojibake", {
  valid <- tempfile(fileext = ".csv")
  writeLines(c("id;value", "a;ok"), valid, useBytes = TRUE)
  parsed <- native_data_environment$wlv_native_read_semicolon(
    valid,
    row.names = 1L
  )
  expect_identical(row.names(parsed), "a")
  expect_identical(parsed$value, "ok")

  invalid <- tempfile(fileext = ".csv")
  writeLines(c("id;value", "a;suposiÃ§ões"), invalid, useBytes = TRUE)
  expect_error(
    native_data_environment$wlv_native_read_semicolon(invalid),
    "invalid UTF-8 text"
  )
})
