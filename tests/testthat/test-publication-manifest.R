publication_manifest_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "source_manifest.R"),
  envir = publication_manifest_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "publication_manifest.R"),
  envir = publication_manifest_environment
)

wlv_publication_write_fixture <- function(path, value) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeBin(charToRaw(enc2utf8(value)), path)
  invisible(path)
}

wlv_make_publication_fixture <- function() {
  root <- tempfile("wlv-publication-")
  run_root <- file.path(root, "runs", "wiodr13", "run-001")
  dir.create(run_root, recursive = TRUE)
  files <- c(
    "arrays/labour_values.fst" = "fst-payload-v1",
    "arrays/labour_values.fst.meta" = "meta-payload-v1",
    "diagnostics/audit.csv" = "indicador,descri\u00e7\u00e3o\nv,valor do trabalho\n"
  )
  for (path in names(files)) {
    wlv_publication_write_fixture(file.path(run_root, path), files[[path]])
  }
  list(
    root = root,
    run_root = run_root,
    files = files,
    artifacts = names(files),
    roles = c("array", "array-metadata", "diagnostics")
  )
}

wlv_build_publication_fixture_run <- function(
    fixture,
    run_id = "run-001",
    created_at_utc = "2026-08-20T12:00:00Z",
    parent_run_id = NULL,
    execution = list(
      started_at_utc = "2026-08-20T11:59:00Z",
      finished_at_utc = "2026-08-20T12:00:00Z",
      duration_seconds = 60,
      warnings = "Aviso com acentua\u00e7\u00e3o",
      host = list(
        r_version = "4.5.1",
        platform = "x86_64-w64-mingw32",
        os = "mingw32",
        arch = "x86_64"
      )
    ),
    result = list(
      provenance = list(
        git = list(
          commit = paste(rep("a", 40L), collapse = ""),
          dirty = FALSE
        )
      ),
      request = list(mode = "calculate", years = c(2000L, 2001L)),
      schema = list(indicators = c("v", "m")),
      audit_summary = list(valid = TRUE)
    )) {
  publication_manifest_environment$wlv_build_run_manifest(
    run_root = fixture$run_root,
    artifacts = rev(fixture$artifacts),
    artifact_roles = rev(fixture$roles),
    run_id = run_id,
    method = "wiodr13",
    result = result,
    execution = execution,
    created_at_utc = created_at_utc,
    parent_run_id = parent_run_id
  )
}

test_that("publication file resolution rejects internal links", {
  fixture <- wlv_make_publication_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  target <- file.path(fixture$run_root, "target")
  alias <- file.path(fixture$run_root, "alias")
  dir.create(target)
  wlv_publication_write_fixture(file.path(target, "payload.bin"), "payload")
  linked <- if (.Platform$OS.type == "windows" &&
      exists("Sys.junction", envir = baseenv(), mode = "function")) {
    suppressWarnings(Sys.junction(target, alias))
  } else {
    suppressWarnings(file.symlink(target, alias))
  }
  if (!isTRUE(linked)) {
    skip("This platform cannot create a directory link for the resolver test.")
  }

  expect_error(
    publication_manifest_environment$wlv_publication_resolve_files(
      fixture$run_root,
      "alias/payload.bin"
    ),
    "canonical link-free paths"
  )
  unlink(alias, recursive = FALSE, force = TRUE)
  expect_true(file.exists(file.path(target, "payload.bin")))

  target_file <- file.path(fixture$run_root, "target-file.bin")
  alias_file <- file.path(fixture$run_root, "alias-file.bin")
  wlv_publication_write_fixture(target_file, "file-payload")
  if (isTRUE(suppressWarnings(file.symlink(target_file, alias_file)))) {
    expect_error(
      publication_manifest_environment$wlv_publication_resolve_files(
        fixture$run_root,
        "alias-file.bin"
      ),
      "canonical link-free paths"
    )
    unlink(alias_file, recursive = FALSE, force = TRUE)
    expect_true(file.exists(target_file))
  }
})

