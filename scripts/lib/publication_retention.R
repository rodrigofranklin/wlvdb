wlv_prune_require_publication_api <- function() {
  scope <- environment()
  required <- c(
    "wlv_publication_paths",
    "wlv_publication_safe_id",
    "wlv_publication_validate_channel",
    "wlv_read_run_manifest",
    "wlv_verify_run_manifest",
    "wlv_read_release_manifest",
    "wlv_verify_release_manifest",
    "wlv_read_channel_marker",
    "wlv_verify_channel_marker",
    "wlv_channel_marker_filename",
    "wlv_publication_file_sha256"
  )
  missing <- required[!vapply(required, exists, logical(1L),
    envir = scope, mode = "function", inherits = TRUE
  )]
  constants <- c("wlv_run_manifest_filename", "wlv_release_manifest_filename")
  missing <- c(missing, constants[!vapply(constants, exists, logical(1L),
    envir = scope, inherits = TRUE
  )])
  if (length(missing)) {
    stop(
      sprintf(
        "Publication retention requires the publication API: %s.",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

wlv_prune_empty_records <- function(type) {
  switch(type,
    marker = data.frame(
      path = character(),
      channel = character(),
      sequence = character(),
      release_id = character(),
      bytes = numeric(),
      stringsAsFactors = FALSE
    ),
    release = data.frame(
      path = character(),
      channel = character(),
      sequence = character(),
      release_id = character(),
      manifest_sha256 = character(),
      bytes = numeric(),
      stringsAsFactors = FALSE
    ),
    run = data.frame(
      path = character(),
      method = character(),
      run_id = character(),
      manifest_sha256 = character(),
      bytes = numeric(),
      stringsAsFactors = FALSE
    ),
    stop(sprintf("Unknown publication record type `%s`.", type), call. = FALSE)
  )
}

wlv_prune_bind_records <- function(records, type) {
  if (!length(records)) return(wlv_prune_empty_records(type))
  result <- do.call(rbind, records)
  rownames(result) <- NULL
  result[order(result$path, method = "radix"), , drop = FALSE]
}

wlv_prune_compare_path <- function(path) {
  path <- sub("/+$", "", chartr("\\", "/", path))
  if (.Platform$OS.type == "windows") tolower(path) else path
}

wlv_prune_assert_inside <- function(
    path,
    parent,
    label,
    direct_child = FALSE,
    directory = NULL) {
  if (
    !is.character(path) || length(path) != 1L || is.na(path) ||
    !file.exists(path)
  ) {
    stop(sprintf("%s is missing: %s.", label, path), call. = FALSE)
  }
  parent <- normalizePath(parent, winslash = "/", mustWork = TRUE)
  resolved <- normalizePath(path, winslash = "/", mustWork = TRUE)
  compare_parent <- wlv_prune_compare_path(parent)
  compare_resolved <- wlv_prune_compare_path(resolved)
  if (!startsWith(compare_resolved, paste0(compare_parent, "/"))) {
    stop(sprintf("%s escapes its publication root: %s.", label, path), call. = FALSE)
  }
  if (
    isTRUE(direct_child) &&
    (!identical(
      wlv_prune_compare_path(dirname(resolved)),
      compare_parent
    ) || !identical(
      compare_resolved,
      wlv_prune_compare_path(file.path(parent, basename(path)))
    ))
  ) {
    stop(sprintf("%s is not a direct child of its publication root.", label),
      call. = FALSE
    )
  }
  info <- file.info(path)
  if (!is.null(directory) && !identical(isTRUE(info$isdir), isTRUE(directory))) {
    stop(
      sprintf(
        "%s must be %s.",
        label,
        if (isTRUE(directory)) "a directory" else "a regular file"
      ),
      call. = FALSE
    )
  }
  link <- Sys.readlink(path)
  if (length(link) == 1L && !is.na(link) && nzchar(link)) {
    stop(sprintf("%s must not be a symbolic link or junction.", label),
      call. = FALSE
    )
  }
  resolved
}

wlv_prune_direct_entries <- function(path) {
  sort(list.files(
    path,
    all.files = TRUE,
    full.names = TRUE,
    recursive = FALSE,
    include.dirs = TRUE,
    no.. = TRUE
  ), method = "radix")
}

wlv_prune_assert_tree <- function(path, parent, label) {
  root <- wlv_prune_assert_inside(path, parent, label, directory = TRUE)
  queue <- root
  visited <- character()
  while (length(queue)) {
    current <- queue[[1L]]
    queue <- queue[-1L]
    key <- wlv_prune_compare_path(current)
    if (key %in% visited) {
      stop(sprintf("%s contains a directory cycle.", label), call. = FALSE)
    }
    visited <- c(visited, key)
    entries <- wlv_prune_direct_entries(current)
    if (!length(entries)) next
    info <- file.info(entries)
    if (anyNA(info$isdir)) {
      stop(sprintf("Cannot inspect every path under %s.", label), call. = FALSE)
    }
    for (index in seq_along(entries)) {
      entry <- entries[[index]]
      link <- Sys.readlink(entry)
      if (length(link) == 1L && !is.na(link) && nzchar(link)) {
        stop(sprintf("%s contains a symbolic link or junction.", label),
          call. = FALSE
        )
      }
      resolved <- normalizePath(entry, winslash = "/", mustWork = TRUE)
      resolved_key <- wlv_prune_compare_path(resolved)
      expected_key <- wlv_prune_compare_path(file.path(
        current,
        basename(entry)
      ))
      if (!identical(resolved_key, expected_key) || !startsWith(
        resolved_key,
        paste0(wlv_prune_compare_path(root), "/")
      )) {
        stop(sprintf("%s contains a redirected or outside path.", label),
          call. = FALSE
        )
      }
      if (isTRUE(info$isdir[[index]])) queue <- c(queue, resolved)
    }
  }
  invisible(root)
}

wlv_prune_path_bytes <- function(path, parent, label) {
  root <- wlv_prune_assert_inside(path, parent, label)
  info <- file.info(root)
  if (!isTRUE(info$isdir)) {
    size <- unname(info$size)
    if (is.na(size) || size < 0 || size > 2^53 - 1) {
      stop(sprintf("%s has an invalid size.", label), call. = FALSE)
    }
    return(as.numeric(size))
  }
  wlv_prune_assert_tree(root, parent, label)
  queue <- root
  total <- 0
  while (length(queue)) {
    current <- queue[[1L]]
    queue <- queue[-1L]
    entries <- wlv_prune_direct_entries(current)
    if (!length(entries)) next
    entry_info <- file.info(entries)
    if (anyNA(entry_info$isdir) || anyNA(entry_info$size)) {
      stop(sprintf("Cannot measure every path under %s.", label), call. = FALSE)
    }
    directories <- entry_info$isdir %in% TRUE
    queue <- c(queue, entries[directories])
    sizes <- as.numeric(entry_info$size[!directories])
    if (any(sizes < 0) || any(sizes > 2^53 - 1)) {
      stop(sprintf("%s contains a file with an invalid size.", label),
        call. = FALSE
      )
    }
    total <- total + sum(sizes)
    if (!is.finite(total) || total > 2^53 - 1) {
      stop("Publication storage exceeds the exact byte-count range.",
        call. = FALSE
      )
    }
  }
  as.numeric(total)
}

wlv_prune_relative <- function(path, results_root) {
  results_root <- normalizePath(results_root, winslash = "/", mustWork = TRUE)
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  compare_root <- wlv_prune_compare_path(results_root)
  compare_path <- wlv_prune_compare_path(path)
  if (!startsWith(compare_path, paste0(compare_root, "/"))) {
    stop("Publication path escapes `results`.", call. = FALSE)
  }
  chartr("\\", "/", substring(path, nchar(results_root) + 2L))
}

wlv_prune_validate_portable_id <- function(value, label) {
  wlv_publication_safe_id(value, label)
  if (nchar(value, type = "bytes") > 128L) {
    stop(sprintf("Invalid %s.", label), call. = FALSE)
  }
  value
}

wlv_prune_scan_runs <- function(paths) {
  records <- list()
  details <- list()
  method_entries <- wlv_prune_direct_entries(paths$runs)
  for (method_path in method_entries) {
    method <- basename(method_path)
    wlv_prune_validate_portable_id(method, "run method directory")
    wlv_prune_assert_inside(
      method_path,
      paths$runs,
      "Run method directory",
      direct_child = TRUE,
      directory = TRUE
    )
    run_entries <- wlv_prune_direct_entries(method_path)
    for (run_path in run_entries) {
      run_id <- basename(run_path)
      wlv_prune_validate_portable_id(run_id, "run directory identifier")
      wlv_prune_assert_inside(
        run_path,
        method_path,
        "Run directory",
        direct_child = TRUE,
        directory = TRUE
      )
      wlv_prune_assert_tree(run_path, paths$runs, "Run directory")
      manifest_path <- file.path(run_path, wlv_run_manifest_filename())
      wlv_prune_assert_inside(
        manifest_path,
        run_path,
        "Run manifest",
        direct_child = TRUE,
        directory = FALSE
      )
      manifest <- wlv_read_run_manifest(manifest_path)
      wlv_verify_run_manifest(manifest, run_path, reject_unlisted = TRUE)
      if (!identical(manifest$method, method) || !identical(manifest$run_id, run_id)) {
        stop("Run directory identity differs from its manifest.", call. = FALSE)
      }
      relative <- wlv_prune_relative(run_path, paths$results)
      records[[length(records) + 1L]] <- data.frame(
        path = relative,
        method = method,
        run_id = run_id,
        manifest_sha256 = wlv_publication_file_sha256(manifest_path),
        bytes = wlv_prune_path_bytes(run_path, paths$runs, "Run directory"),
        stringsAsFactors = FALSE
      )
      details[[relative]] <- manifest
    }
  }
  list(records = wlv_prune_bind_records(records, "run"), details = details)
}

wlv_prune_validate_run_reference_path <- function(reference) {
  expected <- paste(
    "runs",
    reference$method,
    reference$run_id,
    wlv_run_manifest_filename(),
    sep = "/"
  )
  if (!identical(reference$manifest_path, expected)) {
    stop(
      sprintf(
        "Release run `%s` does not use the canonical run path.",
        reference$run_id
      ),
      call. = FALSE
    )
  }
  expected
}

wlv_prune_scan_releases <- function(paths) {
  records <- list()
  details <- list()
  release_entries <- wlv_prune_direct_entries(paths$releases)
  for (release_path in release_entries) {
    release_id <- basename(release_path)
    wlv_prune_validate_portable_id(release_id, "release directory identifier")
    wlv_prune_assert_inside(
      release_path,
      paths$releases,
      "Release directory",
      direct_child = TRUE,
      directory = TRUE
    )
    wlv_prune_assert_tree(release_path, paths$releases, "Release directory")
    manifest_path <- file.path(release_path, wlv_release_manifest_filename())
    wlv_prune_assert_inside(
      manifest_path,
      release_path,
      "Release manifest",
      direct_child = TRUE,
      directory = FALSE
    )
    manifest <- wlv_read_release_manifest(manifest_path)
    wlv_verify_release_manifest(
      manifest,
      release_root = release_path,
      publication_root = paths$results,
      reject_unlisted = TRUE
    )
    if (!identical(manifest$release_id, release_id)) {
      stop("Release directory identity differs from its manifest.", call. = FALSE)
    }
    invisible(lapply(manifest$runs, wlv_prune_validate_run_reference_path))
    relative <- wlv_prune_relative(release_path, paths$results)
    records[[length(records) + 1L]] <- data.frame(
      path = relative,
      channel = manifest$channel,
      sequence = manifest$sequence,
      release_id = release_id,
      manifest_sha256 = wlv_publication_file_sha256(manifest_path),
      bytes = wlv_prune_path_bytes(
        release_path,
        paths$releases,
        "Release directory"
      ),
      stringsAsFactors = FALSE
    )
    details[[release_id]] <- manifest
  }
  list(records = wlv_prune_bind_records(records, "release"), details = details)
}

wlv_prune_scan_markers <- function(paths) {
  records <- list()
  details <- list()
  sequences <- list()
  queue <- paths$channels
  while (length(queue)) {
    current <- queue[[1L]]
    queue <- queue[-1L]
    entries <- wlv_prune_direct_entries(current)
    if (!length(entries)) next
    info <- file.info(entries)
    if (anyNA(info$isdir)) {
      stop("Cannot inspect every publication channel path.", call. = FALSE)
    }
    directories <- entries[info$isdir %in% TRUE]
    for (directory in directories) {
      wlv_prune_assert_inside(
        directory,
        paths$channels,
        "Release channel directory",
        directory = TRUE
      )
      relative_channel <- wlv_prune_relative(directory, paths$channels)
      wlv_publication_validate_channel(relative_channel)
      queue <- c(queue, directory)
    }
    marker_entries <- entries[!info$isdir]
    for (marker_path in marker_entries) {
      wlv_prune_assert_inside(
        marker_path,
        paths$channels,
        "Channel marker",
        directory = FALSE
      )
      channel <- wlv_prune_relative(dirname(marker_path), paths$channels)
      wlv_publication_validate_channel(channel)
      marker <- wlv_read_channel_marker(marker_path)
      wlv_verify_channel_marker(
        marker,
        publication_root = paths$results,
        marker_path = marker_path
      )
      if (!identical(marker$channel, channel)) {
        stop("Channel marker is stored under the wrong channel.", call. = FALSE)
      }
      expected_name <- wlv_channel_marker_filename(
        marker$sequence,
        marker$release_id
      )
      if (!identical(basename(marker_path), expected_name)) {
        stop("Channel marker filename differs from its identity.", call. = FALSE)
      }
      expected_release_path <- paste(
        "releases",
        marker$release_id,
        wlv_release_manifest_filename(),
        sep = "/"
      )
      if (!identical(marker$release_manifest_path, expected_release_path)) {
        stop("Channel marker does not use the canonical release path.",
          call. = FALSE
        )
      }
      sequences[[channel]] <- c(sequences[[channel]], marker$sequence)
      relative <- wlv_prune_relative(marker_path, paths$results)
      records[[length(records) + 1L]] <- data.frame(
        path = relative,
        channel = channel,
        sequence = marker$sequence,
        release_id = marker$release_id,
        bytes = wlv_prune_path_bytes(
          marker_path,
          paths$channels,
          "Channel marker"
        ),
        stringsAsFactors = FALSE
      )
      details[[relative]] <- marker
    }
  }
  for (channel in names(sequences)) {
    if (anyDuplicated(sequences[[channel]])) {
      stop(sprintf("Channel `%s` contains duplicate publication sequences.", channel),
        call. = FALSE
      )
    }
  }
  list(records = wlv_prune_bind_records(records, "marker"), details = details)
}

wlv_prune_validate_store_links <- function(scans) {
  releases <- scans$releases$records
  runs <- scans$runs$records
  markers <- scans$markers$records
  if (nrow(markers)) {
    missing <- setdiff(markers$release_id, releases$release_id)
    if (length(missing)) {
      stop(
        sprintf(
          "Channel markers reference missing releases: %s.",
          paste(missing, collapse = ", ")
        ),
        call. = FALSE
      )
    }
  }
  run_paths <- if (nrow(runs)) {
    paste0(runs$path, "/", wlv_run_manifest_filename())
  } else {
    character()
  }
  referenced <- unique(unlist(lapply(scans$releases$details, function(release) {
    vapply(release$runs, `[[`, character(1L), "manifest_path")
  }), use.names = FALSE))
  missing_runs <- setdiff(referenced, run_paths)
  if (length(missing_runs)) {
    stop(
      sprintf(
        "Release manifests reference missing canonical runs: %s.",
        paste(missing_runs, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

wlv_prune_normalize_policy <- function(keep_releases, channels) {
  if (
    !is.numeric(keep_releases) || !length(keep_releases) ||
    anyNA(keep_releases)
  ) {
    stop("`keep_releases` must be a positive count or a named vector of counts.",
      call. = FALSE
    )
  }
  valid <- (is.finite(keep_releases) & keep_releases >= 1 &
    keep_releases == floor(keep_releases)) |
    (is.infinite(keep_releases) & keep_releases > 0)
  if (any(!valid)) {
    stop("Every `keep_releases` value must be a positive integer or `Inf`.",
      call. = FALSE
    )
  }
  policy_names <- names(keep_releases)
  if (is.null(policy_names) || all(!nzchar(policy_names))) {
    if (length(keep_releases) != 1L) {
      stop("An unnamed `keep_releases` policy must contain exactly one value.",
        call. = FALSE
      )
    }
    return(list(mode = "all", values = unname(as.numeric(keep_releases))))
  }
  if (
    length(policy_names) != length(keep_releases) || anyNA(policy_names) ||
    any(!nzchar(policy_names)) || anyDuplicated(policy_names)
  ) {
    stop("A per-channel retention policy needs unique, non-empty channel names.",
      call. = FALSE
    )
  }
  invisible(lapply(policy_names, wlv_publication_validate_channel))
  unknown <- setdiff(policy_names, channels)
  if (length(unknown)) {
    stop(
      sprintf(
        "Retention policy names unknown channels: %s.",
        paste(unknown, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  order_index <- order(policy_names, method = "radix")
  values <- as.numeric(keep_releases[order_index])
  names(values) <- policy_names[order_index]
  list(mode = "named", values = values)
}

wlv_prune_policy_keep <- function(policy, channel, total) {
  requested <- if (identical(policy$mode, "all")) {
    policy$values[[1L]]
  } else if (channel %in% names(policy$values)) {
    policy$values[[channel]]
  } else {
    Inf
  }
  if (is.infinite(requested)) total else min(total, as.integer(requested))
}

wlv_prune_channel_selection <- function(markers, policy) {
  channels <- sort(unique(markers$channel), method = "radix")
  retained <- character()
  removed <- character()
  summary <- list()
  for (channel in channels) {
    rows <- markers[markers$channel == channel, , drop = FALSE]
    rows <- rows[order(rows$sequence, rows$path, method = "radix"), , drop = FALSE]
    keep <- wlv_prune_policy_keep(policy, channel, nrow(rows))
    keep_index <- if (keep) utils::tail(seq_len(nrow(rows)), keep) else integer()
    drop_index <- setdiff(seq_len(nrow(rows)), keep_index)
    retained <- c(retained, rows$path[keep_index])
    removed <- c(removed, rows$path[drop_index])
    summary[[length(summary) + 1L]] <- data.frame(
      channel = channel,
      releases_total = nrow(rows),
      releases_retained = length(keep_index),
      releases_prunable = length(drop_index),
      current_release_id = rows$release_id[[nrow(rows)]],
      stringsAsFactors = FALSE
    )
  }
  channel_summary <- if (length(summary)) {
    do.call(rbind, summary)
  } else {
    data.frame(
      channel = character(),
      releases_total = integer(),
      releases_retained = integer(),
      releases_prunable = integer(),
      current_release_id = character(),
      stringsAsFactors = FALSE
    )
  }
  rownames(channel_summary) <- NULL
  list(
    retained = sort(retained, method = "radix"),
    removed = sort(removed, method = "radix"),
    summary = channel_summary
  )
}

wlv_prune_empty_plan <- function(root, paths, policy) {
  structure(list(
    schema_version = "1",
    root = root,
    results_root = chartr("\\", "/", paths$results),
    policy = policy,
    channels = wlv_prune_channel_selection(
      wlv_prune_empty_records("marker"),
      policy
    )$summary,
    retained = list(markers = character(), releases = character(), runs = character()),
    delete = list(
      markers = wlv_prune_empty_records("marker"),
      releases = wlv_prune_empty_records("release"),
      runs = wlv_prune_empty_records("run")
    ),
    reclaimable_bytes = 0,
    inventory = list(
      markers = wlv_prune_empty_records("marker"),
      releases = wlv_prune_empty_records("release"),
      runs = wlv_prune_empty_records("run")
    )
  ), class = "wlv_publication_prune_plan")
}

wlv_prune_build_plan <- function(
    root,
    keep_releases = 10L,
    allow_owned_lock = FALSE) {
  wlv_prune_require_publication_api()
  if (!is.character(root) || length(root) != 1L || is.na(root) || !dir.exists(root)) {
    stop("`root` must be one existing project directory.", call. = FALSE)
  }
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  paths <- wlv_publication_paths(root)
  if (dir.exists(paths$results)) {
    paths$results <- wlv_prune_assert_inside(
      paths$results,
      root,
      "Results store",
      direct_child = TRUE,
      directory = TRUE
    )
    if (!identical(basename(paths$results), "results")) {
      stop("Publication results must use the canonical `results` directory.",
        call. = FALSE
      )
    }
  }
  lock_path <- file.path(paths$results, ".lock-results")
  if (!isTRUE(allow_owned_lock) && dir.exists(lock_path)) {
    stop("Publication storage is locked by an active operation.", call. = FALSE)
  }
  present <- vapply(paths[c("runs", "releases", "channels")], dir.exists, logical(1L))
  if (!any(present)) {
    policy <- wlv_prune_normalize_policy(keep_releases, character())
    return(wlv_prune_empty_plan(root, paths, policy))
  }
  if (!all(present)) {
    stop(
      "Publication storage is inconsistent: `runs`, `releases`, and `channels` must all exist.",
      call. = FALSE
    )
  }
  paths$runs <- wlv_prune_assert_inside(paths$runs, paths$results, "Runs store",
    direct_child = TRUE, directory = TRUE
  )
  paths$releases <- wlv_prune_assert_inside(
    paths$releases,
    paths$results,
    "Releases store",
    direct_child = TRUE, directory = TRUE
  )
  paths$channels <- wlv_prune_assert_inside(
    paths$channels,
    paths$results,
    "Channels store",
    direct_child = TRUE, directory = TRUE
  )
  if (!identical(basename(paths$runs), "runs") ||
      !identical(basename(paths$releases), "releases") ||
      !identical(basename(paths$channels), "channels")) {
    stop("Publication storage directories do not use the canonical layout.",
      call. = FALSE
    )
  }

  wlv_prune_assert_tree(
    paths$channels,
    paths$results,
    "Channels store"
  )

  scans <- list(
    runs = wlv_prune_scan_runs(paths),
    releases = wlv_prune_scan_releases(paths),
    markers = wlv_prune_scan_markers(paths)
  )
  if (anyDuplicated(scans$runs$records$run_id)) {
    stop("Publication storage contains duplicate global run identifiers.",
      call. = FALSE
    )
  }
  wlv_prune_validate_store_links(scans)
  marker_records <- scans$markers$records
  actual_channels <- sort(unique(marker_records$channel), method = "radix")
  policy <- wlv_prune_normalize_policy(keep_releases, actual_channels)
  selection <- wlv_prune_channel_selection(marker_records, policy)

  retained_marker_rows <- marker_records[
    marker_records$path %in% selection$retained,
    ,
    drop = FALSE
  ]
  current_release_ids <- selection$summary$current_release_id
  retained_release_ids <- sort(unique(retained_marker_rows$release_id), method = "radix")
  if (length(setdiff(current_release_ids, retained_release_ids))) {
    stop("Retention policy would remove a channel's current release.", call. = FALSE)
  }
  release_records <- scans$releases$records
  retained_release_rows <- release_records[
    release_records$release_id %in% retained_release_ids,
    ,
    drop = FALSE
  ]
  retained_run_manifests <- unique(unlist(lapply(
    retained_release_rows$release_id,
    function(release_id) {
      release <- scans$releases$details[[release_id]]
      vapply(release$runs, `[[`, character(1L), "manifest_path")
    }
  ), use.names = FALSE))
  retained_run_paths <- sort(unique(dirname(retained_run_manifests)), method = "radix")
  run_records <- scans$runs$records

  delete_markers <- marker_records[marker_records$path %in% selection$removed, , drop = FALSE]
  delete_releases <- release_records[
    !release_records$release_id %in% retained_release_ids,
    ,
    drop = FALSE
  ]
  delete_runs <- run_records[!run_records$path %in% retained_run_paths, , drop = FALSE]
  delete_markers <- delete_markers[order(delete_markers$path, method = "radix"), , drop = FALSE]
  delete_releases <- delete_releases[order(delete_releases$path, method = "radix"), , drop = FALSE]
  delete_runs <- delete_runs[order(delete_runs$path, method = "radix"), , drop = FALSE]

  reclaimable <- sum(c(delete_markers$bytes, delete_releases$bytes, delete_runs$bytes))
  if (!is.finite(reclaimable) || reclaimable < 0 || reclaimable > 2^53 - 1) {
    stop("Reclaimable publication storage exceeds the exact byte-count range.",
      call. = FALSE
    )
  }
  structure(list(
    schema_version = "1",
    root = root,
    results_root = paths$results,
    policy = policy,
    channels = selection$summary,
    retained = list(
      markers = selection$retained,
      releases = retained_release_rows$path,
      runs = retained_run_paths
    ),
    delete = list(
      markers = delete_markers,
      releases = delete_releases,
      runs = delete_runs
    ),
    reclaimable_bytes = as.numeric(reclaimable),
    inventory = list(
      markers = marker_records,
      releases = release_records,
      runs = run_records
    )
  ), class = "wlv_publication_prune_plan")
}

#' Plan publication retention without deleting files.
#'
#' An unnamed count applies to every channel. A named vector applies only to
#' those channels; omitted channels are preserved in full. Every channel keeps
#' at least its current release because counts must be positive.
wlv_plan_publication_prune <- function(root = ".", keep_releases = 10L) {
  wlv_prune_build_plan(root, keep_releases, allow_owned_lock = FALSE)
}

wlv_prune_validate_plan <- function(plan) {
  if (!inherits(plan, "wlv_publication_prune_plan") || !is.list(plan)) {
    stop("`plan` must come from `wlv_plan_publication_prune()`.", call. = FALSE)
  }
  required <- c(
    "schema_version", "root", "results_root", "policy", "channels",
    "retained", "delete", "reclaimable_bytes", "inventory"
  )
  if (!identical(names(plan), required) || !identical(plan$schema_version, "1")) {
    stop("Unsupported or malformed publication prune plan.", call. = FALSE)
  }
  if (!is.character(plan$root) || length(plan$root) != 1L ||
      is.na(plan$root) || !dir.exists(plan$root)) {
    stop("Publication prune plan has an invalid project root.", call. = FALSE)
  }
  root <- normalizePath(plan$root, winslash = "/", mustWork = TRUE)
  canonical_results <- wlv_publication_paths(root)$results
  if (dir.exists(canonical_results)) {
    canonical_results <- normalizePath(
      canonical_results,
      winslash = "/",
      mustWork = TRUE
    )
  } else {
    canonical_results <- normalizePath(
      canonical_results,
      winslash = "/",
      mustWork = FALSE
    )
  }
  if (!is.character(plan$results_root) || length(plan$results_root) != 1L ||
      is.na(plan$results_root) || !nzchar(plan$results_root)) {
    stop("Publication prune plan has an invalid results root.", call. = FALSE)
  }
  planned_results <- normalizePath(
    plan$results_root,
    winslash = "/",
    mustWork = FALSE
  )
  if (!identical(
    wlv_prune_compare_path(planned_results),
    wlv_prune_compare_path(canonical_results)
  )) {
    stop(
      "Publication prune plan results root is not the project's canonical `results` directory.",
      call. = FALSE
    )
  }
  plan$root <- root
  plan$results_root <- canonical_results
  plan
}

wlv_prune_policy_input <- function(policy) {
  values <- policy$values
  if (identical(policy$mode, "all")) unname(values[[1L]]) else values
}

wlv_prune_plan_unchanged <- function(planned, current) {
  identical(planned$root, current$root) &&
    identical(planned$results_root, current$results_root) &&
    identical(planned$policy, current$policy) &&
    identical(planned$channels, current$channels) &&
    identical(planned$retained, current$retained) &&
    identical(planned$delete, current$delete) &&
    identical(planned$reclaimable_bytes, current$reclaimable_bytes) &&
    identical(planned$inventory, current$inventory)
}

wlv_prune_acquire_lock <- function(results_root) {
  if (!dir.exists(results_root) &&
      !dir.create(results_root, recursive = TRUE, showWarnings = FALSE)) {
    stop("Could not create the results directory for retention locking.",
      call. = FALSE
    )
  }
  results_root <- normalizePath(results_root, winslash = "/", mustWork = TRUE)
  lock <- file.path(results_root, ".lock-results")
  if (file.exists(lock) || !dir.create(lock, recursive = FALSE, showWarnings = FALSE)) {
    stop("Publication storage is already locked by another operation.",
      call. = FALSE
    )
  }
  resolved <- wlv_prune_assert_inside(
    lock,
    results_root,
    "Publication retention lock",
    direct_child = TRUE,
    directory = TRUE
  )
  if (!identical(basename(resolved), ".lock-results")) {
    stop("Refusing an unsafe publication retention lock.", call. = FALSE)
  }
  resolved
}

wlv_prune_release_lock <- function(lock, results_root) {
  if (!dir.exists(lock)) return(invisible(NULL))
  resolved <- wlv_prune_assert_inside(
    lock,
    results_root,
    "Publication retention lock",
    direct_child = TRUE,
    directory = TRUE
  )
  if (!identical(basename(resolved), ".lock-results")) {
    stop("Refusing to remove an unsafe publication retention lock.",
      call. = FALSE
    )
  }
  if (length(wlv_prune_direct_entries(resolved))) {
    stop("Refusing to remove a publication retention lock that is not empty.",
      call. = FALSE
    )
  }
  unlink(resolved, recursive = TRUE, force = TRUE)
  if (dir.exists(resolved)) {
    stop("Could not release the publication retention lock.", call. = FALSE)
  }
  invisible(NULL)
}

wlv_prune_resolve_target <- function(results_root, relative, type) {
  if (
    !is.character(relative) || length(relative) != 1L || is.na(relative) ||
    !nzchar(relative) || grepl("\\\\", relative) || startsWith(relative, "/")
  ) {
    stop("Prune plan contains an unsafe relative path.", call. = FALSE)
  }
  parts <- strsplit(relative, "/", fixed = TRUE)[[1L]]
  valid <- switch(type,
    marker = length(parts) >= 3L && identical(parts[[1L]], "channels") &&
      grepl(
        "^[0-9]{20}-[A-Za-z0-9][A-Za-z0-9._-]*[.]json$",
        parts[[length(parts)]]
      ),
    release = length(parts) == 2L && identical(parts[[1L]], "releases"),
    run = length(parts) == 3L && identical(parts[[1L]], "runs"),
    FALSE
  )
  ids <- switch(type,
    marker = character(),
    release = parts[[2L]],
    run = parts[2:3],
    character()
  )
  if (!isTRUE(valid)) {
    stop(sprintf("Prune plan contains an invalid %s path.", type), call. = FALSE)
  }
  if (identical(type, "marker")) {
    channel <- paste(parts[2:(length(parts) - 1L)], collapse = "/")
    wlv_publication_validate_channel(channel)
  }
  invisible(lapply(ids, wlv_prune_validate_portable_id, label = paste(type, "path")))
  path <- do.call(file.path, as.list(c(results_root, parts)))
  subtree <- file.path(results_root, parts[[1L]])
  wlv_prune_assert_inside(
    path,
    subtree,
    paste(type, "prune target"),
    direct_child = identical(type, "release"),
    directory = !identical(type, "marker")
  )
}

wlv_prune_prepare_trash <- function(results_root) {
  results_root <- normalizePath(results_root, winslash = "/", mustWork = TRUE)
  trash <- file.path(results_root, ".trash")
  if (!dir.exists(trash) &&
      !dir.create(trash, recursive = FALSE, showWarnings = FALSE)) {
    stop("Could not create the publication quarantine directory.", call. = FALSE)
  }
  trash <- wlv_prune_assert_inside(
    trash,
    results_root,
    "Publication quarantine",
    direct_child = TRUE,
    directory = TRUE
  )
  if (!identical(basename(trash), ".trash")) {
    stop("Refusing an unsafe publication quarantine path.", call. = FALSE)
  }
  wlv_prune_assert_tree(trash, results_root, "Publication quarantine")
  trash
}

wlv_prune_cleanup_trash <- function(results_root) {
  trash <- file.path(results_root, ".trash")
  if (!dir.exists(trash)) return(invisible(0))
  trash <- wlv_prune_prepare_trash(results_root)
  bytes <- wlv_prune_path_bytes(
    trash,
    results_root,
    "Publication quarantine"
  )
  unlink(trash, recursive = TRUE, force = TRUE)
  if (file.exists(trash)) {
    stop("Could not finish cleaning the publication quarantine.", call. = FALSE)
  }
  invisible(bytes)
}

wlv_prune_quarantine_records <- function(
    records,
    results_root,
    trash_root,
    type) {
  quarantined <- character()
  if (!nrow(records)) return(quarantined)
  for (index in seq_len(nrow(records))) {
    target <- wlv_prune_resolve_target(results_root, records$path[[index]], type)
    if (!identical(type, "marker")) {
      wlv_prune_assert_tree(
        target,
        file.path(results_root, if (identical(type, "run")) "runs" else "releases"),
        paste(type, "prune target")
      )
    }
    actual_bytes <- wlv_prune_path_bytes(
      target,
      file.path(results_root, if (identical(type, "marker")) "channels" else paste0(type, "s")),
      paste(type, "prune target")
    )
    if (!identical(actual_bytes, records$bytes[[index]])) {
      stop(sprintf("%s prune target changed after planning.", type), call. = FALSE)
    }
    destination <- tempfile(
      pattern = paste0(".", type, "-"),
      tmpdir = trash_root
    )
    if (file.exists(destination) || !file.rename(target, destination)) {
      stop(sprintf("Could not quarantine planned %s `%s`.", type, records$path[[index]]),
        call. = FALSE
      )
    }
    if (file.exists(target) || !file.exists(destination)) {
      stop(sprintf("Planned %s `%s` was not quarantined atomically.",
        type, records$path[[index]]), call. = FALSE
      )
    }
    quarantined <- c(quarantined, records$path[[index]])
  }
  quarantined
}

#' Apply a previously validated publication retention plan.
#'
#' The default is a dry run. Setting `dry_run = FALSE` acquires the same results
#' lock used by publication, rebuilds and compares the complete plan, then
#' removes only the explicitly listed markers, release directories, and run
#' directories.
wlv_prune_publications <- function(plan, dry_run = TRUE) {
  plan <- wlv_prune_validate_plan(plan)
  if (!is.logical(dry_run) || length(dry_run) != 1L || is.na(dry_run)) {
    stop("`dry_run` must be one non-missing logical value.", call. = FALSE)
  }
  if (isTRUE(dry_run)) {
    return(structure(list(
      dry_run = TRUE,
      deleted = list(markers = character(), releases = character(), runs = character()),
      reclaimable_bytes = plan$reclaimable_bytes,
      reclaimed_bytes = 0,
      plan = plan
    ), class = "wlv_publication_prune_report"))
  }

  results_root <- wlv_publication_paths(plan$root)$results
  lock <- wlv_prune_acquire_lock(results_root)
  lock_open <- TRUE
  on.exit({
    if (lock_open) {
      try(wlv_prune_release_lock(lock, results_root), silent = TRUE)
    }
  }, add = TRUE)
  current <- wlv_prune_build_plan(
    plan$root,
    keep_releases = wlv_prune_policy_input(plan$policy),
    allow_owned_lock = TRUE
  )
  if (!wlv_prune_plan_unchanged(plan, current)) {
    stop(
      "Publication storage changed after planning; create and review a new prune plan.",
      call. = FALSE
    )
  }
  # A prior hard interruption may have stopped while deleting quarantine.
  # It is outside the active publication graph, but clean it only after the
  # reviewed plan has been rebuilt and matched so a mutated plan cannot redirect
  # this destructive step.
  wlv_prune_cleanup_trash(results_root)

  trash_root <- wlv_prune_prepare_trash(current$results_root)
  deleted <- list(
    markers = wlv_prune_quarantine_records(
      current$delete$markers,
      current$results_root,
      trash_root,
      "marker"
    ),
    releases = wlv_prune_quarantine_records(
      current$delete$releases,
      current$results_root,
      trash_root,
      "release"
    ),
    runs = wlv_prune_quarantine_records(
      current$delete$runs,
      current$results_root,
      trash_root,
      "run"
    )
  )
  verified <- wlv_prune_build_plan(
    plan$root,
    keep_releases = wlv_prune_policy_input(plan$policy),
    allow_owned_lock = TRUE
  )
  if (any(vapply(verified$delete, nrow, integer(1L)))) {
    stop("Publication retention completed with eligible paths still present.",
      call. = FALSE
    )
  }
  wlv_prune_cleanup_trash(results_root)
  wlv_prune_release_lock(lock, results_root)
  lock_open <- FALSE
  structure(list(
    dry_run = FALSE,
    deleted = deleted,
    reclaimable_bytes = plan$reclaimable_bytes,
    reclaimed_bytes = plan$reclaimable_bytes,
    plan = plan
  ), class = "wlv_publication_prune_report")
}
