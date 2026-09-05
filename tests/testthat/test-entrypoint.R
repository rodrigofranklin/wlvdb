run_wlv_rscript <- function() {
  file.path(
    R.home("bin"),
    if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  )
}

run_wlv_cli <- function(...) {
  output <- suppressWarnings(system2(
    run_wlv_rscript(),
    c(
      "--vanilla",
      shQuote(file.path(wlv_test_root, "scripts", "run_wlv.R")),
      ...
    ),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status", exact = TRUE)
  locale_warning <- grepl(
    "^(During startup - Warning messages:|[1-9][0-9]*: Setting LC_[A-Z_]+=.*failed ?)$",
    output
  )
  output <- output[!locale_warning]
  if (!is.null(status)) attr(output, "status") <- status
  output
}

wlv_runtime_artifact_inventory <- function() {
  roots <- file.path(wlv_test_root, c("source_data", "results"))
  names(roots) <- c("source_data", "results")
  lapply(roots, function(root) {
    if (!dir.exists(root)) {
      return(data.frame(
        path = character(),
        isdir = logical(),
        size = numeric(),
        mtime = numeric()
      ))
    }
    paths <- sort(list.files(
      root,
      recursive = TRUE,
      full.names = TRUE,
      all.files = TRUE,
      include.dirs = TRUE,
      no.. = TRUE
    ))
    info <- file.info(paths)
    data.frame(
      path = substring(paths, nchar(root) + 2L),
      isdir = info$isdir,
      size = info$size,
      mtime = as.numeric(info$mtime),
      row.names = NULL
    )
  })
}

test_that("bootstrap loads a private runtime without attaching packages", {
  search_before <- search()
  working_directory <- getwd()
  runtime <- wlv_test_load_runtime()

  expect_true(is.function(runtime$prepare_wlv))
  expect_true(is.function(runtime$get_wlv))
  expect_true(is.function(runtime$recalc_wlv))
  expect_identical(parent.env(runtime), baseenv())
  expect_true(environmentIsLocked(runtime))
  expect_true(bindingIsLocked("get_wlv", runtime))
  expect_identical(search(), search_before)
  expect_identical(getwd(), working_directory)
})

test_that("stable source validators are definitions in the private runtime", {
  runtime <- wlv_test_load_runtime()
  catalog <- runtime$wlv_runtime_catalog()

  for (method in c("wiodr13", "wiodr16")) {
    calculate_plan <- runtime$wlv_validate_request(
      method,
      root = wlv_test_root,
      catalog = catalog
    )
    expect_s3_class(calculate_plan, "wlv_run_plan")
    expect_s3_class(
      runtime$wlv_validate_request(
        method,
        repeat_pp = TRUE,
        requested_operations = "prepare",
        root = wlv_test_root,
        catalog = catalog
      ),
      "wlv_run_plan"
    )
    expect_s3_class(
      runtime$wlv_validate_request(
        method,
        mode = "recalculate",
        root = wlv_test_root,
        catalog = catalog
      ),
      "wlv_run_plan"
    )
    validator_id <- calculate_plan$methods$validator_id[[1L]]
    source_id <- calculate_plan$methods$source[[1L]]
    expect_match(validator_id, paste0("^", source_id, "_prepared_v[0-9]+$"))
    validator <- runtime$wlv_load_catalog_validator(
      calculate_plan,
      calculate_plan$methods[1L, , drop = FALSE]
    )
    expect_identical(validator$validator_id, validator_id)
    expect_true(is.function(validator$validate))
    expect_true(is.function(validator$validate_euklems))
  }
  expect_true(exists(
    "wlv_wiodr13_validate_labels",
    envir = runtime,
    mode = "function",
    inherits = FALSE
  ))
  expect_true(exists(
    "wlv_wiodr16_expected_negative_source_k",
    envir = runtime,
    mode = "function",
    inherits = FALSE
  ))
  expect_identical(
    environment(runtime$wlv_validate_wiodr16_prepared),
    runtime
  )
})

test_that("public APIs enforce catalog maturity before side effects", {
  runtime <- wlv_test_load_runtime()

  expect_identical(
    names(formals(runtime$get_wlv)),
    c(
      "methods", "repeat_pp", "papern", "prepaper", "workers",
      "channel", "allow_experimental"
    )
  )
  expect_identical(
    names(formals(runtime$recalc_wlv)),
    c(
      "methods", "at_stage", "sea_vars", "papern", "prepaper", "workers",
      "channel", "allow_experimental"
    )
  )
  expect_identical(
    names(formals(runtime$prepare_wlv)),
    c("methods", "allow_experimental")
  )
  expect_identical(formals(runtime$get_wlv)$papern, 0)
  expect_identical(formals(runtime$get_wlv)$prepaper, FALSE)
  expect_identical(formals(runtime$recalc_wlv)$papern, 0)
  expect_identical(formals(runtime$recalc_wlv)$prepaper, FALSE)
  expect_error(
    runtime$get_wlv("wiodr13", prepaper = TRUE),
    "Paper tooling has been removed",
    fixed = TRUE
  )
  expect_error(
    runtime$recalc_wlv("wiodr13", papern = 1L),
    "Paper tooling has been removed",
    fixed = TRUE
  )

  expect_error(runtime$get_wlv("alternative_1"), "experimental")
  expect_error(runtime$prepare_wlv("alternative_1"), "experimental")
  expect_error(runtime$recalc_wlv("alternative_1"), "experimental")
  expect_error(
    runtime$get_wlv("exiobase395", allow_experimental = TRUE),
    "disabled"
  )
})

test_that("command line entrypoint provides help without project data", {
  output <- run_wlv_cli("--help")

  expect_null(attr(output, "status"))
  expect_true(any(grepl("--method", output, fixed = TRUE)))
  expect_true(any(grepl("--prepare-only", output, fixed = TRUE)))
  expect_true(any(grepl("--channel", output, fixed = TRUE)))
  expect_true(any(grepl("--allow-experimental", output, fixed = TRUE)))
  expect_true(any(grepl("--list-methods", output, fixed = TRUE)))
  expect_false(any(grepl("--paper", output, fixed = TRUE)))
  expect_false(any(grepl("--prepaper", output, fixed = TRUE)))
})

test_that("command line entrypoint rejects removed paper options", {
  for (option in c("--paper=0", "--paper", "--prepaper", "--prepare-paper")) {
    output <- run_wlv_cli(option)
    status <- attr(output, "status", exact = TRUE)

    expect_true(!is.null(status) && status != 0L)
    expect_true(any(grepl("Paper tooling has been removed", output, fixed = TRUE)))
  }
})

test_that("command line activates renv before its first runtime load", {
  launcher <- readLines(
    file.path(wlv_test_root, "scripts", "run_wlv.R"),
    warn = FALSE,
    encoding = "UTF-8"
  )
  activation <- grep(
    'source(file.path(project_root, "renv", "activate.R")',
    launcher,
    fixed = TRUE
  )
  runtime_load <- grep(
    "wlv_load_runtime(project_root)",
    launcher,
    fixed = TRUE
  )

  expect_length(activation, 1L)
  expect_gt(length(runtime_load), 0L)
  expect_lt(activation, min(runtime_load))
})

test_that("command line entrypoint lists the catalog in all supported formats", {
  artifacts_before <- wlv_runtime_artifact_inventory()
  outside <- tempfile("wlv-list-methods-")
  dir.create(outside)
  on.exit(unlink(outside, recursive = TRUE, force = TRUE), add = TRUE)
  previous_directory <- setwd(outside)
  on.exit(setwd(previous_directory), add = TRUE)

  default_output <- run_wlv_cli("--list-methods")
  expect_null(attr(default_output, "status"))
  expect_true(any(grepl("METHOD", default_output, fixed = TRUE)))

  table_output <- run_wlv_cli("--list-methods=table")
  expect_null(attr(table_output, "status"))
  expect_true(any(grepl("METHOD", table_output, fixed = TRUE)))
  expect_true(any(grepl("STATUS", table_output, fixed = TRUE)))
  expect_true(any(grepl("SOURCE_STATUS", table_output, fixed = TRUE)))
  expect_true(any(grepl("wiodr13", table_output, fixed = TRUE)))
  expect_true(any(grepl("exiobase395", table_output, fixed = TRUE)))

  names_output <- run_wlv_cli("--list-methods=names")
  expect_null(attr(names_output, "status"))
  expect_setequal(names_output[nzchar(names_output)], list.dirs(
    file.path(wlv_test_root, "methods"),
    recursive = FALSE,
    full.names = FALSE
  ))

  csv_output <- run_wlv_cli("--list-methods=csv")
  expect_null(attr(csv_output, "status"))
  csv <- utils::read.csv2(
    text = paste(csv_output, collapse = "\n"),
    stringsAsFactors = FALSE
  )
  expect_true(all(c(
    "method", "source", "status", "years", "can_prepare",
    "can_calculate", "can_recalculate"
  ) %in% names(csv)))
  expect_identical(csv$status[csv$method == "wiodr13"], "stable")
  expect_identical(csv$status[csv$method == "exiobase395"], "disabled")
  expect_identical(wlv_runtime_artifact_inventory(), artifacts_before)
})

test_that("command line deferred methods remain non-executable after opt-in", {
  blocked <- run_wlv_cli("--method", "alternative_1", "--check")
  expect_true(!is.null(attr(blocked, "status")) && attr(blocked, "status") != 0L)
  expect_true(any(grepl("experimental", blocked, fixed = TRUE)))
  expect_true(any(grepl("--allow-experimental", blocked, fixed = TRUE)))

  opted_in <- run_wlv_cli(
    "--method", "alternative_1", "--allow-experimental", "--check"
  )
  expect_true(
    !is.null(attr(opted_in, "status")) && attr(opted_in, "status") != 0L
  )
  expect_true(any(grepl(
    "does not support operation(s): calculate",
    opted_in,
    fixed = TRUE
  )))
})

test_that("command line disabled methods cannot be enabled by opt-in", {
  output <- run_wlv_cli(
    "--method", "exiobase395", "--allow-experimental", "--check"
  )

  expect_true(!is.null(attr(output, "status")) && attr(output, "status") != 0L)
  expect_true(any(grepl("disabled", output, fixed = TRUE)))
})

test_that("command line check does not create or modify runtime artifacts", {
  before <- wlv_runtime_artifact_inventory()
  output <- run_wlv_cli("--method", "wiodr13", "--check")
  after <- wlv_runtime_artifact_inventory()

  expect_null(attr(output, "status"))
  expect_identical(after, before)
})

test_that("prepare-only can be checked without downloading data", {
  rscript <- file.path(
    R.home("bin"),
    if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  )
  output <- system2(
    rscript,
    c(
      "--vanilla",
      shQuote(file.path(wlv_test_root, "scripts", "run_wlv.R")),
      "--method", "wiodr13", "--prepare-only", "--check"
    ),
    stdout = TRUE,
    stderr = TRUE
  )

  expect_null(attr(output, "status"))
  expect_true(any(grepl("Environment and arguments are valid", output, fixed = TRUE)))
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
