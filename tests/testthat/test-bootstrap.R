test_that("runtime manifest is explicit, ordered, and excludes legacy executors", {
  bootstrap <- new.env(parent = baseenv())
  sys.source(file.path(wlv_test_root, "R", "bootstrap.R"), envir = bootstrap)

  manifest <- bootstrap$wlv_runtime_definition_manifest()
  files <- bootstrap$wlv_runtime_definition_files(wlv_test_root)
  relative <- gsub("\\\\", "/", substring(
    files,
    nchar(normalizePath(wlv_test_root, winslash = "/", mustWork = TRUE)) + 2L
  ))

  expect_identical(relative, manifest)
  expect_identical(tail(manifest, 2L), c("R/lib/execution.R", "R/main.R"))
  expect_identical(anyDuplicated(manifest), 0L)
  expect_false(any(grepl("paper", manifest, ignore.case = TRUE)))
  expect_false(any(grepl(
    paste0(
      "^R/(lib/(computations|re_computations)[.]R|",
      "modules/(assumptions|matrices|reduced_matrices|variables)/)"
    ),
    manifest
  )))
})

test_that("bootstrap evaluates the exact captured and validated expressions", {
  bootstrap <- new.env(parent = baseenv())
  sys.source(file.path(wlv_test_root, "R", "bootstrap.R"), envir = bootstrap)
  definition <- tempfile("wlv-bootstrap-captured-", fileext = ".R")
  on.exit(unlink(definition, force = TRUE), add = TRUE)
  writeLines(
    "captured_value <- function() 'captured'",
    definition,
    useBytes = TRUE
  )
  captured <- bootstrap$wlv_bootstrap_capture_definitions(
    definition,
    "R/lib/captured.R"
  )
  writeLines(
    "captured_value <- function() 'changed'",
    definition,
    useBytes = TRUE
  )
  expressions <- parse(
    text = bootstrap$wlv_bootstrap_definition_text(
      captured$bytes[[1L]],
      "R/lib/captured.R"
    ),
    encoding = "UTF-8"
  )
  bootstrap$wlv_bootstrap_validate_definitions(
    expressions,
    "R/lib/captured.R"
  )
  namespace <- new.env(parent = baseenv())
  eval(expressions, envir = namespace)

  expect_identical(namespace$captured_value(), "captured")
  expect_identical(
    unname(captured$sha256),
    unclass(as.character(openssl::sha256(captured$bytes[[1L]])))
  )
  loader <- paste(deparse(body(bootstrap$wlv_load_runtime)), collapse = "\n")
  expect_match(loader, "eval\\(parsed_definitions", perl = TRUE)
  expect_false(grepl("sys.source", loader, fixed = TRUE))
  expect_false(grepl("parse(file", loader, fixed = TRUE))
})

test_that("runtime cannot attest a bootstrap loaded from another root", {
  bootstrap <- new.env(parent = baseenv())
  sys.source(file.path(wlv_test_root, "R", "bootstrap.R"), envir = bootstrap)
  other_root <- tempfile("wlv-bootstrap-other-root-")
  dir.create(other_root)
  on.exit(unlink(other_root, recursive = TRUE, force = TRUE), add = TRUE)
  relative <- c("R/bootstrap.R", bootstrap$wlv_runtime_definition_manifest())
  for (path in relative) {
    source <- file.path(wlv_test_root, path)
    destination <- file.path(other_root, path)
    dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    expect_true(file.copy(source, destination, overwrite = FALSE))
  }
  path <- file.path(other_root, "R", "bootstrap.R")
  text <- readLines(path, warn = FALSE, encoding = "UTF-8")
  target <- "The runtime definition manifest is invalid."
  replacement <- "The selected runtime definition manifest is invalid."
  expect_true(any(grepl(target, text, fixed = TRUE)))
  text <- sub(target, replacement, text, fixed = TRUE)
  writeLines(enc2utf8(text), path, useBytes = TRUE)

  expect_error(
    bootstrap$wlv_load_runtime(other_root),
    "executed bootstrap is not structurally identical",
    fixed = TRUE
  )
})

