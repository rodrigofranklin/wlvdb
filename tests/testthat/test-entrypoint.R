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

test_that("main can be sourced without attaching packages", {
  search_before <- search()
  environment <- new.env(parent = globalenv())
  old_wd <- setwd(wlv_test_root)
  on.exit(setwd(old_wd), add = TRUE)

  sys.source(file.path(wlv_test_root, "R", "main.R"), envir = environment)

  expect_true(is.function(environment$prepare_wlv))
  expect_true(is.function(environment$get_wlv))
  expect_true(is.function(environment$recalc_wlv))
  expect_identical(search(), search_before)
})

test_that("stable source validators load from their catalog declarations", {
  environment <- new.env(parent = globalenv())
  old_wd <- setwd(wlv_test_root)
  on.exit(setwd(old_wd), add = TRUE)
  sys.source(file.path(wlv_test_root, "R", "main.R"), envir = environment)

  for (method in c("wiodr13", "wiodr16")) {
    calculate_plan <- environment$wlv_validate_request(
      method,
      catalog = environment$method_catalog
    )
    expect_s3_class(calculate_plan, "wlv_run_plan")
    expect_s3_class(
      environment$wlv_validate_request(
        method,
        repeat_pp = TRUE,
        requested_operations = "prepare",
        catalog = environment$method_catalog
      ),
      "wlv_run_plan"
    )
    expect_s3_class(
      environment$wlv_validate_request(
        method,
        mode = "recalculate",
        catalog = environment$method_catalog
      ),
      "wlv_run_plan"
    )
    bundle <- environment$wlv_load_catalog_validator(
      calculate_plan,
      calculate_plan$methods[1L, , drop = FALSE]
    )
    expect_true(is.function(bundle$validate))
    expect_identical(parent.env(bundle$environment), baseenv())
    if (method == "wiodr16") {
      expect_true(exists(
        "wlv_wiodr13_validate_labels",
        envir = bundle$environment,
        inherits = FALSE
      ))
      expect_true(exists(
        "wlv_wiodr16_expected_negative_source_k",
        envir = bundle$environment,
        inherits = FALSE
      ))
    }
    expect_false(exists(
      calculate_plan$methods$validator_function[[1L]],
      envir = environment,
      inherits = FALSE
    ))
  }
})

test_that("public APIs enforce catalog maturity before side effects", {
  environment <- new.env(parent = globalenv())
  old_wd <- setwd(wlv_test_root)
  on.exit(setwd(old_wd), add = TRUE)
  sys.source(file.path(wlv_test_root, "R", "main.R"), envir = environment)

  expect_identical(
    names(formals(environment$get_wlv)),
    c(
      "methods", "repeat_pp", "papern", "prepaper", "workers",
      "channel", "allow_experimental"
    )
  )
  expect_identical(
    names(formals(environment$recalc_wlv)),
    c(
      "methods", "at_stage", "sea_vars", "papern", "prepaper", "workers",
      "channel", "allow_experimental"
    )
  )
  expect_identical(
    names(formals(environment$prepare_wlv)),
    c("methods", "allow_experimental")
  )

  expect_error(environment$get_wlv("alternative_1"), "experimental")
  expect_error(environment$prepare_wlv("alternative_1"), "experimental")
  expect_error(environment$recalc_wlv("alternative_1"), "experimental")
  expect_error(
    environment$get_wlv("exiobase395", allow_experimental = TRUE),
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

test_that("command line experimental access requires the explicit flag", {
  blocked <- run_wlv_cli("--method", "alternative_1", "--check")
  expect_true(!is.null(attr(blocked, "status")) && attr(blocked, "status") != 0L)
  expect_true(any(grepl("experimental", blocked, fixed = TRUE)))
  expect_true(any(grepl("--allow-experimental", blocked, fixed = TRUE)))

  allowed <- run_wlv_cli(
    "--method", "alternative_1", "--allow-experimental", "--check"
  )
  expect_null(attr(allowed, "status"))
  expect_true(any(grepl(
    "Environment and arguments are valid",
    allowed,
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
  output <- run_wlv_cli(
    "--method", "alternative_1", "--allow-experimental", "--check"
  )
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
