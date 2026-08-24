paper_environment <- new.env(parent = baseenv())
for (path in c(
  file.path("R", "lib", "paper_tasks.R"),
  file.path("R", "utils", "papers", "paper_0_selection.R"),
  file.path("R", "utils", "papers", "paper_3_selection.R"),
  file.path("R", "utils", "papers", "paper_4_selection.R")
)) {
  sys.source(file.path(wlv_test_root, path), envir = paper_environment)
}

wlv_paper_test_arrays <- function(multiplier = 1) {
  years <- c("2008", "2009")
  countries <- c("BRA", "USA", "JPN", "MEX")
  sectors <- c("A", "B")
  sector_indicators <- c("gross_output.s.us", "gross_output.s.du")
  country_indicators <- c(
    "gross_output.s.us",
    "gross_output.s.du",
    "gdp.s.us",
    "gdp.s.du",
    "surplus_value.empe.r.pc",
    "surplus_value.empe_hs.r.pc",
    "surplus_value.empe_ms.r.pc",
    "surplus_value.empe_ls.r.pc",
    "gdp.s.mv"
  )

  m_countries <- array(
    multiplier * seq_len(length(years) * length(countries)^2),
    dim = c(length(years), 1L, length(countries), length(countries)),
    dimnames = list(
      years,
      "transfers_productive_values",
      countries,
      countries
    )
  )
  sea_sectors <- array(
    multiplier * seq_len(
      length(years) * length(sector_indicators) *
        length(sectors) * length(countries)
    ),
    dim = c(
      length(years),
      length(sector_indicators),
      length(sectors),
      length(countries)
    ),
    dimnames = list(years, sector_indicators, sectors, countries)
  )
  sea_countries <- array(
    multiplier * seq_len(
      length(years) * length(country_indicators) * (length(countries) + 1L)
    ) + 100,
    dim = c(
      length(years),
      length(country_indicators),
      length(countries) + 1L
    ),
    dimnames = list(
      years,
      country_indicators,
      c(countries, "WWW")
    )
  )
  list(
    m_countries = m_countries,
    sea_sectors = sea_sectors,
    sea_countries = sea_countries
  )
}

wlv_make_paper_test_context <- function(arrays_by_method) {
  root <- tempfile("wlv-paper-")
  dir.create(root, recursive = TRUE)
  methods <- names(arrays_by_method)
  result_dirs <- setNames(file.path(root, methods), methods)
  for (method in methods) {
    dir.create(result_dirs[[method]])
    saveRDS(
      arrays_by_method[[method]]$m_countries,
      file.path(result_dirs[[method]], "m_countries.fst")
    )
    saveRDS(
      arrays_by_method[[method]]$sea_sectors,
      file.path(result_dirs[[method]], "sea_sectors.fst")
    )
    saveRDS(
      arrays_by_method[[method]]$sea_countries,
      file.path(result_dirs[[method]], "sea_countries.fst")
    )
  }
  context <- paper_environment$wlv_new_paper_context(
    methods = methods,
    result_dirs = result_dirs,
    release_dir = root,
    output_dir = root,
    required_artifacts = c(
      "m_countries.fst",
      "sea_sectors.fst",
      "sea_countries.fst"
    ),
    reader = readRDS,
    workbook_writer = function(sheets, path) {
      saveRDS(sheets, path)
    }
  )
  list(root = root, context = context)
}

test_that("the native paper registry supports only paper 0", {
  registry <- paper_environment$wlv_default_paper_registry()

  expect_s3_class(registry[["0"]], "wlv_paper_spec")
  expect_true(registry[["0"]]$supported)
  expect_false(registry[["3"]]$supported)
  expect_false(registry[["4"]]$supported)
  expect_identical(
    paper_environment$wlv_validate_paper_request(0L, TRUE, registry)$id,
    0L
  )
  expect_error(
    paper_environment$wlv_validate_paper_request(3L, FALSE, registry),
    "Paper `3` is unsupported"
  )
  expect_error(
    paper_environment$wlv_validate_paper_request(3L, TRUE, registry),
    "Paper `3` is unsupported"
  )
  expect_error(
    paper_environment$wlv_validate_paper_request(4L, TRUE, registry),
    "Paper `4` is unsupported"
  )
  expect_error(
    paper_environment$wlv_validate_paper_request(99L, TRUE, registry),
    "not registered.*Supported paper\\(s\\): 0"
  )
})

test_that("paper contexts expose only declared, locked capabilities", {
  fixture <- wlv_make_paper_test_context(list(demo = wlv_paper_test_arrays()))
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  expect_true(environmentIsLocked(fixture$context))
  expect_identical(fixture$context$methods(), "demo")
  expect_error(fixture$context$extra <- TRUE, "locked")
  expect_error(
    fixture$context$read_result("demo", "not-declared.fst"),
    "does not authorize"
  )
  expect_error(
    fixture$context$read_result("../demo", "m_countries.fst"),
    "safe path component"
  )
  expect_error(
    fixture$context$write_workbook("../escape.xlsx", list(data.frame(x = 1))),
    "safe path component"
  )
})

