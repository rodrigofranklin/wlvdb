# Create one fresh release channel whose only run is an authenticated immutable
# workers=1 full run. The large run artifacts are referenced, never copied.

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_argument)) {
  stop("Run issue13-seed-channel.R with Rscript.", call. = FALSE)
}
script_path <- normalizePath(sub("^--file=", "", script_argument[[1L]]),
  winslash = "/", mustWork = TRUE
)
script_dir <- dirname(script_path)
sys.source(file.path(script_dir, "issue13-lib.R"), envir = environment())
sys.source(file.path(dirname(script_dir), "issue13-prep-paper-lib.R"),
  envir = environment()
)
sys.source(file.path(script_dir, "issue13-seed-runtime-lib.R"),
  envir = environment()
)

wlv13_seed_result_properties <- c(
  "schema", "scenario_id", "status", "passed", "started_at", "finished_at",
  "project_root", "expected_commit", "expected_seed_commit", "runtime_kind",
  "method", "channel", "seed_proof_path", "seed_proof_sha256", "run_id",
  "result_id", "run_manifest_sha256", "run_inventory_sha256", "release_id",
  "release_manifest_path", "release_manifest_sha256", "marker_path",
  "marker_sha256"
)

wlv13_seed_result_state <- function(evidence_dir, scenario_id) {
  entries <- sort(list.files(evidence_dir,
    all.files = TRUE,
    no.. = TRUE,
    full.names = FALSE
  ), method = "radix")
  if (any(vapply(file.path(evidence_dir, entries), dir.exists, logical(1L)))) {
    stop("Seed evidence contains a foreign directory.", call. = FALSE)
  }
  support <- c(
    "stdout.log", "stderr.log", "process-samples.csv", "process-metrics.json"
  )
  canonical <- entries[entries == "seed-result.json"]
  temporary <- entries[grepl(
    "^\\.seed-result\\.json-[0-9a-f]+(?:\\.tmp)?$",
    entries,
    perl = TRUE
  )]
  foreign <- setdiff(entries, c(support, canonical, temporary))
  if (length(foreign) || length(canonical) > 1L || length(temporary) > 1L ||
      (length(canonical) && length(temporary))) {
    stop("Seed result evidence has a foreign or ambiguous envelope.",
      call. = FALSE
    )
  }
  selected <- c(canonical, temporary)
  if (!length(selected)) {
    return(list(prior = NULL, canonical = FALSE, temporary = FALSE))
  }
  selected_path <- file.path(evidence_dir, selected[[1L]])
  prior <- tryCatch(
    wlv13_json_read(selected_path, simplify = FALSE),
    error = function(error) {
      if (length(canonical)) stop(error)
      NULL
    }
  )
  if (is.null(prior)) {
    return(list(prior = NULL, canonical = FALSE, temporary = TRUE))
  }
  timestamp_pattern <- paste0(
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}",
    "(?:\\.[0-9]+)?(?:Z|[+-][0-9]{4})$"
  )
  valid_shape <- is.list(prior) && !anyDuplicated(names(prior)) &&
    setequal(names(prior), wlv13_seed_result_properties) &&
    identical(prior$schema, "wlv-issue13-channel-seed-result/1") &&
    identical(prior$scenario_id, scenario_id) &&
    is.character(prior$started_at) && length(prior$started_at) == 1L &&
    grepl(timestamp_pattern, prior$started_at, perl = TRUE) &&
    is.character(prior$finished_at) && length(prior$finished_at) == 1L &&
    grepl(timestamp_pattern, prior$finished_at, perl = TRUE)
  if (!isTRUE(valid_shape)) {
    stop("Parseable seed-result staging is divergent.", call. = FALSE)
  }
  started <- as.POSIXct(prior$started_at,
    format = "%Y-%m-%dT%H:%M:%OS%z", tz = "UTC"
  )
  finished <- as.POSIXct(prior$finished_at,
    format = "%Y-%m-%dT%H:%M:%OS%z", tz = "UTC"
  )
  if (is.na(started) || is.na(finished) || finished < started ||
      finished > Sys.time() + 60) {
    stop("Seed-result staging timestamps are invalid.", call. = FALSE)
  }
  list(
    prior = prior,
    canonical = length(canonical) == 1L,
    temporary = length(temporary) == 1L
  )
}

