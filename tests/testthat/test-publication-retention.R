retention_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "publication_manifest.R"),
  envir = retention_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "publication.R"),
  envir = retention_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "publication_retention.R"),
  envir = retention_environment
)

wlv_retention_test_requirements <- function() {
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("openssl")
}

wlv_retention_test_sequence <- function(value) {
  sprintf("%020d", as.integer(value))
}

wlv_retention_test_root <- function() {
  root <- tempfile("wlv-publication-retention-")
  dir.create(root, recursive = TRUE)
  paths <- retention_environment$wlv_publication_paths(root)
  for (path in unname(paths[c("results", "runs", "releases", "channels")])) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  normalizePath(root, winslash = "/", mustWork = TRUE)
}

wlv_retention_test_run <- function(root, method, run_id, payload = run_id) {
  paths <- retention_environment$wlv_publication_paths(root)
  run_root <- file.path(paths$runs, method, run_id)
  dir.create(run_root, recursive = TRUE, showWarnings = FALSE)
  artifact <- file.path(run_root, "result.bin")
  writeBin(charToRaw(enc2utf8(payload)), artifact)
  manifest <- retention_environment$wlv_build_run_manifest(
    run_root = run_root,
    artifacts = "result.bin",
    artifact_roles = "result",
    run_id = run_id,
    method = method,
    result = list(),
    execution = list()
  )
  manifest_path <- file.path(
    run_root,
    retention_environment$wlv_run_manifest_filename()
  )
  retention_environment$wlv_write_run_manifest(manifest, manifest_path)
  relative_manifest <- paste(
    "runs",
    method,
    run_id,
    retention_environment$wlv_run_manifest_filename(),
    sep = "/"
  )
  list(
    root = run_root,
    artifact = artifact,
    manifest = manifest,
    reference = retention_environment$wlv_build_release_run_reference(
      publication_root = paths$results,
      method = method,
      manifest_path = relative_manifest
    )
  )
}

wlv_retention_test_release <- function(
    root,
    channel,
    sequence,
    release_id,
    run,
    marker = TRUE) {
  paths <- retention_environment$wlv_publication_paths(root)
  release_root <- file.path(paths$releases, release_id)
  dir.create(release_root, recursive = TRUE, showWarnings = FALSE)
  sequence <- wlv_retention_test_sequence(sequence)
  manifest <- retention_environment$wlv_build_release_manifest(
    release_root = release_root,
    artifacts = character(),
    artifact_roles = character(),
    release_id = release_id,
    channel = channel,
    sequence = sequence,
    runs = list(run$reference),
    metadata = list()
  )
  manifest_path <- file.path(
    release_root,
    retention_environment$wlv_release_manifest_filename()
  )
  retention_environment$wlv_write_release_manifest(manifest, manifest_path)
  marker_path <- NULL
  if (isTRUE(marker)) {
    marker_value <- retention_environment$wlv_build_channel_marker(
      channel = channel,
      sequence = sequence,
      release_id = release_id,
      release_manifest_path = paste(
        "releases",
        release_id,
        retention_environment$wlv_release_manifest_filename(),
        sep = "/"
      ),
      release_manifest_sha256 =
        retention_environment$wlv_publication_file_sha256(manifest_path)
    )
    channel_root <- file.path(paths$channels, channel)
    dir.create(channel_root, recursive = TRUE, showWarnings = FALSE)
    marker_path <- file.path(
      channel_root,
      retention_environment$wlv_channel_marker_filename(sequence, release_id)
    )
    retention_environment$wlv_write_channel_marker(marker_value, marker_path)
  }
  list(
    root = release_root,
    manifest_path = manifest_path,
    marker_path = marker_path,
    manifest = manifest,
    run = run
  )
}

