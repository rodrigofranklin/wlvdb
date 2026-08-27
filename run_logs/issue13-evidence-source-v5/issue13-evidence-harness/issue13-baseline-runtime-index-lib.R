# Authentication and lookup for the external baseline scenario/profile index.

wlv13_index_exact_names <- function(value, expected, label) {
  if (!is.list(value) || !setequal(names(value), expected) ||
      length(names(value)) != length(expected)) {
    stop(sprintf("%s has an invalid schema.", label), call. = FALSE)
  }
  invisible(value)
}

wlv13_index_nullable_text <- function(value, name, pattern) {
  if (is.null(value)) return(NULL)
  wlv13_scalar_text(value, name, pattern)
}

wlv13_index_patch_id <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  value <- system2(
    "git", c("patch-id", "--stable"),
    stdin = path, stdout = TRUE, stderr = TRUE
  )
  status <- attr(value, "status", exact = TRUE)
  if (!is.null(status) && !identical(status, 0L)) {
    stop(sprintf("Cannot calculate stable patch-id for `%s`.", path),
      call. = FALSE
    )
  }
  if (length(value) != 1L || !nzchar(trimws(value[[1L]]))) {
    stop(sprintf("Stable patch-id output is invalid for `%s`.", path),
      call. = FALSE
    )
  }
  tokens <- strsplit(trimws(value[[1L]]), "[[:space:]]+", perl = TRUE)[[1L]]
  wlv13_scalar_text(tokens[[1L]], "overlay patch-id", "^[0-9a-f]{40}$")
}

wlv13_index_profile <- function(value, base_commit) {
  required <- c(
    "schema", "id", "inventory_value", "source_commit", "runtime_commit",
    "run_dirty", "overlay_patch_path", "overlay_patch_sha256",
    "overlay_patch_id"
  )
  wlv13_index_exact_names(value, required, "Baseline validation profile")
  if (!identical(value$schema, wlv13_schema$validation_profile)) {
    stop("Baseline validation profile has an unsupported schema.",
      call. = FALSE
    )
  }
  id <- wlv13_scalar_text(value$id, "profile id",
    "^[a-z0-9][a-z0-9._-]*$"
  )
  inventory_value <- wlv13_scalar_text(value$inventory_value,
    "profile inventory_value", "^[a-z0-9][a-z0-9._+-]*$"
  )
  source_commit <- wlv13_scalar_text(value$source_commit,
    "profile source_commit", "^[0-9a-f]{40}$"
  )
  runtime_commit <- wlv13_scalar_text(value$runtime_commit,
    "profile runtime_commit", "^[0-9a-f]{40}$"
  )
  run_dirty <- wlv13_bool(value$run_dirty, "profile run_dirty")
  if (!source_commit %in% c(base_commit, runtime_commit)) {
    stop(paste0(
      "Profile source_commit must be either the immutable base or the clean ",
      "effective runtime commit."
    ), call. = FALSE)
  }
  patch_path <- wlv13_index_nullable_text(value$overlay_patch_path,
    "overlay_patch_path", ".+"
  )
  patch_sha256 <- wlv13_index_nullable_text(value$overlay_patch_sha256,
    "overlay_patch_sha256", "^[0-9a-f]{64}$"
  )
  patch_id <- wlv13_index_nullable_text(value$overlay_patch_id,
    "overlay_patch_id", "^[0-9a-f]{40}$"
  )
  patch_present <- c(
    !is.null(patch_path), !is.null(patch_sha256), !is.null(patch_id)
  )
  if (any(patch_present) && !all(patch_present)) {
    stop("Overlay patch path, SHA-256, and patch-id are all-or-none.",
      call. = FALSE
    )
  }
  if (!any(patch_present)) {
    if (!identical(runtime_commit, base_commit) ||
        !identical(source_commit, base_commit) || isTRUE(run_dirty)) {
      stop("A patch-free baseline profile must be clean at the base commit.",
        call. = FALSE
      )
    }
  } else {
    patch_path <- normalizePath(patch_path, winslash = "/", mustWork = TRUE)
    if (!identical(wlv13_sha256_file(patch_path), patch_sha256) ||
        !identical(wlv13_index_patch_id(patch_path), patch_id)) {
      stop(sprintf("Overlay patch authentication failed for profile `%s`.", id),
        call. = FALSE
      )
    }
    if (identical(runtime_commit, base_commit)) {
      stop("An overlay profile must have a distinct effective commit.",
        call. = FALSE
      )
    }
    if ((identical(source_commit, runtime_commit) && isTRUE(run_dirty)) ||
        (identical(source_commit, base_commit) && !isTRUE(run_dirty))) {
      stop(paste0(
        "Overlay source provenance must be clean at runtime_commit or dirty ",
        "at baseline_base_commit."
      ), call. = FALSE)
    }
  }
  list(
    schema = value$schema,
    id = id,
    inventory_value = inventory_value,
    source_commit = source_commit,
    runtime_commit = runtime_commit,
    run_dirty = run_dirty,
    overlay_patch_path = patch_path,
    overlay_patch_sha256 = patch_sha256,
    overlay_patch_id = patch_id
  )
}

