preparation_task_environment <- new.env(parent = baseenv())
for (path in c(
  file.path("R", "lib", "preparation_tasks.R"),
  file.path("R", "preparation", "native_euklems.R"),
  file.path("R", "preparation", "native_wiodr13.R"),
  file.path("R", "preparation", "native_wiodr16.R"),
  file.path("R", "preparation", "registry.R")
)) {
  sys.source(
    file.path(wlv_test_root, path),
    envir = preparation_task_environment
  )
}

wlv_test_preparation_spec <- function() {
  environment <- preparation_task_environment
  environment$wlv_preparation_task_spec(
    source = "demo",
    services = "write_text",
    parameters = list(
      tag = environment$wlv_preparation_parameter(
        type = "character",
        default = "new"
      )
    ),
    locks = "demo",
    source_record_required = FALSE,
    run = function(ctx) {
      staged_a <- ctx$stage_path("artifacts", "a.txt")
      staged_b <- ctx$stage_path("artifacts", "b.txt")
      dir.create(dirname(staged_a), recursive = TRUE, showWarnings = FALSE)
      writer <- ctx$service("write_text")
      writer(paste0(ctx$arg("tag"), "-a"), staged_a)
      writer(paste0(ctx$arg("tag"), "-b"), staged_b)
      environment$wlv_preparation_result(
        promotions = list(
          demo.a = environment$wlv_preparation_promotion(
            staged_a,
            ctx$path("source_data", "demo", "a.txt")
          ),
          demo.b = environment$wlv_preparation_promotion(
            staged_b,
            ctx$path("source_data", "demo", "b.txt")
          )
        ),
        diagnostics = list(
          context_locked = environmentIsLocked(ctx),
          root = ctx$root,
          staged_a = staged_a
        )
      )
    }
  )
}

wlv_test_preparation_services <- function() {
  list(write_text = function(value, path) {
    writeLines(value, path, useBytes = TRUE)
    invisible(path)
  })
}

test_that("native preparation registry is deterministic and complete", {
  registry <- preparation_task_environment$wlv_default_preparation_registry()

  expect_s3_class(registry, "wlv_preparation_registry")
  expect_identical(names(registry), c("euklems", "wiodr13", "wiodr16"))
  expect_identical(
    unname(registry$wiodr13$locks),
    c("euklems", "wiodr13")
  )
  expect_identical(
    unname(registry$wiodr16$locks),
    c("euklems", "wiodr16")
  )
  expect_identical(unname(registry$euklems$locks), "euklems")
  expect_true(all(c(
    "ensure_directory",
    "files_exist",
    "download_verified",
    "read_excel",
    "publish_normalized_source",
    "write_fst_array"
  ) %in% registry$wiodr13$services))
  expect_true(all(c(
    "ensure_directory",
    "files_exist",
    "download_verified",
    "load_wiodr16_wiot",
    "publish_normalized_source",
    "write_fst_array"
  ) %in% registry$wiodr16$services))
})

test_that("preparation contexts expose absolute paths and declared services", {
  root <- tempfile("wlv-preparation-context-")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  result <- preparation_task_environment$wlv_run_preparation_task(
    spec = wlv_test_preparation_spec(),
    root = root,
    services = wlv_test_preparation_services(),
    arguments = list(tag = "candidate")
  )

  expect_s3_class(result, "wlv_preparation_execution")
  expect_true(result$diagnostics$context_locked)
  expect_identical(
    result$diagnostics$root,
    normalizePath(root, winslash = "/", mustWork = TRUE)
  )
  expect_true(grepl(
    "^[A-Za-z]:/|^/",
    result$diagnostics$staged_a
  ))
  expect_identical(
    readLines(file.path(root, "source_data", "demo", "a.txt")),
    "candidate-a"
  )
  expect_identical(
    readLines(file.path(root, "source_data", "demo", "b.txt")),
    "candidate-b"
  )
  expect_false(dir.exists(file.path(root, "source_data", ".prepare-lock-demo")))
  expect_length(list.files(
    file.path(root, "source_data", ".preparation-staging"),
    all.files = TRUE,
    no.. = TRUE
  ), 0L)
})

test_that("an injected promotion failure restores every previous artifact", {
  root <- tempfile("wlv-preparation-rollback-")
  destination <- file.path(root, "source_data", "demo")
  dir.create(destination, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  writeLines("old-a", file.path(destination, "a.txt"), useBytes = TRUE)
  writeLines("old-b", file.path(destination, "b.txt"), useBytes = TRUE)

  expect_error(
    preparation_task_environment$wlv_run_preparation_task(
      spec = wlv_test_preparation_spec(),
      root = root,
      services = wlv_test_preparation_services(),
      fail_at = "after_install:demo.a"
    ),
    "Injected preparation failure"
  )
  expect_identical(readLines(file.path(destination, "a.txt")), "old-a")
  expect_identical(readLines(file.path(destination, "b.txt")), "old-b")
  expect_setequal(list.files(destination), c("a.txt", "b.txt"))
  expect_false(dir.exists(file.path(root, "source_data", ".prepare-lock-demo")))
  expect_length(list.files(
    file.path(root, "source_data", ".preparation-staging"),
    all.files = TRUE,
    no.. = TRUE
  ), 0L)
})

test_that("preparation contracts reject implicit capabilities and bad arguments", {
  root <- tempfile("wlv-preparation-contract-")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  expect_error(
    preparation_task_environment$wlv_run_preparation_task(
      spec = wlv_test_preparation_spec(),
      root = root,
      services = list(other = identity)
    ),
    "services are missing: write_text"
  )
  expect_error(
    preparation_task_environment$wlv_run_preparation_task(
      spec = wlv_test_preparation_spec(),
      root = root,
      services = wlv_test_preparation_services(),
      arguments = list(tag = 1L)
    ),
    "incompatible with type `character`"
  )
  expect_error(
    preparation_task_environment$wlv_run_preparation_task(
      spec = wlv_test_preparation_spec(),
      root = root,
      services = wlv_test_preparation_services(),
      arguments = list(unknown = "x")
    ),
    "Unknown preparation argument"
  )

  required_spec <- preparation_task_environment$wlv_preparation_task_spec(
    source = "required",
    run = function(ctx) stop("must not run"),
    services = "write_text",
    parameters = list(
      required_value = preparation_task_environment$wlv_preparation_parameter(
        type = "character",
        required = TRUE
      )
    ),
    source_record_required = FALSE
  )
  expect_s3_class(required_spec, "wlv_preparation_task_spec")
  expect_error(
    preparation_task_environment$wlv_run_preparation_task(
      spec = required_spec,
      root = root,
      services = wlv_test_preparation_services()
    ),
    "Required preparation argument `required_value` is missing"
  )
})

test_that("pinned native source contracts retain scientific coverage", {
  contract <- preparation_task_environment$wlv_wiodr16_contract_native()
  expect_identical(contract$years, as.character(2000:2014))
  expect_length(contract$countries, 43L)
  expect_length(contract$sectors, 56L)
  expect_length(contract$rdata_members, 15L)
  expect_identical(
    preparation_task_environment$wlv_normalize_euklems_years_native(
      1995:2010
    ),
    as.character(1995:2010)
  )
  expect_error(
    preparation_task_environment$wlv_normalize_euklems_years_native(
      c(2000L, 2000L)
    ),
    "unique integers"
  )
})