test_that("channel marker validation rejects a marker file symlink", {
  root <- tempfile("wlv-marker-link-")
  results <- file.path(root, "results")
  release_id <- "release-test"
  for (path in c(
    file.path(results, "runs"),
    file.path(results, "releases", release_id),
    file.path(results, "channels", "stable")
  )) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  marker <- publication_manifest_environment$wlv_build_channel_marker(
    channel = "stable",
    sequence = "00000000000000000001",
    release_id = release_id,
    release_manifest_path = paste(
      "releases",
      release_id,
      "release_manifest.json",
      sep = "/"
    ),
    release_manifest_sha256 = strrep("0", 64L)
  )
  channel_root <- file.path(results, "channels", "stable")
  marker_path <- file.path(
    channel_root,
    publication_manifest_environment$wlv_channel_marker_filename(
      marker$sequence,
      marker$release_id
    )
  )
  backup_path <- file.path(channel_root, "backup.json")
  wlv_publication_write_fixture(backup_path, "{}")
  expect_true(file.exists(backup_path))
  if (isTRUE(suppressWarnings(file.symlink(backup_path, marker_path)))) {
    expect_error(
      publication_manifest_environment$wlv_validate_channel_marker_path(
        marker,
        results,
        marker_path,
        must_exist = TRUE
      ),
      "symbolic link|does not match channel"
    )
    unlink(marker_path, recursive = FALSE, force = TRUE)
    expect_true(file.exists(backup_path))
  }
})

test_that("run result_id is stable and excludes volatile execution identity", {
  fixture <- wlv_make_publication_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  first <- wlv_build_publication_fixture_run(fixture)
  second <- wlv_build_publication_fixture_run(
    fixture,
    run_id = "run-002",
    created_at_utc = "2026-08-21T12:00:00Z",
    parent_run_id = "run-001",
    execution = list(
      started_at_utc = "2026-08-21T11:55:00Z",
      finished_at_utc = "2026-08-21T12:00:00Z",
      duration_seconds = 300,
      warnings = character(),
      host = list(r_version = "4.5.2", os = "linux", arch = "x86_64")
    )
  )

  expect_false(identical(first$run_id, second$run_id))
  expect_identical(first$result_id, second$result_id)
  expect_identical(
    vapply(first$artifacts, `[[`, character(1), "path"),
    sort(fixture$artifacts, method = "radix")
  )

  changed_result <- first$result
  changed_result$request$mode <- "recalculate"
  semantic_change <- wlv_build_publication_fixture_run(
    fixture,
    run_id = "run-003",
    result = changed_result
  )
  expect_false(identical(first$result_id, semantic_change$result_id))

  wlv_publication_write_fixture(
    file.path(fixture$run_root, "arrays", "labour_values.fst"),
    "fst-payload-v2"
  )
  artifact_change <- wlv_build_publication_fixture_run(
    fixture,
    run_id = "run-004"
  )
  expect_false(identical(first$result_id, artifact_change$result_id))
})

test_that("run manifests round-trip as strict UTF-8 JSON", {
  fixture <- wlv_make_publication_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  manifest <- wlv_build_publication_fixture_run(fixture)
  path <- file.path(fixture$run_root, "run_manifest.json")

  expect_identical(
    publication_manifest_environment$wlv_write_run_manifest(manifest, path),
    path
  )
  roundtrip <- publication_manifest_environment$wlv_read_run_manifest(path)
  expect_true(publication_manifest_environment$wlv_publication_json_identical(
    manifest,
    roundtrip
  ))
  installed_text <- rawToChar(readBin(path, "raw", n = file.info(path)$size))
  Encoding(installed_text) <- "UTF-8"
  expect_match(installed_text,
    "Aviso com acentua\u00e7\u00e3o",
    fixed = TRUE
  )
  expect_no_error(publication_manifest_environment$wlv_verify_run_manifest(
    path,
    fixture$run_root
  ))
  expect_error(
    publication_manifest_environment$wlv_write_run_manifest(manifest, path),
    "Refusing to overwrite"
  )

  extra_field <- manifest
  extra_field$unexpected <- TRUE
  expect_error(
    publication_manifest_environment$wlv_validate_run_manifest(extra_field),
    "exactly these fields"
  )
  wrong_version <- manifest
  wrong_version$schema_version <- "2"
  expect_error(
    publication_manifest_environment$wlv_validate_run_manifest(wrong_version),
    "Unsupported run manifest schema version"
  )
  unsupported_result <- manifest
  unsupported_result$result$volatile_note <- list(value = "no")
  expect_error(
    publication_manifest_environment$wlv_validate_run_manifest(unsupported_result),
    "unsupported fields"
  )
  unsupported_execution <- manifest
  unsupported_execution$execution$command_line <- "Rscript"
  expect_error(
    publication_manifest_environment$wlv_validate_run_manifest(unsupported_execution),
    "unsupported fields"
  )
  missing_parent <- manifest
  missing_parent$parent_run_id <- NULL
  missing_parent <- missing_parent[names(missing_parent) != "parent_run_id"]
  expect_error(
    publication_manifest_environment$wlv_validate_run_manifest(missing_parent),
    "exactly these fields"
  )

  invalid_utf8 <- file.path(fixture$root, "invalid.json")
  writeBin(as.raw(0xff), invalid_utf8)
  expect_error(
    publication_manifest_environment$wlv_read_run_manifest(invalid_utf8),
    "not valid UTF-8"
  )
})