wlv13_seed_write_result <- function(value, evidence_dir, scenario_id) {
  state <- wlv13_seed_result_state(evidence_dir, scenario_id)
  path <- file.path(evidence_dir, "seed-result.json")
  wlv13_json_write_or_verify(value, path)
  installed <- wlv13_json_read(path, simplify = FALSE)
  if (!wlv13_json_equivalent(value, path) ||
      !identical(installed$scenario_id, scenario_id)) {
    stop("Installed seed-result evidence changed during recovery.",
      call. = FALSE
    )
  }
  invisible(path)
}

wlv13_seed_channel_main <- function() {
arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L) {
  stop("Expected <seed-spec.json> <evidence-directory>.", call. = FALSE)
}
spec_path <- normalizePath(arguments[[1L]], winslash = "/", mustWork = TRUE)
evidence_dir <- wlv13_ensure_dir(arguments[[2L]], "seed evidence directory")
spec <- wlv13_json_read(spec_path, simplify = TRUE)
required <- c(
  "schema", "scenario_id", "project_root", "expected_commit", "method",
  "channel", "seed_result_path", "expected_seed_commit"
)
if (!is.list(spec) || any(!required %in% names(spec)) ||
    !identical(spec$schema, "wlv-issue13-channel-seed/1")) {
  stop("Channel-seed specification has an invalid schema.", call. = FALSE)
}
scenario_id <- wlv13_id(spec$scenario_id, "scenario_id")
project_root <- wlv13_normalize_existing_dir(spec$project_root, "project root")
expected_commit <- wlv13_scalar_text(spec$expected_commit,
  "expected_commit", "^[0-9a-f]{40}$"
)
expected_seed_commit <- wlv13_scalar_text(spec$expected_seed_commit,
  "expected_seed_commit", "^[0-9a-f]{40}$"
)
method <- wlv13_scalar_text(spec$method, "method", "^[a-z][a-z0-9_]*$")
channel <- wlv13_scalar_text(spec$channel, "channel",
  "^[a-z0-9][a-z0-9._-]*$"
)
seed_result_path <- normalizePath(spec$seed_result_path,
  winslash = "/", mustWork = TRUE
)
if (wlv13_is_within(evidence_dir, project_root) ||
    wlv13_is_within(seed_result_path, project_root)) {
  stop("Seed inputs/evidence must be outside the evaluated worktree.",
    call. = FALSE
  )
}
if (!identical(wlv13_git_commit(project_root), expected_commit) ||
    !wlv13_git_runtime_clean(project_root)) {
  stop("Channel seeding requires a pinned, clean runtime.", call. = FALSE)
}

