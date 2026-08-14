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
})
