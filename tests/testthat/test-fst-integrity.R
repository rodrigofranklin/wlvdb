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

test_that("streaming FST verification is exact across chunks", {
  skip_if_not_installed("fst")
  skip_if_not_installed("openssl")
  root <- wlv_fst_integrity_root("streaming")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  value <- array(
    c(1, NA_real_, NaN, -Inf, Inf, 0, -0, 8),
    dim = c(2L, 4L),
    dimnames = list(c("r1", "r2"), c("c1", "c2", "c3", "c4"))
  )
  path <- file.path(root, "array.fst")
  fst_integrity_environment$write_fst_array(value, path)

  expect_true(
    fst_integrity_environment$wlv_fst_verify_bundle_chunks(
      path,
      value,
      chunk_size = 3L
    )
  )

  wrong_missingness <- value
  wrong_missingness[[2L]] <- NaN
  wrong_missingness[[3L]] <- NA_real_
  expect_error(
    fst_integrity_environment$wlv_fst_verify_bundle_chunks(
      path,
      wrong_missingness,
      chunk_size = 3L
    ),
    "values changed"
  )

  wrong_last_block <- value
  wrong_last_block[[8L]] <- 9
  expect_error(
    fst_integrity_environment$wlv_fst_verify_bundle_chunks(
      path,
      wrong_last_block,
      chunk_size = 3L
    ),
    "rows 7-8: values changed"
  )
})