test_that("runtime loading is independent of the process working directory", {
  outside <- tempfile("wlv-bootstrap-outside-")
  dir.create(outside)
  on.exit(unlink(outside, recursive = TRUE, force = TRUE), add = TRUE)
  old_working_directory <- setwd(outside)
  on.exit(setwd(old_working_directory), add = TRUE)
  search_before <- search()

  runtime <- wlv_test_load_runtime(wlv_test_root)

  expect_identical(
    normalizePath(getwd(), winslash = "/", mustWork = TRUE),
    normalizePath(outside, winslash = "/", mustWork = TRUE)
  )
  expect_identical(search(), search_before)
  expect_identical(
    runtime$.wlv_runtime_root(),
    normalizePath(wlv_test_root, winslash = "/", mustWork = TRUE)
  )
  expect_identical(parent.env(runtime), baseenv())
  expect_true(environmentIsLocked(runtime))
  bindings <- ls(runtime, all.names = TRUE)
  expect_true(all(vapply(
    bindings,
    function(name) is.function(get(name, envir = runtime, inherits = FALSE)),
    logical(1L)
  )))
  sealed_accessors <- c(
    ".wlv_runtime_root",
    ".wlv_runtime_files",
    ".wlv_runtime_definition_paths",
    ".wlv_runtime_definition_md5",
    ".wlv_runtime_definition_sha256",
    ".wlv_runtime_definition_compatibility_sha256",
    ".wlv_runtime_generation",
    ".wlv_runtime_compatibility_generation"
  )
  expect_true(all(vapply(
    setdiff(bindings, sealed_accessors),
    function(name) identical(
      environment(get(name, envir = runtime, inherits = FALSE)),
      runtime
    ),
    logical(1L)
  )))
  expect_true(all(vapply(sealed_accessors, function(name) {
    holder <- environment(get(name, envir = runtime, inherits = FALSE))
    identical(parent.env(holder), baseenv()) &&
      environmentIsLocked(holder) &&
      exists(".value", envir = holder, inherits = FALSE) &&
      bindingIsLocked(".value", holder)
  }, logical(1L))))
  expect_true(all(grepl(
    "^[0-9a-f]{64}$",
    runtime$.wlv_runtime_definition_sha256()
  )))
  expect_match(runtime$.wlv_runtime_generation(), "^[0-9a-f]{64}$")
  expect_match(
    runtime$.wlv_runtime_compatibility_generation(),
    "^[0-9a-f]{64}$"
  )
  expect_true(all(grepl(
    "^[0-9a-f]{64}$",
    runtime$.wlv_runtime_definition_compatibility_sha256()
  )))
  expect_identical(
    runtime$.wlv_runtime_compatibility_generation(),
    runtime$wlv_runtime_definition_generation(
      runtime$.wlv_runtime_definition_compatibility_sha256()
    )
  )
  expect_identical(
    runtime$.wlv_runtime_generation(),
    runtime$wlv_runtime_definition_generation(
      runtime$.wlv_runtime_definition_sha256()
    )
  )
  expect_true(all(vapply(bindings, bindingIsLocked, logical(1L), env = runtime)))
  expect_error(runtime$temporary_binding <- TRUE, "locked environment")
})

test_that("bootstrap metadata accessors seal and defensively copy containers", {
  bootstrap <- new.env(parent = baseenv())
  sys.source(file.path(wlv_test_root, "R", "bootstrap.R"), envir = bootstrap)
  accessor <- bootstrap$wlv_bootstrap_value_accessor(list(nested = list(1L)))
  first <- accessor()
  first$nested[[1L]] <- 2L

  expect_identical(accessor(), list(nested = list(1L)))
  holder <- environment(accessor)
  expect_true(environmentIsLocked(holder))
  expect_true(bindingIsLocked(".value", holder))
  expect_error(assign(".value", list(), envir = holder), "locked binding")
})

test_that("runtime compatibility generation is invariant to line endings", {
  bootstrap <- new.env(parent = baseenv())
  sys.source(file.path(wlv_test_root, "R", "bootstrap.R"), envir = bootstrap)
  lf <- charToRaw("alpha <- function() {\n  1L\n}\n")
  crlf <- charToRaw("alpha <- function() {\r\n  1L\r\n}\r\n")
  cr <- charToRaw("alpha <- function() {\r  1L\r}\r")
  hashes <- vapply(
    list(lf, crlf, cr),
    bootstrap$wlv_bootstrap_compatibility_sha256_bytes,
    character(1L),
    relative_path = "R/example.R"
  )
  expect_identical(unname(hashes), rep(hashes[[1L]], 3L))
  expect_false(identical(
    as.character(openssl::sha256(lf)),
    as.character(openssl::sha256(crlf))
  ))
})

test_that("bootstrap rejects incomplete project roots before loading", {
  incomplete <- tempfile("wlv-bootstrap-incomplete-")
  dir.create(incomplete)
  on.exit(unlink(incomplete, recursive = TRUE, force = TRUE), add = TRUE)
  bootstrap <- new.env(parent = baseenv())
  sys.source(file.path(wlv_test_root, "R", "bootstrap.R"), envir = bootstrap)

  expect_error(
    bootstrap$wlv_runtime_definition_files(incomplete),
    "Runtime definition file\\(s\\) do not exist"
  )
})

test_that("every runtime manifest file contains only function definitions", {
  bootstrap <- new.env(parent = baseenv())
  sys.source(file.path(wlv_test_root, "R", "bootstrap.R"), envir = bootstrap)

  for (relative_path in bootstrap$wlv_runtime_definition_manifest()) {
    expressions <- parse(
      file.path(wlv_test_root, relative_path),
      encoding = "UTF-8",
      keep.source = TRUE
    )
    function_definitions <- vapply(expressions, function(expression) {
      is.call(expression) && length(expression) == 3L &&
        is.symbol(expression[[1L]]) &&
        identical(as.character(expression[[1L]]), "<-") &&
        is.symbol(expression[[2L]]) &&
        is.call(expression[[3L]]) &&
        length(expression[[3L]]) >= 3L &&
        is.symbol(expression[[3L]][[1L]]) &&
        identical(as.character(expression[[3L]][[1L]]), "function")
    }, logical(1L))

    expect_true(
      length(expressions) > 0L && all(function_definitions),
      info = relative_path
    )
    expect_no_error(bootstrap$wlv_bootstrap_validate_definitions(
      expressions,
      relative_path
    ))
  }
})