seed_report <- wlv13_json_read(seed_result_path, simplify = FALSE)
arm <- strsplit(scenario_id, "/", fixed = TRUE)[[1L]][[1L]]
if (!arm %in% c("baseline", "candidate")) {
  stop("Seed scenario_id has an unsupported arm.", call. = FALSE)
}
expected_seed_scenario <- paste0(
  arm, "/calculate/", method, "/workers1"
)
wlv13_validate_native_seed_report(
  seed_report, expected_seed_scenario, project_root, expected_seed_commit
)
run_index <- which(vapply(seed_report$outputs, function(output) {
  is.list(output) && identical(output$kind, "run") &&
    identical(output$method, method)
}, logical(1L)))
if (length(run_index) != 1L) {
  stop("Full-run seed evidence does not identify exactly one method run.",
    call. = FALSE
  )
}
seed <- seed_report$outputs[[run_index]]
if (!is.null(seed$parent_run_id)) {
  stop("Refusing to seed a channel from a recalculated child run.",
    call. = FALSE
  )
}
loaded_runtime <- wlv13_load_seed_runtime(project_root, expected_commit)
runtime <- loaded_runtime$runtime
assert_runtime_unchanged <- loaded_runtime$assert_unchanged
assert_runtime_unchanged()
paths <- runtime$wlv_publication_ensure_store(project_root)
run_root <- normalizePath(seed$root, winslash = "/", mustWork = TRUE)
expected_run_root <- normalizePath(file.path(
  paths$runs, method, seed$run_id
), winslash = "/", mustWork = TRUE)
if (!identical(tolower(run_root), tolower(expected_run_root))) {
  stop("Seed run is not the canonical immutable run-store path.",
    call. = FALSE
  )
}
run_inventory <- wlv13_run_inventory(run_root)
if (!identical(wlv13_inventory_signature(run_inventory),
      seed$inventory_sha256) ||
    !identical(run_inventory$manifest_sha256, seed$manifest_sha256) ||
    !identical(run_inventory$manifest$run_id, seed$run_id) ||
    !identical(run_inventory$manifest$result_id, seed$result_id) ||
    !is.null(run_inventory$manifest$parent_run_id) ||
    !identical(
      run_inventory$manifest$result$provenance$git$commit,
      expected_seed_commit
    ) ||
    !identical(run_inventory$manifest$result$request$mode, "calculate") ||
    !identical(as.integer(run_inventory$manifest$result$request$workers), 1L)) {
  stop("Seed run identity or full-run request differs from its evidence.",
    call. = FALSE
  )
}
prior_result_state <- wlv13_seed_result_state(evidence_dir, scenario_id)
prior_result <- prior_result_state$prior
started_at <- if (is.null(prior_result)) wlv13_now() else
  prior_result$started_at
existing_markers <- runtime$wlv_list_channel_markers(project_root, channel)
existing_release <- runtime$wlv_read_current_release(
  project_root, channel = channel, required = FALSE
)
has_prior_result_artifact <- isTRUE(prior_result_state$canonical) ||
  isTRUE(prior_result_state$temporary)
