shared_publication_fixture_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "scripts", "lib", "source_manifest.R"),
  envir = shared_publication_fixture_environment
)
sys.source(
  file.path(wlv_test_root, "scripts", "lib", "publication_manifest.R"),
  envir = shared_publication_fixture_environment
)

shared_publication_fixture_root <- file.path(
  wlv_test_root,
  "contracts",
  "results",
  "fixtures",
  "v1"
)

shared_publication_fixture_inventory <- function(root, sha256_file) {
  lines <- readLines(
    file.path(root, "SHA256SUMS"),
    encoding = "UTF-8",
    warn = FALSE
  )
  expect_true(length(lines) > 0L)
  expect_true(all(grepl("^[0-9a-f]{64}  [^/].+$", lines)))
  expected_hashes <- substr(lines, 1L, 64L)
  expected_paths <- substring(lines, 67L)
  actual_paths <- list.files(
    root,
    recursive = TRUE,
    all.files = TRUE,
    full.names = FALSE,
    include.dirs = FALSE,
    no.. = TRUE
  )
  actual_paths <- sort(
    setdiff(chartr("\\", "/", actual_paths), "SHA256SUMS"),
    method = "radix"
  )
  expect_identical(expected_paths, actual_paths)
  observed_hashes <- vapply(
    file.path(root, expected_paths),
    sha256_file,
    character(1L)
  )
  expect_identical(unname(observed_hashes), expected_hashes)
  invisible(TRUE)
}

test_that("the shared v1 fixture verifies the complete publication chain", {
  fixture <- shared_publication_fixture_root
  marker_path <- file.path(
    fixture,
    "channels",
    "stable",
    "00000000000000000001-release-fixture-v1.json"
  )
  release_path <- file.path(
    fixture,
    "releases",
    "release-fixture-v1",
    "release_manifest.json"
  )
  run_path <- file.path(
    fixture,
    "runs",
    "example",
    "run-fixture-v1",
    "run_manifest.json"
  )

  marker <- shared_publication_fixture_environment$wlv_read_channel_marker(
    marker_path
  )
  release <- shared_publication_fixture_environment$wlv_read_release_manifest(
    release_path
  )
  run <- shared_publication_fixture_environment$wlv_read_run_manifest(run_path)

  expect_no_error(
    shared_publication_fixture_environment$wlv_verify_channel_marker(
      marker_path,
      fixture
    )
  )
  expect_no_error(
    shared_publication_fixture_environment$wlv_verify_release_manifest(
      release,
      dirname(release_path),
      publication_root = fixture
    )
  )
  expect_no_error(
    shared_publication_fixture_environment$wlv_verify_run_manifest(
      run,
      dirname(run_path)
    )
  )
  expect_identical(marker$release_id, release$release_id)
  expect_identical(release$runs[[1L]]$run_id, run$run_id)
  expect_identical(release$runs[[1L]]$result_id, run$result_id)

  shared_publication_fixture_inventory(
    fixture,
    shared_publication_fixture_environment$wlv_publication_file_sha256
  )
  payload <- readBin(
    file.path(dirname(run_path), "payload.txt"),
    what = "raw",
    n = file.info(file.path(dirname(run_path), "payload.txt"))$size
  )
  payload <- rawToChar(payload)
  Encoding(payload) <- "UTF-8"
  expect_false(is.na(iconv(payload, from = "UTF-8", to = "UTF-8", sub = NA)))
  expect_match(payload, "publicação imutável", fixed = TRUE)
})