test_that("run verification detects corruption, missing files, and extras", {
  fixture <- wlv_make_publication_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  manifest <- wlv_build_publication_fixture_run(fixture)
  manifest_path <- file.path(fixture$run_root, "run_manifest.json")
  publication_manifest_environment$wlv_write_run_manifest(manifest, manifest_path)

  fst_path <- file.path(fixture$run_root, "arrays", "labour_values.fst")
  wlv_publication_write_fixture(fst_path, "fst-PAYLOAD-v1")
  expect_error(
    publication_manifest_environment$wlv_verify_run_manifest(
      manifest,
      fixture$run_root
    ),
    "SHA-256 mismatch"
  )
  wlv_publication_write_fixture(fst_path, fixture$files[["arrays/labour_values.fst"]])

  meta_path <- file.path(fixture$run_root, "arrays", "labour_values.fst.meta")
  unlink(meta_path)
  expect_error(
    publication_manifest_environment$wlv_verify_run_manifest(
      manifest,
      fixture$run_root
    ),
    "missing: arrays/labour_values.fst.meta",
    fixed = TRUE
  )
  wlv_publication_write_fixture(
    meta_path,
    fixture$files[["arrays/labour_values.fst.meta"]]
  )

  extra <- wlv_publication_write_fixture(
    file.path(fixture$run_root, "unexpected.csv"),
    "unexpected"
  )
  expect_error(
    publication_manifest_environment$wlv_verify_run_manifest(
      manifest,
      fixture$run_root
    ),
    "unlisted: unexpected.csv",
    fixed = TRUE
  )
  expect_no_error(publication_manifest_environment$wlv_verify_run_manifest(
    manifest,
    fixture$run_root,
    reject_unlisted = FALSE
  ))
  unlink(extra)
})

test_that("publication paths are contained and FST sidecars are inseparable", {
  fixture <- wlv_make_publication_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  manifest <- wlv_build_publication_fixture_run(fixture)

  traversing <- manifest
  traversing$artifacts[[1L]]$path <- "../outside.fst"
  expect_error(
    publication_manifest_environment$wlv_validate_run_manifest(traversing),
    "relative paths"
  )
  absolute <- manifest
  absolute$artifacts[[1L]]$path <- "C:/outside.fst"
  expect_error(
    publication_manifest_environment$wlv_validate_run_manifest(absolute),
    "relative paths"
  )

  expect_error(
    publication_manifest_environment$wlv_build_run_manifest(
      fixture$run_root,
      artifacts = c(
        "arrays/labour_values.fst",
        "diagnostics/audit.csv"
      ),
      artifact_roles = c("array", "diagnostics"),
      run_id = "unpaired-fst",
      method = "wiodr13"
    ),
    "missing sidecars"
  )
  expect_error(
    publication_manifest_environment$wlv_build_run_manifest(
      fixture$run_root,
      artifacts = "arrays/labour_values.fst.meta",
      artifact_roles = "array-metadata",
      run_id = "orphan-meta",
      method = "wiodr13"
    ),
    "orphan sidecars"
  )

  manifest_path <- file.path(fixture$run_root, "run_manifest.json")
  publication_manifest_environment$wlv_write_run_manifest(manifest, manifest_path)
  expect_error(
    publication_manifest_environment$wlv_build_run_manifest(
      fixture$run_root,
      artifacts = c(fixture$artifacts, "run_manifest.json"),
      artifact_roles = c(fixture$roles, "manifest"),
      run_id = "self-hash",
      method = "wiodr13"
    ),
    "must not inventory themselves"
  )
})

