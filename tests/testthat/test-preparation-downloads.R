preparation_download_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "utils", "preparation_downloads.R"),
  envir = preparation_download_environment
)

wlv_write_raw_file <- function(path, value) {
  writeBin(charToRaw(value), path)
  invisible(path)
}

test_that("download verification checks exact size and cryptographic hashes", {
  root <- tempfile("wlv-download-verification-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  path <- wlv_write_raw_file(file.path(root, "abc.bin"), "abc")

  expect_identical(
    preparation_download_environment$wlv_file_hash(path, "sha1"),
    "a9993e364706816aba3e25717850c26c9cd0d89d"
  )
  expect_identical(
    preparation_download_environment$wlv_file_hash(path, "sha256"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
  expect_no_error(
    preparation_download_environment$wlv_verify_download(
      path,
      expected_size = 3,
      expected_hash = "a9993e364706816aba3e25717850c26c9cd0d89d",
      hash_algorithm = "sha1"
    )
  )
  expect_error(
    preparation_download_environment$wlv_verify_download(
      path,
      expected_size = 4,
      expected_hash = "a9993e364706816aba3e25717850c26c9cd0d89d",
      hash_algorithm = "sha1"
    ),
    "Size mismatch"
  )
  expect_error(
    preparation_download_environment$wlv_verify_download(
      path,
      expected_size = 3,
      expected_hash = paste(rep("0", 40), collapse = ""),
      hash_algorithm = "sha1"
    ),
    "SHA1 mismatch"
  )
})

test_that("a verified download is installed once and then reused", {
  root <- tempfile("wlv-download-cache-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  destination <- file.path(root, "source.bin")
  downloads <- 0L
  validations <- 0L
  staged_extensions <- character()

  downloader <- function(url, destfile, mode, quiet) {
    downloads <<- downloads + 1L
    staged_extensions <<- c(staged_extensions, tools::file_ext(destfile))
    wlv_write_raw_file(destfile, "abc")
    0L
  }
  validator <- function(path) {
    validations <<- validations + 1L
    identical(readBin(path, "raw", n = 3L), charToRaw("abc"))
  }
  download <- function() {
    preparation_download_environment$wlv_download_verified(
      url = "https://example.invalid/source.bin",
      destination = destination,
      expected_size = 3,
      expected_hash = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
      hash_algorithm = "sha256",
      validator = validator,
      downloader = downloader
    )
  }

  expect_message(download(), "Installed verified download")
  expect_identical(downloads, 1L)
  expect_identical(readBin(destination, "raw", n = 3L), charToRaw("abc"))

  expect_message(download(), "Using verified download")
  expect_identical(downloads, 1L)
  expect_identical(validations, 2L)
  expect_identical(staged_extensions, "bin")
  expect_identical(list.files(root), "source.bin")
})

test_that("an invalid cached file is safely replaced", {
  root <- tempfile("wlv-download-replace-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  destination <- wlv_write_raw_file(file.path(root, "source.bin"), "old")

  downloader <- function(url, destfile, mode, quiet) {
    wlv_write_raw_file(destfile, "abc")
    0L
  }

  messages <- capture_messages(
    preparation_download_environment$wlv_download_verified(
      url = "https://example.invalid/source.bin",
      destination = destination,
      expected_size = 3,
      expected_hash = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
      hash_algorithm = "sha256",
      downloader = downloader
    )
  )
  expect_match(paste(messages, collapse = "\n"), "Replacing invalid cached download")
  expect_match(paste(messages, collapse = "\n"), "Installed verified download")
  expect_identical(readBin(destination, "raw", n = 3L), charToRaw("abc"))
  expect_identical(list.files(root), "source.bin")
})

test_that("a failed replacement preserves the previous cached file", {
  root <- tempfile("wlv-download-rollback-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  destination <- wlv_write_raw_file(file.path(root, "source.bin"), "keep")

  downloader <- function(url, destfile, mode, quiet) {
    wlv_write_raw_file(destfile, "xyz")
    0L
  }

  replacement_error <- NULL
  messages <- capture_messages(
    replacement_error <- tryCatch(
      preparation_download_environment$wlv_download_verified(
        url = "https://example.invalid/source.bin",
        destination = destination,
        expected_size = 3,
        expected_hash = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
        hash_algorithm = "sha256",
        downloader = downloader
      ),
      error = identity
    )
  )
  expect_s3_class(replacement_error, "error")
  expect_match(conditionMessage(replacement_error), "SHA256 mismatch")
  expect_match(paste(messages, collapse = "\n"), "Replacing invalid cached download")
  expect_identical(readBin(destination, "raw", n = 4L), charToRaw("keep"))
  expect_identical(list.files(root), "source.bin")
})

test_that("download destinations must be created explicitly", {
  root <- tempfile("wlv-download-directory-")
  destination <- file.path(root, "source.bin")

  expect_error(
    preparation_download_environment$wlv_download_verified(
      url = "https://example.invalid/source.bin",
      destination = destination,
      expected_size = 3,
      expected_hash = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
      downloader = function(...) stop("must not run")
    ),
    "directory does not exist"
  )
})

test_that("array outputs replace their data and metadata as one transaction", {
  root <- tempfile("wlv-array-write-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  destination <- wlv_write_raw_file(file.path(root, "array.fst"), "old-data")
  saveRDS("old-metadata", paste0(destination, ".meta"))

  writer <- function(value, path) {
    wlv_write_raw_file(path, value$data)
    saveRDS(value$metadata, paste0(path, ".meta"))
  }
  preparation_download_environment$wlv_write_fst_array_atomic(
    list(data = "new-data", metadata = "new-metadata"),
    destination,
    writer = writer
  )

  expect_identical(readBin(destination, "raw", n = 8L), charToRaw("new-data"))
  expect_identical(readRDS(paste0(destination, ".meta")), "new-metadata")
  expect_setequal(list.files(root), c("array.fst", "array.fst.meta"))
})

test_that("an incomplete array write preserves the previous output pair", {
  root <- tempfile("wlv-array-rollback-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  destination <- wlv_write_raw_file(file.path(root, "array.fst"), "old-data")
  saveRDS("old-metadata", paste0(destination, ".meta"))

  expect_error(
    preparation_download_environment$wlv_write_fst_array_atomic(
      "new-data",
      destination,
      writer = function(value, path) wlv_write_raw_file(path, value)
    ),
    "did not produce"
  )
  expect_identical(readBin(destination, "raw", n = 8L), charToRaw("old-data"))
  expect_identical(readRDS(paste0(destination, ".meta")), "old-metadata")
  expect_setequal(list.files(root), c("array.fst", "array.fst.meta"))
})