if (has_prior_result_artifact &&
    (is.null(existing_release) || length(existing_markers) != 1L)) {
  stop(
    paste0(
      "Seed-result evidence can be resumed only after an authenticated ",
      "release and channel-marker commit."
    ),
    call. = FALSE
  )
}
if (is.null(existing_release) && !length(existing_markers)) {
  release_directories <- list.dirs(paths$releases,
    full.names = TRUE, recursive = FALSE
  )
  orphan_candidates <- lapply(release_directories, function(directory) {
    manifest_path <- file.path(directory, "release_manifest.json")
    if (!file.exists(manifest_path)) return(NULL)
    manifest <- tryCatch(
      runtime$wlv_read_release_manifest(manifest_path),
      error = function(error) NULL
    )
    if (is.null(manifest) || !identical(manifest$channel, channel) ||
        !identical(manifest$release_id, basename(directory)) ||
        !identical(as.integer(manifest$sequence), 1L) ||
        length(manifest$runs) != 1L ||
        !identical(manifest$runs[[1L]]$method, method) ||
        !identical(manifest$runs[[1L]]$run_id, seed$run_id) ||
        !identical(manifest$runs[[1L]]$result_id, seed$result_id) ||
        !identical(manifest$runs[[1L]]$manifest_sha256,
          seed$manifest_sha256)) {
      return(NULL)
    }
    runtime$wlv_verify_release_manifest(
      manifest,
      release_root = directory,
      publication_root = paths$results,
      reject_unlisted = TRUE
    )
    list(
      root = normalizePath(directory, winslash = "/", mustWork = TRUE),
      manifest = manifest,
      manifest_path = normalizePath(manifest_path,
        winslash = "/", mustWork = TRUE
      )
    )
  })
  orphan_candidates <- Filter(Negate(is.null), orphan_candidates)
  if (length(orphan_candidates) > 1L) {
    stop("More than one authenticated interrupted seed release exists.",
      call. = FALSE
    )
  }
  if (length(orphan_candidates) == 1L) {
    orphan <- orphan_candidates[[1L]]
    marker <- runtime$wlv_build_channel_marker(
      channel = channel,
      sequence = orphan$manifest$sequence,
      release_id = orphan$manifest$release_id,
      release_manifest_path = runtime$wlv_publication_relative_path(
        orphan$manifest_path, paths$results
      ),
      release_manifest_sha256 = runtime$wlv_publication_file_sha256(
        orphan$manifest_path
      )
    )
    channel_dir <- runtime$wlv_publication_channel_directory(
      project_root, channel, create = TRUE
    )
    marker_path <- file.path(channel_dir,
      runtime$wlv_channel_marker_filename(
        orphan$manifest$sequence, orphan$manifest$release_id
      )
    )
    marker_staging <- tempfile(pattern = ".seed-marker-recovery-",
      tmpdir = paths$staging
    )
    if (!dir.create(marker_staging, recursive = FALSE, showWarnings = FALSE)) {
      stop("Could not create recovered seed-marker staging.", call. = FALSE)
    }
    on.exit(if (dir.exists(marker_staging)) {
      unlink(marker_staging, recursive = TRUE, force = TRUE)
    }, add = TRUE)
    pending_marker <- file.path(marker_staging, basename(marker_path))
    runtime$wlv_write_channel_marker(marker, pending_marker)
    runtime$wlv_verify_channel_marker(
      marker, paths$results, verify_release = TRUE
    )
    wlv13_recheck_inventory(run_inventory)
    if (file.exists(marker_path) || !file.rename(pending_marker, marker_path)) {
      stop("Could not atomically recover the seed channel marker.", call. = FALSE)
    }
    existing_markers <- runtime$wlv_list_channel_markers(
      project_root, channel
    )
    existing_release <- runtime$wlv_read_current_release(
      project_root, channel = channel, required = TRUE
    )
  }
}
if (!is.null(existing_release) || length(existing_markers)) {
  if (is.null(existing_release) || length(existing_markers) != 1L) {
    stop("Scenario channel has a non-canonical interrupted seed.", call. = FALSE)
  }
  current <- runtime$wlv_resolve_current_method_run(
    project_root, method, channel = channel
  )
  if (!identical(current$run_id, seed$run_id) ||
      !identical(current$result_id, seed$result_id) ||
      !identical(existing_release$manifest$channel, channel) ||
      !identical(as.integer(existing_release$manifest$sequence), 1L) ||
      length(existing_release$manifest$runs) != 1L ||
      !identical(existing_release$manifest$runs[[1L]]$method, method) ||
      !identical(existing_release$manifest$runs[[1L]]$run_id, seed$run_id) ||
      !identical(existing_release$manifest$runs[[1L]]$result_id,
        seed$result_id) ||
      !identical(existing_release$manifest$runs[[1L]]$manifest_sha256,
        seed$manifest_sha256) ||
      !identical(existing_release$marker_path, normalizePath(
        existing_markers[[1L]], winslash = "/", mustWork = TRUE
      ))) {
    stop("Existing seed channel does not resolve to the authenticated run.",
      call. = FALSE
    )
  }
  wlv13_recheck_inventory(run_inventory)
  assert_runtime_unchanged()
  report <- list(
    schema = "wlv-issue13-channel-seed-result/1",
    scenario_id = scenario_id,
    status = "passed",
    passed = TRUE,
    started_at = started_at,
    finished_at = if (is.null(prior_result)) wlv13_now() else
      prior_result$finished_at,
    project_root = project_root,
    expected_commit = expected_commit,
    expected_seed_commit = expected_seed_commit,
    runtime_kind = loaded_runtime$kind,
    method = method,
    channel = channel,
    seed_proof_path = seed_result_path,
    seed_proof_sha256 = wlv13_sha256_file(seed_result_path),
    run_id = seed$run_id,
    result_id = seed$result_id,
    run_manifest_sha256 = seed$manifest_sha256,
    run_inventory_sha256 = seed$inventory_sha256,
    release_id = existing_release$manifest$release_id,
    release_manifest_path = existing_release$manifest_path,
    release_manifest_sha256 = wlv13_sha256_file(
      existing_release$manifest_path
    ),
    marker_path = existing_release$marker_path,
    marker_sha256 = wlv13_sha256_file(existing_release$marker_path)
  )
  wlv13_seed_write_result(report, evidence_dir, scenario_id)
  return(invisible(report))
}

