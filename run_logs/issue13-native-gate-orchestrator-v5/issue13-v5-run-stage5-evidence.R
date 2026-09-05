# Creates one isolated, validated publication alias for an authenticated
# calculate parent, then performs exactly one full legacy recalculation.  It is
# capture tooling only; no generated alias is consumed as scientific evidence.

wlv13_v5_stage5_run_main <- function(arguments = commandArgs(TRUE)) {
  if (length(arguments) != 5L) {
    stop(paste0(
      "Usage: Rscript issue13-v5-run-stage5-evidence.R ",
      "<project-root> <method> <parent-run-id> <stage> <channel>"
    ), call. = FALSE)
  }
  project_root <- normalizePath(arguments[[1L]], winslash = "/",
    mustWork = TRUE
  )
  method <- enc2utf8(arguments[[2L]])
  parent_run_id <- enc2utf8(arguments[[3L]])
  stage <- suppressWarnings(as.integer(arguments[[4L]]))
  channel <- enc2utf8(arguments[[5L]])
  if (!grepl("^[a-z][a-z0-9_]*$", method) ||
      !grepl("^run-[0-9A-Za-z-]+$", parent_run_id) ||
      length(stage) != 1L || is.na(stage) ||
      !stage %in% c(1L, 4L, 5L) ||
      !grepl("^issue13-v5d-stage-(1|4|5)-[a-z0-9-]+$", channel) ||
      !identical(channel, paste0(
        "issue13-v5d-stage-", stage, "-",
        gsub("_", "-", method, fixed = TRUE)
      ))) {
    stop("Invalid stage-five capture request.", call. = FALSE)
  }

  old_directory <- getwd()
  on.exit(setwd(old_directory), add = TRUE)
  setwd(project_root)
  source(file.path("renv", "activate.R"), local = TRUE)
  runtime <- new.env(parent = globalenv())
  sys.source(file.path("R", "main.R"), envir = runtime)

  parent_root <- normalizePath(file.path(
    project_root, "results", "runs", method, parent_run_id
  ), winslash = "/", mustWork = TRUE)
  parent_manifest_path <- normalizePath(file.path(
    parent_root, runtime$wlv_run_manifest_filename
  ), winslash = "/", mustWork = TRUE)
  parent <- runtime$wlv_read_run_manifest(parent_manifest_path)
  runtime$wlv_verify_run_manifest(parent, parent_root)
  if (!identical(parent$method, method) ||
      !identical(parent$run_id, parent_run_id) ||
      !is.null(parent$parent_run_id)) {
    stop("The stage-five capture parent is not a calculate run.",
      call. = FALSE
    )
  }

  paths <- runtime$wlv_publication_ensure_store(project_root)
  if (length(runtime$wlv_list_channel_markers(project_root, channel))) {
    stop("The isolated stage-five channel already exists.", call. = FALSE)
  }
  release_id <- paste0(
    "release-v5d-parent-", method, "-s", stage, "-",
    substr(parent_run_id, 5L, 20L)
  )
  release_root <- file.path(paths$releases, release_id)
  if (file.exists(release_root) ||
      !dir.create(release_root, recursive = FALSE, showWarnings = FALSE)) {
    stop("Could not create the isolated parent release.", call. = FALSE)
  }
  sequence <- "00000000000000000001"
  run_reference <- list(
    method = method,
    run_id = parent$run_id,
    result_id = parent$result_id,
    manifest_path = runtime$wlv_publication_relative_path(
      parent_manifest_path, paths$results
    ),
    manifest_sha256 = runtime$wlv_publication_file_sha256(
      parent_manifest_path
    )
  )
  release <- runtime$wlv_build_release_manifest(
    release_root = release_root,
    artifacts = character(),
    artifact_roles = character(),
    release_id = release_id,
    channel = channel,
    sequence = sequence,
    runs = list(run_reference),
    metadata = list(
      methods = method,
      evidence_parent_run_id = parent_run_id,
      capture_role = "stage5-parent-alias"
    ),
    created_at_utc = parent$created_at_utc
  )
  release_manifest_path <- file.path(
    release_root, runtime$wlv_release_manifest_filename
  )
  runtime$wlv_write_release_manifest(release, release_manifest_path)
  runtime$wlv_verify_release_manifest(
    release_manifest_path, release_root, paths$results,
    reject_unlisted = TRUE
  )
  marker <- runtime$wlv_build_channel_marker(
    channel = channel,
    sequence = sequence,
    release_id = release_id,
    release_manifest_path = runtime$wlv_publication_relative_path(
      release_manifest_path, paths$results
    ),
    release_manifest_sha256 = runtime$wlv_publication_file_sha256(
      release_manifest_path
    ),
    published_at_utc = parent$created_at_utc
  )
  channel_root <- runtime$wlv_publication_channel_directory(
    project_root, channel, create = TRUE
  )
  marker_path <- file.path(channel_root,
    runtime$wlv_channel_marker_filename(sequence, release_id)
  )
  runtime$wlv_write_channel_marker(marker, marker_path)
  runtime$wlv_verify_channel_marker(
    marker_path, publication_root = paths$results,
    marker_path = marker_path, verify_release = TRUE
  )
  resolved <- runtime$wlv_resolve_current_method_run(
    project_root, method, channel, allow_legacy = FALSE
  )
  if (!identical(resolved$run_id, parent_run_id) ||
      !identical(resolved$path, parent_root) || isTRUE(resolved$legacy)) {
    stop("The isolated channel does not resolve the authenticated parent.",
      call. = FALSE
    )
  }

  method_root <- file.path(project_root, "results", "runs", method)
  before <- if (dir.exists(method_root)) {
    sort(list.dirs(method_root, full.names = TRUE, recursive = FALSE),
      method = "radix"
    )
  } else {
    character()
  }
  runtime$recalc_wlv(
    methods = method,
    at_stage = stage,
    sea_vars = NULL,
    papern = 0L,
    prepaper = FALSE,
    workers = 1L,
    channel = channel,
    allow_experimental = TRUE
  )
  after <- sort(list.dirs(method_root, full.names = TRUE, recursive = FALSE),
    method = "radix"
  )
  created <- setdiff(after, before)
  if (length(created) != 1L) {
    stop("The full recalculation did not create exactly one child run.",
      call. = FALSE
    )
  }
  child <- runtime$wlv_read_run_manifest(file.path(
    created[[1L]], runtime$wlv_run_manifest_filename
  ))
  if (!identical(child$parent_run_id, parent_run_id) ||
      !identical(child$method, method)) {
    stop("The recalculation child is not bound to its exact parent.",
      call. = FALSE
    )
  }
  cat(paste(c(
    "recalculation_record",
    paste0("method=", method),
    paste0("at_stage=", stage),
    paste0("parent_run_id=", parent_run_id),
    paste0("child_run_root=", normalizePath(
      created[[1L]], winslash = "/", mustWork = TRUE
    )),
    paste0("alias_release_id=", release_id),
    paste0("alias_release_manifest_sha256=",
      runtime$wlv_publication_file_sha256(release_manifest_path)),
    paste0("alias_marker_sha256=",
      runtime$wlv_publication_file_sha256(marker_path))
  ), collapse = ";"), "\n", sep = "")
  invisible(created[[1L]])
}

if (sys.nframe() == 0L) {
  wlv13_v5_stage5_run_main()
}
