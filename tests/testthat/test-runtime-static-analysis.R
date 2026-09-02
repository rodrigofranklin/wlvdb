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

test_that("runtime escapes cannot be hidden behind aliases or target variables", {
  root <- tempfile("wlv-static-runtime-alias-")
  dir.create(file.path(root, "R", "lib"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  task <- file.path(root, "R", "lib", "task.R")
  writeLines(
    c(
      "loader <- base::source",
      "second_loader <- loader",
      "directory_changer <- get('setwd')",
      "environment_reader <- base::globalenv",
      "source_name <- 'sys.source'",
      "runtime_tools <- list(loader = base::source, changer = base::setwd)",
      "selected_loader <- runtime_tools$loader",
      "copied_tools <- runtime_tools",
      "run <- function(tool_name) {",
      "  second_loader('module.R')",
      "  directory_changer('elsewhere')",
      "  environment_reader()",
      "  do.call(source_name, list('module.R'))",
      "  get(source_name)",
      "  match.fun(source_name)",
      "  runtime_tools$loader('module.R')",
      "  runtime_tools[['changer']]('elsewhere')",
      "  runtime_tools[[tool_name]]('module.R')",
      "  selected_loader('module.R')",
      "  copied_tools$loader('module.R')",
      "}"
    ),
    task
  )

  violations <- runtime_static_environment$wlv_runtime_static_violations(
    root = root,
    files = task,
    allowlist = character()
  )

  expect_true(any(violations$rule == "dynamic_source"))
  expect_true(any(violations$rule == "working_directory"))
  expect_true(any(violations$rule == "global_environment"))
  expect_gte(sum(violations$rule == "indirect_runtime_escape"), 3L)
  expect_true(any(grepl(
    "second_loader->source",
    violations$symbol,
    fixed = TRUE
  )))
  expect_true(any(violations$symbol == "sys.source"))
  expect_true(any(grepl(
    "runtime_tools$loader->source",
    violations$symbol,
    fixed = TRUE
  )))
  expect_true(any(grepl(
    "selected_loader->source",
    violations$symbol,
    fixed = TRUE
  )))
  expect_true(any(grepl(
    "copied_tools$loader->source",
    violations$symbol,
    fixed = TRUE
  )))
})

test_that("ordinary data fields named source are not executable aliases", {
  root <- tempfile("wlv-static-source-fields-")
  dir.create(file.path(root, "R", "lib"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  task <- file.path(root, "R", "lib", "task.R")
  writeLines(
    c(
      "run <- function(source, record) {",
      "  selected <- record$source",
      "  payload <- list(source = source, selected = selected)",
      "  data.frame(source = payload$source, value = 1L)",
      "}"
    ),
    task
  )

  expect_identical(
    nrow(runtime_static_environment$wlv_runtime_static_violations(
      root = root,
      files = task,
      allowlist = character()
    )),
    0L
  )
})

test_that("parsed expressions cannot be dynamically evaluated", {
  root <- tempfile("wlv-static-eval-parse-")
  dir.create(file.path(root, "R", "lib"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  task <- file.path(root, "R", "lib", "task.R")
  writeLines(
    c(
      "parser <- base::parse",
      "evaluator <- base::eval",
      "run <- function(text) {",
      "  parsed <- parser(text = text)",
      "  evaluator(parsed)",
      "  caught <- tryCatch(identity(parser(text = text)), error = identity)",
      "  evaluator(caught)",
      "  do.call('eval', list(parse(text = text)))",
      "  lapply(parse(text = text), eval)",
      "  captured <- vector('list', 1L)",
      "  captured[[1L]] <- parsed",
      "  evaluator(captured[[1L]])",
      "  nested <- list(value = identity(str2expression(text)))",
      "  evaluator(nested$value)",
      "  language_tools <- list(parser = base::str2lang, evaluator = base::eval)",
      "  boxed <- list(language_tools$parser(text))",
      "  language_tools$evaluator(boxed[[1L]])",
      "}",
      "safe_parser <- function(path) parse(file = path)"
    ),
    task
  )

  violations <- runtime_static_environment$wlv_runtime_static_violations(
    root = root,
    files = task,
    allowlist = character()
  )

  expect_gte(sum(violations$rule == "dynamic_evaluation"), 7L)
  expect_true(any(grepl("evaluator->eval", violations$symbol, fixed = TRUE)))
  expect_true(any(grepl(
    "language_tools$evaluator->eval",
    violations$symbol,
    fixed = TRUE
  )))
  safe_only <- file.path(root, "R", "lib", "safe.R")
  writeLines("safe_parser <- function(path) parse(file = path)", safe_only)
  expect_identical(
    nrow(runtime_static_environment$wlv_runtime_static_violations(
      root = root,
      files = safe_only,
      allowlist = character()
    )),
    0L
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
  writeLines(c(
    "source('definitions.R')",
    "parsed <- parse(text = 'value <- function() TRUE')",
    "eval(parsed)",
    "setwd('elsewhere')"
  ), loader)
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
    c(
      "working_directory", "dynamic_source", "global_environment",
      "dynamic_evaluation"
    )
  )
  expect_identical(
    sum(
      violations$file == "R/bootstrap.R" &
        violations$rule == "dynamic_evaluation"
    ),
    1L
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

test_that("bootstrap permits exactly its one structurally pinned evaluation", {
  root <- tempfile("wlv-static-bootstrap-eval-")
  dir.create(file.path(root, "R"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  loader <- file.path(root, "R", "bootstrap.R")
  exact_call <- paste0(
    "base::eval(parsed_definitions[[index]], ",
    "envir = namespace)"
  )
  writeLines(c(
    "parsed_definitions <- vector('list', 1L)",
    "parsed_definitions[[1L]] <- parse(text = 'value <- 1')",
    "index <- 1L",
    "namespace <- new.env(parent = baseenv())",
    exact_call
  ), loader)

  exact <- runtime_static_environment$wlv_runtime_static_violations(
    root = root,
    files = loader
  )
  expect_identical(nrow(exact), 0L)

  writeLines(c(
    "parsed_definitions <- vector('list', 1L)",
    "parsed_definitions[[1L]] <- parse(text = 'value <- 1')",
    "index <- 1L",
    "namespace <- new.env(parent = baseenv())",
    exact_call,
    exact_call
  ), loader)
  duplicated <- runtime_static_environment$wlv_runtime_static_violations(
    root = root,
    files = loader
  )
  expect_identical(
    sum(duplicated$rule == "dynamic_evaluation"),
    2L
  )

  writeLines(c(
    "parsed_definitions <- vector('list', 1L)",
    "parsed_definitions[[1L]] <- parse(text = 'value <- 1')",
    "index <- 1L",
    "namespace <- new.env(parent = baseenv())",
    "base::eval(parsed_definitions[[index]], envir = parent.frame())"
  ), loader)
  near_miss <- runtime_static_environment$wlv_runtime_static_violations(
    root = root,
    files = loader
  )
  expect_identical(
    sum(near_miss$rule == "dynamic_evaluation"),
    1L
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

test_that("scientific modules cannot introspect runner frames or bindings", {
  root <- tempfile("wlv-static-science-reflection-")
  dir.create(file.path(root, "R", "modules", "native"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  module <- file.path(root, "R", "modules", "native", "probe.R")
  writeLines(
    c(
      "probe <- function(ctx) {",
      "  environment(ctx$service('module_contract'))",
      "  .BaseNamespaceEnv[['environment']](ctx$service('module_contract'))",
      "  methods::getFunction('environment')",
      "  utils::getAnywhere('sys.frames')$objs[[1L]]()",
      "  utils::getFromNamespace('sys.frames', 'base')()",
      "  base::getExportedValue('base', 'sys.frames')()",
      "  base::dynGet('working')",
      "  base::.Primitive('globalenv')()",
      "  base::asNamespace('base')[['sys.frames']]()",
      "  base:::sys.frames()",
      "  utils::dump.frames(to.file = FALSE)",
      "  methods::findFunction('sys.frames')",
      "  sys.frames()",
      "  base::sys.status()",
      "  parent.frame()",
      "  base::unlockBinding('entries', ctx)",
      "  rlang::env_get(ctx, 'input_store')",
      "}"
    ),
    module
  )

  violations <- runtime_static_environment$wlv_runtime_static_violations(
    root = root,
    files = module,
    allowlist = character()
  )
  scientific <- violations[violations$rule == "scientific_io", , drop = FALSE]

  expect_true(any(scientific$symbol == "environment"))
  expect_true(any(scientific$symbol == ".BaseNamespaceEnv"))
  expect_true(any(scientific$symbol == "methods::getFunction"))
  expect_true(any(scientific$symbol == "getAnywhere"))
  expect_true(any(scientific$symbol == "getFromNamespace"))
  expect_true(any(scientific$symbol == "getExportedValue"))
  expect_true(any(scientific$symbol == "dynGet"))
  expect_true(any(scientific$symbol == ".Primitive"))
  expect_true(any(scientific$symbol == "asNamespace"))
  expect_true(any(scientific$symbol == "sys.frames"))
  expect_true(any(scientific$symbol == "dump.frames"))
  expect_true(any(scientific$symbol == "methods::findFunction"))
  expect_true(any(scientific$symbol == "sys.frames"))
  expect_true(any(scientific$symbol == "sys.status"))
  expect_true(any(scientific$symbol == "parent.frame"))
  expect_true(any(scientific$symbol == "unlockBinding"))
  expect_true(any(scientific$symbol == "rlang::env_get"))
})

test_that("namespaced and higher-order scientific escapes are rejected", {
  root <- tempfile("wlv-static-science-namespaced-")
  dir.create(file.path(root, "R", "modules", "native"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  module <- file.path(root, "R", "modules", "native", "probe.R")
  writeLines(
    c(
      "probe <- function(paths) {",
      "  fs::file_delete(paths[[1L]])",
      "  readr::read_csv(paths[[1L]])",
      "  processx::run('Rscript', '--version')",
      "  processx::process$new('Rscript', '--version')",
      "  base::.Call('native_symbol')",
      "  lapply(paths, base::readRDS)",
      "  purrr::walk(paths, fs::file_delete)",
      "}"
    ),
    module
  )

  violations <- runtime_static_environment$wlv_runtime_static_violations(
    root = root,
    files = module,
    allowlist = character()
  )
  scientific <- violations[violations$rule == "scientific_io", , drop = FALSE]

  expect_true(any(scientific$symbol == "fs::file_delete"))
  expect_true(any(scientific$symbol == "readr::read_csv"))
  expect_true(any(scientific$symbol == "processx::run"))
  expect_true(any(scientific$symbol == "processx::process$new"))
  expect_true(any(scientific$symbol == ".Call"))
  expect_true(any(grepl("lapply->readRDS", scientific$symbol, fixed = TRUE)))
  expect_true(any(grepl(
    "walk->fs::file_delete",
    scientific$symbol,
    fixed = TRUE
  )))
})

test_that("reachable runtime rejects legacy executor paths", {
  root <- tempfile("wlv-static-legacy-path-")
  dir.create(file.path(root, "R", "lib"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  task <- file.path(root, "R", "lib", "task.R")
  writeLines(
    c(
      "legacy <- function() c(",
      "  file.path('R', 'lib', 'computations.R'),",
      "  'R/modules/variables/sea_sectors.R',",
      "  'methods/demo/_method_solutions.csv'",
      ")",
      "public_artifact <- function() '_method_solutions.csv'"
    ),
    task
  )

  violations <- runtime_static_environment$wlv_runtime_static_violations(
    root = root,
    files = task,
    allowlist = character()
  )
  legacy <- violations[violations$rule == "legacy_path", , drop = FALSE]

  expect_gte(nrow(legacy), 3L)
  expect_false(any(legacy$expression == "\"_method_solutions.csv\""))
})

test_that("tests and renv retain their explicit infrastructure exceptions", {
  root <- tempfile("wlv-static-infrastructure-")
  dir.create(file.path(root, "tests", "testthat"), recursive = TRUE)
  dir.create(file.path(root, "renv"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  contents <- c(
    "source('R/lib/computations.R')",
    "setwd('elsewhere')",
    "assign('value', 1, envir = .GlobalEnv)",
    "do.call('source', list('module.R'))",
    "eval(parse(text = 'value <- 1'))",
    "legacy <- 'methods/demo/_method_solutions.csv'"
  )
  test_file <- file.path(root, "tests", "testthat", "helper-probe.R")
  renv_file <- file.path(root, "renv", "activate.R")
  writeLines(contents, test_file)
  writeLines(contents, renv_file)

  violations <- runtime_static_environment$wlv_runtime_static_violations(
    root = root,
    files = c(test_file, renv_file)
  )

  expect_identical(nrow(violations), 0L)
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
