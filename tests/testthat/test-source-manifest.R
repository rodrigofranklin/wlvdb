source_manifest_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "source_manifest.R"),
  envir = source_manifest_environment
)

wlv_write_manifest_fixture_file <- function(path, value) {
  writeBin(charToRaw(value), path)
  invisible(path)
}

wlv_make_source_manifest_fixture <- function() {
  root <- tempfile("wlv-source-manifest-")
  dir.create(root)
  files <- c(
    "m_io.fst" = "fst-one",
    "m_io.fst.meta" = "meta-one",
    "labels.csv" = "code,value\nx,1\n"
  )
  for (name in names(files)) {
    wlv_write_manifest_fixture_file(file.path(root, name), files[[name]])
  }
  contract_path <- wlv_write_manifest_fixture_file(
    file.path(root, "unit-contract.csv"),
    "contract_id,unit\nwiod-test,usd\n"
  )
  list(
    root = root,
    files = files,
    contract_path = contract_path,
    artifacts = names(files),
    roles = c("array", "array-metadata", "labels")
  )
}

wlv_build_fixture_manifest <- function(fixture, reverse = FALSE) {
  index <- seq_along(fixture$artifacts)
  if (reverse) {
    index <- rev(index)
  }
  source_manifest_environment$wlv_build_source_manifest(
    source_root = fixture$root,
    artifacts = fixture$artifacts[index],
    artifact_roles = fixture$roles[index],
    contract_path = fixture$contract_path,
    contract_id = "wiod-test",
    contract_version = "2026-08-16"
  )
}