test_that("release and channel marker verify the complete publication chain", {
  fixture <- wlv_make_publication_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  run <- wlv_build_publication_fixture_run(fixture)
  run_manifest_path <- file.path(fixture$run_root, "run_manifest.json")
  publication_manifest_environment$wlv_write_run_manifest(run, run_manifest_path)

  run_reference <- publication_manifest_environment$wlv_build_release_run_reference(
    fixture$root,
    method = "wiodr13",
    manifest_path = "runs/wiodr13/run-001/run_manifest.json"
  )
  expect_identical(
    names(run_reference),
    publication_manifest_environment$wlv_publication_run_reference_fields
  )

  release_root <- file.path(fixture$root, "releases", "release-001")
  dir.create(release_root, recursive = TRUE)
  wlv_publication_write_fixture(
    file.path(release_root, "labels.csv"),
    "indicador,r\u00f3tulo\nv,Valor do trabalho\n"
  )
  release <- publication_manifest_environment$wlv_build_release_manifest(
    release_root = release_root,
    artifacts = "labels.csv",
    artifact_roles = "labels",
    release_id = "release-001",
    channel = "stable",
    sequence = "00000000000000000001",
    runs = list(run_reference),
    metadata = list(title = "Publica\u00e7\u00e3o est\u00e1vel"),
    created_at_utc = "2026-08-20T12:01:00Z"
  )
  release_manifest_path <- file.path(release_root, "release_manifest.json")
  publication_manifest_environment$wlv_write_release_manifest(
    release,
    release_manifest_path
  )
  expect_no_error(publication_manifest_environment$wlv_verify_release_manifest(
    release_manifest_path,
    release_root,
    publication_root = fixture$root
  ))
  relocated_release <- release
  relocated_release$runs[[1L]]$manifest_path <- "copies/run_manifest.json"
  expect_error(
    publication_manifest_environment$wlv_validate_release_manifest(
      relocated_release
    ),
    "must use canonical path"
  )

  marker <- publication_manifest_environment$wlv_build_channel_marker(
    channel = "stable",
    sequence = "00000000000000000001",
    release_id = "release-001",
    release_manifest_path = "releases/release-001/release_manifest.json",
    release_manifest_sha256 = publication_manifest_environment$wlv_publication_file_sha256(
      release_manifest_path
    ),
    published_at_utc = "2026-08-20T12:02:00Z"
  )
  marker_root <- file.path(fixture$root, "channels", "stable")
  dir.create(marker_root, recursive = TRUE)
  marker_path <- file.path(
    marker_root,
    publication_manifest_environment$wlv_channel_marker_filename(
      marker$sequence,
      marker$release_id
    )
  )
  publication_manifest_environment$wlv_write_channel_marker(marker, marker_path)
  expect_no_error(publication_manifest_environment$wlv_verify_channel_marker(
    marker_path,
    fixture$root
  ))
  relocated_release_marker <- marker
  relocated_release_marker$release_manifest_path <-
    "copies/release_manifest.json"
  expect_error(
    publication_manifest_environment$wlv_validate_channel_marker(
      relocated_release_marker
    ),
    "release must use canonical path"
  )

  relocated_root <- file.path(fixture$root, "channels", "experiment")
  dir.create(relocated_root, recursive = TRUE)
  relocated_marker <- file.path(relocated_root, basename(marker_path))
  file.copy(marker_path, relocated_marker)
  expect_error(
    publication_manifest_environment$wlv_verify_channel_marker(
      relocated_marker,
      fixture$root
    ),
    "does not match channel `stable`",
    fixed = TRUE
  )

  expect_error(
    publication_manifest_environment$wlv_verify_channel_marker(
      marker,
      fixture$root,
      marker_path = file.path(marker_root, "00000000000000000002-release-001.json")
    ),
    "sequence does not match filename"
  )
  traversing <- marker
  traversing$release_manifest_path <- "../release_manifest.json"
  expect_error(
    publication_manifest_environment$wlv_validate_channel_marker(traversing),
    "relative paths"
  )

  labels_path <- file.path(release_root, "labels.csv")
  labels_payload <- "indicador,r\u00f3tulo\nv,Valor do trabalho\n"
  wlv_publication_write_fixture(labels_path, "corrupted release artifact")
  expect_error(
    publication_manifest_environment$wlv_verify_release_manifest(
      release,
      release_root,
      publication_root = fixture$root
    ),
    "Size mismatch|SHA-256 mismatch"
  )
  wlv_publication_write_fixture(labels_path, labels_payload)
  release_extra <- wlv_publication_write_fixture(
    file.path(release_root, "unlisted.csv"),
    "unlisted"
  )
  expect_error(
    publication_manifest_environment$wlv_verify_release_manifest(
      release,
      release_root,
      publication_root = fixture$root
    ),
    "unlisted: unlisted.csv",
    fixed = TRUE
  )
  unlink(release_extra)

  mismatched_reference <- release
  mismatched_reference$runs[[1L]]$result_id <- paste0(rep("0", 64L), collapse = "")
  expect_error(
    publication_manifest_environment$wlv_verify_release_manifest(
      mismatched_reference,
      release_root,
      publication_root = fixture$root
    ),
    "Run reference identity mismatch"
  )

  original_run_manifest <- readBin(
    run_manifest_path,
    "raw",
    n = file.info(run_manifest_path)$size
  )
  writeBin(c(original_run_manifest, charToRaw(" ")), run_manifest_path)
  expect_error(
    publication_manifest_environment$wlv_verify_release_manifest(
      release,
      release_root,
      publication_root = fixture$root
    ),
    "Run manifest SHA-256 mismatch"
  )
  writeBin(original_run_manifest, run_manifest_path)

  original_release_manifest <- readBin(
    release_manifest_path,
    "raw",
    n = file.info(release_manifest_path)$size
  )
  writeBin(c(original_release_manifest, charToRaw(" ")), release_manifest_path)
  expect_error(
    publication_manifest_environment$wlv_verify_channel_marker(
      marker,
      fixture$root,
      marker_path = marker_path
    ),
    "Release manifest SHA-256 mismatch"
  )
})

