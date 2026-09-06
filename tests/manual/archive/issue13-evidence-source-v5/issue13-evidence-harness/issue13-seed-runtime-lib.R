# Fail-closed dual runtime loader used only by the external issue #13 seeder.
# The candidate bootstrap remains authoritative when present.  A baseline
# runtime is accepted only when the exact legacy definition pair is present.

wlv13_seed_runtime_required_bindings <- c(
  "wlv_publication_ensure_store",
  "wlv_read_current_release",
  "wlv_list_channel_markers",
  "wlv_new_publication_id",
  "wlv_publication_increment_sequence",
  "wlv_read_panel_result_csv",
  "wlv_write_result_csv",
  "wlv_build_release_run_reference",
  "wlv_publication_relative_path",
  "wlv_build_release_manifest",
  "wlv_write_release_manifest",
  "wlv_verify_release_manifest",
  "wlv_read_release_manifest",
  "wlv_build_channel_marker",
  "wlv_publication_file_sha256",
  "wlv_publication_channel_directory",
  "wlv_channel_marker_filename",
  "wlv_write_channel_marker",
  "wlv_verify_channel_marker",
  "wlv_resolve_current_method_run"
)

wlv13_seed_same_path <- function(left, right, must_work = TRUE) {
  left <- normalizePath(left, winslash = "/", mustWork = must_work)
  right <- normalizePath(right, winslash = "/", mustWork = must_work)
  if (.Platform$OS.type == "windows") {
    left <- tolower(left)
    right <- tolower(right)
  }
  identical(left, right)
}

wlv13_seed_runtime_layout <- function(root) {
  root <- wlv13_normalize_existing_dir(root, "seed runtime root")
  paths <- c(
    bootstrap = file.path(root, "R", "bootstrap.R"),
    functions = file.path(root, "R", "lib", "functions.R"),
    main = file.path(root, "R", "main.R")
  )
  present <- stats::setNames(
    file.exists(paths) & !(file.info(paths)$isdir %in% TRUE),
    names(paths)
  )
  kind <- if (present[["bootstrap"]]) {
    "candidate"
  } else if (all(present[c("functions", "main")])) {
    "baseline"
  } else {
    stop(
      paste0(
        "Seed runtime layout is unsupported: expected R/bootstrap.R or the ",
        "complete legacy R/lib/functions.R + R/main.R pair."
      ),
      call. = FALSE
    )
  }
  definition_paths <- if (identical(kind, "candidate")) {
    paths[["bootstrap"]]
  } else {
    unname(paths[c("functions", "main")])
  }
  expected_paths <- chartr("\\", "/", definition_paths)
  resolved_paths <- normalizePath(definition_paths,
    winslash = "/", mustWork = TRUE
  )
  if (.Platform$OS.type == "windows") {
    expected_paths <- tolower(expected_paths)
    resolved_paths <- tolower(resolved_paths)
  }
  if (!identical(unname(resolved_paths), unname(expected_paths)) ||
      any(!vapply(definition_paths, wlv13_is_within, logical(1L),
        parent = root
      ))) {
    stop("Seed runtime definitions must be canonical files inside the worktree.",
      call. = FALSE
    )
  }
  list(
    kind = kind,
    root = root,
    paths = paths,
    definition_paths = definition_paths
  )
}

wlv13_seed_definition_records <- function(paths) {
  records <- lapply(paths, wlv13_file_record)
  names(records) <- chartr("\\", "/", paths)
  records
}