test_that("source SHA-256 and generation IDs are deterministic", {
  fixture <- wlv_make_source_manifest_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  expect_identical(
    source_manifest_environment$wlv_source_file_sha256(
      wlv_write_manifest_fixture_file(file.path(fixture$root, "abc.bin"), "abc")
    ),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
  forward <- wlv_build_fixture_manifest(fixture)
  reverse <- wlv_build_fixture_manifest(fixture, reverse = TRUE)
  expect_identical(forward, reverse)
  expect_identical(forward$artifact, sort(fixture$artifacts, method = "radix"))
  expect_identical(
    forward$source_generation_id[[1L]],
    "329fc2584d688761c4b3b64d8fb92c41f48c8868c09606aafd969c53532f2542"
  )
  expect_identical(
    source_manifest_environment$wlv_source_manifest_sha256(forward),
    "77207fd5edbf14dd8e516a2486a3793c4ada6c8ebf78a163d044386a70c9886a"
  )
  expect_length(unique(forward$source_generation_id), 1L)

  timestamps <- Sys.time() - seq_along(fixture$artifacts) * 3600
  for (index in seq_along(fixture$artifacts)) {
    Sys.setFileTime(file.path(fixture$root, fixture$artifacts[[index]]), timestamps[[index]])
  }
  after_timestamp_change <- wlv_build_fixture_manifest(fixture)
  expect_identical(forward, after_timestamp_change)
})

test_that("source manifest CSV has an exact schema and verified contents", {
  fixture <- wlv_make_source_manifest_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  manifest <- wlv_build_fixture_manifest(fixture)
  path <- file.path(fixture$root, "source-manifest.csv")

  expect_identical(
    source_manifest_environment$wlv_write_source_manifest(manifest, path),
    path
  )
  expect_identical(
    source_manifest_environment$wlv_read_source_manifest(path),
    manifest
  )
  expect_no_error(source_manifest_environment$wlv_verify_source_manifest(
    path,
    fixture$root,
    fixture$contract_path,
    expected_contract_id = "wiod-test",
    expected_contract_version = "2026-08-16"
  ))

  malformed <- file.path(fixture$root, "malformed.csv")
  utils::write.csv(manifest[rev(names(manifest))], malformed, row.names = FALSE)
  expect_error(
    source_manifest_environment$wlv_read_source_manifest(malformed),
    "exactly these columns"
  )

  invalid_generation <- manifest
  invalid_generation$source_generation_id <- paste0(
    "0",
    substring(invalid_generation$source_generation_id, 2L)
  )
  utils::write.csv(invalid_generation, malformed, row.names = FALSE)
  expect_error(
    source_manifest_environment$wlv_read_source_manifest(malformed),
    "generation ID does not match"
  )
})

test_that("verification detects tampering in fst, metadata, CSV, and contract files", {
  fixture <- wlv_make_source_manifest_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  manifest <- wlv_build_fixture_manifest(fixture)

  replacements <- c(
    "m_io.fst" = "fst-ONE",
    "m_io.fst.meta" = "meta-ONE",
    "labels.csv" = "code,value\nx,2\n"
  )
  for (artifact in names(replacements)) {
    path <- file.path(fixture$root, artifact)
    wlv_write_manifest_fixture_file(path, replacements[[artifact]])
    expect_error(
      source_manifest_environment$wlv_verify_source_manifest(
        manifest,
        fixture$root,
        fixture$contract_path
      ),
      paste0("SHA-256 mismatch for source artifact `", artifact, "`"),
      fixed = TRUE
    )
    wlv_write_manifest_fixture_file(path, fixture$files[[artifact]])
  }

  wlv_write_manifest_fixture_file(
    fixture$contract_path,
    "contract_id,unit\nwiod-test,lcu\n"
  )
  expect_error(
    source_manifest_environment$wlv_verify_source_manifest(
      manifest,
      fixture$root,
      fixture$contract_path
    ),
    "Contract SHA-256 mismatch",
    fixed = TRUE
  )
})

test_that("result provenance snapshots block unsafe recalculations", {
  fixture <- wlv_make_source_manifest_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  result_dir <- file.path(fixture$root, "result")
  dir.create(result_dir)
  manifest <- wlv_build_fixture_manifest(fixture)

  path <- source_manifest_environment$wlv_write_result_source_provenance(
    result_dir,
    "wiod-test",
    manifest
  )
  expect_identical(
    path,
    file.path(result_dir, "_source_provenance.csv")
  )
  provenance <- source_manifest_environment$wlv_read_result_source_provenance(result_dir)
  expect_identical(
    names(provenance),
    source_manifest_environment$wlv_source_provenance_schema
  )
  expect_identical(provenance$source_generation_id, manifest$source_generation_id[[1L]])
  expect_no_error(
    source_manifest_environment$wlv_assert_recalculation_source_provenance(
      result_dir,
      manifest,
      "wiod-test"
    )
  )

  wlv_write_manifest_fixture_file(file.path(fixture$root, "labels.csv"), "code,value\nx,2\n")
  changed_generation <- wlv_build_fixture_manifest(fixture)
  expect_error(
    source_manifest_environment$wlv_assert_recalculation_source_provenance(
      result_dir,
      changed_generation,
      "wiod-test"
    ),
    "source generation differs",
    fixed = TRUE
  )
  wlv_write_manifest_fixture_file(
    file.path(fixture$root, "labels.csv"),
    fixture$files[["labels.csv"]]
  )

  wlv_write_manifest_fixture_file(
    fixture$contract_path,
    "contract_id,unit\nwiod-test,lcu\n"
  )
  changed_contract <- wlv_build_fixture_manifest(fixture)
  expect_error(
    source_manifest_environment$wlv_assert_recalculation_source_provenance(
      result_dir,
      changed_contract,
      "wiod-test"
    ),
    "source unit contract differs",
    fixed = TRUE
  )

  legacy_result <- file.path(fixture$root, "legacy-result")
  dir.create(legacy_result)
  expect_error(
    source_manifest_environment$wlv_assert_recalculation_source_provenance(
      legacy_result,
      manifest,
      "wiod-test"
    ),
    "legacy result has no source-provenance sidecar",
    fixed = TRUE
  )
})