wlv13_read_baseline_runtime_index <- function(path, expected_sha256,
                                               baseline_base_commit) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  expected_sha256 <- wlv13_scalar_text(expected_sha256,
    "baseline_runtime_index_sha256", "^[0-9a-f]{64}$"
  )
  baseline_base_commit <- wlv13_scalar_text(baseline_base_commit,
    "baseline_base_commit", "^[0-9a-f]{40}$"
  )
  if (!identical(wlv13_sha256_file(path), expected_sha256)) {
    stop("Baseline runtime index SHA-256 mismatch.", call. = FALSE)
  }
  value <- wlv13_json_read(path, simplify = FALSE)
  wlv13_index_exact_names(value,
    c("schema", "baseline_base_commit", "created_at", "profiles", "scenarios"),
    "Baseline runtime index"
  )
  if (!identical(value$schema, wlv13_schema$baseline_runtime_index) ||
      !identical(value$baseline_base_commit, baseline_base_commit)) {
    stop("Baseline runtime index schema or base commit is invalid.",
      call. = FALSE
    )
  }
  wlv13_scalar_text(value$created_at, "runtime index created_at")
  if (!is.list(value$profiles) || !length(value$profiles) ||
      !is.list(value$scenarios) || !length(value$scenarios)) {
    stop("Baseline runtime index profiles/scenarios must be non-empty arrays.",
      call. = FALSE
    )
  }
  profiles <- lapply(value$profiles, wlv13_index_profile,
    base_commit = baseline_base_commit
  )
  profile_ids <- vapply(profiles, `[[`, character(1L), "id")
  if (anyDuplicated(profile_ids) ||
      !identical(order(profile_ids, method = "radix"), seq_along(profile_ids))) {
    stop("Baseline profiles must have unique, canonically ordered IDs.",
      call. = FALSE
    )
  }
  names(profiles) <- profile_ids

  scenario_required <- c("scenario_id", "runtime_commit", "profile_id")
  scenarios <- lapply(seq_along(value$scenarios), function(index) {
    record <- value$scenarios[[index]]
    wlv13_index_exact_names(record, scenario_required,
      sprintf("Baseline runtime scenario %d", index)
    )
    scenario_id <- wlv13_id(record$scenario_id, "runtime scenario_id")
    runtime_commit <- wlv13_scalar_text(record$runtime_commit,
      "runtime scenario commit", "^[0-9a-f]{40}$"
    )
    profile_id <- wlv13_scalar_text(record$profile_id,
      "runtime scenario profile_id", "^[a-z0-9][a-z0-9._-]*$"
    )
    if (!profile_id %in% names(profiles) ||
        !identical(runtime_commit, profiles[[profile_id]]$runtime_commit)) {
      stop(sprintf("Scenario `%s` is not bound to its profile commit.",
        scenario_id
      ), call. = FALSE)
    }
    list(
      scenario_id = scenario_id,
      runtime_commit = runtime_commit,
      profile_id = profile_id
    )
  })
  scenario_ids <- vapply(scenarios, `[[`, character(1L), "scenario_id")
  expected_ids <- sort(wlv13_scenario_ids()[
    startsWith(wlv13_scenario_ids(), "baseline/")
  ], method = "radix")
  if (anyDuplicated(scenario_ids) ||
      !identical(scenario_ids, expected_ids)) {
    stop(sprintf(
      "Baseline runtime index coverage differs (missing=[%s]; extra=[%s]).",
      paste(setdiff(expected_ids, scenario_ids), collapse = ","),
      paste(setdiff(scenario_ids, expected_ids), collapse = ",")
    ), call. = FALSE)
  }
  used_profiles <- sort(unique(vapply(scenarios, `[[`, character(1L),
    "profile_id"
  )), method = "radix")
  if (!identical(used_profiles, sort(names(profiles), method = "radix"))) {
    stop("Baseline runtime index contains unused profiles.", call. = FALSE)
  }
  names(scenarios) <- scenario_ids
  list(
    path = path,
    sha256 = expected_sha256,
    baseline_base_commit = baseline_base_commit,
    profiles = profiles,
    scenarios = scenarios
  )
}