wlv_retention_test_fixture <- function() {
  root <- wlv_retention_test_root()
  stable_runs <- lapply(1:3, function(index) {
    wlv_retention_test_run(root, "core", paste0("run-stable-", index))
  })
  stable <- lapply(1:3, function(index) {
    wlv_retention_test_release(
      root,
      channel = "stable",
      sequence = index,
      release_id = paste0("release-stable-", index),
      run = stable_runs[[index]]
    )
  })
  experiment_runs <- lapply(1:2, function(index) {
    wlv_retention_test_run(root, "core", paste0("run-experiment-", index))
  })
  experiment <- lapply(1:2, function(index) {
    wlv_retention_test_release(
      root,
      channel = "exploration/v2",
      sequence = index,
      release_id = paste0("release-experiment-", index),
      run = experiment_runs[[index]]
    )
  })
  orphan_run <- wlv_retention_test_run(root, "core", "run-orphan")
  orphan_release <- wlv_retention_test_release(
    root,
    channel = "stable",
    sequence = 4L,
    release_id = "release-orphan",
    run = orphan_run,
    marker = FALSE
  )
  list(
    root = root,
    stable = stable,
    experiment = experiment,
    orphan_release = orphan_release,
    orphan_run = orphan_run
  )
}

test_that("retention planning is channel-aware and preserves current releases", {
  wlv_retention_test_requirements()
  fixture <- wlv_retention_test_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  plan <- retention_environment$wlv_plan_publication_prune(
    fixture$root,
    keep_releases = c(stable = 2, `exploration/v2` = 1)
  )

  expect_s3_class(plan, "wlv_publication_prune_plan")
  expect_equal(nrow(plan$delete$markers), 2L)
  expect_equal(nrow(plan$delete$releases), 3L)
  expect_equal(nrow(plan$delete$runs), 3L)
  expect_gt(plan$reclaimable_bytes, 0)
  expect_setequal(
    plan$channels$current_release_id,
    c("release-stable-3", "release-experiment-2")
  )
  expect_false(any(plan$delete$markers$release_id %in%
    plan$channels$current_release_id))
  expect_true(all(c(
    "releases/release-stable-2",
    "releases/release-stable-3",
    "releases/release-experiment-2"
  ) %in% plan$retained$releases))
  expect_true(all(c(
    "runs/core/run-stable-2",
    "runs/core/run-stable-3",
    "runs/core/run-experiment-2"
  ) %in% plan$retained$runs))
})

test_that("unnamed policies apply to all channels and named omissions preserve a channel", {
  wlv_retention_test_requirements()
  fixture <- wlv_retention_test_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  global <- retention_environment$wlv_plan_publication_prune(
    fixture$root,
    keep_releases = 1L
  )
  expect_equal(nrow(global$delete$markers), 3L)

  stable_only <- retention_environment$wlv_plan_publication_prune(
    fixture$root,
    keep_releases = c(stable = 1L)
  )
  expect_false(any(startsWith(
    stable_only$delete$markers$path,
    "channels/exploration/v2/"
  )))
  expect_true(all(c(
    "releases/release-experiment-1",
    "releases/release-experiment-2"
  ) %in% stable_only$retained$releases))
})

test_that("pruning is a dry run by default and reports reclaimable bytes", {
  wlv_retention_test_requirements()
  fixture <- wlv_retention_test_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  plan <- retention_environment$wlv_plan_publication_prune(
    fixture$root,
    keep_releases = c(stable = 2, `exploration/v2` = 1)
  )
  before <- sort(list.files(
    fixture$root,
    recursive = TRUE,
    all.files = TRUE,
    full.names = FALSE
  ))

  report <- retention_environment$wlv_prune_publications(plan)
  after <- sort(list.files(
    fixture$root,
    recursive = TRUE,
    all.files = TRUE,
    full.names = FALSE
  ))

  expect_s3_class(report, "wlv_publication_prune_report")
  expect_true(report$dry_run)
  expect_identical(after, before)
  expect_identical(report$reclaimable_bytes, plan$reclaimable_bytes)
  expect_identical(report$reclaimed_bytes, 0)
  expect_true(all(lengths(report$deleted) == 0L))
})

test_that("an approved plan removes only eligible markers, releases, and runs", {
  wlv_retention_test_requirements()
  fixture <- wlv_retention_test_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  policy <- c(stable = 2, `exploration/v2` = 1)
  plan <- retention_environment$wlv_plan_publication_prune(
    fixture$root,
    keep_releases = policy
  )

  report <- retention_environment$wlv_prune_publications(
    plan,
    dry_run = FALSE
  )

  expect_false(report$dry_run)
  expect_identical(report$reclaimed_bytes, plan$reclaimable_bytes)
  for (type in names(plan$delete)) {
    expect_false(any(file.exists(file.path(
      plan$results_root,
      plan$delete[[type]]$path
    ))))
  }
  expect_true(all(file.exists(file.path(plan$results_root, plan$retained$markers))))
  expect_true(all(dir.exists(file.path(plan$results_root, plan$retained$releases))))
  expect_true(all(dir.exists(file.path(plan$results_root, plan$retained$runs))))
  expect_false(dir.exists(file.path(plan$results_root, ".lock-results")))

  verified <- retention_environment$wlv_plan_publication_prune(
    fixture$root,
    keep_releases = policy
  )
  expect_true(all(vapply(verified$delete, nrow, integer(1L)) == 0L))
})

