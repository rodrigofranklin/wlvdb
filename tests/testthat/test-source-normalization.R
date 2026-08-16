source_normalization_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "source_manifest.R"),
  envir = source_normalization_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "source_normalization.R"),
  envir = source_normalization_environment
)

wlv_test_source_m_io <- function() {
  array(
    c(1, NA_real_, -2, 4, 5, 6, 7, 8),
    dim = c(2L, 2L, 2L),
    dimnames = list(
      year = c("2000", "2001"),
      input = c("A.s1", "A.s2"),
      output = c("A.s1", "A.c1")
    )
  )
}

wlv_test_source_sea <- function(contract, value = 2) {
  variables <- contract$sea$variable
  result <- array(
    value,
    dim = c(2L, length(variables), 1L, 1L),
    dimnames = list(
      year = c("2000", "2001"),
      variable = variables,
      sector = "s1",
      country = "A"
    )
  )
  result[2L, variables[[1L]], 1L, 1L] <- NA_real_
  result
}

wlv_test_normalized_source_writer <- function(value, path) {
  saveRDS(value, path, version = 3L)
  saveRDS(
    list(dim = dim(value), dimnames = dimnames(value)),
    paste0(path, ".meta"),
    version = 3L
  )
  invisible(path)
}

wlv_make_source_publication_fixture <- function() {
  root <- tempfile("wlv-normalized-publication-")
  dir.create(root)
  labels <- c(
    "countries.csv" = "code;name\nA;Country A\n",
    "sectors.csv" = "code;name\ns1;Sector 1\n",
    "demand.csv" = "code;name\nc1;Demand 1\n"
  )
  for (name in names(labels)) {
    writeBin(charToRaw(labels[[name]]), file.path(root, name))
  }
  contract_paths <- file.path(root, c("unit-contract.csv", "aggregation-contract.csv"))
  writeBin(
    charToRaw("contract;artifact;unit\nwiod-test;m_io;current_usd\n"),
    contract_paths[[1L]]
  )
  writeBin(
    charToRaw("contract;level;operation\nwiod-test;country;sum\n"),
    contract_paths[[2L]]
  )
  contract <-
    source_normalization_environment$wlv_source_normalization_contract("wiodr13")
  normalized <- source_normalization_environment$wlv_normalize_source(
    wlv_test_source_m_io(),
    wlv_test_source_sea(contract),
    "wiodr13",
    contract
  )
  list(
    root = root,
    labels = labels,
    contract_paths = contract_paths,
    normalized = normalized,
    unit_contract_sidecar = data.frame(
      contract = "wiod-test",
      artifact = c("m_io", "sea"),
      unit = c("current_usd", "declared_by_variable"),
      stringsAsFactors = FALSE,
      check.names = FALSE
    ),
    gfcf = data.frame(
      year = c("2000", "2001"),
      input = c("A.s1", "A.s2"),
      output = c("A.c1", "A.c1"),
      value_million_usd = c(-1, -2),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
}

wlv_publish_source_fixture <- function(fixture, normalized = fixture$normalized) {
  source_normalization_environment$wlv_publish_normalized_source(
    normalized = normalized,
    source_dir = fixture$root,
    unit_contract_id = "wiod-test",
    unit_contract_version = "2026-08-16",
    unit_contract_paths = fixture$contract_paths,
    unit_contract_sidecar = fixture$unit_contract_sidecar,
    gfcf_observations = fixture$gfcf,
    writer = wlv_test_normalized_source_writer
  )
}

wlv_test_file_bytes <- function(path) {
  readBin(path, what = "raw", n = file.info(path)$size)
}

wlv_test_directory_snapshot <- function(path) {
  files <- sort(list.files(path, recursive = TRUE, all.files = TRUE), method = "radix")
  stats::setNames(
    lapply(file.path(path, files), wlv_test_file_bytes),
    files
  )
}

wlv_test_flip_last_byte <- function(path) {
  bytes <- wlv_test_file_bytes(path)
  stopifnot(length(bytes) > 0L)
  bytes[[length(bytes)]] <- as.raw(bitwXor(as.integer(bytes[[length(bytes)]]), 1L))
  writeBin(bytes, path)
  invisible(path)
}

test_that("stable WIOD contracts cover every prepared SEA variable", {
  contract <- source_normalization_environment$wlv_source_normalization_contract
  wiodr13 <- contract("wiodr13")
  wiodr16 <- contract("wiodr16")

  expect_s3_class(wiodr13, "wlv_source_normalization_contract")
  expect_identical(wiodr13$contract_id, "wiodr13_source_normalization_v1")
  expect_identical(wiodr13$m_io$multiplier, 1e6)
  expect_setequal(
    wiodr13$sea$variable,
    c(
      "GO", "II", "VA", "COMP", "LAB", "CAP", "GFCF", "EMP", "EMPE",
      "H_EMP", "H_EMPE", "GO_P", "II_P", "VA_P", "GFCF_P", "GO_QI",
      "II_QI", "VA_QI", "LABHS", "LABMS", "LABLS", "H_HS", "H_MS",
      "H_LS", "K_GFCF", "VA_USD", "GO_USD"
    )
  )
  expect_identical(nrow(wiodr13$sea), 27L)
  expect_identical(
    wiodr13$sea$canonical_unit[wiodr13$sea$variable == "K_GFCF"],
    "constant_1995_lcu"
  )

  expect_identical(wiodr16$contract_id, "wiodr16_source_normalization_v1")
  expect_identical(nrow(wiodr16$sea), 18L)
  expect_setequal(
    wiodr16$sea$variable,
    c(
      "GO", "II", "VA", "COMP", "LAB", "CAP", "K", "EMP", "EMPE",
      "H_EMPE", "GO_PI", "II_PI", "VA_PI", "GO_QI", "II_QI", "VA_QI",
      "VA_USD", "GO_USD"
    )
  )

  expect_error(
    contract("other"),
    "Unknown source normalization contract `other`.",
    fixed = TRUE
  )
})

test_that("WIOD13 normalization applies each declared canonical scale once", {
  contract <-
    source_normalization_environment$wlv_source_normalization_contract("wiodr13")
  m_io <- wlv_test_source_m_io()
  sea <- wlv_test_source_sea(contract)
  normalized <- source_normalization_environment$wlv_normalize_source(
    m_io,
    sea,
    "wiodr13",
    contract
  )

  expect_identical(dim(normalized$m_io), dim(m_io))
  expect_identical(dimnames(normalized$m_io), dimnames(m_io))
  expect_equal(as.numeric(normalized$m_io), as.numeric(m_io) * 1e6)
  expect_identical(dim(normalized$sea), dim(sea))
  expect_identical(dimnames(normalized$sea), dimnames(sea))
  expect_identical(which(is.na(normalized$sea)), which(is.na(sea)))

  expect_equal(normalized$sea[1L, "GO", 1L, 1L], 2e6)
  expect_equal(normalized$sea[1L, "EMP", 1L, 1L], 2e3)
  expect_equal(normalized$sea[1L, "H_EMP", 1L, 1L], 2e6)
  expect_equal(normalized$sea[1L, "GO_P", 1L, 1L], 0.02)
  expect_equal(normalized$sea[1L, "GO_QI", 1L, 1L], 0.02)
  expect_equal(normalized$sea[1L, "LABHS", 1L, 1L], 2)
  expect_equal(normalized$sea[1L, "K_GFCF", 1L, 1L], 2e6)
  expect_equal(normalized$sea[1L, "VA_USD", 1L, 1L], 2e6)

  marker <-
    source_normalization_environment$wlv_source_normalization_marker(normalized$sea)
  expect_identical(marker$contract_id, contract$contract_id)
  expect_identical(marker$source, "wiodr13")
  expect_identical(marker$artifact, "sea")
  expect_true(marker$canonical)
})

test_that("WIOD16 normalization applies source-specific scales", {
  contract <-
    source_normalization_environment$wlv_source_normalization_contract("wiodr16")
  normalized <- source_normalization_environment$wlv_normalize_source(
    wlv_test_source_m_io(),
    wlv_test_source_sea(contract),
    "wiodr16",
    contract
  )

  expect_equal(normalized$sea[1L, "K", 1L, 1L], 2e6)
  expect_equal(normalized$sea[1L, "EMP", 1L, 1L], 2e3)
  expect_equal(normalized$sea[1L, "H_EMPE", 1L, 1L], 2e6)
  expect_equal(normalized$sea[1L, "GO_PI", 1L, 1L], 0.02)
  expect_equal(normalized$sea[1L, "VA_QI", 1L, 1L], 0.02)
  expect_equal(normalized$sea[1L, "GO_USD", 1L, 1L], 2e6)
})

test_that("normalization rejects incomplete labels and variable coverage", {
  contract <-
    source_normalization_environment$wlv_source_normalization_contract("wiodr13")
  normalize <- source_normalization_environment$wlv_normalize_source
  m_io <- wlv_test_source_m_io()
  sea <- wlv_test_source_sea(contract)

  missing <- sea[, -1L, , , drop = FALSE]
  expect_error(
    normalize(m_io, missing, "wiodr13", contract),
    "SEA variable coverage differs from the contract (missing: GO).",
    fixed = TRUE
  )

  unexpected <- sea
  dimnames(unexpected)[[2L]][1L] <- "EXTRA"
  expect_error(
    normalize(m_io, unexpected, "wiodr13", contract),
    "missing: GO; unexpected: EXTRA",
    fixed = TRUE
  )

  incomplete_labels <- m_io
  dimnames(incomplete_labels)[[3L]] <- NULL
  expect_error(
    normalize(incomplete_labels, sea, "wiodr13", contract),
    "must have complete, non-duplicated labels",
    fixed = TRUE
  )
  expect_error(
    source_normalization_environment$wlv_normalize_source_array(
      matrix(1, 2L, 2L),
      contract,
      "m_io"
    ),
    "must be a non-empty numeric 3-dimensional array",
    fixed = TRUE
  )
})

test_that("explicit markers prevent a second normalization", {
  contract <-
    source_normalization_environment$wlv_source_normalization_contract("wiodr16")
  m_io <- wlv_test_source_m_io()
  sea <- wlv_test_source_sea(contract)
  normalized <- source_normalization_environment$wlv_normalize_source(
    m_io,
    sea,
    "wiodr16",
    contract
  )

  expect_error(
    source_normalization_environment$wlv_normalize_source_array(
      normalized$m_io,
      contract,
      "m_io"
    ),
    "already source-normalized by `wiodr16_source_normalization_v1`",
    fixed = TRUE
  )
  expect_error(
    source_normalization_environment$wlv_normalize_source(
      normalized$m_io,
      normalized$sea,
      "wiodr16",
      contract
    ),
    "already source-normalized",
    fixed = TRUE
  )
})

test_that("an already-USD source can declare an identity contract", {
  new_contract <-
    source_normalization_environment$wlv_new_source_normalization_contract
  contract <- new_contract(
    source = "usd_ready",
    contract_id = "usd_ready_identity_v1",
    m_io_multiplier = 1,
    sea_multipliers = c(VA_USD = 1, GO_USD = 1),
    m_io_source_unit = "current_usd",
    m_io_canonical_unit = "current_usd",
    sea_source_units = "current_usd",
    sea_canonical_units = "current_usd"
  )
  m_io <- wlv_test_source_m_io()
  sea <- wlv_test_source_sea(contract, value = 17)
  normalized <- source_normalization_environment$wlv_normalize_source(
    m_io,
    sea,
    "usd_ready",
    contract
  )

  expect_equal(as.numeric(normalized$m_io), as.numeric(m_io))
  expect_equal(as.numeric(normalized$sea), as.numeric(sea))
  expect_identical(dimnames(normalized$m_io), dimnames(m_io))
  expect_identical(dimnames(normalized$sea), dimnames(sea))
  expect_identical(
    normalized$contract$sea$canonical_unit,
    c("current_usd", "current_usd")
  )
  expect_error(
    source_normalization_environment$wlv_normalize_source(
      m_io,
      sea,
      "wiodr13",
      contract
    ),
    "does not match contract source",
    fixed = TRUE
  )
})

test_that("normalized source publication hashes every artifact and contract", {
  fixture <- wlv_make_source_publication_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  manifest <- wlv_publish_source_fixture(fixture)
  normalized_dir <- file.path(fixture$root, "normalized")
  expected_artifacts <- c(
    "_gfcf_canonical.rds",
    "_normalization_contract.csv",
    "_source_manifest.csv",
    "_unit_contract.csv",
    "countries.csv",
    "demand.csv",
    "m_io.fst",
    "m_io.fst.meta",
    "sea.fst",
    "sea.fst.meta",
    "sectors.csv"
  )
  expect_identical(
    sort(list.files(normalized_dir), method = "radix"),
    expected_artifacts
  )
  expect_identical(
    source_normalization_environment$wlv_read_source_manifest(
      file.path(normalized_dir, "_source_manifest.csv")
    ),
    manifest
  )
  expect_no_error(
    source_normalization_environment$wlv_verify_source_manifest(
      manifest,
      normalized_dir,
      fixture$contract_paths,
      expected_contract_id = "wiod-test",
      expected_contract_version = "2026-08-16"
    )
  )
  expect_identical(
    manifest$artifact_role[manifest$artifact == "_gfcf_canonical.rds"],
    "raw_gfcf_diagnostic"
  )

  reversed_contracts <- source_normalization_environment$wlv_build_source_manifest(
    source_root = normalized_dir,
    artifacts = manifest$artifact,
    artifact_roles = manifest$artifact_role,
    contract_path = rev(fixture$contract_paths),
    contract_id = "wiod-test",
    contract_version = "2026-08-16"
  )
  expect_identical(reversed_contracts, manifest)

  for (artifact in c(
    "m_io.fst", "m_io.fst.meta", "countries.csv", "_gfcf_canonical.rds"
  )) {
    path <- file.path(normalized_dir, artifact)
    original <- wlv_test_file_bytes(path)
    wlv_test_flip_last_byte(path)
    expect_error(
      source_normalization_environment$wlv_verify_source_manifest(
        manifest,
        normalized_dir,
        fixture$contract_paths
      ),
      paste0("SHA-256 mismatch for source artifact `", artifact, "`"),
      fixed = TRUE
    )
    writeBin(original, path)
  }

  wlv_test_flip_last_byte(fixture$contract_paths[[2L]])
  expect_error(
    source_normalization_environment$wlv_verify_source_manifest(
      manifest,
      normalized_dir,
      fixture$contract_paths
    ),
    "Contract SHA-256 mismatch",
    fixed = TRUE
  )
})

test_that("failed atomic installation restores the previous normalized generation", {
  fixture <- wlv_make_source_publication_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  wlv_publish_source_fixture(fixture)
  normalized_dir <- file.path(fixture$root, "normalized")
  previous <- wlv_test_directory_snapshot(normalized_dir)

  replacement <- fixture$normalized
  replacement$m_io[[1L]] <- replacement$m_io[[1L]] + 123
  base_file_rename <- base::file.rename
  source_normalization_environment$file.rename <- function(from, to) {
    is_install <-
      startsWith(basename(from), ".normalized-staging-") &&
      identical(basename(to), "normalized")
    if (is_install) {
      return(FALSE)
    }
    base_file_rename(from, to)
  }
  on.exit(
    rm("file.rename", envir = source_normalization_environment),
    add = TRUE
  )

  expect_error(
    wlv_publish_source_fixture(fixture, replacement),
    "Could not install the normalized source generation.",
    fixed = TRUE
  )
  expect_identical(wlv_test_directory_snapshot(normalized_dir), previous)
  expect_length(
    list.files(
      fixture$root,
      pattern = "^[.]normalized-(staging|backup)-",
      all.files = TRUE
    ),
    0L
  )
})

test_that("rollback copies and verifies the backup when rename restoration fails", {
  fixture <- wlv_make_source_publication_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  wlv_publish_source_fixture(fixture)
  normalized_dir <- file.path(fixture$root, "normalized")
  previous <- wlv_test_directory_snapshot(normalized_dir)

  replacement <- fixture$normalized
  replacement$m_io[[1L]] <- replacement$m_io[[1L]] + 456
  base_file_rename <- base::file.rename
  source_normalization_environment$file.rename <- function(from, to) {
    is_install <-
      startsWith(basename(from), ".normalized-staging-") &&
      identical(basename(to), "normalized")
    is_restore <-
      startsWith(basename(from), ".normalized-backup-") &&
      identical(basename(to), "normalized")
    if (is_install || is_restore) {
      return(FALSE)
    }
    base_file_rename(from, to)
  }
  on.exit(
    rm("file.rename", envir = source_normalization_environment),
    add = TRUE
  )

  expect_error(
    wlv_publish_source_fixture(fixture, replacement),
    "Could not install the normalized source generation.",
    fixed = TRUE
  )
  expect_identical(wlv_test_directory_snapshot(normalized_dir), previous)
  expect_length(
    list.files(
      fixture$root,
      pattern = "^[.]normalized-(staging|backup)-",
      all.files = TRUE
    ),
    0L
  )
})