test_that("release paper contexts expose only methods selected by the run plan", {
  root <- tempfile("wlv-paper-release-")
  results <- file.path(root, "results")
  release_dir <- file.path(results, "releases", "release-test")
  dir.create(release_dir, recursive = TRUE)
  methods <- c("requested", "previous")
  runs <- lapply(methods, function(method) {
    relative <- file.path("runs", method, "run-test", "manifest.json")
    path <- file.path(results, relative)
    dir.create(dirname(path), recursive = TRUE)
    writeLines("{}", path)
    list(method = method, manifest_path = gsub("\\\\", "/", relative))
  })
  release <- list(root = release_dir, manifest = list(runs = runs))
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  context <- paper_environment$wlv_new_release_paper_context(
    project_root = root,
    release = release,
    paper = paper_environment$wlv_resolve_paper(0L),
    reader = readRDS,
    selected_methods = "requested",
    workbook_writer = function(sheets, path) saveRDS(sheets, path)
  )
  expect_identical(context$methods(), "requested")
  expect_error(
    paper_environment$wlv_new_release_paper_context(
      project_root = root,
      release = release,
      paper = paper_environment$wlv_resolve_paper(0L),
      reader = readRDS,
      selected_methods = "missing",
      workbook_writer = function(sheets, path) saveRDS(sheets, path)
    ),
    "no selected method"
  )
})

test_that("paper 0 produces the legacy workbook tables through explicit context", {
  first <- wlv_paper_test_arrays(1)
  second <- wlv_paper_test_arrays(2)
  second$sea_sectors <- second$sea_sectors[
    , rev(dimnames(second$sea_sectors)[[2L]]), , , drop = FALSE
  ]
  second$sea_countries <- second$sea_countries[
    , rev(dimnames(second$sea_countries)[[2L]]), , drop = FALSE
  ]
  fixture <- wlv_make_paper_test_context(list(
    alternative_1 = first,
    zerodep_1 = second
  ))
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  paper <- paper_environment$wlv_resolve_paper(0L)

  result <- paper_environment$wlv_run_paper_task(
    paper,
    fixture$context,
    namespace_checker = function(package) TRUE
  )

  expect_s3_class(result, "wlv_paper_result")
  expect_identical(basename(result$output), "reduction_problem.xlsx")
  expect_true(file.exists(result$output))
  expect_length(result$sheets, 11L)
  expect_identical(dim(result$sheets[[1L]]), c(8L, 3L))
  expect_identical(names(result$sheets[[1L]]), c(
    "market_prices", "alternative_1", "zerodep_1"
  ))
  expect_identical(dim(result$sheets[[2L]]), c(4L, 5L))
  expect_identical(names(result$sheets[[2L]]), c(
    "mp", "alternative_1", "X.", "zerodep_1", "X..1"
  ))
  expect_identical(dim(result$sheets[[3L]]), c(4L, 5L))
  expect_identical(names(result$sheets[[3L]]), c(
    "mp", "alternative_1", "X.", "zerodep_1", "X..1"
  ))
  expect_identical(dim(result$sheets[[4L]]), c(5L, 2L))
  expect_identical(dim(result$sheets[[5L]]), c(5L, 6L))
  expect_identical(dim(result$sheets[[9L]]), c(4L, 2L))
  expect_identical(readRDS(result$output), result$sheets)
})

test_that("paper 0 rejects incompatible method result axes before writing", {
  first <- wlv_paper_test_arrays(1)
  second <- wlv_paper_test_arrays(2)
  dimnames(second$sea_sectors)[[4L]][[1L]] <- "ARG"
  fixture <- wlv_make_paper_test_context(list(first = first, second = second))
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  expect_error(
    paper_environment$wlv_run_paper_task(
      paper_environment$wlv_resolve_paper(0L),
      fixture$context,
      namespace_checker = function(package) TRUE
    ),
    "compatible `sea_sectors` axes"
  )
  expect_false(file.exists(file.path(fixture$root, "reduction_problem.xlsx")))
})

test_that("paper workbook writes are atomic when the writer fails", {
  arrays <- list(demo = wlv_paper_test_arrays())
  fixture <- wlv_make_paper_test_context(arrays)
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  target <- file.path(fixture$root, "reduction_problem.xlsx")
  saveRDS(list(previous = TRUE), target)
  previous <- readBin(target, what = "raw", n = file.info(target)$size)
  context <- paper_environment$wlv_new_paper_context(
    methods = "demo",
    result_dirs = c(demo = file.path(fixture$root, "demo")),
    release_dir = fixture$root,
    output_dir = fixture$root,
    required_artifacts = c(
      "m_countries.fst",
      "sea_sectors.fst",
      "sea_countries.fst"
    ),
    reader = readRDS,
    workbook_writer = function(sheets, path) {
      saveRDS(sheets, path)
      stop("injected workbook failure", call. = FALSE)
    }
  )

  expect_error(
    context$write_workbook(
      "reduction_problem.xlsx",
      list(sheet = data.frame(value = 1L))
    ),
    "injected workbook failure",
    fixed = TRUE
  )
  expect_identical(
    readBin(target, what = "raw", n = file.info(target)$size),
    previous
  )
  expect_false(any(grepl(
    "^[.]reduction_problem-",
    list.files(fixture$root, all.files = TRUE)
  )))
})
