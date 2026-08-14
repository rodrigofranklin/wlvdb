test_that("main can be sourced without attaching packages", {
  search_before <- search()
  environment <- new.env(parent = globalenv())
  old_wd <- setwd(wlv_test_root)
  on.exit(setwd(old_wd), add = TRUE)

  sys.source(file.path(wlv_test_root, "R", "main.R"), envir = environment)

  expect_true(is.function(environment$get_wlv))
  expect_true(is.function(environment$recalc_wlv))
  expect_identical(search(), search_before)
})

test_that("command line entrypoint provides help without project data", {
  rscript <- file.path(
    R.home("bin"),
    if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  )
  output <- system2(
    rscript,
    c(
      "--vanilla",
      shQuote(file.path(wlv_test_root, "scripts", "run_wlv.R")),
      "--help"
    ),
    stdout = TRUE,
    stderr = TRUE
  )

  expect_null(attr(output, "status"))
  expect_true(any(grepl("--method", output, fixed = TRUE)))
})

test_that("command line validation rejects unknown and unsafe methods", {
  rscript <- file.path(
    R.home("bin"),
    if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  )
  entrypoint <- shQuote(file.path(wlv_test_root, "scripts", "run_wlv.R"))

  for (method in c("does-not-exist", "../wiodr13")) {
    output <- suppressWarnings(system2(
      rscript,
      c("--vanilla", entrypoint, "--method", method, "--check"),
      stdout = TRUE,
      stderr = TRUE
    ))

    status <- attr(output, "status")
    expect_true(!is.null(status) && status != 0L)
    expect_true(any(grepl("Unknown or invalid method", output, fixed = TRUE)))
  }
})

test_that("command line entrypoint never calculates implicitly", {
  rscript <- file.path(
    R.home("bin"),
    if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  )
  output <- suppressWarnings(system2(
    rscript,
    c("--vanilla", shQuote(file.path(wlv_test_root, "scripts", "run_wlv.R"))),
    stdout = TRUE,
    stderr = TRUE
  ))

  expect_identical(attr(output, "status"), 2L)
  expect_true(any(grepl("Usage:", output, fixed = TRUE)))
})