test_that("interrupted quarantine cleanup cannot damage the active store", {
  wlv_retention_test_requirements()
  fixture <- wlv_retention_test_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  policy <- c(stable = 2, `exploration/v2` = 1)
  plan <- retention_environment$wlv_plan_publication_prune(
    fixture$root,
    keep_releases = policy
  )

  original_cleanup <- retention_environment$wlv_prune_cleanup_trash
  cleanup_calls <- 0L
  retention_environment$wlv_prune_cleanup_trash <- function(results_root) {
    cleanup_calls <<- cleanup_calls + 1L
    if (cleanup_calls == 2L) {
      stop("injected quarantine cleanup interruption", call. = FALSE)
    }
    original_cleanup(results_root)
  }
  expect_error(
    retention_environment$wlv_prune_publications(plan, dry_run = FALSE),
    "injected quarantine cleanup interruption",
    fixed = TRUE
  )
  retention_environment$wlv_prune_cleanup_trash <- original_cleanup

  trash <- file.path(plan$results_root, ".trash")
  expect_true(dir.exists(trash))
  expect_true(length(list.files(trash, all.files = TRUE, no.. = TRUE)) > 0L)
  expect_false(dir.exists(file.path(plan$results_root, ".lock-results")))
  recovered_plan <- retention_environment$wlv_plan_publication_prune(
    fixture$root,
    keep_releases = policy
  )
  expect_true(all(vapply(recovered_plan$delete, nrow, integer(1L)) == 0L))
  expect_no_error(retention_environment$wlv_prune_publications(
    recovered_plan,
    dry_run = FALSE
  ))
  expect_false(file.exists(trash))
})

test_that("a stale plan is rejected before any publication is deleted", {
  wlv_retention_test_requirements()
  fixture <- wlv_retention_test_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  plan <- retention_environment$wlv_plan_publication_prune(
    fixture$root,
    keep_releases = 1L
  )
  wlv_retention_test_run(fixture$root, "core", "run-created-after-plan")

  expect_error(
    retention_environment$wlv_prune_publications(plan, dry_run = FALSE),
    "changed after planning"
  )
  expect_true(all(file.exists(file.path(
    plan$results_root,
    plan$delete$markers$path
  ))))
  expect_false(dir.exists(file.path(plan$results_root, ".lock-results")))
})

test_that("a mutated plan cannot redirect retention cleanup", {
  wlv_retention_test_requirements()
  fixture <- wlv_retention_test_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  plan <- retention_environment$wlv_plan_publication_prune(
    fixture$root,
    keep_releases = 1L
  )

  outside <- tempfile("wlv-retention-outside-")
  sentinel <- file.path(outside, ".trash", "sentinel.txt")
  dir.create(dirname(sentinel), recursive = TRUE)
  writeLines("must remain", sentinel, useBytes = TRUE)
  on.exit(unlink(outside, recursive = TRUE, force = TRUE), add = TRUE)

  redirected <- plan
  redirected$results_root <- outside
  expect_error(
    retention_environment$wlv_prune_publications(
      redirected,
      dry_run = FALSE
    ),
    "canonical `results` directory",
    fixed = TRUE
  )
  expect_true(file.exists(sentinel))
  expect_false(dir.exists(file.path(outside, ".lock-results")))
})

test_that("retention rejects internally redirected directory entries", {
  root <- tempfile("wlv-retention-links-")
  tree <- file.path(root, "tree")
  sibling <- file.path(root, "sibling")
  dir.create(tree, recursive = TRUE)
  dir.create(sibling)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  link <- file.path(tree, "redirected")
  linked <- if (.Platform$OS.type == "windows" &&
      exists("Sys.junction", envir = baseenv(), mode = "function")) {
    suppressWarnings(Sys.junction(sibling, link))
  } else {
    suppressWarnings(file.symlink(sibling, link))
  }
  if (!isTRUE(linked)) {
    skip("This platform cannot create a directory link for the retention test.")
  }

  expect_error(
    retention_environment$wlv_prune_assert_tree(
      tree,
      root,
      "Retention test tree"
    ),
    "symbolic link or junction|redirected or outside"
  )
  unlink(link, recursive = FALSE, force = TRUE)
  expect_true(dir.exists(sibling))
})

