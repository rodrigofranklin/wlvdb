# Builds exact stage-five multiplicity profiles from authenticated historical
# evidence.  Candidate recalculations are deliberately not inputs: the
# expected candidate child is projected from an authenticated candidate/full
# baseline parent identity, while each legacy child delta is independently
# proven by a clean baseline recalculation.

wlv13_v5d_stage5_auth <- function(value) {
  list(
    run_id = value$run_id,
    commit = value$commit,
    tree = value$tree,
    source_sha256 = value$source_sha256,
    run_manifest_sha256 = value$run_manifest_sha256,
    run_inventory_sha256 = value$run_inventory_sha256
  )
}

wlv13_v5d_capture_field <- function(lines, key) {
  matches <- grep(paste0("^", key, "="), lines, value = TRUE)
  if (length(matches) != 1L) {
    stop(sprintf("Capture record lacks singular field `%s`.", key),
      call. = FALSE
    )
  }
  substring(matches, nchar(key) + 2L)
}

wlv13_v5d_capture_semicolon_record <- function(line, prefix, fields) {
  parts <- strsplit(enc2utf8(line), ";", fixed = TRUE)[[1L]]
  if (!length(parts) || !identical(parts[[1L]], prefix)) {
    stop("Invalid capture evidence record prefix.", call. = FALSE)
  }
  positions <- regexpr("=", parts[-1L], fixed = TRUE)
  if (any(positions < 2L)) {
    stop("Invalid capture evidence field.", call. = FALSE)
  }
  names <- substring(parts[-1L], 1L, positions - 1L)
  values <- vapply(seq_along(positions), function(index) {
    value <- parts[-1L][[index]]
    position <- positions[[index]]
    if (position < 2L) {
      stop("Invalid capture evidence field.", call. = FALSE)
    }
    substring(value, position + 1L)
  }, character(1L))
  if (!identical(names, fields) || anyDuplicated(names)) {
    stop("Capture evidence record has an invalid exact schema.",
      call. = FALSE
    )
  }
  as.list(stats::setNames(values, names))
}

wlv13_v5d_directory_inventory_sha256 <- function(root) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  paths <- sort(list.files(
    root, recursive = TRUE, all.files = TRUE, full.names = TRUE,
    include.dirs = FALSE, no.. = TRUE
  ), method = "radix")
  info <- file.info(paths)
  if (!length(paths) || anyNA(info$isdir) || any(info$isdir)) {
    stop("Capture tooling inventory is invalid.", call. = FALSE)
  }
  prefix <- paste0(root, "/")
  relative <- ifelse(startsWith(paths, prefix), substring(paths,
    nchar(prefix) + 1L
  ), "")
  if (any(!nzchar(relative)) || anyDuplicated(relative)) {
    stop("Capture tooling inventory paths are invalid.", call. = FALSE)
  }
  records <- vapply(seq_along(paths), function(index) {
    paste(
      relative[[index]],
      format(info$size[[index]], scientific = FALSE, trim = TRUE),
      wlv13_sha256_file(paths[[index]]), sep = "|"
    )
  }, character(1L))
  wlv13_v5d_sha256_text(paste(records, collapse = "\n"))
}