wlv13_validate_baseline_runtime_matrix <- function(index, candidate_commit) {
  candidate_commit <- wlv13_scalar_text(candidate_commit,
    "candidate_commit", "^[0-9a-f]{40}$"
  )
  runtime_commits <- vapply(index$scenarios, `[[`, character(1L),
    "runtime_commit"
  )
  if (any(runtime_commits == candidate_commit)) {
    stop("Baseline runtime index must not reference the candidate commit.",
      call. = FALSE
    )
  }
  for (method in wlv13_methods) {
    method_ids <- paste0("baseline/", c(
      wlv13_calculate_phase(method, 1L),
      if (method %in% c("wiodr13", "wiodr16")) {
        wlv13_calculate_phase(method, 2L)
      } else {
        character()
      },
      wlv13_recalculation_phases(method)
    ))
    records <- index$scenarios[method_ids]
    profiles <- unique(vapply(records, `[[`, character(1L), "profile_id"))
    commits <- unique(vapply(records, `[[`, character(1L), "runtime_commit"))
    if (length(profiles) != 1L || length(commits) != 1L) {
      stop(sprintf(
        "All calculation/recalculation scenarios for `%s` must share one profile and commit.",
        method
      ), call. = FALSE)
    }
  }
  issue13_base_commit <- "cc2c86189a06676bcb9f0e05e08033d710a92509"
  if (identical(index$baseline_base_commit, issue13_base_commit)) {
    expected_profiles <- c(
      "strict-cc2",
      "validation-overlay-final",
      "validation-overlay-final+nan-clean-v2",
      "validation-overlay-norow-cc2"
    )
    observed_profiles <- sort(unname(vapply(index$profiles, `[[`,
      character(1L), "inventory_value"
    )), method = "radix")
    if (!identical(observed_profiles, sort(expected_profiles,
        method = "radix"))) {
      stop("The issue #13 baseline index must contain exactly four scientific profiles.",
        call. = FALSE
      )
    }
    expected_method_profile <- c(
      wiodr13 = "strict-cc2",
      wiodr16 = "strict-cc2",
      alternative_1 = "validation-overlay-final",
      alternative_2 = "validation-overlay-final+nan-clean-v2",
      norow_w13 = "validation-overlay-norow-cc2",
      ochoa_1 = "validation-overlay-final",
      ochoa_2 = "validation-overlay-final",
      petrovic = "validation-overlay-final+nan-clean-v2",
      wiodr13v09 = "validation-overlay-final",
      wiodr16v09 = "strict-cc2",
      zerodep_1 = "strict-cc2",
      zerodep_2 = "strict-cc2"
    )
    for (method in names(expected_method_profile)) {
      full_id <- paste0("baseline/", wlv13_calculate_phase(method, 1L))
      profile_id <- index$scenarios[[full_id]]$profile_id
      observed <- index$profiles[[profile_id]]$inventory_value
      if (!identical(observed, expected_method_profile[[method]])) {
        stop(sprintf("Method `%s` is bound to the wrong scientific profile.",
          method
        ), call. = FALSE)
      }
    }
  }
  invisible(TRUE)
}

wlv13_git_single_value <- function(root, arguments, label) {
  value <- system2("git", c("-C", root, arguments),
    stdout = TRUE, stderr = TRUE
  )
  status <- attr(value, "status", exact = TRUE)
  if ((!is.null(status) && !identical(status, 0L)) || length(value) != 1L) {
    stop(sprintf("Cannot read %s for `%s`.", label, root), call. = FALSE)
  }
  trimws(value[[1L]])
}

wlv13_profile_diff_patch_id <- function(root, base_commit, runtime_commit) {
  temporary <- tempfile("wlv13-profile-diff-", fileext = ".patch")
  on.exit(if (file.exists(temporary)) unlink(temporary, force = TRUE), add = TRUE)
  value <- system2("git", c(
    "-C", root, "diff", "--binary", "--full-index",
    base_commit, runtime_commit, "--"
  ), stdout = temporary, stderr = TRUE)
  status <- attr(value, "status", exact = TRUE)
  if (!is.null(status) && !identical(status, 0L)) {
    stop(sprintf("Cannot authenticate profile diff in `%s`.", root),
      call. = FALSE
    )
  }
  if (!file.exists(temporary) || file.info(temporary)$size <= 0) {
    stop("Overlay profile diff is empty.", call. = FALSE)
  }
  wlv13_index_patch_id(temporary)
}

wlv13_validate_profile_root <- function(root, profile, baseline_base_commit) {
  root <- wlv13_normalize_existing_dir(root, "profile project root")
  if (!identical(wlv13_git_commit(root), profile$runtime_commit) ||
      !wlv13_git_runtime_clean(root)) {
    stop(sprintf("Profile `%s` root is not pinned/runtime-clean.", profile$id),
      call. = FALSE
    )
  }
  if (is.null(profile$overlay_patch_path)) {
    if (!identical(profile$runtime_commit, baseline_base_commit)) {
      stop("Patch-free profile root differs from the base commit.",
        call. = FALSE
      )
    }
  } else {
    parent <- wlv13_git_single_value(root,
      c("rev-parse", paste0(profile$runtime_commit, "^")),
      "profile parent commit"
    )
    if (!identical(parent, baseline_base_commit) ||
        !identical(wlv13_profile_diff_patch_id(
          root, baseline_base_commit, profile$runtime_commit
        ), profile$overlay_patch_id)) {
      stop(sprintf("Profile `%s` commit does not match its overlay patch.",
        profile$id
      ), call. = FALSE)
    }
  }
  invisible(TRUE)
}
