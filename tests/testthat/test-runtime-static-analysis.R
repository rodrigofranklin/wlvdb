runtime_static_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "runtime_static_analysis.R"),
  envir = runtime_static_environment
)

test_that("static analysis identifies direct, qualified, and indirect escapes", {
  root <- tempfile("wlv-static-")
  dir.create(file.path(root, "R", "lib"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  task <- file.path(root, "R", "lib", "task.R")
  writeLines(
    c(
      "run <- function() {",
      "  source('module.R')",
      "  base::sys.source('module.R', envir = new.env())",
      "  setwd('elsewhere')",
      "  assign('value', 1, envir = .GlobalEnv)",
      "  globalenv()",
      "  do.call('source', list('module.R'))",
      "}"
    ),
    task
  )

  violations <- runtime_static_environment$wlv_runtime_static_violations(
    root = root,
    files = task,
    allowlist = character()
  )

  expect_setequal(
    unique(violations$rule),
    c(
      "dynamic_source",
      "working_directory",
      "global_environment",
      "indirect_runtime_escape"
    )
  )
  expect_setequal(
    unique(violations$symbol),
    c("source", "sys.source", "setwd", ".GlobalEnv", "globalenv")
  )
  expect_error(
    runtime_static_environment$wlv_assert_runtime_static_clean(
      root = root,
      files = task,
      allowlist = character()
    ),
    "Forbidden runtime construct"
  )
})

test_that("bootstrap and launcher exceptions never permit global-state escape", {
  root <- tempfile("wlv-static-allow-")
  dir.create(file.path(root, "R", "lib"), recursive = TRUE)
  dir.create(file.path(root, "scripts"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  loader <- file.path(root, "R", "bootstrap.R")
  task <- file.path(root, "R", "lib", "task.R")
  launcher <- file.path(root, "scripts", "run_wlv.R")
  writeLines(c("source('definitions.R')", "setwd('elsewhere')"), loader)
  writeLines("source('definitions.R')", task)
  writeLines("sys.source('R/main.R', envir = .GlobalEnv)", launcher)

  violations <- runtime_static_environment$wlv_runtime_static_violations(
    root = root,
    files = c(loader, task, launcher)
  )

  expect_setequal(
    violations$file,
    c("R/bootstrap.R", "R/lib/task.R", "scripts/run_wlv.R")
  )
  expect_setequal(
    violations$rule,
    c("working_directory", "dynamic_source", "global_environment")
  )
  expect_identical(
    violations$symbol[violations$file == "scripts/run_wlv.R"],
    ".GlobalEnv"
  )
  expect_error(
    runtime_static_environment$wlv_runtime_static_violations(
      root = root,
      files = task,
      allowlist = "R/lib/task.R"
    ),
    "allowlist is restricted"
  )
})

test_that("scientific modules cannot access files, directories, or processes", {
  root <- tempfile("wlv-static-science-")
  dir.create(file.path(root, "R", "modules", "native"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  module <- file.path(root, "R", "modules", "native", "probe.R")
  writeLines(
    c(
      "probe <- function() {",
      "  readRDS('payload.rds')",
      "  file.path('results', 'release')",
      "  system2('Rscript', '--version')",
      "}"
    ),
    module
  )
  violations <- runtime_static_environment$wlv_runtime_static_violations(
    root = root,
    files = module,
    allowlist = character()
  )
  expect_setequal(unique(violations$rule), "scientific_io")
  expect_setequal(
    unique(violations$symbol),
    c("readRDS", "file.path", "system2")
  )
})

test_that("scientific IO cannot be hidden behind aliases or dynamic lookup", {
  root <- tempfile("wlv-static-science-alias-")
  dir.create(file.path(root, "R", "modules", "native"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  module <- file.path(root, "R", "modules", "native", "probe.R")
  writeLines(
    c(
      "probe <- function() {",
      "  reader <- base::readRDS",
      "  second_reader <- reader",
      "  reader('payload.rds')",
      "  second_reader('payload.rds')",
      "  get('writeLines')('payload', 'output.txt')",
      "}"
    ),
    module
  )

  violations <- runtime_static_environment$wlv_runtime_static_violations(
    root = root,
    files = module,
    allowlist = character()
  )
  expect_true(nrow(violations) >= 5L)
  expect_true(all(violations$rule == "scientific_io"))
  expect_true(any(grepl("reader->readRDS", violations$symbol, fixed = TRUE)))
  expect_true(any(violations$symbol == "get"))
})

test_that("scientific IO cannot be hidden behind runtime helpers", {
  root <- tempfile("wlv-static-science-transitive-")
  dir.create(file.path(root, "R", "lib"), recursive = TRUE)
  dir.create(file.path(root, "R", "modules", "native"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  helper <- file.path(root, "R", "lib", "helper.R")
  module <- file.path(root, "R", "modules", "native", "probe.R")
  writeLines(c(
    "unsafe_helper <- function(path) writeLines('payload', path)"
  ), helper)
  writeLines(c(
    "probe <- function(path) unsafe_helper(path)"
  ), module)

  violations <- runtime_static_environment$wlv_runtime_static_violations(
    root = root,
    files = c(helper, module),
    allowlist = character()
  )
  scientific <- violations[violations$file == "R/modules/native/probe.R", ]
  expect_true(nrow(scientific) >= 1L)
  expect_true(any(scientific$rule == "scientific_io"))
  expect_true(any(grepl(
    "unsafe_helper->writeLines",
    scientific$symbol,
    fixed = TRUE
  )))
})

test_that("runtime task code has no implicit execution or global-state escape", {
  bootstrap <- file.path(wlv_test_root, "R", "bootstrap.R")
  skip_if_not(
    file.exists(bootstrap),
    "the deterministic runtime bootstrap has not been integrated yet"
  )
  runtime <- wlv_test_load_runtime()
  reachable_files <- runtime$wlv_runtime_static_files(wlv_test_root)
  expected_launchers <- normalizePath(
    file.path(
      wlv_test_root,
      "scripts",
      c(
        "benchmark_leontief.R", "bootstrap.R",
        "render_method_catalog.R", "run_wlv.R"
      )
    ),
    winslash = "/",
    mustWork = TRUE
  )
  expect_true(all(expected_launchers %in% reachable_files))
  violations <- runtime$wlv_runtime_static_violations(
    root = wlv_test_root,
    files = reachable_files
  )
  details <- if (nrow(violations)) {
    paste(
      sprintf(
        "%s:%s [%s: %s]",
        violations$file,
        ifelse(is.na(violations$line), "?", violations$line),
        violations$rule,
        violations$symbol
      ),
      collapse = "\n"
    )
  } else {
    NULL
  }
  expect_identical(nrow(violations), 0L, info = details)
})
