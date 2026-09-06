test_that("generated method documentation matches the canonical catalog", {
  rscript <- file.path(
    R.home("bin"),
    if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  )
  renderer <- file.path(wlv_test_root, "scripts", "render_method_catalog.R")
  output <- system2(
    rscript,
    c("--vanilla", shQuote(renderer), "--check"),
    stdout = TRUE,
    stderr = TRUE
  )

  expect_null(attr(output, "status"), info = paste(output, collapse = "\n"))
  expect_true(any(grepl("is synchronized", output, fixed = TRUE)))

  document <- readLines(
    file.path(wlv_test_root, "docs", "methods.md"),
    warn = FALSE,
    encoding = "UTF-8"
  )
  expect_true(any(grepl("| Validation ID |", document, fixed = TRUE)))
  expect_true(any(grepl("| Validator ID |", document, fixed = TRUE)))
  expect_true(any(grepl("| Policy | Documentation |", document, fixed = TRUE)))
  expect_true(any(grepl("`wiodr13_scientific_v1`", document, fixed = TRUE)))
  expect_true(any(grepl("`wiodr13_prepared_v1`", document, fixed = TRUE)))
  expect_false(any(grepl("Test/fixture", document, fixed = TRUE)))
  expect_false(any(grepl("| Policy | Script | Factory |", document, fixed = TRUE)))
  expect_false(any(grepl("tests/testthat/test-wiodr13-validation.R", document, fixed = TRUE)))
  expect_false(any(grepl("scripts/lib/missingness.R", document, fixed = TRUE)))
})
