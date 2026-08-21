fst_integrity_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "functions.R"),
  envir = fst_integrity_environment
)

wlv_fst_integrity_root <- function(label) {
  root <- tempfile(paste0("wlv-fst-integrity-", label, "-"))
  dir.create(root)
  root
}

wlv_fst_integrity_files <- function(root) {
  list.files(root, all.files = TRUE, no.. = TRUE)
}

test_that("versioned FST bundles preserve values, dimensions, and Unicode dimnames", {
  skip_if_not_installed("fst")
  skip_if_not_installed("openssl")
  root <- wlv_fst_integrity_root("roundtrip")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  value <- array(
    c("a\u00e7\u00e3o", "caf\u00e9", "\u03b2", "\u6771\u4eac"),
    dim = c(2L, 2L),
    dimnames = setNames(
      list(c("Esp\u00edrito Santo", "S\u00e3o Paulo"), c("\u03b1", "\u03b2")),
      c("regi\u00e3o", "vari\u00e1vel")
    )
  )
  path <- file.path(root, "matrix.fst")

  expect_identical(
    fst_integrity_environment$write_fst_array(value, path),
    path
  )
  observed <- fst_integrity_environment$read_fst_array(path)
  metadata <- readRDS(paste0(path, ".meta"))

  expect_identical(observed, value)
  expect_identical(metadata$schema_version, "1")
  expect_match(metadata$fst_sha256, "^[0-9a-f]{64}$")
  expect_identical(metadata$array_dimnames, dimnames(value))
  expect_identical(
    metadata$fst_sha256,
    fst_integrity_environment$wlv_fst_file_sha256(path)
  )
  expect_setequal(
    wlv_fst_integrity_files(root),
    basename(c(path, paste0(path, ".meta")))
  )
})

test_that("FST arrays require readable and structurally valid sidecars", {
  skip_if_not_installed("fst")
  skip_if_not_installed("openssl")
  root <- wlv_fst_integrity_root("sidecar")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  path <- file.path(root, "array.fst")
  fst::write_fst(data.frame(Data = 1:4), path)

  expect_error(
    fst_integrity_environment$read_fst_array(path),
    "sidecar metadata is missing"
  )

  metadata_path <- paste0(path, ".meta")
  writeBin(charToRaw("not an RDS file"), metadata_path)
  expect_error(
    fst_integrity_environment$read_fst_array(path),
    "Cannot read FST sidecar metadata"
  )

  saveRDS("not a metadata list", metadata_path)
  expect_error(
    fst_integrity_environment$read_fst_array(path),
    "Invalid FST sidecar metadata"
  )

  saveRDS(list(dim = c(3L, 2L)), metadata_path)
  expect_error(
    fst_integrity_environment$read_fst_array(path),
    "length mismatch"
  )
})

test_that("versioned sidecars detect data and metadata corruption", {
  skip_if_not_installed("fst")
  skip_if_not_installed("openssl")
  root <- wlv_fst_integrity_root("corruption")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  path <- file.path(root, "array.fst")
  value <- array(seq_len(6), c(2L, 3L))

  fst_integrity_environment$write_fst_array(value, path)
  fst::write_fst(data.frame(Data = rev(seq_len(6))), path)
  expect_error(
    fst_integrity_environment$read_fst_array(path),
    "SHA-256 mismatch"
  )

  fst_integrity_environment$write_fst_array(value, path)
  metadata_path <- paste0(path, ".meta")
  metadata <- readRDS(metadata_path)
  metadata$fst_sha256 <- strrep("0", 64L)
  saveRDS(metadata, metadata_path)
  expect_error(
    fst_integrity_environment$read_fst_array(path),
    "SHA-256 mismatch"
  )

  fst_integrity_environment$write_fst_array(value, path)
  metadata <- readRDS(metadata_path)
  metadata$schema_version <- "2"
  saveRDS(metadata, metadata_path)
  expect_error(
    fst_integrity_environment$read_fst_array(path),
    "Unsupported FST sidecar schema version"
  )
})

test_that("legacy FST sidecars remain readable", {
  skip_if_not_installed("fst")
  root <- wlv_fst_integrity_root("legacy")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  value <- array(
    seq_len(12),
    c(2L, 3L, 2L),
    dimnames = list(
      row = c("r1", "r2"),
      sector = c("s1", "s2", "s3"),
      year = c("2020", "2021")
    )
  )
  path <- file.path(root, "named.fst")
  fst::write_fst(data.frame(Data = as.vector(value)), path)
  saveRDS(c(list(dim = dim(value)), dimnames(value)), paste0(path, ".meta"))

  expect_identical(fst_integrity_environment$read_fst_array(path), value)

  unnamed <- array(seq_len(4), c(2L, 2L))
  unnamed_path <- file.path(root, "unnamed.fst")
  fst::write_fst(data.frame(Data = as.vector(unnamed)), unnamed_path)
  saveRDS(list(dim = dim(unnamed)), paste0(unnamed_path, ".meta"))

  expect_identical(
    fst_integrity_environment$read_fst_array(unnamed_path),
    unnamed
  )
})

test_that("round-trip failure leaves an existing FST bundle untouched", {
  skip_if_not_installed("fst")
  skip_if_not_installed("openssl")
  root <- wlv_fst_integrity_root("validation-rollback")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  path <- file.path(root, "array.fst")
  old_value <- array(seq_len(4), c(2L, 2L))
  new_value <- array(seq_len(6), c(2L, 3L))
  fst_integrity_environment$write_fst_array(old_value, path)

  original_reader <- fst_integrity_environment$wlv_fst_read_bundle
  fst_integrity_environment$wlv_fst_read_bundle <- function(file_name) {
    if (grepl("-write-", basename(file_name), fixed = TRUE)) {
      stop("injected round-trip failure", call. = FALSE)
    }
    original_reader(file_name)
  }
  on.exit({
    fst_integrity_environment$wlv_fst_read_bundle <- original_reader
  }, add = TRUE)

  expect_error(
    fst_integrity_environment$write_fst_array(new_value, path),
    "injected round-trip failure"
  )
  expect_identical(original_reader(path), old_value)
  expect_setequal(
    wlv_fst_integrity_files(root),
    basename(c(path, paste0(path, ".meta")))
  )
})

test_that("failed pair installation restores the previous FST bundle", {
  skip_if_not_installed("fst")
  skip_if_not_installed("openssl")
  root <- wlv_fst_integrity_root("install-rollback")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  path <- file.path(root, "array.fst")
  old_value <- array(seq_len(4), c(2L, 2L))
  new_value <- array(seq_len(6), c(2L, 3L))
  fst_integrity_environment$write_fst_array(old_value, path)

  original_rename <- base::file.rename
  fst_integrity_environment$file.rename <- function(from, to) {
    installing_data <- identical(to, path) &&
      grepl("-write-", basename(from), fixed = TRUE)
    if (installing_data) {
      return(FALSE)
    }
    original_rename(from, to)
  }
  on.exit(rm("file.rename", envir = fst_integrity_environment), add = TRUE)

  expect_error(
    fst_integrity_environment$write_fst_array(new_value, path),
    "Cannot install verified FST bundle file"
  )
  expect_identical(fst_integrity_environment$read_fst_array(path), old_value)
  expect_setequal(
    wlv_fst_integrity_files(root),
    basename(c(path, paste0(path, ".meta")))
  )
})
