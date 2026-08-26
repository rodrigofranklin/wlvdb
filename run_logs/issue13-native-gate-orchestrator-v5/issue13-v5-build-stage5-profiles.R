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
  records <- sort(records, method = "radix")
  wlv13_v5d_sha256_text(paste(records, collapse = "\n"))
}

wlv13_v5d_fsutil_call <- function(fsutil_path, operation, path) {
  if (!identical(.Platform$OS.type, "windows") ||
      length(fsutil_path) != 1L || !file.exists(fsutil_path) ||
      length(operation) != 2L || length(path) != 1L || !nzchar(path)) {
    stop("Physical snapshot inspection requires sealed Windows fsutil.",
      call. = FALSE
    )
  }
  output <- suppressWarnings(system2(
    fsutil_path,
    c(operation, shQuote(path, type = "cmd")),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(output, "status", exact = TRUE)
  if (is.null(status)) status <- 0L
  list(status = as.integer(status), output = enc2utf8(output))
}

wlv13_v5d_fsutil_file_id <- function(fsutil_path, path) {
  result <- wlv13_v5d_fsutil_call(
    fsutil_path, c("file", "queryfileid"), path
  )
  matches <- regmatches(result$output, gregexpr(
    "0x[0-9A-Fa-f]{32}", result$output, perl = TRUE
  ))
  values <- unique(tolower(substring(
    unlist(matches, use.names = FALSE), 3L
  )))
  if (result$status != 0L || length(values) != 1L ||
      !grepl("^[0-9a-f]{32}$", values[[1L]])) {
    stop("fsutil did not return one exact 128-bit file ID.",
      call. = FALSE
    )
  }
  values[[1L]]
}

wlv13_v5d_fsutil_assert_not_reparse <- function(fsutil_path, path) {
  result <- wlv13_v5d_fsutil_call(
    fsutil_path, c("reparsepoint", "query"), path
  )
  if (result$status != 1L) {
    stop("Physical snapshot contains or ambiguously traverses a reparse point.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

wlv13_v5d_fsutil_link_count <- function(fsutil_path, path) {
  result <- wlv13_v5d_fsutil_call(
    fsutil_path, c("hardlink", "list"), path
  )
  links <- trimws(result$output)
  links <- links[nzchar(links)]
  if (result$status != 0L || !length(links) ||
      any(!startsWith(links, "\\"))) {
    stop("fsutil did not return an exact hard-link inventory.",
      call. = FALSE
    )
  }
  as.integer(length(links))
}

wlv13_v5d_recorded_windows_path <- function(path, physical = FALSE) {
  if (length(path) != 1L || !nzchar(path)) {
    stop("Recorded physical snapshot path is empty.", call. = FALSE)
  }
  value <- gsub("/", "\\", path, fixed = TRUE)
  pattern <- if (physical) {
    "^\\\\\\\\\\?\\\\Volume\\{[0-9A-Fa-f-]+\\}\\\\"
  } else {
    "^[A-Za-z]:\\\\"
  }
  if (!grepl(pattern, value, perl = TRUE)) {
    stop("Recorded physical snapshot path is not absolute and local.",
      call. = FALSE
    )
  }
  value
}

wlv13_v5d_physical_volume <- function(path) {
  value <- wlv13_v5d_recorded_windows_path(path, physical = TRUE)
  match <- regexpr(
    "^\\\\\\\\\\?\\\\Volume\\{[0-9A-Fa-f-]+\\}\\\\",
    value, perl = TRUE
  )
  if (match[[1L]] != 1L) {
    stop("Recorded physical path lacks an exact Volume-GUID prefix.",
      call. = FALSE
    )
  }
  regmatches(value, match)
}

wlv13_v5d_physical_path_matches_lexical <- function(
    lexical_path, physical_path, volume) {
  lexical <- wlv13_v5d_recorded_windows_path(lexical_path)
  physical <- wlv13_v5d_recorded_windows_path(
    physical_path, physical = TRUE
  )
  if (!identical(wlv13_v5d_physical_volume(volume), volume)) {
    stop("Expected physical volume is not canonical.", call. = FALSE)
  }
  expected <- paste0(volume, substring(lexical, 4L))
  identical(tolower(physical), tolower(expected))
}

wlv13_v5d_physical_tree <- function(
    lexical_root, physical_root, fsutil_path) {
  lexical_root <- wlv13_v5d_recorded_windows_path(lexical_root)
  physical_root <- wlv13_v5d_recorded_windows_path(
    physical_root, physical = TRUE
  )
  physical_slash <- tolower(gsub("\\", "/", physical_root, fixed = TRUE))
  volume_match <- regexec(
    "^(//\\?/volume\\{[^}]+\\}/)", physical_slash, perl = TRUE
  )
  volume_parts <- regmatches(physical_slash, volume_match)[[1L]]
  if (length(volume_parts) != 2L || !dir.exists(lexical_root) ||
      !dir.exists(physical_root)) {
    stop("Physical snapshot roots are missing or lack a Volume-GUID path.",
      call. = FALSE
    )
  }
  volume <- volume_parts[[2L]]
  queue <- list(list(
    relative = ".", lexical = lexical_root, physical = physical_root
  ))
  records <- list()
  while (length(queue)) {
    current <- queue[[1L]]
    queue <- queue[-1L]
    wlv13_v5d_fsutil_assert_not_reparse(fsutil_path, current$lexical)
    wlv13_v5d_fsutil_assert_not_reparse(fsutil_path, current$physical)
    lexical_id <- wlv13_v5d_fsutil_file_id(fsutil_path, current$lexical)
    physical_id <- wlv13_v5d_fsutil_file_id(fsutil_path, current$physical)
    if (!identical(lexical_id, physical_id)) {
      stop("Lexical and Volume-GUID paths identify different items.",
        call. = FALSE
      )
    }
    information <- file.info(current$lexical)
    physical_information <- file.info(current$physical)
    lexical_is_directory <- information$isdir[[1L]]
    physical_is_directory <- physical_information$isdir[[1L]]
    if (nrow(information) != 1L || nrow(physical_information) != 1L ||
        anyNA(c(lexical_is_directory, physical_is_directory)) ||
        !identical(lexical_is_directory, physical_is_directory)) {
      stop("Physical snapshot item type is invalid.", call. = FALSE)
    }
    if (isTRUE(lexical_is_directory)) {
      line <- paste("D", current$relative, volume, lexical_id, sep = "|")
      children <- sort(list.files(
        current$lexical, all.files = TRUE, full.names = FALSE,
        no.. = TRUE
      ), method = "radix")
      for (child in children) {
        relative <- if (identical(current$relative, ".")) {
          child
        } else {
          paste(current$relative, child, sep = "/")
        }
        queue[[length(queue) + 1L]] <- list(
          relative = relative,
          lexical = file.path(current$lexical, child),
          physical = file.path(current$physical, child, fsep = "\\")
        )
      }
      link_count <- NA_integer_
    } else {
      link_count <- wlv13_v5d_fsutil_link_count(
        fsutil_path, current$lexical
      )
      physical_link_count <- wlv13_v5d_fsutil_link_count(
        fsutil_path, current$physical
      )
      if (!identical(link_count, physical_link_count)) {
        stop("Lexical and Volume-GUID hard-link counts differ.",
          call. = FALSE
        )
      }
      line <- paste(
        "F", current$relative, volume, lexical_id, link_count, sep = "|"
      )
    }
    records[[length(records) + 1L]] <- list(
      relative = current$relative,
      is_directory = isTRUE(lexical_is_directory),
      file_id = lexical_id,
      link_count = link_count,
      line = line
    )
  }
  order_index <- order(vapply(
    records, function(record) record$relative, character(1L)
  ), method = "radix")
  records <- records[order_index]
  lines <- vapply(records, function(record) record$line, character(1L))
  list(
    volume = volume,
    records = records,
    file_count = sum(!vapply(
      records, function(record) record$is_directory, logical(1L)
    )),
    directory_count = sum(vapply(
      records, function(record) record$is_directory, logical(1L)
    )) - 1L,
    physical_inventory_sha256 =
      wlv13_v5d_sha256_text(paste(lines, collapse = "\n"))
  )
}

wlv13_v5d_physical_snapshot_attest <- function(
    source_path, snapshot_path, source_physical_path,
    snapshot_physical_path, fsutil_path,
    expected_file_count = 84L, expected_directory_count = 5L) {
  source <- wlv13_v5d_physical_tree(
    source_path, source_physical_path, fsutil_path
  )
  snapshot <- wlv13_v5d_physical_tree(
    snapshot_path, snapshot_physical_path, fsutil_path
  )
  source_keys <- vapply(source$records, function(record) {
    paste(record$relative, record$is_directory, sep = "|")
  }, character(1L))
  snapshot_keys <- vapply(snapshot$records, function(record) {
    paste(record$relative, record$is_directory, sep = "|")
  }, character(1L))
  if (!identical(source$volume, snapshot$volume) ||
      !identical(source_keys, snapshot_keys) ||
      source$file_count != expected_file_count ||
      source$directory_count != expected_directory_count ||
      snapshot$file_count != expected_file_count ||
      snapshot$directory_count != expected_directory_count) {
    stop("Physical source and snapshot topology differs.", call. = FALSE)
  }
  independence <- vapply(seq_along(source$records), function(index) {
    source_record <- source$records[[index]]
    snapshot_record <- snapshot$records[[index]]
    if (identical(source_record$file_id, snapshot_record$file_id)) {
      stop("Snapshot reuses a source physical item.", call. = FALSE)
    }
    if (!snapshot_record$is_directory &&
        snapshot_record$link_count != 1L) {
      stop("Snapshot file has an external hard link.", call. = FALSE)
    }
    paste(
      source_record$relative,
      if (source_record$is_directory) "directory" else "file",
      paste0(source$volume, ":", source_record$file_id),
      paste0(snapshot$volume, ":", snapshot_record$file_id),
      sep = "|"
    )
  }, character(1L))
  list(
    file_count = source$file_count,
    directory_count = source$directory_count,
    source_physical_inventory_sha256 =
      source$physical_inventory_sha256,
    snapshot_physical_inventory_sha256 =
      snapshot$physical_inventory_sha256,
    independence_sha256 =
      wlv13_v5d_sha256_text(paste(independence, collapse = "\n"))
  )
}

wlv13_v5d_capture_external_inventories <- function(
    bridge_capture_path, harness_dir) {
  bridge_capture_path <- normalizePath(
    bridge_capture_path, winslash = "/", mustWork = TRUE
  )
  harness_dir <- normalizePath(
    harness_dir, winslash = "/", mustWork = TRUE
  )
  bridge_lines <- readLines(
    bridge_capture_path, warn = FALSE, encoding = "UTF-8"
  )
  r_library_path <- normalizePath(wlv13_v5d_capture_field(
    bridge_lines, "r_library_path"
  ), winslash = "/", mustWork = TRUE)
  harness_runtime_path <- normalizePath(wlv13_v5d_capture_field(
    bridge_lines, "harness_runtime_path"
  ), winslash = "/", mustWork = TRUE)
  windows_registry <- suppressWarnings(utils::readRegistry(
    "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
    hive = "HLM", maxdepth = 1L
  ))
  registry_system_root <- windows_registry[["SystemRoot"]]
  if (!is.character(registry_system_root) ||
      length(registry_system_root) != 1L ||
      !grepl("^[A-Za-z]:[/\\\\]", registry_system_root)) {
    stop("Windows registry lacks a canonical system-root identity.",
      call. = FALSE
    )
  }
  system_root <- normalizePath(
    registry_system_root, winslash = "/", mustWork = TRUE
  )
  fsutil_path <- normalizePath(file.path(
    system_root, "System32", "fsutil.exe"
  ), winslash = "/", mustWork = TRUE)
  recorded_fsutil_path <- normalizePath(wlv13_v5d_capture_field(
    bridge_lines, "fsutil_path"
  ), winslash = "/", mustWork = TRUE)
  if (!identical(tolower(recorded_fsutil_path), tolower(fsutil_path))) {
    stop("Capture record does not name canonical System32 fsutil.",
      call. = FALSE
    )
  }
  source_data_origin_record_path <- wlv13_v5d_capture_field(
    bridge_lines, "source_data_origin_path"
  )
  source_data_snapshot_record_path <- wlv13_v5d_capture_field(
    bridge_lines, "source_data_snapshot_path"
  )
  source_data_origin_path <- normalizePath(
    source_data_origin_record_path, winslash = "/", mustWork = TRUE
  )
  source_data_snapshot_path <- normalizePath(
    source_data_snapshot_record_path, winslash = "/", mustWork = TRUE
  )
  list(
    harness_path = harness_dir,
    harness_inventory_sha256 =
      wlv13_v5d_directory_inventory_sha256(harness_dir),
    harness_runtime_path = harness_runtime_path,
    harness_runtime_inventory_sha256 =
      wlv13_v5d_directory_inventory_sha256(harness_runtime_path),
    r_library_path = r_library_path,
    r_library_inventory_sha256 =
      wlv13_v5d_directory_inventory_sha256(r_library_path),
    fsutil_path = fsutil_path,
    fsutil_sha256 = wlv13_sha256_file(fsutil_path),
    source_data_origin_path = source_data_origin_path,
    source_data_origin_record_path = source_data_origin_record_path,
    source_data_origin_inventory_sha256 =
      wlv13_v5d_directory_inventory_sha256(source_data_origin_path),
    source_data_snapshot_path = source_data_snapshot_path,
    source_data_snapshot_record_path = source_data_snapshot_record_path,
    source_data_snapshot_inventory_sha256 =
      wlv13_v5d_directory_inventory_sha256(source_data_snapshot_path),
    source_data_origin_physical_path = wlv13_v5d_capture_field(
      bridge_lines, "source_data_origin_physical_path"
    ),
    source_data_snapshot_physical_path = wlv13_v5d_capture_field(
      bridge_lines, "source_data_snapshot_physical_path"
    )
  )
}

wlv13_v5d_validate_stage5_capture <- function(
    bridge_capture_path, bridge_index_path, bridge_manifest_path,
    stage_capture_path, stage_index_path, evidence, harness_dir,
    external_inventories, verify_live = TRUE) {
  if (!identical(verify_live, TRUE) && !identical(verify_live, FALSE)) {
    stop("Capture live-validation mode is invalid.", call. = FALSE)
  }
  requested_verify_live <- verify_live
  lockBinding("requested_verify_live", environment())
  official_source_inventory_sha256 <-
    "6c5e3c5583f431899658197484c4ebba3b1b1ee58b21b11f88fb1665084fbc4a"
  lockBinding("official_source_inventory_sha256", environment())
  live_checks <- stats::setNames(integer(6L), c(
    "bridge_physical", "stage_bridge_physical",
    "stage_snapshot_physical", "source_origin_content",
    "bridge_snapshot_content", "stage_snapshot_content"
  ))
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
  inventory_names <- c(
    "harness_path", "harness_inventory_sha256", "harness_runtime_path",
    "harness_runtime_inventory_sha256", "r_library_path",
    "r_library_inventory_sha256", "fsutil_path", "fsutil_sha256",
    "source_data_origin_path", "source_data_origin_record_path",
    "source_data_origin_inventory_sha256", "source_data_snapshot_path",
    "source_data_snapshot_record_path",
    "source_data_snapshot_inventory_sha256",
    "source_data_origin_physical_path",
    "source_data_snapshot_physical_path"
  )
  if (!is.list(external_inventories) ||
      !identical(names(external_inventories), inventory_names) ||
      !identical(
        external_inventories$source_data_origin_inventory_sha256,
        official_source_inventory_sha256
      ) ||
      !identical(external_inventories$harness_path, harness_dir) ||
      !identical(external_inventories$harness_runtime_path,
        dirname(harness_dir)) ||
      any(!grepl("^[0-9a-f]{64}$", unlist(external_inventories[c(
        "harness_inventory_sha256", "harness_runtime_inventory_sha256",
        "r_library_inventory_sha256", "fsutil_sha256",
        "source_data_origin_inventory_sha256",
        "source_data_snapshot_inventory_sha256"
      )], use.names = FALSE)))) {
    stop("Capture external inventory cache is invalid.", call. = FALSE)
  }
  bridge_lines <- readLines(
    bridge_capture_path, warn = FALSE, encoding = "UTF-8"
  )
  bridge_header <- c(
    "schema", "baseline_base_commit", "baseline_base_tree",
    "baseline_runtime_commit", "baseline_runtime_tree",
    "harness_path", "harness_inventory_sha256", "harness_runtime_path",
    "harness_runtime_inventory_before_sha256",
    "harness_runtime_inventory_after_sha256", "rscript_path",
    "rscript_sha256", "fsutil_path", "fsutil_sha256", "r_library_path",
    "r_library_inventory_before_sha256",
    "r_library_inventory_after_sha256", "tool_records", "baseline_worktree",
    "captured_methods", "verified_records",
    "seed_evidence_index_sha256", "source_data_origin_path",
    "source_data_snapshot_path",
    "source_data_origin_inventory_before_sha256",
    "source_data_origin_inventory_after_sha256",
    "source_data_snapshot_inventory_before_sha256",
    "source_data_snapshot_inventory_after_sha256",
    "source_data_origin_physical_path",
    "source_data_snapshot_physical_path",
    "source_data_physical_file_count",
    "source_data_physical_directory_count",
    "source_data_origin_physical_before_sha256",
    "source_data_origin_physical_after_sha256",
    "source_data_snapshot_physical_before_sha256",
    "source_data_snapshot_physical_after_sha256",
    "source_data_independence_before_sha256",
    "source_data_independence_after_sha256",
    "source_wiodr13_manifest_sha256",
    "source_wiodr16_manifest_sha256",
    "source_wiodr13_inventory_before_sha256",
    "source_wiodr13_inventory_after_sha256",
    "source_wiodr16_inventory_before_sha256",
    "source_wiodr16_inventory_after_sha256", "evidence_index",
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
    verified_records = "7", tool_records = "7"
  )
  bridge_fixed_valid <- all(vapply(names(bridge_fixed), function(key) {
    identical(wlv13_v5d_capture_field(bridge_lines, key),
      unname(bridge_fixed[[key]]))
  }, logical(1L)))
  bridge_rscript_path <- normalizePath(wlv13_v5d_capture_field(
    bridge_lines, "rscript_path"
  ), winslash = "/", mustWork = TRUE)
  bridge_fsutil_path <- normalizePath(wlv13_v5d_capture_field(
    bridge_lines, "fsutil_path"
  ), winslash = "/", mustWork = TRUE)
  bridge_r_library_path <- normalizePath(wlv13_v5d_capture_field(
    bridge_lines, "r_library_path"
  ), winslash = "/", mustWork = TRUE)
  bridge_r_library_hashes <- vapply(c(
    "r_library_inventory_before_sha256",
    "r_library_inventory_after_sha256"
  ), function(key) {
    wlv13_v5d_capture_field(bridge_lines, key)
  }, character(1L))
  bridge_harness_runtime_path <- normalizePath(wlv13_v5d_capture_field(
    bridge_lines, "harness_runtime_path"
  ), winslash = "/", mustWork = TRUE)
  bridge_harness_runtime_hashes <- vapply(c(
    "harness_runtime_inventory_before_sha256",
    "harness_runtime_inventory_after_sha256"
  ), function(key) {
    wlv13_v5d_capture_field(bridge_lines, key)
  }, character(1L))
  bridge_source_inventory_hashes <- vapply(c(
    "source_wiodr13_inventory_before_sha256",
    "source_wiodr13_inventory_after_sha256",
    "source_wiodr16_inventory_before_sha256",
    "source_wiodr16_inventory_after_sha256"
  ), function(key) {
    wlv13_v5d_capture_field(bridge_lines, key)
  }, character(1L))
  bridge_source_origin_record_path <- wlv13_v5d_capture_field(
    bridge_lines, "source_data_origin_path"
  )
  bridge_source_snapshot_record_path <- wlv13_v5d_capture_field(
    bridge_lines, "source_data_snapshot_path"
  )
  bridge_source_origin_path <- normalizePath(
    bridge_source_origin_record_path, winslash = "/", mustWork = TRUE
  )
  bridge_source_snapshot_path <- normalizePath(
    bridge_source_snapshot_record_path, winslash = "/", mustWork = TRUE
  )
  bridge_source_data_hashes <- vapply(c(
    "source_data_origin_inventory_before_sha256",
    "source_data_origin_inventory_after_sha256",
    "source_data_snapshot_inventory_before_sha256",
    "source_data_snapshot_inventory_after_sha256"
  ), function(key) {
    wlv13_v5d_capture_field(bridge_lines, key)
  }, character(1L))
  bridge_worktree <- normalizePath(wlv13_v5d_capture_field(
    bridge_lines, "baseline_worktree"
  ), winslash = "/", mustWork = TRUE)
  bridge_source_origin_physical_path <- wlv13_v5d_recorded_windows_path(
    wlv13_v5d_capture_field(
      bridge_lines, "source_data_origin_physical_path"
    ), physical = TRUE
  )
  bridge_source_snapshot_physical_path <- wlv13_v5d_recorded_windows_path(
    wlv13_v5d_capture_field(
      bridge_lines, "source_data_snapshot_physical_path"
    ), physical = TRUE
  )
  bridge_physical_volume <- wlv13_v5d_physical_volume(
    bridge_source_origin_physical_path
  )
  bridge_physical_hashes <- vapply(c(
    "source_data_origin_physical_before_sha256",
    "source_data_origin_physical_after_sha256",
    "source_data_snapshot_physical_before_sha256",
    "source_data_snapshot_physical_after_sha256",
    "source_data_independence_before_sha256",
    "source_data_independence_after_sha256"
  ), function(key) {
    wlv13_v5d_capture_field(bridge_lines, key)
  }, character(1L))
  bridge_fsutil_bound <-
    identical(tolower(bridge_fsutil_path),
      tolower(external_inventories$fsutil_path)) &&
    identical(wlv13_v5d_capture_field(
      bridge_lines, "fsutil_sha256"
    ), external_inventories$fsutil_sha256) &&
    identical(wlv13_sha256_file(bridge_fsutil_path),
      external_inventories$fsutil_sha256)
  if (!bridge_fsutil_bound) {
    stop("Bridge capture fsutil is not independently authenticated.",
      call. = FALSE
    )
  }
  bridge_live_physical <- if (requested_verify_live) {
    value <- wlv13_v5d_physical_snapshot_attest(
      bridge_source_origin_record_path,
      bridge_source_snapshot_record_path,
      bridge_source_origin_physical_path,
      bridge_source_snapshot_physical_path,
      bridge_fsutil_path
    )
    live_checks[["bridge_physical"]] <-
      live_checks[["bridge_physical"]] + 1L
    value
  } else {
    NULL
  }
  bridge_physical_valid <-
    identical(
      wlv13_v5d_physical_volume(bridge_source_snapshot_physical_path),
      bridge_physical_volume
    ) && wlv13_v5d_physical_path_matches_lexical(
      bridge_source_origin_record_path,
      bridge_source_origin_physical_path,
      bridge_physical_volume
    ) && wlv13_v5d_physical_path_matches_lexical(
      bridge_source_snapshot_record_path,
      bridge_source_snapshot_physical_path,
      bridge_physical_volume
    ) &&
    identical(
      bridge_source_origin_physical_path,
      wlv13_v5d_recorded_windows_path(
        external_inventories$source_data_origin_physical_path,
        physical = TRUE
      )
    ) && identical(
      bridge_source_snapshot_physical_path,
      wlv13_v5d_recorded_windows_path(
        external_inventories$source_data_snapshot_physical_path,
        physical = TRUE
      )
    ) && identical(wlv13_v5d_capture_field(
      bridge_lines, "source_data_physical_file_count"
    ), "84") && identical(wlv13_v5d_capture_field(
      bridge_lines, "source_data_physical_directory_count"
    ), "5") && all(grepl("^[0-9a-f]{64}$", bridge_physical_hashes)) &&
    identical(bridge_physical_hashes[[1L]], bridge_physical_hashes[[2L]]) &&
    identical(bridge_physical_hashes[[3L]], bridge_physical_hashes[[4L]]) &&
    identical(bridge_physical_hashes[[5L]], bridge_physical_hashes[[6L]]) &&
    (!requested_verify_live || (
      identical(bridge_live_physical$file_count, 84L) &&
      identical(bridge_live_physical$directory_count, 5L) &&
      identical(
        bridge_live_physical$source_physical_inventory_sha256,
        bridge_physical_hashes[[1L]]
      ) && identical(
        bridge_live_physical$snapshot_physical_inventory_sha256,
        bridge_physical_hashes[[3L]]
      ) && identical(
        bridge_live_physical$independence_sha256,
        bridge_physical_hashes[[5L]]
      )
    ))
  bridge_tooling_valid <-
    identical(wlv13_v5d_capture_field(
      bridge_lines, "harness_path"
    ), harness_dir) &&
    identical(wlv13_v5d_capture_field(
      bridge_lines, "harness_inventory_sha256"
    ), external_inventories$harness_inventory_sha256) &&
    identical(bridge_harness_runtime_path,
      external_inventories$harness_runtime_path) &&
    all(grepl("^[0-9a-f]{64}$", bridge_harness_runtime_hashes)) &&
    all(bridge_harness_runtime_hashes ==
      external_inventories$harness_runtime_inventory_sha256) &&
    identical(wlv13_v5d_capture_field(
      bridge_lines, "rscript_sha256"
    ), wlv13_sha256_file(bridge_rscript_path)) &&
    identical(bridge_fsutil_path, external_inventories$fsutil_path) &&
    identical(wlv13_v5d_capture_field(
      bridge_lines, "fsutil_sha256"
    ), external_inventories$fsutil_sha256) &&
    identical(wlv13_v5d_capture_field(
      bridge_lines, "fsutil_sha256"
    ), wlv13_sha256_file(bridge_fsutil_path)) &&
    identical(bridge_r_library_path,
      external_inventories$r_library_path) &&
    all(grepl("^[0-9a-f]{64}$", bridge_r_library_hashes)) &&
    all(bridge_r_library_hashes ==
      external_inventories$r_library_inventory_sha256) &&
    identical(bridge_source_origin_path,
      external_inventories$source_data_origin_path) &&
    identical(bridge_source_snapshot_path,
      external_inventories$source_data_snapshot_path) &&
    identical(bridge_source_snapshot_path, normalizePath(file.path(
      bridge_worktree, "source_data"
    ), winslash = "/", mustWork = TRUE)) &&
    !identical(bridge_source_origin_path, bridge_source_snapshot_path) &&
    all(grepl("^[0-9a-f]{64}$", bridge_source_data_hashes)) &&
    all(bridge_source_data_hashes == bridge_source_data_hashes[[1L]]) &&
    identical(bridge_source_data_hashes[[1L]],
      external_inventories$source_data_origin_inventory_sha256) &&
    identical(bridge_source_data_hashes[[3L]],
      external_inventories$source_data_snapshot_inventory_sha256) &&
    all(grepl("^[0-9a-f]{64}$", bridge_source_inventory_hashes)) &&
    identical(bridge_source_inventory_hashes[[1L]],
      bridge_source_inventory_hashes[[2L]]) &&
    identical(bridge_source_inventory_hashes[[3L]],
      bridge_source_inventory_hashes[[4L]])
  if (length(bridge_lines) != length(bridge_header) + 7L + 7L ||
      !identical(bridge_keys, bridge_header) ||
      !identical(bridge_lines[[1L]],
        "schema=issue13-v5-clean-bridge-capture/2") ||
      !bridge_fixed_valid || !bridge_tooling_valid ||
      !bridge_physical_valid ||
      length(bridge_tool_lines) != 7L || length(bridge_records) != 7L ||
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
    "coordinator_library", "diagnostics_override", "metadata_equivalence",
    "verifier"
  )
  bridge_tool_files <- stats::setNames(c(
    "issue13-v5-build-diagnostic-bridges.R",
    "issue13-v5-capture-clean-bridge-evidence.ps1",
    "issue13-v5-compare-override.R",
    "issue13-v5-coordinator-lib.ps1",
    "issue13-v5-diagnostics-override.R",
    "issue13-v5-metadata-equivalence.json",
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
    "harness_inventory_sha256", "harness_runtime_path",
    "harness_runtime_inventory_before_sha256",
    "harness_runtime_inventory_after_sha256", "rscript_path", "rscript_sha256",
    "fsutil_path", "fsutil_sha256", "r_library_path",
    "r_library_inventory_before_sha256",
    "r_library_inventory_after_sha256", "methods", "stages",
    "bridge_capture_record_sha256",
    "bridge_evidence_index_sha256", "bridge_manifest_sha256",
    "stage5_evidence_index_sha256",
    "source_data_origin_path",
    "source_data_origin_inventory_before_sha256",
    "source_data_origin_inventory_after_sha256",
    "bridge_source_data_snapshot_path",
    "bridge_source_data_snapshot_inventory_before_sha256",
    "bridge_source_data_snapshot_inventory_after_sha256",
    "source_data_origin_physical_path",
    "source_data_physical_file_count",
    "source_data_physical_directory_count",
    "source_data_origin_physical_before_sha256",
    "source_data_origin_physical_after_sha256",
    "bridge_source_data_snapshot_physical_path",
    "bridge_source_data_snapshot_physical_before_sha256",
    "bridge_source_data_snapshot_physical_after_sha256",
    "bridge_source_data_independence_before_sha256",
    "bridge_source_data_independence_after_sha256",
    "source_wiodr13_inventory_before_sha256",
    "source_wiodr13_inventory_after_sha256",
    "source_wiodr16_inventory_before_sha256",
    "source_wiodr16_inventory_after_sha256", "recipe_records",
    "reference_records", "seed_records", "target_records",
    "worktree_records", "source_snapshot_records"
  )
  stage_keys <- sub("=.*$", "", stage_lines[seq_along(stage_header)])
  recipe_lines <- grep("^recipe_record;", stage_lines, value = TRUE)
  worktree_lines <- grep("^worktree_record;", stage_lines, value = TRUE)
  source_snapshot_lines <- grep(
    "^source_snapshot_record;", stage_lines, value = TRUE
  )
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
    recipe_records = "10", reference_records = "12",
    seed_records = "36", target_records = "36",
    worktree_records = "6", source_snapshot_records = "6"
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
    identical(inventory_hashes[[3L]], inventory_hashes[[4L]]) &&
    identical(inventory_hashes[[1L]],
      bridge_source_inventory_hashes[[1L]]) &&
    identical(inventory_hashes[[3L]],
      bridge_source_inventory_hashes[[3L]])
  stage_source_origin_record_path <- wlv13_v5d_capture_field(
    stage_lines, "source_data_origin_path"
  )
  stage_source_origin_path <- normalizePath(
    stage_source_origin_record_path, winslash = "/", mustWork = TRUE
  )
  stage_bridge_source_snapshot_record_path <- wlv13_v5d_capture_field(
    stage_lines, "bridge_source_data_snapshot_path"
  )
  stage_bridge_source_snapshot_path <- normalizePath(
    stage_bridge_source_snapshot_record_path,
    winslash = "/", mustWork = TRUE
  )
  stage_source_data_hashes <- vapply(c(
    "source_data_origin_inventory_before_sha256",
    "source_data_origin_inventory_after_sha256",
    "bridge_source_data_snapshot_inventory_before_sha256",
    "bridge_source_data_snapshot_inventory_after_sha256"
  ), function(key) {
    wlv13_v5d_capture_field(stage_lines, key)
  }, character(1L))
  stage_live_source_content_valid <- if (requested_verify_live) {
    live_origin_hash <- wlv13_v5d_directory_inventory_sha256(
      stage_source_origin_path
    )
    live_checks[["source_origin_content"]] <-
      live_checks[["source_origin_content"]] + 1L
    live_bridge_hash <- wlv13_v5d_directory_inventory_sha256(
      stage_bridge_source_snapshot_path
    )
    live_checks[["bridge_snapshot_content"]] <-
      live_checks[["bridge_snapshot_content"]] + 1L
    identical(
      live_origin_hash,
      external_inventories$source_data_origin_inventory_sha256
    ) && identical(
      live_bridge_hash,
      external_inventories$source_data_snapshot_inventory_sha256
    )
  } else {
    TRUE
  }
  source_data_valid <-
    identical(stage_source_origin_record_path,
      bridge_source_origin_record_path) &&
    identical(stage_bridge_source_snapshot_record_path,
      bridge_source_snapshot_record_path) &&
    identical(stage_source_origin_path, bridge_source_origin_path) &&
    identical(stage_source_origin_path,
      external_inventories$source_data_origin_path) &&
    identical(stage_bridge_source_snapshot_path,
      bridge_source_snapshot_path) &&
    identical(stage_bridge_source_snapshot_path,
      external_inventories$source_data_snapshot_path) &&
    !identical(stage_source_origin_path,
      stage_bridge_source_snapshot_path) &&
    all(grepl(sha, stage_source_data_hashes)) &&
    all(stage_source_data_hashes == stage_source_data_hashes[[1L]]) &&
    identical(stage_source_data_hashes[[1L]],
      external_inventories$source_data_origin_inventory_sha256) &&
    identical(stage_source_data_hashes[[3L]],
      external_inventories$source_data_snapshot_inventory_sha256) &&
    stage_live_source_content_valid
  stage_rscript_path <- normalizePath(wlv13_v5d_capture_field(
    stage_lines, "rscript_path"
  ), winslash = "/", mustWork = TRUE)
  stage_fsutil_path <- normalizePath(wlv13_v5d_capture_field(
    stage_lines, "fsutil_path"
  ), winslash = "/", mustWork = TRUE)
  stage_r_library_path <- normalizePath(wlv13_v5d_capture_field(
    stage_lines, "r_library_path"
  ), winslash = "/", mustWork = TRUE)
  stage_r_library_hashes <- vapply(c(
    "r_library_inventory_before_sha256",
    "r_library_inventory_after_sha256"
  ), function(key) {
    wlv13_v5d_capture_field(stage_lines, key)
  }, character(1L))
  stage_harness_runtime_path <- normalizePath(wlv13_v5d_capture_field(
    stage_lines, "harness_runtime_path"
  ), winslash = "/", mustWork = TRUE)
  stage_harness_runtime_hashes <- vapply(c(
    "harness_runtime_inventory_before_sha256",
    "harness_runtime_inventory_after_sha256"
  ), function(key) {
    wlv13_v5d_capture_field(stage_lines, key)
  }, character(1L))
  stage_source_origin_physical_path <- wlv13_v5d_recorded_windows_path(
    wlv13_v5d_capture_field(
      stage_lines, "source_data_origin_physical_path"
    ), physical = TRUE
  )
  stage_bridge_source_snapshot_physical_path <-
    wlv13_v5d_recorded_windows_path(wlv13_v5d_capture_field(
      stage_lines, "bridge_source_data_snapshot_physical_path"
    ), physical = TRUE)
  stage_bridge_physical_hashes <- vapply(c(
    "source_data_origin_physical_before_sha256",
    "source_data_origin_physical_after_sha256",
    "bridge_source_data_snapshot_physical_before_sha256",
    "bridge_source_data_snapshot_physical_after_sha256",
    "bridge_source_data_independence_before_sha256",
    "bridge_source_data_independence_after_sha256"
  ), function(key) {
    wlv13_v5d_capture_field(stage_lines, key)
  }, character(1L))
  stage_fsutil_bound <-
    identical(tolower(stage_fsutil_path),
      tolower(external_inventories$fsutil_path)) &&
    identical(tolower(stage_fsutil_path), tolower(bridge_fsutil_path)) &&
    identical(wlv13_v5d_capture_field(
      stage_lines, "fsutil_sha256"
    ), external_inventories$fsutil_sha256) &&
    identical(wlv13_sha256_file(stage_fsutil_path),
      external_inventories$fsutil_sha256)
  if (!stage_fsutil_bound) {
    stop("Stage capture fsutil is not independently authenticated.",
      call. = FALSE
    )
  }
  stage_live_bridge_physical <- if (requested_verify_live) {
    value <- wlv13_v5d_physical_snapshot_attest(
      stage_source_origin_record_path,
      stage_bridge_source_snapshot_record_path,
      stage_source_origin_physical_path,
      stage_bridge_source_snapshot_physical_path,
      stage_fsutil_path
    )
    live_checks[["stage_bridge_physical"]] <-
      live_checks[["stage_bridge_physical"]] + 1L
    value
  } else {
    NULL
  }
  stage_bridge_physical_valid <-
    identical(wlv13_v5d_physical_volume(
      stage_source_origin_physical_path
    ), bridge_physical_volume) &&
    identical(wlv13_v5d_physical_volume(
      stage_bridge_source_snapshot_physical_path
    ), bridge_physical_volume) &&
    wlv13_v5d_physical_path_matches_lexical(
      stage_source_origin_record_path,
      stage_source_origin_physical_path,
      bridge_physical_volume
    ) && wlv13_v5d_physical_path_matches_lexical(
      stage_bridge_source_snapshot_record_path,
      stage_bridge_source_snapshot_physical_path,
      bridge_physical_volume
    ) &&
    identical(stage_source_origin_physical_path,
      bridge_source_origin_physical_path) &&
    identical(stage_bridge_source_snapshot_physical_path,
      bridge_source_snapshot_physical_path) &&
    identical(wlv13_v5d_capture_field(
      stage_lines, "source_data_physical_file_count"
    ), "84") && identical(wlv13_v5d_capture_field(
      stage_lines, "source_data_physical_directory_count"
    ), "5") && all(grepl(sha, stage_bridge_physical_hashes)) &&
    identical(stage_bridge_physical_hashes, bridge_physical_hashes) &&
    identical(stage_bridge_physical_hashes[[1L]],
      stage_bridge_physical_hashes[[2L]]) &&
    identical(stage_bridge_physical_hashes[[3L]],
      stage_bridge_physical_hashes[[4L]]) &&
    identical(stage_bridge_physical_hashes[[5L]],
      stage_bridge_physical_hashes[[6L]]) &&
    (!requested_verify_live || (
      identical(stage_live_bridge_physical$file_count, 84L) &&
      identical(stage_live_bridge_physical$directory_count, 5L) &&
      identical(
        stage_live_bridge_physical$source_physical_inventory_sha256,
        stage_bridge_physical_hashes[[1L]]
      ) && identical(
        stage_live_bridge_physical$snapshot_physical_inventory_sha256,
        stage_bridge_physical_hashes[[3L]]
      ) && identical(
        stage_live_bridge_physical$independence_sha256,
        stage_bridge_physical_hashes[[5L]]
      )
    ))
  tooling_valid <- identical(wlv13_v5d_capture_field(
      stage_lines, "harness_path"
    ), harness_dir) &&
    identical(wlv13_v5d_capture_field(
      stage_lines, "harness_inventory_sha256"
    ), external_inventories$harness_inventory_sha256) &&
    identical(stage_harness_runtime_path,
      external_inventories$harness_runtime_path) &&
    identical(stage_harness_runtime_path, bridge_harness_runtime_path) &&
    all(grepl(sha, stage_harness_runtime_hashes)) &&
    all(stage_harness_runtime_hashes ==
      external_inventories$harness_runtime_inventory_sha256) &&
    identical(stage_harness_runtime_hashes,
      bridge_harness_runtime_hashes) &&
    identical(wlv13_v5d_capture_field(
      stage_lines, "rscript_path"
    ), wlv13_v5d_capture_field(bridge_lines, "rscript_path")) &&
    identical(wlv13_v5d_capture_field(
      stage_lines, "rscript_sha256"
    ), wlv13_sha256_file(stage_rscript_path)) &&
    identical(wlv13_v5d_capture_field(
      stage_lines, "rscript_sha256"
    ), wlv13_v5d_capture_field(bridge_lines, "rscript_sha256")) &&
    identical(stage_fsutil_path, external_inventories$fsutil_path) &&
    identical(stage_fsutil_path, bridge_fsutil_path) &&
    identical(wlv13_v5d_capture_field(
      stage_lines, "fsutil_sha256"
    ), external_inventories$fsutil_sha256) &&
    identical(wlv13_v5d_capture_field(
      stage_lines, "fsutil_sha256"
    ), wlv13_sha256_file(stage_fsutil_path)) &&
    identical(wlv13_v5d_capture_field(
      stage_lines, "fsutil_sha256"
    ), wlv13_v5d_capture_field(bridge_lines, "fsutil_sha256")) &&
    identical(stage_r_library_path,
      external_inventories$r_library_path) &&
    identical(stage_r_library_path, bridge_r_library_path) &&
    all(grepl(sha, stage_r_library_hashes)) &&
    all(stage_r_library_hashes ==
      external_inventories$r_library_inventory_sha256) &&
    identical(stage_r_library_hashes, bridge_r_library_hashes)
  if (length(stage_lines) !=
        length(stage_header) + 10L + 6L + 6L + 12L + 36L + 36L ||
      !identical(stage_keys, stage_header) ||
      !identical(stage_lines[[1L]],
        "schema=issue13-v5-clean-stage5-capture/2") ||
      !fixed_valid || !hash_valid || !inventory_valid || !source_data_valid ||
      !stage_bridge_physical_valid || !tooling_valid ||
      length(recipe_lines) != 10L || length(worktree_lines) != 6L ||
      length(source_snapshot_lines) != 6L ||
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
    "coordinator_library", "diagnostics_override", "launcher",
    "metadata_equivalence", "stage5_builder", "stage5_capture_script",
    "verifier"
  )
  recipe_files <- stats::setNames(c(
    "issue13-v5-build-diagnostic-bridges.R",
    "issue13-v5-capture-clean-bridge-evidence.ps1",
    "issue13-v5-compare-override.R",
    "issue13-v5-coordinator-lib.ps1",
    "issue13-v5-diagnostics-override.R",
    "issue13-v5-run-stage5-evidence.R",
    "issue13-v5-metadata-equivalence.json",
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
  source_snapshots <- lapply(source_snapshot_lines, function(line) {
    wlv13_v5d_capture_semicolon_record(
      line, "source_snapshot_record",
      c(
        "key", "path", "physical_path", "file_count", "directory_count",
        "inventory_before_sha256", "inventory_after_sha256",
        "physical_before_sha256", "physical_after_sha256",
        "independence_before_sha256", "independence_after_sha256"
      )
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
      vapply(worktrees, `[[`, character(1L), "key"),
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
  worktree_paths <- stats::setNames(
    vapply(worktrees, function(record) record$path, character(1L)),
    vapply(worktrees, function(record) record$key, character(1L))
  )
  source_snapshot_keys <- vapply(
    source_snapshots, function(record) record$key, character(1L)
  )
  source_snapshot_physical_paths <- vapply(
    source_snapshots, function(record) {
      wlv13_v5d_recorded_windows_path(record$physical_path, physical = TRUE)
    }, character(1L)
  )
  if (!identical(source_snapshot_keys, expected_worktree_keys) ||
      anyDuplicated(tolower(source_snapshot_physical_paths)) ||
      any(vapply(source_snapshots, function(record) {
        record_path_raw <- record$path
        record_path <- normalizePath(
          record_path_raw, winslash = "/", mustWork = TRUE
        )
        expected_path <- normalizePath(file.path(
          worktree_paths[[record$key]], "source_data"
        ), winslash = "/", mustWork = TRUE)
        record_physical_path <- wlv13_v5d_recorded_windows_path(
          record$physical_path, physical = TRUE
        )
        live_physical <- if (requested_verify_live) {
          value <- wlv13_v5d_physical_snapshot_attest(
            stage_source_origin_record_path, record_path_raw,
            stage_source_origin_physical_path, record_physical_path,
            stage_fsutil_path
          )
          live_checks[["stage_snapshot_physical"]] <<-
            live_checks[["stage_snapshot_physical"]] + 1L
          value
        } else {
          NULL
        }
        live_inventory_valid <- if (requested_verify_live) {
          value <- identical(
            wlv13_v5d_directory_inventory_sha256(record_path),
            record$inventory_before_sha256
          )
          live_checks[["stage_snapshot_content"]] <<-
            live_checks[["stage_snapshot_content"]] + 1L
          value
        } else {
          TRUE
        }
        !identical(record_path, expected_path) ||
          identical(record_path, stage_source_origin_path) ||
          identical(record_path, stage_bridge_source_snapshot_path) ||
          !identical(wlv13_v5d_physical_volume(record_physical_path),
            bridge_physical_volume) ||
          !wlv13_v5d_physical_path_matches_lexical(
            record_path_raw, record_physical_path, bridge_physical_volume
          ) ||
          identical(tolower(record_physical_path),
            tolower(stage_source_origin_physical_path)) ||
          identical(tolower(record_physical_path),
            tolower(stage_bridge_source_snapshot_physical_path)) ||
          !identical(record$file_count, "84") ||
          !identical(record$directory_count, "5") ||
          !grepl(sha, record$inventory_before_sha256) ||
          !identical(
            record$inventory_before_sha256,
            record$inventory_after_sha256
          ) ||
          !identical(
            record$inventory_before_sha256,
            stage_source_data_hashes[[1L]]
          ) ||
          !grepl(sha, record$physical_before_sha256) ||
          !identical(record$physical_before_sha256,
            record$physical_after_sha256) ||
          !grepl(sha, record$independence_before_sha256) ||
          !identical(record$independence_before_sha256,
            record$independence_after_sha256) ||
          !live_inventory_valid ||
          (requested_verify_live && (
            !identical(live_physical$file_count, 84L) ||
            !identical(live_physical$directory_count, 5L) ||
            !identical(
              live_physical$source_physical_inventory_sha256,
              stage_bridge_physical_hashes[[1L]]
            ) || !identical(
              live_physical$snapshot_physical_inventory_sha256,
              record$physical_before_sha256
            ) || !identical(
              live_physical$independence_sha256,
              record$independence_before_sha256
            )
          ))
      }, logical(1L)))) {
    stop("Stage-five source-data snapshots are not physical exact copies.",
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
  expected_live_checks <- if (requested_verify_live) {
    stats::setNames(c(1L, 1L, 6L, 1L, 1L, 6L), names(live_checks))
  } else {
    stats::setNames(integer(6L), names(live_checks))
  }
  if (!identical(live_checks, expected_live_checks)) {
    stop("Stage-five capture live-check canary is incomplete.",
      call. = FALSE
    )
  }
  wlv13_sha256_file(stage_capture_path)
}

wlv13_v5d_live_validation_structure_selftest <- function() {
  calls_in <- function(expression) {
    value <- list()
    visit <- function(node) {
      if (is.call(node)) {
        value[[length(value) + 1L]] <<- node
        children <- as.list(node)[-1L]
      } else if (is.expression(node) || is.pairlist(node) || is.list(node)) {
        children <- as.list(node)
      } else {
        return(invisible(NULL))
      }
      invisible(lapply(children, visit))
      invisible(NULL)
    }
    visit(expression)
    value
  }
  call_head <- function(call) {
    if (is.call(call) && is.symbol(call[[1L]])) {
      as.character(call[[1L]])
    } else {
      ""
    }
  }
  assertions <- 0L
  assert <- function(value, message) {
    if (!isTRUE(value)) stop(message, call. = FALSE)
    assertions <<- assertions + 1L
    invisible(NULL)
  }
  validator <- wlv13_v5d_validate_stage5_capture
  validator_calls <- calls_in(body(validator))
  validator_heads <- vapply(validator_calls, call_head, character(1L))
  assert(identical(formals(validator)$verify_live, TRUE),
    "Capture validator live-mode default changed."
  )
  assignment_base <- function(lhs) {
    while (is.call(lhs) && call_head(lhs) %in% c("[", "[[", "$", "@")) {
      lhs <- lhs[[2L]]
    }
    if (is.symbol(lhs)) as.character(lhs) else ""
  }
  assignments <- validator_calls[validator_heads %in% c("<-", "<<-", "=")]
  requested_assignments <- Filter(function(call) {
    assignment_base(call[[2L]]) %in%
      c("verify_live", "requested_verify_live")
  }, assignments)
  official_assignments <- Filter(function(call) {
    identical(assignment_base(call[[2L]]),
      "official_source_inventory_sha256")
  }, assignments)
  validator_body <- body(validator)
  lock_probe <- new.env(parent = emptyenv())
  lock_probe$requested_verify_live <- TRUE
  lockBinding("requested_verify_live", lock_probe)
  lock_rejects_subassignment <- tryCatch({
    lock_probe$requested_verify_live[] <- FALSE
    FALSE
  }, error = function(error) TRUE)
  assert(length(requested_assignments) == 1L &&
      identical(as.character(requested_assignments[[1L]][[2L]]),
        "requested_verify_live") &&
      identical(requested_assignments[[1L]][[3L]], as.name("verify_live")) &&
      identical(validator_body[[3L]],
        quote(requested_verify_live <- verify_live)) &&
      identical(validator_body[[4L]],
        quote(lockBinding("requested_verify_live", environment()))) &&
      length(official_assignments) == 1L &&
      identical(validator_body[[5L]], quote(
        official_source_inventory_sha256 <-
          "6c5e3c5583f431899658197484c4ebba3b1b1ee58b21b11f88fb1665084fbc4a"
      )) && identical(validator_body[[6L]], quote(
        lockBinding("official_source_inventory_sha256", environment())
      )) &&
      identical(assignment_base(quote(requested_verify_live[])),
        "requested_verify_live") &&
      identical(assignment_base(quote(
        official_source_inventory_sha256[]
      )), "official_source_inventory_sha256") &&
      isTRUE(lock_rejects_subassignment),
    "Capture validator live-mode assignment is not singular and immutable."
  )
  dynamic_assignments <- validator_calls[validator_heads %in% c(
    "assign", "delayedAssign", "makeActiveBinding", "unlockBinding"
  )]
  assert(!any(vapply(dynamic_assignments, function(call) {
    length(call) >= 2L && is.character(call[[2L]]) &&
      call[[2L]] %in% c(
        "verify_live", "requested_verify_live",
        "official_source_inventory_sha256"
      )
  }, logical(1L))),
  "Capture validator dynamically assigns its live-mode canary."
  )
  live_if_calls <- Filter(function(call) {
    identical(call_head(call), "if") && length(call) >= 3L &&
      identical(call[[2L]], as.name("requested_verify_live"))
  }, validator_calls)
  verify_if_calls <- Filter(function(call) {
    identical(call_head(call), "if") && length(call) >= 3L &&
      identical(call[[2L]], as.name("verify_live"))
  }, validator_calls)
  assert(length(live_if_calls) == 6L && length(verify_if_calls) == 0L,
    "Capture validator live branches changed."
  )
  verify_symbols <- 0L
  count_verify_symbols <- function(node) {
    if (is.symbol(node) && identical(as.character(node), "verify_live")) {
      verify_symbols <<- verify_symbols + 1L
    }
    if (is.call(node) || is.expression(node) || is.pairlist(node) ||
        is.list(node)) {
      invisible(lapply(as.list(node), count_verify_symbols))
    }
    invisible(NULL)
  }
  count_verify_symbols(body(validator))
  assert(identical(verify_symbols, 3L),
    "Capture validator uses its mutable formal outside the frozen prologue."
  )
  assert(sum(validator_heads == "wlv13_v5d_physical_snapshot_attest") == 3L &&
      sum(validator_heads == "wlv13_v5d_directory_inventory_sha256") == 3L,
    "Capture validator live proof call sites changed."
  )
  main_calls <- calls_in(body(wlv13_v5d_stage5_generator_main))
  main_validator_calls <- main_calls[vapply(main_calls, function(call) {
    identical(call_head(call), "wlv13_v5d_validate_stage5_capture")
  }, logical(1L))]
  mutation_calls <- calls_in(body(wlv13_v5d_stage5_capture_mutation_selftest))
  mutation_validator_calls <- mutation_calls[vapply(mutation_calls,
    function(call) {
      identical(call_head(call), "wlv13_v5d_validate_stage5_capture")
    }, logical(1L)
  )]
  assert(length(main_validator_calls) == 2L &&
      all(vapply(main_validator_calls, function(call) {
        identical(call[["verify_live"]], TRUE)
      }, logical(1L))) && length(mutation_validator_calls) == 1L &&
      identical(mutation_validator_calls[[1L]][["verify_live"]], FALSE),
    "Capture validator call sites do not freeze live versus mutation modes."
  )
  assertions
}

wlv13_v5d_stage5_capture_mutation_selftest <- function(
    bridge_capture_path, bridge_index_path, bridge_manifest_path,
    stage_capture_path, stage_index_path, evidence, harness_dir,
    external_inventories) {
  assertions <- 0L
  expect_error <- function(expression, label) {
    failed <- tryCatch({
      force(expression)
      FALSE
    }, error = function(error) {
      inherits(error, "wlv13_v5d_capture_mutation_rejection")
    })
    if (!failed) {
      stop(sprintf("Stage-five capture mutation passed: %s.", label),
        call. = FALSE
      )
    }
    assertions <<- assertions + 1L
  }
  original <- readLines(stage_capture_path, warn = FALSE, encoding = "UTF-8")
  capture_directory <- normalizePath(
    dirname(stage_capture_path), winslash = "/", mustWork = TRUE
  )
  mutation_directory <- normalizePath(
    tempdir(), winslash = "/", mustWork = TRUE
  )
  capture_prefix <- paste0(tolower(capture_directory), "/")
  if (identical(tolower(mutation_directory), tolower(capture_directory)) ||
      startsWith(tolower(mutation_directory), capture_prefix)) {
    stop("Mutation self-test temporary directory overlaps the capture root.",
      call. = FALSE
    )
  }
  temporary <- tempfile(
    pattern = "issue13-v5d-mutated-capture-",
    tmpdir = mutation_directory, fileext = ".txt"
  )
  on.exit(unlink(temporary, force = TRUE), add = TRUE)
  validate_mutation <- function(lines, mutated_evidence = evidence) {
    writeLines(lines, temporary, sep = "\n", useBytes = TRUE)
    tryCatch(
      wlv13_v5d_validate_stage5_capture(
        bridge_capture_path, bridge_index_path, bridge_manifest_path,
        temporary, stage_index_path, mutated_evidence, harness_dir,
        external_inventories, verify_live = FALSE
      ),
      error = function(error) {
        rejection <- simpleError(
          conditionMessage(error), call = conditionCall(error)
        )
        class(rejection) <- c(
          "wlv13_v5d_capture_mutation_rejection", class(rejection)
        )
        stop(rejection)
      }
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
  mutation[1:2] <- mutation[2:1]
  expect_error(validate_mutation(mutation), "stage header order")
  mutation <- append(original, original[[1L]], after = 1L)
  expect_error(validate_mutation(mutation), "duplicate stage header")
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
  index <- line_index("^source_data_origin_path=")
  mutation[[index]] <- paste0(mutation[[index]], "0")
  expect_error(validate_mutation(mutation), "source origin path")
  mutation <- original
  index <- line_index("^source_data_origin_physical_path=")
  mutation[[index]] <- paste0(mutation[[index]], "0")
  expect_error(validate_mutation(mutation), "source origin physical path")
  mutation <- original
  index <- line_index("^source_data_origin_inventory_after_sha256=")
  mutation[[index]] <- paste0(
    "source_data_origin_inventory_after_sha256=", mutate_hash(
      sub("^[^=]*=", "", mutation[[index]])
    )
  )
  expect_error(validate_mutation(mutation), "source origin hash")
  mutation <- original
  index <- line_index("^source_data_origin_physical_after_sha256=")
  mutation[[index]] <- paste0(
    "source_data_origin_physical_after_sha256=", mutate_hash(
      sub("^[^=]*=", "", mutation[[index]])
    )
  )
  expect_error(validate_mutation(mutation), "source origin physical hash")
  mutation <- original
  index <- line_index("^bridge_source_data_snapshot_path=")
  mutation[[index]] <- paste0(mutation[[index]], "0")
  expect_error(validate_mutation(mutation), "bridge source snapshot path")
  mutation <- original
  index <- line_index("^bridge_source_data_snapshot_physical_path=")
  mutation[[index]] <- paste0(mutation[[index]], "0")
  expect_error(validate_mutation(mutation),
    "bridge source snapshot physical path"
  )
  mutation <- original
  index <- line_index(
    "^bridge_source_data_snapshot_inventory_after_sha256="
  )
  mutation[[index]] <- paste0(
    "bridge_source_data_snapshot_inventory_after_sha256=", mutate_hash(
      sub("^[^=]*=", "", mutation[[index]])
    )
  )
  expect_error(validate_mutation(mutation), "bridge source snapshot hash")
  mutation <- original
  index <- line_index(
    "^bridge_source_data_snapshot_physical_after_sha256="
  )
  mutation[[index]] <- paste0(
    "bridge_source_data_snapshot_physical_after_sha256=", mutate_hash(
      sub("^[^=]*=", "", mutation[[index]])
    )
  )
  expect_error(validate_mutation(mutation),
    "bridge source snapshot physical hash"
  )
  mutation <- original
  index <- line_index("^harness_inventory_sha256=")
  mutation[[index]] <- paste0("harness_inventory_sha256=", mutate_hash(
    sub("^[^=]*=", "", mutation[[index]])
  ))
  expect_error(validate_mutation(mutation), "harness inventory")
  mutation <- original
  index <- line_index("^harness_runtime_path=")
  mutation[[index]] <- paste0(mutation[[index]], "0")
  expect_error(validate_mutation(mutation), "harness runtime path")
  mutation <- original
  index <- line_index("^harness_runtime_inventory_after_sha256=")
  mutation[[index]] <- paste0(
    "harness_runtime_inventory_after_sha256=", mutate_hash(
      sub("^[^=]*=", "", mutation[[index]])
    )
  )
  expect_error(validate_mutation(mutation), "harness runtime hash")
  mutation <- original
  index <- line_index("^rscript_sha256=")
  mutation[[index]] <- paste0("rscript_sha256=", mutate_hash(
    sub("^[^=]*=", "", mutation[[index]])
  ))
  expect_error(validate_mutation(mutation), "Rscript hash")
  mutation <- original
  forged_executable <- normalizePath(file.path(
    dirname(external_inventories$fsutil_path), "cmd.exe"
  ), winslash = "/", mustWork = TRUE)
  path_index <- line_index("^fsutil_path=")
  hash_index <- line_index("^fsutil_sha256=")
  mutation[[path_index]] <- paste0("fsutil_path=", forged_executable)
  mutation[[hash_index]] <- paste0(
    "fsutil_sha256=", wlv13_sha256_file(forged_executable)
  )
  expect_error(validate_mutation(mutation), "coherent fsutil executable")
  mutation <- original
  index <- line_index("^r_library_path=")
  mutation[[index]] <- paste0(mutation[[index]], "0")
  expect_error(validate_mutation(mutation), "R library path")
  mutation <- original
  index <- line_index("^r_library_inventory_after_sha256=")
  mutation[[index]] <- paste0(
    "r_library_inventory_after_sha256=", mutate_hash(
      sub("^[^=]*=", "", mutation[[index]])
    )
  )
  expect_error(validate_mutation(mutation), "R library hash")
  recipe_index <- grep("^recipe_record;", original)[[1L]]
  expect_error(validate_mutation(mutate_field(
    original, recipe_index, "sha256"
  )), "recipe hash")
  expect_error(validate_mutation(original[-recipe_index]), "missing recipe")
  worktree_indexes <- grep("^worktree_record;", original)
  mutation <- original
  mutation[worktree_indexes[1:2]] <- mutation[rev(worktree_indexes[1:2])]
  expect_error(validate_mutation(mutation), "worktree order")
  source_snapshot_indexes <- grep("^source_snapshot_record;", original)
  expect_error(validate_mutation(mutate_field(
    original, source_snapshot_indexes[[1L]], "path"
  )), "source snapshot path")
  expect_error(validate_mutation(mutate_field(
    original, source_snapshot_indexes[[1L]], "inventory_before_sha256"
  )), "source snapshot inventory before")
  expect_error(validate_mutation(mutate_field(
    original, source_snapshot_indexes[[1L]], "inventory_after_sha256"
  )), "source snapshot hash")
  expect_error(validate_mutation(mutate_field(
    original, source_snapshot_indexes[[1L]], "physical_path"
  )), "source snapshot physical path")
  expect_error(validate_mutation(mutate_field(
    original, source_snapshot_indexes[[1L]], "physical_after_sha256"
  )), "source snapshot physical hash")
  expect_error(validate_mutation(mutate_field(
    original, source_snapshot_indexes[[1L]], "physical_before_sha256"
  )), "source snapshot physical before")
  expect_error(validate_mutation(mutate_field(
    original, source_snapshot_indexes[[1L]], "independence_after_sha256"
  )), "source snapshot independence after")
  expect_error(
    validate_mutation(original[-source_snapshot_indexes[[1L]]]),
    "missing source snapshot"
  )
  mutation <- original
  mutation[source_snapshot_indexes[1:2]] <-
    mutation[rev(source_snapshot_indexes[1:2])]
  expect_error(validate_mutation(mutation), "source snapshot order")
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
  live_structure_assertions <-
    wlv13_v5d_live_validation_structure_selftest()
  if (!identical(live_structure_assertions, 7L)) {
    stop("Capture live-validation structure self-test is incomplete.",
      call. = FALSE
    )
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
  external_inventories <- wlv13_v5d_capture_external_inventories(
    bridge_capture_path, harness_dir
  )
  capture_record_sha256 <- wlv13_v5d_validate_stage5_capture(
    bridge_capture_path, bridge_index_path, bridge_path,
    stage_capture_path, evidence_path, evidence, harness_dir,
    external_inventories, verify_live = TRUE
  )
  capture_assertions <- wlv13_v5d_stage5_capture_mutation_selftest(
    bridge_capture_path, bridge_index_path, bridge_path,
    stage_capture_path, evidence_path, evidence, harness_dir,
    external_inventories
  )
  if (!identical(capture_assertions, 46L)) {
    stop("Stage-five capture mutation self-test is incomplete.",
      call. = FALSE
    )
  }
  confirmed_capture_record_sha256 <- wlv13_v5d_validate_stage5_capture(
    bridge_capture_path, bridge_index_path, bridge_path,
    stage_capture_path, evidence_path, evidence, harness_dir,
    external_inventories, verify_live = TRUE
  )
  if (!identical(
      confirmed_capture_record_sha256, capture_record_sha256
    )) {
    stop("Stage-five capture changed across its two live validations.",
      call. = FALSE
    )
  }
  value <- wlv13_v5d_generate_stage5_profiles(
    evidence, contract_root, bridges, capture_record_sha256,
    arguments[[8L]]
  )
  cat(sprintf(
    paste0("generated_rows=%d profiles_sha256=%s capture_assertions=%d ",
      "live_structure_assertions=%d\n"),
    nrow(value), wlv13_sha256_file(arguments[[8L]]), capture_assertions,
    live_structure_assertions
  ))
  invisible(value)
}

if (sys.nframe() == 0L) {
  wlv13_v5d_stage5_generator_main()
}