test_that("bootstrap accepts functions and rejects every non-function RHS", {
  bootstrap <- new.env(parent = baseenv())
  sys.source(file.path(wlv_test_root, "R", "bootstrap.R"), envir = bootstrap)

  expect_no_error(bootstrap$wlv_bootstrap_validate_definitions(
    expression(value <- function() TRUE),
    "R/lib/definition.R"
  ))
  expect_error(
    bootstrap$wlv_bootstrap_validate_definitions(
      expression(run_task()),
      "R/lib/task.R"
    ),
    "top-level execution"
  )
  expect_error(
    bootstrap$wlv_bootstrap_validate_definitions(
      expression(value <- run_task()),
      "R/lib/task-assignment.R"
    ),
    "top-level execution"
  )
  invalid_definitions <- list(
    literal = expression(value <- "literal"),
    vector = expression(value <- c("one", "two")),
    container = expression(value <- list(one = 1L)),
    module_spec = expression(value <- wlv_module_spec(id = "module")),
    factory_call = expression(value <- make_definition()),
    alias = expression(value <- another_function)
  )
  for (label in names(invalid_definitions)) {
    expect_error(
      bootstrap$wlv_bootstrap_validate_definitions(
        invalid_definitions[[label]],
        paste0("R/lib/", label, ".R")
      ),
      "top-level execution",
      info = label
    )
  }
  expect_identical(
    bootstrap$wlv_bootstrap_definition_names(expression(
      first <- function() TRUE,
      object$field <- 1,
      second <- 2
    )),
    c("first", "second")
  )
})

test_that("runtime bootstrap performs no repository-backed catalog I/O", {
  bootstrap <- new.env(parent = baseenv())
  sys.source(file.path(wlv_test_root, "R", "bootstrap.R"), envir = bootstrap)
  root <- tempfile("wlv-bootstrap-definitions-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  relative <- c("R/bootstrap.R", bootstrap$wlv_runtime_definition_manifest())
  for (directory in unique(dirname(relative))) {
    dir.create(file.path(root, directory), recursive = TRUE, showWarnings = FALSE)
  }
  expect_true(all(file.copy(
    file.path(wlv_test_root, relative),
    file.path(root, relative),
    overwrite = TRUE
  )))

  runtime <- bootstrap$wlv_load_runtime(root)

  expect_false(exists("method_catalog", envir = runtime, inherits = FALSE))
  expect_false(exists("method_list", envir = runtime, inherits = FALSE))
  expect_true(is.function(runtime$wlv_runtime_catalog))
  definition <- file.path(root, "R", "main.R")
  writeLines(
    c(readLines(definition, encoding = "UTF-8"), ""),
    definition,
    useBytes = TRUE
  )
  expect_error(
    runtime$wlv_runtime_catalog(),
    "Runtime definitions changed after bootstrap",
    fixed = TRUE
  )
})

test_that("runtime functions do not depend on attached package symbols", {
  runtime <- wlv_test_load_runtime(wlv_test_root)
  bindings <- ls(runtime, all.names = TRUE)
  allowed <- c(bindings, ls(baseenv(), all.names = TRUE))
  unresolved <- lapply(bindings, function(name) {
    value <- get(name, envir = runtime, inherits = FALSE)
    if (!is.function(value)) return(character())
    globals <- codetools::findGlobals(value, merge = FALSE)
    setdiff(unique(c(globals$functions, globals$variables)), allowed)
  })
  names(unresolved) <- bindings
  unresolved <- unresolved[lengths(unresolved) > 0L]

  expect_length(unresolved, 0L)
})

test_that("private runtime exposes no pre-cutover adapters or publishers", {
  runtime <- wlv_test_load_runtime(wlv_test_root)
  retired <- c(
    "wlv_aggregation_legacy_row",
    "wlv_aggregation_registry_legacy_flags",
    "wlv_publish_result_staging",
    "wlv_rollback_result_staging",
    "wlv_reinstate_new_result_staging",
    "wlv_finalize_result_staging",
    "wlv_prepare_global_metadata",
    "wlv_rollback_global_metadata",
    "wlv_begin_global_metadata_transaction",
    "wlv_finalize_global_metadata",
    "wlv_write_result_source_provenance",
    "wlv_read_indicator_metadata",
    "wlv_display_values",
    "wlv_write_fst_array_atomic",
    "convert_array_RDS"
  )
  expect_false(any(retired %in% ls(runtime, all.names = TRUE)))
  expect_false("allow_legacy" %in% names(formals(
    runtime$wlv_resolve_current_method_run
  )))
  expect_false("legacy_aggregations" %in% names(formals(
    runtime$wlv_scientific_validate_result_arrays
  )))
})
