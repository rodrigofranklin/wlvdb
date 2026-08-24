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
  expect_false(any(grepl(
    paste0(
      "^R/(lib/(computations|re_computations)[.]R|",
      "modules/(assumptions|matrices|reduced_matrices|variables)/)"
    ),
    manifest
  )))
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
    runtime$.wlv_runtime_root,
    normalizePath(wlv_test_root, winslash = "/", mustWork = TRUE)
  )
  expect_identical(parent.env(runtime), baseenv())
  expect_true(environmentIsLocked(runtime))
  bindings <- ls(runtime, all.names = TRUE)
  expect_true(all(vapply(bindings, bindingIsLocked, logical(1L), env = runtime)))
  expect_error(runtime$temporary_binding <- TRUE, "locked environment")
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

test_that("bootstrap accepts definitions and rejects top-level task execution", {
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