wlv13_validate_native_seed_report <- function(report, scenario_id,
                                               project_root,
                                               expected_seed_commit) {
  scenario_id <- wlv13_id(scenario_id, "seed scenario_id")
  project_root <- wlv13_normalize_existing_dir(project_root,
    "seed project root"
  )
  expected_seed_commit <- wlv13_scalar_text(expected_seed_commit,
    "expected_seed_commit", "^[0-9a-f]{40}$"
  )
  if (!is.list(report) ||
      !identical(report$schema, wlv13_schema$scenario) ||
      !isTRUE(report$passed) ||
      !identical(report$status, "passed") ||
      !identical(report$scenario_id, scenario_id) ||
      !identical(report$expected_commit, expected_seed_commit) ||
      !identical(report$observed_commit, expected_seed_commit) ||
      !is.null(report$error) || !is.list(report$outputs)) {
    stop("Full-run seed evidence is invalid.", call. = FALSE)
  }
  if (!wlv13_seed_same_path(report$project_root, project_root)) {
    stop("Full-run seed evidence belongs to another project root.",
      call. = FALSE
    )
  }
  if ("execution_mode" %in% names(report) ||
      "authentication" %in% names(report)) {
    stop("The native final gate forbids imported seed evidence.",
      call. = FALSE
    )
  }
  invisible(report)
}

wlv13_load_seed_runtime <- function(root, expected_commit) {
  layout <- wlv13_seed_runtime_layout(root)
  expected_commit <- wlv13_scalar_text(expected_commit,
    "expected_commit", "^[0-9a-f]{40}$"
  )
  if (!identical(wlv13_git_commit(layout$root), expected_commit) ||
      !wlv13_git_runtime_clean(layout$root)) {
    stop("Seed runtime must be pinned and runtime-clean before loading.",
      call. = FALSE
    )
  }

  working_directory <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  search_path <- search()
  definition_records <- wlv13_seed_definition_records(
    layout$definition_paths
  )
  loaded <- wlv_gate_load_runtime(layout$root)
  if (!is.list(loaded) || !identical(loaded$kind, layout$kind) ||
      !is.environment(loaded$runtime)) {
    stop("Dual loader returned an unexpected runtime kind or value.",
      call. = FALSE
    )
  }
  runtime <- loaded$runtime
  required <- wlv13_seed_runtime_required_bindings
  if (identical(layout$kind, "candidate")) {
    required <- c(required, "wlv_assert_loaded_runtime_unchanged")
  }
  available <- vapply(required, exists, logical(1L),
    envir = runtime, mode = "function", inherits = FALSE
  )
  if (!all(available)) {
    stop(sprintf("Seed runtime API is incomplete: %s.",
      paste(required[!available], collapse = ", ")
    ), call. = FALSE)
  }
  binding_snapshot <- mget(required, envir = runtime, inherits = FALSE)

  assert_unchanged <- function() {
    if (!wlv13_seed_same_path(getwd(), working_directory) ||
        !identical(search(), search_path)) {
      stop("Seed runtime changed the working directory or search path.",
        call. = FALSE
      )
    }
    current_records <- wlv13_seed_definition_records(
      layout$definition_paths
    )
    if (!identical(current_records, definition_records)) {
      stop("Seed runtime definition files changed after loading.",
        call. = FALSE
      )
    }
    bindings_ok <- vapply(required, function(name) {
      exists(name, envir = runtime, inherits = FALSE) &&
        identical(get(name, envir = runtime, inherits = FALSE),
          binding_snapshot[[name]]
        )
    }, logical(1L))
    if (!all(bindings_ok)) {
      stop(sprintf("Loaded seed runtime bindings changed: %s.",
        paste(required[!bindings_ok], collapse = ", ")
      ), call. = FALSE)
    }
    if (identical(layout$kind, "candidate")) {
      runtime$wlv_assert_loaded_runtime_unchanged()
    }
    if (!identical(wlv13_git_commit(layout$root), expected_commit) ||
        !wlv13_git_runtime_clean(layout$root)) {
      stop("Seed runtime inputs changed after loading.", call. = FALSE)
    }
    invisible(TRUE)
  }

  assert_unchanged()
  list(
    kind = layout$kind,
    runtime = runtime,
    assert_unchanged = assert_unchanged,
    definition_records = definition_records,
    required_bindings = as.list(required)
  )
}