test_that("FST bundles preserve base storage and reject lossy attributes", {
  skip_if_not_installed("fst")
  skip_if_not_installed("openssl")
  root <- wlv_fst_integrity_root("storage")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  supported <- list(
    logical = array(c(TRUE, FALSE, NA, TRUE), c(2L, 2L)),
    integer = array(c(1L, NA_integer_, 3L, 4L), c(2L, 2L)),
    double = array(c(1, NA_real_, NaN, Inf), c(2L, 2L)),
    character = array(c("a", NA_character_, "c", "d"), c(2L, 2L)),
    raw = array(as.raw(1:4), c(2L, 2L))
  )
  for (name in names(supported)) {
    path <- file.path(root, paste0(name, ".fst"))
    fst_integrity_environment$write_fst_array(supported[[name]], path)
    expect_identical(
      fst_integrity_environment$read_fst_array(path),
      supported[[name]],
      info = name
    )
  }

  classed <- factor(c("a", "b", "a", "c"))
  dim(classed) <- c(2L, 2L)
  expect_error(
    fst_integrity_environment$write_fst_array(
      classed,
      file.path(root, "factor.fst")
    ),
    "unsupported FST array attribute"
  )
  expect_error(
    fst_integrity_environment$write_fst_array(
      array(as.complex(1:4), c(2L, 2L)),
      file.path(root, "complex.fst")
    ),
    "unsupported FST array storage type `complex`"
  )
  expect_false(file.exists(file.path(root, "factor.fst")))
  expect_false(file.exists(file.path(root, "complex.fst")))

  clean <- array(
    as.double(1:4),
    c(2L, 2L),
    dimnames = list(c("r1", "r2"), c("c1", "c2"))
  )
  clean_path <- file.path(root, "clean.fst")
  fst_integrity_environment$write_fst_array(clean, clean_path)
  lossy <- clean
  attr(lossy, "units") <- "labor_hours"
  attr(lossy, "provenance") <- "synthetic"
  expect_error(
    fst_integrity_environment$write_fst_array(
      lossy,
      file.path(root, "lossy.fst")
    ),
    paste0(
      "unsupported FST array attribute\\(s\\): units, provenance.*",
      "Only `dim` and optional `dimnames` are supported"
    )
  )
  expect_error(
    fst_integrity_environment$wlv_fst_verify_bundle_chunks(
      clean_path,
      lossy
    ),
    "unsupported FST array attribute"
  )
  expect_false(file.exists(file.path(root, "lossy.fst")))
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

test_that("FST reads reject bundle changes during deserialization", {
  skip_if_not_installed("fst")
  skip_if_not_installed("openssl")
  root <- wlv_fst_integrity_root("read-toctou")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  path <- file.path(root, "array.fst")
  metadata_path <- paste0(path, ".meta")
  value <- array(
    seq_len(6),
    c(2L, 3L),
    dimnames = list(c("r1", "r2"), c("c1", "c2", "c3"))
  )
  fst_integrity_environment$write_fst_array(value, path)

  original_hash <- fst_integrity_environment$wlv_fst_file_sha256
  data_hook <- new.env(parent = emptyenv())
  data_hook$mutated <- FALSE
  fst_integrity_environment$wlv_fst_file_sha256 <- function(candidate) {
    observed <- original_hash(candidate)
    if (identical(candidate, path) && !isTRUE(data_hook$mutated)) {
      data_hook$mutated <- TRUE
      fst::write_fst(data.frame(Data = rev(as.vector(value))), candidate)
    }
    observed
  }
  on.exit({
    fst_integrity_environment$wlv_fst_file_sha256 <- original_hash
  }, add = TRUE)
  expect_error(
    fst_integrity_environment$read_fst_array(path),
    "data changed while it was read"
  )

  fst_integrity_environment$wlv_fst_file_sha256 <- original_hash
  fst_integrity_environment$write_fst_array(value, path)
  metadata_hook <- new.env(parent = emptyenv())
  metadata_hook$mutated <- FALSE
  fst_integrity_environment$wlv_fst_file_sha256 <- function(candidate) {
    observed <- original_hash(candidate)
    if (identical(candidate, metadata_path) &&
        !isTRUE(metadata_hook$mutated)) {
      metadata_hook$mutated <- TRUE
      metadata <- readRDS(candidate)
      metadata$array_dimnames[[1L]][[1L]] <- "tampered"
      saveRDS(metadata, candidate, version = 3L)
    }
    observed
  }
  expect_error(
    fst_integrity_environment$read_fst_array(path),
    "sidecar metadata changed while it was read"
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

test_that("streaming verification failure leaves an existing FST bundle untouched", {
  skip_if_not_installed("fst")
  skip_if_not_installed("openssl")
  root <- wlv_fst_integrity_root("validation-rollback")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  path <- file.path(root, "array.fst")
  old_value <- array(seq_len(4), c(2L, 2L))
  new_value <- array(seq_len(6), c(2L, 3L))
  fst_integrity_environment$write_fst_array(old_value, path)

  original_verifier <- fst_integrity_environment$wlv_fst_verify_bundle_chunks
  fst_integrity_environment$wlv_fst_verify_bundle_chunks <- function(
      file_name,
      expected,
      drop_axis_names = FALSE,
      chunk_size = 1048576L) {
    if (grepl("-write-", basename(file_name), fixed = TRUE)) {
      stop("injected streaming verification failure", call. = FALSE)
    }
    original_verifier(
      file_name,
      expected,
      drop_axis_names = drop_axis_names,
      chunk_size = chunk_size
    )
  }
  on.exit({
    fst_integrity_environment$wlv_fst_verify_bundle_chunks <- original_verifier
  }, add = TRUE)

  expect_error(
    fst_integrity_environment$write_fst_array(new_value, path),
    "injected streaming verification failure"
  )
  expect_identical(
    fst_integrity_environment$wlv_fst_read_bundle(path),
    old_value
  )
  expect_setequal(
    wlv_fst_integrity_files(root),
    basename(c(path, paste0(path, ".meta")))
  )
})

test_that("sidecar mutation between verification and install restores the bundle", {
  skip_if_not_installed("fst")
  skip_if_not_installed("openssl")
  root <- wlv_fst_integrity_root("metadata-toctou")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  path <- file.path(root, "array.fst")
  old_value <- array(
    seq_len(4),
    c(2L, 2L),
    dimnames = list(c("old-r1", "old-r2"), c("old-c1", "old-c2"))
  )
  new_value <- array(
    seq_len(6),
    c(2L, 3L),
    dimnames = list(c("new-r1", "new-r2"), c("new-c1", "new-c2", "new-c3"))
  )
  fst_integrity_environment$write_fst_array(old_value, path)

  original_verifier <- fst_integrity_environment$wlv_fst_verify_bundle_chunks
  fst_integrity_environment$wlv_fst_verify_bundle_chunks <- function(
      file_name,
      expected,
      drop_axis_names = FALSE,
      chunk_size = 1048576L) {
    original_verifier(
      file_name,
      expected,
      drop_axis_names = drop_axis_names,
      chunk_size = chunk_size
    )
    if (grepl("-write-", basename(file_name), fixed = TRUE)) {
      metadata_path <- paste0(file_name, ".meta")
      metadata <- readRDS(metadata_path)
      metadata$array_dimnames[[1L]][[1L]] <- "tampered"
      saveRDS(metadata, metadata_path, version = 3L)
    }
    invisible(TRUE)
  }
  on.exit({
    fst_integrity_environment$wlv_fst_verify_bundle_chunks <- original_verifier
  }, add = TRUE)

  expect_error(
    fst_integrity_environment$write_fst_array(new_value, path),
    "Installed FST array bundle failed final verification"
  )
  expect_identical(
    fst_integrity_environment$read_fst_array(path),
    old_value
  )
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