release_id <- runtime$wlv_new_publication_id("release")
sequence <- runtime$wlv_publication_increment_sequence(NULL)
staging <- tempfile(
  pattern = paste0(".seed-", release_id, "-"),
  tmpdir = paths$staging
)
if (!dir.create(staging, recursive = FALSE, showWarnings = FALSE)) {
  stop("Could not create seed-release staging.", call. = FALSE)
}
staging_open <- TRUE
final <- file.path(paths$releases, release_id)
final_open <- FALSE
marker_path <- NULL
committed <- FALSE
on.exit({
  if (staging_open && dir.exists(staging)) {
    unlink(staging, recursive = TRUE, force = TRUE)
  }
  if (!committed && final_open && dir.exists(final)) {
    unlink(final, recursive = TRUE, force = TRUE)
  }
  if (!committed && !is.null(marker_path) && file.exists(marker_path)) {
    unlink(marker_path, force = TRUE)
  }
}, add = TRUE)

indicators <- runtime$wlv_read_panel_result_csv(
  file.path(run_root, "_panel_indicators.csv"),
  columns = c("cod_label", "label")
)
metadata <- runtime$wlv_read_panel_result_csv(
  file.path(run_root, "_panel_meta_indicators.csv"),
  columns = c("value", "groups", "type", "reverted")
)
runtime$wlv_write_result_csv(
  indicators, file.path(staging, "indicators_en.csv")
)
runtime$wlv_write_result_csv(
  metadata, file.path(staging, "meta_indicators.csv")
)
run_reference <- runtime$wlv_build_release_run_reference(
  publication_root = paths$results,
  method = method,
  manifest_path = runtime$wlv_publication_relative_path(
    file.path(run_root, "run_manifest.json"), paths$results
  )
)
release <- runtime$wlv_build_release_manifest(
  release_root = staging,
  artifacts = c("indicators_en.csv", "meta_indicators.csv"),
  artifact_roles = c("panel_labels", "panel_metadata"),
  release_id = release_id,
  channel = channel,
  sequence = sequence,
  runs = list(run_reference),
  metadata = list(methods = method)
)
release_manifest_path <- file.path(staging, "release_manifest.json")
runtime$wlv_write_release_manifest(release, release_manifest_path)
runtime$wlv_verify_release_manifest(
  release,
  release_root = staging,
  publication_root = paths$results,
  reject_unlisted = TRUE
)
wlv13_recheck_inventory(run_inventory)
if (file.exists(final) || !file.rename(staging, final)) {
  stop("Could not promote the seed release.", call. = FALSE)
}
staging_open <- FALSE
final_open <- TRUE
final <- normalizePath(final, winslash = "/", mustWork = TRUE)
installed_manifest_path <- file.path(final, "release_manifest.json")
installed <- runtime$wlv_read_release_manifest(installed_manifest_path)
runtime$wlv_verify_release_manifest(
  installed,
  release_root = final,
  publication_root = paths$results,
  reject_unlisted = TRUE
)