wlv13_v5d_validate_stage5_capture <- function(
    bridge_capture_path, bridge_index_path, bridge_manifest_path,
    stage_capture_path, stage_index_path, evidence, harness_dir) {
  paths <- vapply(list(
    bridge_capture_path, bridge_index_path, bridge_manifest_path,
    stage_capture_path, stage_index_path
  ), normalizePath, character(1L), winslash = "/", mustWork = TRUE)
  bridge_capture_path <- paths[[1L]]
  bridge_index_path <- paths[[2L]]
  bridge_manifest_path <- paths[[3L]]
  stage_capture_path <- paths[[4L]]
  stage_index_path <- paths[[5L]]
  harness_dir <- normalizePath(harness_dir, winslash = "/", mustWork = TRUE)
  bridge_lines <- readLines(
    bridge_capture_path, warn = FALSE, encoding = "UTF-8"
  )
  bridge_header <- c(
    "schema", "baseline_base_commit", "baseline_base_tree",
    "baseline_runtime_commit", "baseline_runtime_tree",
    "harness_path", "harness_inventory_sha256", "rscript_path",
    "rscript_sha256", "tool_records", "baseline_worktree",
    "captured_methods", "verified_records",
    "seed_evidence_index_sha256", "source_wiodr13_manifest_sha256",
    "source_wiodr16_manifest_sha256", "evidence_index",
    "evidence_index_sha256"
  )
  bridge_keys <- sub("=.*$", "", bridge_lines[seq_along(bridge_header)])
  bridge_records <- grep("^evidence_record;", bridge_lines, value = TRUE)
  bridge_tool_lines <- grep("^tool_record;", bridge_lines, value = TRUE)
  bridge_fields <- c(
    "method", "mode", "at_stage", "scenario_id", "run_id",
    "parent_run_id", "commit", "tree", "request_sha256",
    "source_sha256", "run_manifest_sha256", "run_inventory_sha256",
    "anomalies_sha256", "unit_sha256", "nonfinite_sha256",
    "verify_log_sha256"
  )
  bridge_fixed <- c(
    baseline_base_commit = "cc2c86189a06676bcb9f0e05e08033d710a92509",
    baseline_base_tree = "0cb1142cdadd74bf95272010f5393ebe2af79f47",
    baseline_runtime_commit = "e2f4d6dae9a6d35c966b305fabac52e489faa3e7",
    baseline_runtime_tree = "7da19c4f2913e857040ba228280f404b0e54eaab",
    captured_methods = paste(c(
      "alternative_1", "alternative_2", "norow_w13", "ochoa_1",
      "ochoa_2", "petrovic", "wiodr13v09"
    ), collapse = ","),
    verified_records = "7", tool_records = "5"
  )
  bridge_fixed_valid <- all(vapply(names(bridge_fixed), function(key) {
    identical(wlv13_v5d_capture_field(bridge_lines, key),
      unname(bridge_fixed[[key]]))
  }, logical(1L)))
  bridge_rscript_path <- normalizePath(wlv13_v5d_capture_field(
    bridge_lines, "rscript_path"
  ), winslash = "/", mustWork = TRUE)
  bridge_tooling_valid <-
    identical(wlv13_v5d_capture_field(
      bridge_lines, "harness_path"
    ), harness_dir) &&
    identical(wlv13_v5d_capture_field(
      bridge_lines, "harness_inventory_sha256"
    ), wlv13_v5d_directory_inventory_sha256(harness_dir)) &&
    identical(wlv13_v5d_capture_field(
      bridge_lines, "rscript_sha256"
    ), wlv13_sha256_file(bridge_rscript_path))
  if (length(bridge_lines) != length(bridge_header) + 5L + 7L ||
      !identical(bridge_keys, bridge_header) ||
      !identical(bridge_lines[[1L]],
        "schema=issue13-v5-clean-bridge-capture/1") ||
      !bridge_fixed_valid || !bridge_tooling_valid ||
      length(bridge_tool_lines) != 5L || length(bridge_records) != 7L ||
      !identical(wlv13_v5d_capture_field(
        bridge_lines, "evidence_index_sha256"
      ), wlv13_sha256_file(bridge_index_path)) ||
      any(!grepl("^[0-9a-f]{64}$", vapply(c(
        "seed_evidence_index_sha256", "source_wiodr13_manifest_sha256",
        "source_wiodr16_manifest_sha256"
      ), function(key) {
        wlv13_v5d_capture_field(bridge_lines, key)
      }, character(1L))))) {
    stop("The bridge capture record is not exhaustive.", call. = FALSE)
  }
  bridge_tools <- lapply(bridge_tool_lines, function(line) {
    wlv13_v5d_capture_semicolon_record(
      line, "tool_record", c("name", "sha256")
    )
  })
  bridge_tool_names <- c(
    "bridge_builder", "bridge_capture_script", "compare_override",
    "diagnostics_override", "verifier"
  )
  bridge_tool_files <- stats::setNames(c(
    "issue13-v5-build-diagnostic-bridges.R",
    "issue13-v5-capture-clean-bridge-evidence.ps1",
    "issue13-v5-compare-override.R",
    "issue13-v5-diagnostics-override.R",
    "issue13-v5-verify-diagnostic-evidence.R"
  ), bridge_tool_names)
  bridge_tool_root <- normalizePath(script_dir,
    winslash = "/", mustWork = TRUE
  )
  if (!identical(
      vapply(bridge_tools, `[[`, character(1L), "name"),
      bridge_tool_names
    ) || any(!vapply(seq_along(bridge_tools), function(index) {
      record <- bridge_tools[[index]]
      identical(record$sha256, wlv13_sha256_file(file.path(
        bridge_tool_root, bridge_tool_files[[record$name]]
      )))
    }, logical(1L)))) {
    stop("Bridge capture tools differ from their recorded bytes.",
      call. = FALSE
    )
  }
  bridge_parsed <- lapply(bridge_records, function(line) {
    wlv13_v5d_capture_semicolon_record(
      line, "evidence_record", bridge_fields
    )
  })
  bridge_methods <- vapply(bridge_parsed, `[[`, character(1L), "method")
  expected_bridge_methods <- c(
    "alternative_1", "alternative_2", "norow_w13", "ochoa_1",
    "ochoa_2", "petrovic", "wiodr13v09"
  )
  if (!identical(bridge_methods, expected_bridge_methods) ||
      any(vapply(bridge_parsed, function(record) {
        !identical(record$mode, "calculate") ||
          nzchar(record$at_stage) || nzchar(record$parent_run_id) ||
          !identical(record$commit, bridge_fixed[[
            "baseline_runtime_commit"
          ]]) || !identical(record$tree, bridge_fixed[[
            "baseline_runtime_tree"
          ]]) || any(!grepl("^[0-9a-f]{64}$", unlist(record[c(
            "request_sha256", "source_sha256", "run_manifest_sha256",
            "run_inventory_sha256", "anomalies_sha256",
            "verify_log_sha256"
          )], use.names = FALSE)))
      }, logical(1L)))) {
    stop("The bridge capture records are not the exact clean references.",
      call. = FALSE
    )
  }

  stage_lines <- readLines(
    stage_capture_path, warn = FALSE, encoding = "UTF-8"
  )
  stage_header <- c(
    "schema", "baseline_base_commit", "baseline_base_tree",
    "baseline_runtime_commit", "baseline_runtime_tree", "harness_path",
    "harness_inventory_sha256", "rscript_path", "rscript_sha256", "methods",
    "stages", "bridge_capture_record_sha256",
    "bridge_evidence_index_sha256", "bridge_manifest_sha256",
    "stage5_evidence_index_sha256",
    "source_wiodr13_inventory_before_sha256",
    "source_wiodr13_inventory_after_sha256",
    "source_wiodr16_inventory_before_sha256",
    "source_wiodr16_inventory_after_sha256", "recipe_records",
    "reference_records", "seed_records", "target_records",
    "worktree_records"
  )
  stage_keys <- sub("=.*$", "", stage_lines[seq_along(stage_header)])
  recipe_lines <- grep("^recipe_record;", stage_lines, value = TRUE)
  worktree_lines <- grep("^worktree_record;", stage_lines, value = TRUE)
  reference_lines <- grep(
    "^evidence_record;role=baseline_reference;", stage_lines, value = TRUE
  )
  target_lines <- grep(
    "^evidence_record;role=baseline_target;", stage_lines, value = TRUE
  )
  seed_lines <- grep(
    "^seed_record;role=parent_alias;", stage_lines, value = TRUE
  )
  sha <- "^[0-9a-f]{64}$"
  fixed_values <- c(
    baseline_base_commit = "cc2c86189a06676bcb9f0e05e08033d710a92509",
    baseline_base_tree = "0cb1142cdadd74bf95272010f5393ebe2af79f47",
    baseline_runtime_commit = "e2f4d6dae9a6d35c966b305fabac52e489faa3e7",
    baseline_runtime_tree = "7da19c4f2913e857040ba228280f404b0e54eaab",
    methods = paste(wlv13_v5d_methods, collapse = ","),
    stages = "1,4,5",
    recipe_records = "8", reference_records = "12",
    seed_records = "36", target_records = "36",
    worktree_records = "6"
  )
  fixed_valid <- all(vapply(names(fixed_values), function(key) {
    identical(wlv13_v5d_capture_field(stage_lines, key),
      unname(fixed_values[[key]]))
  }, logical(1L)))
  hash_valid <- identical(wlv13_v5d_capture_field(
      stage_lines, "bridge_capture_record_sha256"
    ), wlv13_sha256_file(bridge_capture_path)) &&
    identical(wlv13_v5d_capture_field(
      stage_lines, "bridge_evidence_index_sha256"
    ), wlv13_sha256_file(bridge_index_path)) &&
    identical(wlv13_v5d_capture_field(
      stage_lines, "bridge_manifest_sha256"
    ), wlv13_sha256_file(bridge_manifest_path)) &&
    identical(wlv13_v5d_capture_field(
      stage_lines, "stage5_evidence_index_sha256"
    ), wlv13_sha256_file(stage_index_path))
  inventory_hashes <- vapply(c(
    "source_wiodr13_inventory_before_sha256",
    "source_wiodr13_inventory_after_sha256",
    "source_wiodr16_inventory_before_sha256",
    "source_wiodr16_inventory_after_sha256"
  ), function(key) {
    wlv13_v5d_capture_field(stage_lines, key)
  }, character(1L))
  inventory_valid <- all(grepl(sha, inventory_hashes)) &&
    identical(inventory_hashes[[1L]], inventory_hashes[[2L]]) &&
    identical(inventory_hashes[[3L]], inventory_hashes[[4L]])
  stage_rscript_path <- normalizePath(wlv13_v5d_capture_field(
    stage_lines, "rscript_path"
  ), winslash = "/", mustWork = TRUE)
  tooling_valid <- identical(wlv13_v5d_capture_field(
      stage_lines, "harness_path"
    ), harness_dir) &&
    identical(wlv13_v5d_capture_field(
      stage_lines, "harness_inventory_sha256"
    ), wlv13_v5d_directory_inventory_sha256(harness_dir)) &&
    identical(wlv13_v5d_capture_field(
      stage_lines, "rscript_path"
    ), wlv13_v5d_capture_field(bridge_lines, "rscript_path")) &&
    identical(wlv13_v5d_capture_field(
      stage_lines, "rscript_sha256"
    ), wlv13_sha256_file(stage_rscript_path)) &&
    identical(wlv13_v5d_capture_field(
      stage_lines, "rscript_sha256"
    ), wlv13_v5d_capture_field(bridge_lines, "rscript_sha256"))
  if (length(stage_lines) !=
        length(stage_header) + 8L + 6L + 12L + 36L + 36L ||
      !identical(stage_keys, stage_header) ||
      !identical(stage_lines[[1L]],
        "schema=issue13-v5-clean-stage5-capture/1") ||
      !fixed_valid || !hash_valid || !inventory_valid || !tooling_valid ||
      length(recipe_lines) != 8L || length(worktree_lines) != 6L ||
      length(reference_lines) != 12L || length(seed_lines) != 36L ||
      length(target_lines) != 36L) {
    stop("The stage-five capture record is not exhaustive.", call. = FALSE)
  }
  recipes <- lapply(recipe_lines, function(line) {
    wlv13_v5d_capture_semicolon_record(
      line, "recipe_record", c("name", "sha256")
    )
  })
  recipe_names <- c(
    "bridge_builder", "bridge_capture_script", "compare_override",
    "diagnostics_override", "launcher", "stage5_builder",
    "stage5_capture_script", "verifier"
  )
  recipe_files <- stats::setNames(c(
    "issue13-v5-build-diagnostic-bridges.R",
    "issue13-v5-capture-clean-bridge-evidence.ps1",
    "issue13-v5-compare-override.R",
    "issue13-v5-diagnostics-override.R",
    "issue13-v5-run-stage5-evidence.R",
    "issue13-v5-build-stage5-profiles.R",
    "issue13-v5-capture-clean-stage5-evidence.ps1",
    "issue13-v5-verify-diagnostic-evidence.R"
  ), recipe_names)
  recipe_root <- normalizePath(script_dir, winslash = "/", mustWork = TRUE)
  recipe_valid <- identical(
    vapply(recipes, `[[`, character(1L), "name"), recipe_names
  ) && all(vapply(seq_along(recipes), function(index) {
    record <- recipes[[index]]
    identical(record$sha256, wlv13_sha256_file(file.path(
      recipe_root, recipe_files[[record$name]]
    )))
  }, logical(1L)))
  if (!recipe_valid) {
    stop("Stage-five capture recipes differ from their recorded bytes.",
      call. = FALSE
    )
  }
  worktrees <- lapply(worktree_lines, function(line) {
    wlv13_v5d_capture_semicolon_record(
      line, "worktree_record",
      c("key", "path", "commit", "tree", "git_status_sha256")
    )
  })
  expected_worktree_keys <- sort(as.vector(outer(
    as.character(c(1L, 4L, 5L)), c(
      "cc2c86189a06676bcb9f0e05e08033d710a92509",
      "e2f4d6dae9a6d35c966b305fabac52e489faa3e7"
    ), paste, sep = "|"
  )), method = "radix")
  empty_sha256 <- wlv13_v5d_sha256_text("")
  if (!identical(
      sort(vapply(worktrees, `[[`, character(1L), "key"), method = "radix"),
      expected_worktree_keys
    ) || !identical(
      sort(unique(evidence$baseline_target_project_root), method = "radix"),
      sort(vapply(worktrees, `[[`, character(1L), "path"), method = "radix")
    ) || any(vapply(worktrees, function(record) {
      parts <- strsplit(record$key, "|", fixed = TRUE)[[1L]]
      expected_tree <- if (length(parts) == 2L && identical(
          parts[[2L]], fixed_values[["baseline_base_commit"]]
        )) {
        fixed_values[["baseline_base_tree"]]
      } else {
        fixed_values[["baseline_runtime_tree"]]
      }
      length(parts) != 2L || !parts[[1L]] %in% c("1", "4", "5") ||
        !parts[[2L]] %in% c(
          fixed_values[["baseline_base_commit"]],
          fixed_values[["baseline_runtime_commit"]]
        ) || !identical(record$commit, parts[[2L]]) ||
        !identical(record$tree, expected_tree) ||
        !identical(record$git_status_sha256, empty_sha256)
    }, logical(1L)))) {
    stop("Stage-five capture worktree inventory is incomplete.",
      call. = FALSE
    )
  }
  common_fields <- c(
    "role", "method", "mode", "at_stage", "scenario_id", "run_id",
    "parent_run_id", "commit", "tree", "request_sha256",
    "source_sha256", "run_manifest_sha256", "run_inventory_sha256",
    "anomalies_sha256", "unit_sha256", "nonfinite_sha256"
  )
  references <- lapply(reference_lines, function(line) {
    wlv13_v5d_capture_semicolon_record(
      line, "evidence_record", c(common_fields, "verify_log_sha256")
    )
  })
  targets <- lapply(target_lines, function(line) {
    wlv13_v5d_capture_semicolon_record(
      line, "evidence_record",
      c(common_fields, "run_log_sha256", "verify_log_sha256")
    )
  })
  seeds <- lapply(seed_lines, function(line) {
    wlv13_v5d_capture_semicolon_record(
      line, "seed_record", c(
        "role", "channel", "method", "at_stage", "parent_run_id",
        "child_run_root", "alias_release_id",
        "alias_release_manifest_sha256", "alias_marker_sha256",
        "parent_verify_log_sha256", "run_log_sha256"
      )
    )
  })
  reference_methods <- vapply(references, `[[`, character(1L), "method")
  expected_matrix <- do.call(rbind, lapply(wlv13_v5d_methods,
    function(method) data.frame(
      method = method, at_stage = as.character(c(1L, 4L, 5L)),
      stringsAsFactors = FALSE, check.names = FALSE
    )
  ))
  observed_matrix <- data.frame(
    method = vapply(targets, `[[`, character(1L), "method"),
    at_stage = vapply(targets, `[[`, character(1L), "at_stage"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  seed_matrix <- data.frame(
    method = vapply(seeds, `[[`, character(1L), "method"),
    at_stage = vapply(seeds, `[[`, character(1L), "at_stage"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  record_hash_fields <- c(
    "request_sha256", "source_sha256", "run_manifest_sha256",
    "run_inventory_sha256", "anomalies_sha256", "verify_log_sha256"
  )
  record_hashes_valid <- all(vapply(c(references, targets), function(record) {
    all(vapply(record[record_hash_fields], function(value) {
      grepl(sha, value)
    }, logical(1L))) &&
      (!nzchar(record$unit_sha256) || grepl(sha, record$unit_sha256)) &&
      (!nzchar(record$nonfinite_sha256) ||
        grepl(sha, record$nonfinite_sha256)) &&
      grepl("^[0-9a-f]{40}$", record$commit) &&
      grepl("^[0-9a-f]{40}$", record$tree)
  }, logical(1L))) && all(vapply(targets, function(record) {
    grepl(sha, record$run_log_sha256)
  }, logical(1L)))
  seed_publication_valid <- function(seed, row) {
    tryCatch({
      project_root <- normalizePath(
        row$baseline_target_project_root, winslash = "/", mustWork = TRUE
      )
      results_root <- normalizePath(file.path(project_root, "results"),
        winslash = "/", mustWork = TRUE
      )
      release_path <- normalizePath(file.path(
        results_root, "releases", seed$alias_release_id,
        "release_manifest.json"
      ), winslash = "/", mustWork = TRUE)
      channel_root <- normalizePath(file.path(
        results_root, "channels", seed$channel
      ), winslash = "/", mustWork = TRUE)
      marker_paths <- sort(list.files(
        channel_root, pattern = "^[0-9]{20}-.*[.]json$",
        full.names = TRUE
      ), method = "radix")
      alias_marker_path <- normalizePath(file.path(
        channel_root, paste0(
          "00000000000000000001-", seed$alias_release_id, ".json"
        )
      ), winslash = "/", mustWork = TRUE)
      release <- wlv13_json_read(release_path, simplify = FALSE)
      alias_marker <- wlv13_json_read(alias_marker_path, simplify = FALSE)
      child_marker <- if (length(marker_paths) == 2L) {
        wlv13_json_read(marker_paths[[2L]], simplify = FALSE)
      } else {
        NULL
      }
      child_release_path <- if (is.list(child_marker) &&
          is.character(child_marker$release_manifest_path) &&
          length(child_marker$release_manifest_path) == 1L &&
          !grepl("(^|[/\\])[.][.]($|[/\\])",
            child_marker$release_manifest_path)) {
        normalizePath(file.path(
          results_root, child_marker$release_manifest_path
        ), winslash = "/", mustWork = TRUE)
      } else {
        ""
      }
      child_release <- if (nzchar(child_release_path)) {
        wlv13_json_read(child_release_path, simplify = FALSE)
      } else {
        NULL
      }
      release_run <- if (is.list(release) &&
          is.list(release$runs) && length(release$runs) == 1L) {
        release$runs[[1L]]
      } else {
        NULL
      }
      child_run <- if (is.list(child_release) &&
          is.list(child_release$runs)) {
        matches <- Filter(function(value) {
          identical(value$method, seed$method)
        }, child_release$runs)
        if (length(matches) == 1L) matches[[1L]] else NULL
      } else {
        NULL
      }
      identical(wlv13_sha256_file(release_path),
          seed$alias_release_manifest_sha256) &&
        identical(wlv13_sha256_file(alias_marker_path),
          seed$alias_marker_sha256) && length(marker_paths) == 2L &&
        startsWith(basename(marker_paths[[2L]]),
          "00000000000000000002-") &&
        is.list(release_run) &&
        identical(release$release_id, seed$alias_release_id) &&
        identical(release$channel, seed$channel) &&
        identical(release$sequence, "00000000000000000001") &&
        identical(release_run$method, seed$method) &&
        identical(release_run$run_id, seed$parent_run_id) &&
        identical(alias_marker$release_id, seed$alias_release_id) &&
        identical(alias_marker$channel, seed$channel) &&
        identical(alias_marker$sequence, "00000000000000000001") &&
        is.list(child_run) &&
        identical(child_marker$channel, seed$channel) &&
        identical(child_marker$sequence, "00000000000000000002") &&
        identical(child_run$run_id,
          basename(row$baseline_target_run_root)) &&
        wlv13_is_within(child_release_path, results_root)
    }, error = function(error) FALSE)
  }
  seed_valid <- identical(seed_matrix, expected_matrix) &&
    all(vapply(seq_along(seeds), function(index) {
      seed <- seeds[[index]]
      row <- evidence[index, , drop = FALSE]
      reference <- references[[match(seed$method, reference_methods)]]
      identical(seed$role, "parent_alias") &&
        identical(seed$channel, paste0(
          "issue13-v5d-stage-", seed$at_stage, "-",
          gsub("_", "-", seed$method, fixed = TRUE)
        )) && identical(seed$parent_run_id, reference$run_id) &&
        identical(normalizePath(seed$child_run_root, winslash = "/",
          mustWork = TRUE), normalizePath(row$baseline_target_run_root,
          winslash = "/", mustWork = TRUE)) &&
        grepl("^release-v5d-parent-[A-Za-z0-9._-]+$",
          seed$alias_release_id) &&
        all(grepl(sha, unlist(seed[c(
          "alias_release_manifest_sha256", "alias_marker_sha256",
          "parent_verify_log_sha256", "run_log_sha256"
        )], use.names = FALSE))) && seed_publication_valid(seed, row)
    }, logical(1L)))
  if (!identical(reference_methods, wlv13_v5d_methods) ||
      !identical(observed_matrix, expected_matrix) || !record_hashes_valid ||
      !seed_valid ||
      any(vapply(references, function(record) {
        !identical(record$role, "baseline_reference") ||
          !identical(record$mode, "calculate") || nzchar(record$at_stage) ||
          nzchar(record$parent_run_id)
      }, logical(1L)))) {
    stop("Stage-five capture execution records are invalid.", call. = FALSE)
  }
  references_by_method <- stats::setNames(references, reference_methods)
  if (any(vapply(seq_along(targets), function(index) {
      target <- targets[[index]]
      seed <- seeds[[index]]
      reference <- references_by_method[[target$method]]
      row <- evidence[index, , drop = FALSE]
      !identical(target$role, "baseline_target") ||
        !identical(target$mode, "recalculate") ||
        !identical(target$parent_run_id, reference$run_id) ||
        !identical(target$commit, reference$commit) ||
        !identical(target$tree, reference$tree) ||
        !identical(target$source_sha256, reference$source_sha256) ||
        !identical(target$run_log_sha256, seed$run_log_sha256) ||
        !identical(target$scenario_id, paste0(
          "recalculate/stage-", target$at_stage, "/all/workers-1"
        )) || !identical(target$run_id,
          basename(row$baseline_target_run_root)) ||
        !identical(target$parent_run_id,
          basename(row$baseline_target_parent_run_root))
    }, logical(1L)))) {
    stop("Stage-five target records are not direct exact descendants.",
      call. = FALSE
    )
  }
  wlv13_sha256_file(stage_capture_path)
}

wlv13_v5d_stage5_capture_mutation_selftest <- function(
    bridge_capture_path, bridge_index_path, bridge_manifest_path,
    stage_capture_path, stage_index_path, evidence, harness_dir) {
  assertions <- 0L
  expect_error <- function(expression, label) {
    failed <- tryCatch({
      force(expression)
      FALSE
    }, error = function(error) TRUE)
    if (!failed) {
      stop(sprintf("Stage-five capture mutation passed: %s.", label),
        call. = FALSE
      )
    }
    assertions <<- assertions + 1L
  }
  original <- readLines(stage_capture_path, warn = FALSE, encoding = "UTF-8")
  temporary <- tempfile(
    pattern = "issue13-v5d-mutated-capture-",
    tmpdir = dirname(stage_capture_path), fileext = ".txt"
  )
  on.exit(unlink(temporary, force = TRUE), add = TRUE)
  validate_mutation <- function(lines, mutated_evidence = evidence) {
    writeLines(lines, temporary, sep = "\n", useBytes = TRUE)
    wlv13_v5d_validate_stage5_capture(
      bridge_capture_path, bridge_index_path, bridge_manifest_path,
      temporary, stage_index_path, mutated_evidence, harness_dir
    )
  }
  line_index <- function(pattern) {
    value <- grep(pattern, original)
    if (length(value) != 1L) {
      stop("Mutation self-test fixture is ambiguous.", call. = FALSE)
    }
    value
  }
  mutate_hash <- function(value) {
    paste0(substr(value, 1L, nchar(value) - 1L),
      if (endsWith(value, "0")) "1" else "0"
    )
  }
  mutate_field <- function(lines, index, field) {
    pattern <- paste0("(^|;)", field, "=([^;]*)")
    match <- regexec(pattern, lines[[index]], perl = TRUE)
    groups <- regmatches(lines[[index]], match)[[1L]]
    if (length(groups) != 3L) {
      stop("Mutation self-test field is missing.", call. = FALSE)
    }
    replacement <- paste0(groups[[2L]], field, "=", groups[[3L]], "0")
    lines[[index]] <- sub(pattern, replacement, lines[[index]], perl = TRUE)
    lines
  }

  mutation <- original
  mutation[[1L]] <- "schema=issue13-v5-clean-stage5-capture/forged"
  expect_error(validate_mutation(mutation), "schema")
  mutation <- original
  index <- line_index("^bridge_manifest_sha256=")
  mutation[[index]] <- paste0("bridge_manifest_sha256=", mutate_hash(
    sub("^[^=]*=", "", mutation[[index]])
  ))
  expect_error(validate_mutation(mutation), "bridge manifest hash")
  mutation <- original
  index <- line_index("^source_wiodr13_inventory_after_sha256=")
  mutation[[index]] <- paste0(
    "source_wiodr13_inventory_after_sha256=", mutate_hash(
      sub("^[^=]*=", "", mutation[[index]])
    )
  )
  expect_error(validate_mutation(mutation), "source inventory after")
  mutation <- original
  index <- line_index("^harness_inventory_sha256=")
  mutation[[index]] <- paste0("harness_inventory_sha256=", mutate_hash(
    sub("^[^=]*=", "", mutation[[index]])
  ))
  expect_error(validate_mutation(mutation), "harness inventory")
  mutation <- original
  index <- line_index("^rscript_sha256=")
  mutation[[index]] <- paste0("rscript_sha256=", mutate_hash(
    sub("^[^=]*=", "", mutation[[index]])
  ))
  expect_error(validate_mutation(mutation), "Rscript hash")
  recipe_index <- grep("^recipe_record;", original)[[1L]]
  expect_error(validate_mutation(mutate_field(
    original, recipe_index, "sha256"
  )), "recipe hash")
  expect_error(validate_mutation(original[-recipe_index]), "missing recipe")
  reference_indexes <- grep(
    "^evidence_record;role=baseline_reference;", original
  )
  mutation <- original
  mutation[reference_indexes[1:2]] <- mutation[rev(reference_indexes[1:2])]
  expect_error(validate_mutation(mutation), "reference order")
  seed_indexes <- grep("^seed_record;role=parent_alias;", original)
  expect_error(validate_mutation(original[-seed_indexes[[1L]]]),
    "missing seed record"
  )
  expect_error(validate_mutation(mutate_field(
    original, seed_indexes[[1L]], "parent_run_id"
  )), "seed parent")
  expect_error(validate_mutation(mutate_field(
    original, seed_indexes[[1L]], "channel"
  )), "seed channel")
  target_indexes <- grep(
    "^evidence_record;role=baseline_target;", original
  )
  mutation <- original
  mutation[target_indexes[1:2]] <- mutation[rev(target_indexes[1:2])]
  expect_error(validate_mutation(mutation), "target order")
  for (field in c("parent_run_id", "commit", "source_sha256", "run_id")) {
    expect_error(validate_mutation(mutate_field(
      original, target_indexes[[1L]], field
    )), paste0("target ", field))
  }
  expect_error(validate_mutation(original[-target_indexes[[1L]]]),
    "missing target record"
  )
  expect_error(validate_mutation(original, evidence[-1L, , drop = FALSE]),
    "missing evidence row"
  )
  expect_error(validate_mutation(
    original, rbind(evidence, evidence[1L, , drop = FALSE])
  ), "extra evidence row")
  reordered <- evidence[c(2L, 1L, seq.int(3L, nrow(evidence))), , drop = FALSE]
  expect_error(validate_mutation(original, reordered), "evidence row order")
  parent_mutation <- evidence
  parent_mutation$baseline_target_parent_run_root[[1L]] <-
    parent_mutation$baseline_target_run_root[[1L]]
  expect_error(validate_mutation(original, parent_mutation),
    "evidence target parent"
  )
  assertions
}

wlv13_v5d_stage5_normalized_keys <- function(
    value, profile, bridges, owner_contract, arm, mode) {
  columns <- wlv13_cross_engine_schema("_anomalies.csv")
  anomalies <- wlv13_v5d_normalize_table(
    wlv13_read_csv_semantic(value$anomalies$path), columns,
    paste(arm, "stage-five anomaly evidence")
  )
  stages <- wlv13_v5d_validate_anomaly_shape(
    anomalies, paste(arm, "stage-five anomaly evidence")
  )
  if (identical(arm, "candidate")) {
    resolution <- if (profile$expected_count > 0L) {
      if (is.null(value$nonfinite)) {
        stop("Candidate stage-five evidence lacks non-finite diagnostics.",
          call. = FALSE
        )
      }
      diagnostic <- wlv13_v5d_normalize_table(
        wlv13_read_csv_semantic(value$nonfinite$path),
        wlv13_cross_engine_schema(
          "_nonfinite_resolution_diagnostics.csv"
        ), "Candidate stage-five non-finite evidence"
      )
      wlv13_v5d_validate_nonfinite_value(
        diagnostic, profile$method, profile, anomalies
      )
    } else {
      list(
        passed = is.null(value$nonfinite),
        resolution_mask = rep(FALSE, nrow(anomalies))
      )
    }
    if (!isTRUE(resolution$passed)) {
      stop("Candidate stage-five non-finite evidence is invalid.",
        call. = FALSE
      )
    }
    keep <- if (identical(profile$action, "replace_nan_with_zero")) {
      rep(TRUE, nrow(anomalies))
    } else {
      !resolution$resolution_mask
    }
    anomalies <- anomalies[keep, , drop = FALSE]
    stages <- stages[keep]
    modules <- wlv13_v5d_normalize_baseline_anomaly_modules(
      anomalies, profile, bridges, "recalculate"
    )
    selected <- bridges[
      bridges$method == profile$method &
        bridges$artifact_name == "_anomalies.csv", , drop = FALSE
    ]
    if (modules$changed_rows != 0L ||
        modules$target_generation_rows != sum(as.integer(
          selected$expected_candidate_evidence_rows
        ))) {
      stop("Candidate stage-five owner generation is not exact.",
        call. = FALSE
      )
    }
    normalized <- anomalies
  } else {
    resolution <- wlv13_v5d_bridge_baseline_nonfinite(anomalies, profile)
    if (!isTRUE(resolution$passed)) {
      stop("Baseline stage-five non-finite evidence is invalid.",
        call. = FALSE
      )
    }
    policy <- wlv13_v5d_normalize_baseline_anomaly_policy(
      resolution$value, profile
    )
    modules <- wlv13_v5d_normalize_baseline_anomaly_modules(
      policy$value, profile, bridges, mode
    )
    if (!modules$coverage_complete || modules$target_generation_rows != 0L) {
      stop("Baseline stage-five bridge coverage is incomplete.",
        call. = FALSE
      )
    }
    normalized <- modules$value
  }
  wlv13_v5d_raw_row_keys(normalized[stages >= 5L, , drop = FALSE])
}

wlv13_v5d_generate_stage5_profiles <- function(
    evidence, contract_project_root, bridges, capture_record_sha256,
    output_path) {
  columns <- c(
    "method", "candidate_reference_project_root",
    "candidate_reference_run_root", "baseline_reference_project_root",
    "baseline_reference_run_root", "baseline_target_project_root",
    "baseline_target_parent_run_root", "baseline_target_run_root"
  )
  if (!is.data.frame(evidence) || !identical(names(evidence), columns) ||
      file.exists(output_path) ||
      !grepl("^[0-9a-f]{64}$", capture_record_sha256)) {
    stop("Invalid stage-five evidence index or output path.", call. = FALSE)
  }
  expected <- expand.grid(
    method = wlv13_v5d_methods, at_stage = as.character(c(1L, 4L, 5L)),
    stringsAsFactors = FALSE
  )
  observed <- vector("list", nrow(evidence))
  results <- vector("list", nrow(evidence))
  for (index in seq_len(nrow(evidence))) {
    method <- evidence$method[[index]]
    candidate <- wlv13_v5d_bridge_authenticate_run(
      evidence$candidate_reference_project_root[[index]],
      evidence$candidate_reference_run_root[[index]], method, "calculate"
    )
    baseline <- wlv13_v5d_bridge_authenticate_run(
      evidence$baseline_reference_project_root[[index]],
      evidence$baseline_reference_run_root[[index]], method, "calculate"
    )
    target <- wlv13_v5d_bridge_authenticate_run(
      evidence$baseline_target_project_root[[index]],
      evidence$baseline_target_run_root[[index]], method, "recalculate"
    )
    target_parent <- wlv13_v5d_bridge_authenticate_run(
      evidence$baseline_target_project_root[[index]],
      evidence$baseline_target_parent_run_root[[index]], method, "calculate"
    )
    if (!identical(target$parent_run_id, baseline$run_id) ||
        !identical(target$parent_run_id, target_parent$run_id) ||
        !identical(target$execution$sea_vars, character()) ||
        !target$execution$at_stage %in% c("1", "4", "5") ||
        target$execution$workers != 1L) {
      stop("Stage-five target is not an exact full recalculation.",
        call. = FALSE
      )
    }
    if (!wlv13_v5d_stage5_bridge_reference_binding(
        bridges, method, candidate, baseline
      )) {
      stop(paste0(
        "Stage-five references differ from the sealed diagnostic-bridge ",
        "evidence."
      ), call. = FALSE)
    }
    identity_fields <- c(
      "run_id", "commit", "tree", "source_sha256",
      "run_manifest_sha256", "run_inventory_sha256"
    )
    target_parent_identity <- vapply(identity_fields, function(field) {
      identical(target_parent[[field]], baseline[[field]])
    }, logical(1L))
    target_identity <- vapply(c("commit", "tree", "source_sha256"),
      function(field) identical(target[[field]], baseline[[field]]),
      logical(1L)
    )
    if (!all(target_parent_identity) || !all(target_identity) ||
        !identical(target_parent$anomalies$sha256,
          baseline$anomalies$sha256) ||
        !identical(target_parent$execution, baseline$execution)) {
      stop("Stage-five target is not derived from the sealed parent.",
        call. = FALSE
      )
    }
    reference_fields <- c(
      "method", "mode", "at_stage", "sea_vars_sha256", "workers",
      "request_sha256", "scenario_id"
    )
    if (!identical(
        candidate$execution[reference_fields],
        baseline$execution[reference_fields]
      ) || !identical(candidate$execution$mode, "calculate") ||
        !identical(candidate$execution$at_stage, "") ||
        !identical(candidate$execution$sea_vars, character()) ||
        !identical(candidate$execution$workers, 1L)) {
      stop("Stage-five calculate reference requests differ.",
        call. = FALSE
      )
    }
    historical_profile <- wlv13_v5d_scientific_profile_from_run(
      candidate, method
    )
    current_profile <- wlv13_v5d_scientific_profile_from_head(
      contract_project_root, method
    )
    profile <- historical_profile$profile
    if (!identical(profile, current_profile$profile)) {
      stop(paste0(
        "Historical and current scientific diagnostic profiles differ for `",
        method, "`."
      ), call. = FALSE)
    }
    owner_contract <- wlv13_v5d_candidate_owner_contract(
      contract_project_root, method
    )
    if (!wlv13_v5d_bridge_targets_valid(
        bridges, method, "_anomalies.csv", owner_contract
      )) {
      stop("Stage-five evidence bridge is not owned by the current DAG.",
        call. = FALSE
      )
    }
    candidate_keys <- wlv13_v5d_stage5_normalized_keys(
      candidate, profile, bridges, owner_contract, "candidate", "calculate"
    )
    baseline_keys <- wlv13_v5d_stage5_normalized_keys(
      baseline, profile, bridges, owner_contract, "baseline", "calculate"
    )
    target_keys <- wlv13_v5d_stage5_normalized_keys(
      target, profile, bridges, owner_contract, "baseline", "recalculate"
    )
    target_difference <- wlv13_v5d_stage5_difference(
      wlv13_v5d_stage5_counts(candidate_keys),
      wlv13_v5d_stage5_counts(target_keys)
    )
    results[[index]] <- if (target_difference$same_keys &&
        target_difference$exact) {
      NULL
    } else {
      wlv13_v5d_derive_stage5_profile(
        candidate_keys, baseline_keys, target_keys,
        candidate$execution, baseline$execution, target$execution,
        candidate$anomalies$sha256, baseline$anomalies$sha256,
        target$anomalies$sha256, wlv13_v5d_stage5_auth(candidate),
        wlv13_v5d_stage5_auth(baseline), wlv13_v5d_stage5_auth(target),
        capture_record_sha256
      )
    }
    observed[[index]] <- data.frame(
      method = method, at_stage = target$execution$at_stage,
      stringsAsFactors = FALSE, check.names = FALSE
    )
  }
  observed <- do.call(rbind, observed)
  if (nrow(observed) != nrow(expected) || anyDuplicated(observed) ||
      !identical(
        sort(wlv13_v5d_raw_row_keys(observed), method = "radix"),
        sort(wlv13_v5d_raw_row_keys(expected), method = "radix")
      )) {
    stop("Stage-five evidence lacks the exact 12 x 3 full matrix.",
      call. = FALSE
    )
  }
  results <- Filter(Negate(is.null), results)
  value <- if (length(results)) {
    do.call(rbind, results)
  } else {
    as.data.frame(stats::setNames(
      replicate(length(wlv13_v5d_stage5_profile_columns), character(),
        simplify = FALSE
      ), wlv13_v5d_stage5_profile_columns
    ), stringsAsFactors = FALSE, check.names = FALSE)
  }
  value <- value[order(
    match(value$method, wlv13_v5d_methods), as.integer(value$at_stage),
    method = "radix"
  ), wlv13_v5d_stage5_profile_columns, drop = FALSE]
  row.names(value) <- NULL
  output_directory <- normalizePath(dirname(output_path), winslash = "/",
    mustWork = TRUE
  )
  staging_path <- tempfile(
    pattern = "issue13-v5-stage5-profiles-", tmpdir = output_directory,
    fileext = ".csv"
  )
  on.exit(unlink(staging_path, force = TRUE), add = TRUE)
  utils::write.table(
    value, file = staging_path, sep = ";", row.names = FALSE,
    col.names = TRUE, quote = TRUE, qmethod = "double",
    fileEncoding = "UTF-8", eol = "\n"
  )
  reread <- wlv13_v5d_read_stage5_profiles(staging_path)
  if (!identical(value, reread)) {
    stop("Generated stage-five profiles failed their UTF-8 round trip.",
      call. = FALSE
    )
  }
  if (!file.rename(staging_path, output_path) || !file.exists(output_path)) {
    stop("Could not atomically promote the stage-five profile manifest.",
      call. = FALSE
    )
  }
  invisible(value)
}

wlv13_v5d_stage5_generator_main <- function(arguments = commandArgs(TRUE)) {
  if (!length(arguments)) return(invisible(NULL))
  if (length(arguments) != 8L) {
    stop(paste0(
      "Usage: Rscript issue13-v5-build-stage5-profiles.R ",
      "<harness-dir> <candidate-contract-root> <bridge-manifest.csv> ",
      "<bridge-capture-record.txt> <bridge-evidence-index.csv> ",
      "<stage5-capture-record.txt> <stage5-evidence-index.csv> ",
      "<new-output.csv>"
    ), call. = FALSE)
  }
  harness_dir <- normalizePath(arguments[[1L]], winslash = "/",
    mustWork = TRUE
  )
  contract_root <- normalizePath(arguments[[2L]], winslash = "/",
    mustWork = TRUE
  )
  bridge_path <- normalizePath(arguments[[3L]], winslash = "/",
    mustWork = TRUE
  )
  bridge_capture_path <- normalizePath(arguments[[4L]], winslash = "/",
    mustWork = TRUE
  )
  bridge_index_path <- normalizePath(arguments[[5L]], winslash = "/",
    mustWork = TRUE
  )
  stage_capture_path <- normalizePath(arguments[[6L]], winslash = "/",
    mustWork = TRUE
  )
  evidence_path <- normalizePath(arguments[[7L]], winslash = "/",
    mustWork = TRUE
  )
  script_path <- sub("^--file=", "", grep(
    "^--file=", commandArgs(FALSE), value = TRUE
  )[[1L]])
  script_dir <<- normalizePath(dirname(script_path), winslash = "/",
    mustWork = TRUE
  )
  source(file.path(harness_dir, "issue13-lib.R"))
  source(file.path(dirname(harness_dir), "issue13-prep-paper-lib.R"))
  source(file.path(harness_dir, "issue13-compare-lib.R"))
  source(file.path(script_dir, "issue13-v5-compare-override.R"))
  source(file.path(script_dir, "issue13-v5-diagnostics-override.R"))
  source(file.path(script_dir, "issue13-v5-build-diagnostic-bridges.R"))
  bridges <- wlv13_v5d_validate_bridge_manifest(
    wlv13_read_csv_semantic(bridge_path)
  )
  evidence <- wlv13_v5d_normalize_table(
    wlv13_read_csv_semantic(evidence_path),
    c(
      "method", "candidate_reference_project_root",
      "candidate_reference_run_root", "baseline_reference_project_root",
      "baseline_reference_run_root", "baseline_target_project_root",
      "baseline_target_parent_run_root", "baseline_target_run_root"
    ), "Stage-five evidence index"
  )
  capture_record_sha256 <- wlv13_v5d_validate_stage5_capture(
    bridge_capture_path, bridge_index_path, bridge_path,
    stage_capture_path, evidence_path, evidence, harness_dir
  )
  capture_assertions <- wlv13_v5d_stage5_capture_mutation_selftest(
    bridge_capture_path, bridge_index_path, bridge_path,
    stage_capture_path, evidence_path, evidence, harness_dir
  )
  if (!identical(capture_assertions, 21L)) {
    stop("Stage-five capture mutation self-test is incomplete.",
      call. = FALSE
    )
  }
  value <- wlv13_v5d_generate_stage5_profiles(
    evidence, contract_root, bridges, capture_record_sha256,
    arguments[[8L]]
  )
  cat(sprintf(
    "generated_rows=%d profiles_sha256=%s capture_assertions=%d\n",
    nrow(value), wlv13_sha256_file(arguments[[8L]]), capture_assertions
  ))
  invisible(value)
}

if (sys.nframe() == 0L) {
  wlv13_v5d_stage5_generator_main()
}