test_that("retention planner rejects a redirected channel", {
  wlv_retention_test_requirements()
  root <- wlv_retention_test_root()
  paths <- retention_environment$wlv_publication_paths(root)
  experiment <- file.path(paths$channels, "experiment")
  stable <- file.path(paths$channels, "stable")
  dir.create(experiment)
  on.exit({
    if (dir.exists(stable) || file.exists(stable)) {
      unlink(stable, recursive = FALSE, force = TRUE)
    }
    unlink(root, recursive = TRUE, force = TRUE)
  }, add = TRUE)

  linked <- if (.Platform$OS.type == "windows" &&
      exists("Sys.junction", envir = baseenv(), mode = "function")) {
    suppressWarnings(Sys.junction(experiment, stable))
  } else {
    suppressWarnings(file.symlink(experiment, stable))
  }
  if (!isTRUE(linked)) {
    skip("This platform cannot create a directory link for the retention test.")
  }

  expect_error(
    retention_environment$wlv_plan_publication_prune(root, 1L),
    "symbolic link or junction|redirected or outside"
  )
  unlink(stable, recursive = FALSE, force = TRUE)
  expect_true(dir.exists(experiment))
})

test_that("invalid manifests and inconsistent stores block retention", {
  wlv_retention_test_requirements()
  fixture <- wlv_retention_test_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  writeBin(charToRaw("tampered"), fixture$stable[[3L]]$run$artifact)

  expect_error(
    retention_environment$wlv_plan_publication_prune(fixture$root, 1L),
    "[Ss]ize mismatch|SHA-256 mismatch"
  )

  lock <- file.path(fixture$root, "results", ".lock-results")
  dir.create(lock)
  expect_error(
    retention_environment$wlv_plan_publication_prune(fixture$root, 1L),
    "locked"
  )
  unlink(lock, recursive = TRUE, force = TRUE)

  partial <- tempfile("wlv-partial-publication-")
  dir.create(file.path(partial, "results", "runs"), recursive = TRUE)
  on.exit(unlink(partial, recursive = TRUE, force = TRUE), add = TRUE)
  expect_error(
    retention_environment$wlv_plan_publication_prune(partial, 1L),
    "inconsistent"
  )

  unexpected <- wlv_retention_test_root()
  on.exit(unlink(unexpected, recursive = TRUE, force = TRUE), add = TRUE)
  writeBin(
    charToRaw("unexpected"),
    file.path(unexpected, "results", "releases", "unexpected.txt")
  )
  expect_error(
    retention_environment$wlv_plan_publication_prune(unexpected, 1L),
    "must be a directory"
  )
})

test_that("retention ignores legacy results when no publication store exists", {
  wlv_retention_test_requirements()
  root <- tempfile("wlv-legacy-results-")
  legacy <- file.path(root, "results", "legacy_method")
  dir.create(legacy, recursive = TRUE)
  legacy_file <- file.path(legacy, "result.fst")
  writeBin(charToRaw("legacy"), legacy_file)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  plan <- retention_environment$wlv_plan_publication_prune(root, 1L)
  expect_identical(plan$reclaimable_bytes, 0)
  expect_true(all(vapply(plan$delete, nrow, integer(1L)) == 0L))
  report <- retention_environment$wlv_prune_publications(plan, dry_run = FALSE)
  expect_false(report$dry_run)
  expect_true(file.exists(legacy_file))
})

test_that("retention policies reject unsafe or ambiguous values", {
  wlv_retention_test_requirements()
  fixture <- wlv_retention_test_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  expect_error(
    retention_environment$wlv_plan_publication_prune(fixture$root, 0L),
    "positive integer"
  )
  expect_error(
    retention_environment$wlv_plan_publication_prune(
      fixture$root,
      c(unknown = 1L)
    ),
    "unknown channels"
  )
  expect_error(
    retention_environment$wlv_prune_publications(list(), dry_run = FALSE),
    "must come from"
  )
})
