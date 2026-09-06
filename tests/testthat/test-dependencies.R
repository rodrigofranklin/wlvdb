test_that("declared dependencies are represented in the lockfile", {
  description <- read.dcf(file.path(wlv_test_root, "DESCRIPTION"))
  fields <- c("Imports", "Suggests")
  declared <- unique(trimws(unlist(strsplit(description[1, fields], ","))))
  declared <- sub("[[:space:]]*\\(.*$", "", declared)

  lockfile <- renv::lockfile_read(file.path(wlv_test_root, "renv.lock"))
  locked <- names(lockfile$Packages)

  expect_true(all(declared %in% locked))
  expect_false("writexl" %in% locked)
})

test_that("the restored library and lockfile are synchronized", {
  status <- renv::status(project = wlv_test_root)
  expect_true(status$synchronized)
})

test_that("feature dependency groups remain declared", {
  environment <- new.env(parent = baseenv())
  sys.source(file.path(wlv_test_root, "scripts", "lib", "dependencies.R"), envir = environment)

  description <- read.dcf(file.path(wlv_test_root, "DESCRIPTION"))
  declared <- paste(description[1, c("Imports", "Suggests")], collapse = ",")
  declared <- trimws(unlist(strsplit(declared, ",")))
  declared <- sub("[[:space:]]*\\(.*$", "", declared)

  groups <- environment$wlv_dependency_groups()
  grouped <- unique(unlist(groups, use.names = FALSE))
  expect_true(all(grouped %in% declared))
  expect_false("papers" %in% names(groups))
  expect_false("writexl" %in% grouped)
})

test_that("a missing dependency produces an actionable error", {
  environment <- new.env(parent = baseenv())
  sys.source(file.path(wlv_test_root, "scripts", "lib", "dependencies.R"), envir = environment)

  missing_package <- paste(c("not", "an", "installed", "package"), collapse = "-")
  expect_error(
    environment$wlv_require_packages(
      missing_package,
      attach = FALSE,
      checker = function(package) FALSE
    ),
    "scripts/bootstrap.R",
    fixed = TRUE
  )
})