marker <- runtime$wlv_build_channel_marker(
  channel = channel,
  sequence = sequence,
  release_id = release_id,
  release_manifest_path = runtime$wlv_publication_relative_path(
    installed_manifest_path, paths$results
  ),
  release_manifest_sha256 = runtime$wlv_publication_file_sha256(
    installed_manifest_path
  )
)
channel_dir <- runtime$wlv_publication_channel_directory(
  project_root, channel, create = TRUE
)
marker_path <- file.path(channel_dir,
  runtime$wlv_channel_marker_filename(sequence, release_id)
)
marker_staging <- tempfile(pattern = ".seed-marker-", tmpdir = paths$staging)
if (!dir.create(marker_staging, recursive = FALSE, showWarnings = FALSE)) {
  stop("Could not create seed-marker staging.", call. = FALSE)
}
on.exit(if (dir.exists(marker_staging)) {
  unlink(marker_staging, recursive = TRUE, force = TRUE)
}, add = TRUE)
pending_marker <- file.path(marker_staging, basename(marker_path))
runtime$wlv_write_channel_marker(marker, pending_marker)
runtime$wlv_verify_channel_marker(marker, paths$results, verify_release = TRUE)
wlv13_recheck_inventory(run_inventory)
if (file.exists(marker_path)) {
  # Another recovery may have completed the exact commit while this process
  # was paused.  Once the destination exists it is visible state: never remove
  # either it or the release from cleanup.  Authenticate and adopt only an
  # identical marker; preserve a divergent one and fail closed.
  committed <- TRUE
  installed_marker <- runtime$wlv_read_channel_marker(marker_path)
  if (!runtime$wlv_publication_json_identical(installed_marker, marker)) {
    stop("A divergent seed channel marker already exists.", call. = FALSE)
  }
} else if (!file.rename(pending_marker, marker_path)) {
  stop("Could not atomically install the seed channel marker.", call. = FALSE)
} else {
  # The marker rename is the publication commit point.  From this instruction
  # onward the immutable release and its visible marker must never be rolled
  # back, even if a post-commit authentication or evidence write fails.
  committed <- TRUE
}
verified <- runtime$wlv_read_current_release(
  project_root, channel = channel, required = TRUE
)
current <- runtime$wlv_resolve_current_method_run(
  project_root, method, channel = channel
)
if (!identical(current$run_id, seed$run_id) ||
    !identical(current$result_id, seed$result_id) ||
    !identical(verified$manifest$release_id, release_id)) {
  stop("Installed seed channel does not resolve to the authenticated full run.",
    call. = FALSE
  )
}
wlv13_recheck_inventory(run_inventory)
assert_runtime_unchanged()
if (!identical(wlv13_git_commit(project_root), expected_commit) ||
    !wlv13_git_runtime_clean(project_root)) {
  stop("Runtime inputs changed while installing the seed channel.",
    call. = FALSE
  )
}
report <- list(
  schema = "wlv-issue13-channel-seed-result/1",
  scenario_id = scenario_id,
  status = "passed",
  passed = TRUE,
  started_at = started_at,
  finished_at = if (is.null(prior_result)) wlv13_now() else
    prior_result$finished_at,
  project_root = project_root,
  expected_commit = expected_commit,
  expected_seed_commit = expected_seed_commit,
  runtime_kind = loaded_runtime$kind,
  method = method,
  channel = channel,
  seed_proof_path = seed_result_path,
  seed_proof_sha256 = wlv13_sha256_file(seed_result_path),
  run_id = seed$run_id,
  result_id = seed$result_id,
  run_manifest_sha256 = seed$manifest_sha256,
  run_inventory_sha256 = seed$inventory_sha256,
  release_id = release_id,
  release_manifest_path = installed_manifest_path,
  release_manifest_sha256 = wlv13_sha256_file(installed_manifest_path),
  marker_path = marker_path,
  marker_sha256 = wlv13_sha256_file(marker_path)
)
wlv13_seed_write_result(report, evidence_dir, scenario_id)
invisible(report)
}

wlv13_seed_channel_main()
