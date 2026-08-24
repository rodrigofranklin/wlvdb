test_that("run manifests authenticate only semantically validated bytes", {
  skip_if_not_installed("fst")
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("openssl")

  fixture <- wlv_make_native_public_e2e_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  original_build <- runtime$wlv_build_run_manifest
  injected <- FALSE
  assign(
    "wlv_build_run_manifest",
    function(run_root, ...) {
      if (!injected) {
        path <- file.path(run_root, "_states.csv")
        size <- file.info(path)$size
        bytes <- readBin(path, "raw", n = size)
        writeBin(c(bytes, charToRaw("\n# injected mutation\n")), path)
        injected <<- TRUE
      }
      original_build(run_root = run_root, ...)
    },
    envir = runtime
  )

  expect_error(
    runtime$get_wlv(
      methods = fixture$method,
      workers = 1L,
      channel = fixture$channel,
      allow_experimental = TRUE
    ),
    "changed after semantic validation|mismatch for run artifact"
  )
  expect_true(injected)
  expect_null(runtime$wlv_read_current_release(
    fixture$root,
    fixture$channel,
    required = FALSE
  ))
})

test_that("promotion verifies validated artifacts after the atomic move", {
  skip_if_not_installed("fst")
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("openssl")

  fixture <- wlv_make_native_public_e2e_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  injected <- FALSE
  assign(
    "file.rename",
    function(from, to) {
      renamed <- base::file.rename(from, to)
      if (isTRUE(renamed) && !injected &&
          file.exists(file.path(to, runtime$wlv_run_manifest_filename))) {
        path <- file.path(to, "_states.csv")
        size <- file.info(path)$size
        bytes <- readBin(path, "raw", n = size)
        writeBin(c(bytes, charToRaw("\n# post-move mutation\n")), path)
        injected <<- TRUE
      }
      renamed
    },
    envir = runtime
  )

  expect_error(
    runtime$get_wlv(
      methods = fixture$method,
      workers = 1L,
      channel = fixture$channel,
      allow_experimental = TRUE
    ),
    "mismatch for run artifact",
    fixed = TRUE
  )
  expect_true(injected)
  expect_null(runtime$wlv_read_current_release(
    fixture$root,
    fixture$channel,
    required = FALSE
  ))
})

test_that("publication rejects opaque artifacts without a semantic contract", {
  skip_if_not_installed("fst")
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("openssl")

  fixture <- wlv_make_native_public_e2e_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  original_validate <- runtime$wlv_validate_staged_results
  injected <- FALSE
  assign(
    "wlv_validate_staged_results",
    function(staging, ...) {
      writeBin(charToRaw("opaque"), file.path(staging, "opaque.bin"))
      injected <<- TRUE
      original_validate(staging = staging, ...)
    },
    envir = runtime
  )

  expect_error(
    runtime$get_wlv(
      methods = fixture$method,
      workers = 1L,
      channel = fixture$channel,
      allow_experimental = TRUE
    ),
    "unexpected: opaque.bin",
    fixed = TRUE
  )
  expect_true(injected)
  expect_null(runtime$wlv_read_current_release(
    fixture$root,
    fixture$channel,
    required = FALSE
  ))
})

test_that("scientific checks cannot change after semantic validation", {
  skip_if_not_installed("fst")
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("openssl")

  fixture <- wlv_make_native_public_e2e_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  original_allowlist <- runtime$wlv_assert_staged_result_artifact_allowlist
  injected <- FALSE
  assign(
    "wlv_assert_staged_result_artifact_allowlist",
    function(staging, expected_artifacts, require_scientific_checks) {
      result <- original_allowlist(
        staging,
        expected_artifacts,
        require_scientific_checks
      )
      if (isTRUE(require_scientific_checks) && !injected) {
        path <- file.path(staging, "_scientific_checks.csv")
        size <- file.info(path)$size
        bytes <- readBin(path, "raw", n = size)
        writeBin(c(bytes, charToRaw("corrupt")), path)
        injected <<- TRUE
      }
      result
    },
    envir = runtime
  )

  expect_error(
    runtime$get_wlv(
      methods = fixture$method,
      workers = 1L,
      channel = fixture$channel,
      allow_experimental = TRUE
    ),
    "Staged scientific checks changed",
    fixed = TRUE
  )
  expect_true(injected)
  expect_null(runtime$wlv_read_current_release(
    fixture$root,
    fixture$channel,
    required = FALSE
  ))
})

test_that("release artifacts are verified again after the atomic move", {
  skip_if_not_installed("fst")
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("openssl")

  fixture <- wlv_make_native_public_e2e_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  injected <- FALSE
  assign(
    "file.rename",
    function(from, to) {
      renamed <- base::file.rename(from, to)
      if (isTRUE(renamed) && !injected &&
          file.exists(file.path(to, runtime$wlv_release_manifest_filename))) {
        path <- file.path(to, "indicators_en.csv")
        size <- file.info(path)$size
        bytes <- readBin(path, "raw", n = size)
        writeBin(c(bytes, charToRaw("\npost-move mutation\n")), path)
        injected <<- TRUE
      }
      renamed
    },
    envir = runtime
  )

  expect_error(
    runtime$get_wlv(
      methods = fixture$method,
      workers = 1L,
      channel = fixture$channel,
      allow_experimental = TRUE
    ),
    "mismatch for release artifact",
    fixed = TRUE
  )
  expect_true(injected)
  expect_null(runtime$wlv_read_current_release(
    fixture$root,
    fixture$channel,
    required = FALSE
  ))
})