test_that("checked-in JSON schemas use the synchronized v1 literals", {
  schemas <- c(
    "run-manifest-v1.schema.json",
    "release-manifest-v1.schema.json",
    "channel-marker-v1.schema.json"
  )
  expected <- c(
    "wlv-run-manifest",
    "wlv-release-manifest",
    "wlv-channel-marker"
  )
  for (index in seq_along(schemas)) {
    path <- file.path(wlv_test_root, "contracts", "results", schemas[[index]])
    schema_text <- paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
    expect_true(jsonlite::validate(schema_text))
    schema <- jsonlite::read_json(path, simplifyVector = FALSE)
    expect_identical(schema$properties$schema$const, expected[[index]])
    expect_identical(schema$properties$schema_version$const, "1")
  }
  run_schema <- jsonlite::read_json(
    file.path(
      wlv_test_root,
      "contracts",
      "results",
      "run-manifest-v1.schema.json"
    ),
    simplifyVector = FALSE
  )
  expect_identical(
    run_schema$properties$output_contract$properties$id$const,
    "wlvpanel-output"
  )
  expect_identical(
    run_schema$properties$output_contract$properties$version$const,
    "1.0.0"
  )
})

test_that("normative schema patterns reject non-canonical channels and paths", {
  release_schema <- jsonlite::read_json(
    file.path(
      wlv_test_root,
      "contracts",
      "results",
      "release-manifest-v1.schema.json"
    ),
    simplifyVector = FALSE
  )
  run_schema <- jsonlite::read_json(
    file.path(
      wlv_test_root,
      "contracts",
      "results",
      "run-manifest-v1.schema.json"
    ),
    simplifyVector = FALSE
  )
  marker_schema <- jsonlite::read_json(
    file.path(
      wlv_test_root,
      "contracts",
      "results",
      "channel-marker-v1.schema.json"
    ),
    simplifyVector = FALSE
  )
  channel_pattern <- release_schema[["$defs"]][["channel"]][["pattern"]]
  marker_channel_pattern <- marker_schema[["properties"]][["channel"]][[
    "pattern"
  ]]
  path_pattern <- run_schema[["$defs"]][["relative_path"]][["pattern"]]
  run_manifest_pattern <- release_schema[["$defs"]][["run_reference"]][[
    "properties"
  ]][["manifest_path"]][["pattern"]]
  release_manifest_pattern <- marker_schema[["properties"]][[
    "release_manifest_path"
  ]][["pattern"]]

  expect_true(all(grepl(
    channel_pattern,
    c("stable", "research/input-v3"),
    perl = TRUE
  )))
  expect_false(any(grepl(
    channel_pattern,
    c("a/../b", "a//b", "a/", "a/.hidden", "stable.", "a/v2."),
    perl = TRUE
  )))
  expect_identical(marker_channel_pattern, channel_pattern)
  expect_true(all(grepl(
    path_pattern,
    c("a.txt", "runs/a/run.json", "nome válido.csv"),
    perl = TRUE
  )))
  expect_false(any(grepl(
    path_pattern,
    c("a/../b", "a/./b", "a//b", "a/", "a\\b", "C:/x", "a. /b"),
    perl = TRUE
  )))
  expect_true(grepl(
    run_manifest_pattern,
    "runs/wiodr13/run-001/run_manifest.json",
    perl = TRUE
  ))
  expect_false(grepl(
    run_manifest_pattern,
    "copies/run_manifest.json",
    perl = TRUE
  ))
  expect_true(grepl(
    release_manifest_pattern,
    "releases/release-001/release_manifest.json",
    perl = TRUE
  ))
  expect_false(grepl(
    release_manifest_pattern,
    "copies/release_manifest.json",
    perl = TRUE
  ))
})
