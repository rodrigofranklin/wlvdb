# Exhaustive normalized-source equivalence for the terminal Issue #13 gate.
#
# The manifest contains every cell of each architecture-dependent table for
# both engines. A cross-engine difference is accepted only when each arm is an
# exact match for its independently authenticated, controller-pinned table.

wlv13_v5p_manifest_cache <- new.env(parent = emptyenv())

wlv13_v5p_normalize_table <- function(value, label) {
  if (!is.data.frame(value) || !length(names(value)) ||
      anyDuplicated(names(value))) {
    stop(sprintf("%s has an invalid table schema.", label), call. = FALSE)
  }
  result <- as.data.frame(lapply(value, function(column) {
    column <- as.character(column)
    column[is.na(column)] <- ""
    enc2utf8(column)
  }), stringsAsFactors = FALSE, check.names = FALSE)
  rownames(result) <- NULL
  result
}

wlv13_v5p_encode_table <- function(value) {
  value <- wlv13_v5p_normalize_table(value, "Preparation table")
  list(
    columns = as.list(names(value)),
    rows = lapply(seq_len(nrow(value)), function(index) {
      as.list(unname(vapply(
        value[index, , drop = FALSE],
        function(column) as.character(column[[1L]]), character(1L)
      )))
    })
  )
}

wlv13_v5p_decode_table <- function(value, label) {
  if (!is.list(value) || !identical(names(value), c("columns", "rows")) ||
      !is.list(value$columns) || !is.list(value$rows)) {
    stop(sprintf("%s has an invalid encoded table.", label), call. = FALSE)
  }
  columns <- unlist(value$columns, use.names = FALSE)
  if (!is.character(columns) || !length(columns) || anyNA(columns) ||
      any(!nzchar(columns)) || anyDuplicated(columns)) {
    stop(sprintf("%s has invalid encoded columns.", label), call. = FALSE)
  }
  rows <- lapply(value$rows, function(row) {
    cells <- unlist(row, use.names = FALSE)
    if (!is.character(cells) || anyNA(cells) ||
        length(cells) != length(columns)) {
      stop(sprintf("%s has an invalid encoded row.", label), call. = FALSE)
    }
    enc2utf8(cells)
  })
  result <- as.data.frame(stats::setNames(
    lapply(seq_along(columns), function(index) {
      if (length(rows)) {
        vapply(rows, `[[`, character(1L), index)
      } else {
        character()
      }
    }), columns
  ), stringsAsFactors = FALSE, check.names = FALSE)
  rownames(result) <- NULL
  result
}

wlv13_v5p_table_sha256 <- function(value) {
  if (!exists("wlv13_sha256_text", mode = "function", inherits = TRUE)) {
    stop("The pinned SHA-256 helper is unavailable.", call. = FALSE)
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package `jsonlite` is required by preparation equivalence.",
      call. = FALSE
    )
  }
  encoded <- wlv13_v5p_encode_table(value)
  wlv13_sha256_text(as.character(jsonlite::toJSON(
    encoded, auto_unbox = TRUE, digits = NA, null = "null", na = "string"
  )))
}

wlv13_v5p_exact_table <- function(left, right) {
  is.data.frame(left) && is.data.frame(right) && identical(left, right)
}

wlv13_v5p_validate_manifest <- function(value) {
  sources <- c("wiodr13", "wiodr16")
  artifacts <- c("_unit_contract.csv", "_source_manifest.csv")
  valid <- is.list(value) && identical(names(value), c(
    "schema", "baseline_commit", "candidate_commit_at_derivation",
    "derivation", "sources", "artifacts", "profiles"
  )) &&
    identical(value$schema, "wlv-issue13-preparation-equivalence/1") &&
    identical(value$baseline_commit,
      "cc2c86189a06676bcb9f0e05e08033d710a92509") &&
    identical(value$candidate_commit_at_derivation,
      "a70cef8ef7ec19b329dd60cc2a10f49bf0c9533b") &&
    identical(value$derivation, paste(
      "Exact authenticated normalized-source tables paired by source and arm;",
      "no field, row, wildcard, tolerance or row-order projection."
    )) &&
    identical(unlist(value$sources, use.names = FALSE), sources) &&
    identical(unlist(value$artifacts, use.names = FALSE), artifacts) &&
    is.list(value$profiles) && length(value$profiles) == length(sources) &&
    identical(vapply(value$profiles, `[[`, character(1L), "source"), sources)
  if (!valid) {
    stop("The exhaustive preparation equivalence manifest is invalid.",
      call. = FALSE
    )
  }
  for (profile in value$profiles) {
    if (!identical(names(profile), c("source", "baseline", "candidate"))) {
      stop("A preparation equivalence profile has an invalid envelope.",
        call. = FALSE
      )
    }
    for (arm in c("baseline", "candidate")) {
      arm_profile <- profile[[arm]]
      if (!is.list(arm_profile) || !identical(names(arm_profile), c(
          "source_generation_id", "contract_id", "contract_version",
          "contract_sha256", "artifacts"
        )) ||
          !is.character(arm_profile$source_generation_id) ||
          length(arm_profile$source_generation_id) != 1L ||
          !grepl("^[0-9a-f]{64}$", arm_profile$source_generation_id) ||
          !is.character(arm_profile$contract_id) ||
          length(arm_profile$contract_id) != 1L ||
          !nzchar(arm_profile$contract_id) ||
          !identical(arm_profile$contract_version, "2") ||
          !is.character(arm_profile$contract_sha256) ||
          length(arm_profile$contract_sha256) != 1L ||
          !grepl("^[0-9a-f]{64}$", arm_profile$contract_sha256) ||
          !is.list(arm_profile$artifacts) ||
          length(arm_profile$artifacts) != length(artifacts) ||
          !identical(vapply(arm_profile$artifacts, `[[`, character(1L),
            "artifact"), artifacts)) {
        stop("A preparation arm profile is invalid.", call. = FALSE)
      }
      for (artifact in arm_profile$artifacts) {
        if (!identical(names(artifact), c(
            "artifact", "file_sha256", "table_sha256", "table"
          )) ||
            !is.character(artifact$file_sha256) ||
            length(artifact$file_sha256) != 1L ||
            !grepl("^[0-9a-f]{64}$", artifact$file_sha256) ||
            !is.character(artifact$table_sha256) ||
            length(artifact$table_sha256) != 1L ||
            !grepl("^[0-9a-f]{64}$", artifact$table_sha256)) {
          stop("A preparation artifact profile is invalid.", call. = FALSE)
        }
        decoded <- wlv13_v5p_decode_table(
          artifact$table,
          paste(profile$source, arm, artifact$artifact, sep = "/")
        )
        if (!identical(wlv13_v5p_table_sha256(decoded),
            artifact$table_sha256)) {
          stop("A preparation artifact table fingerprint is invalid.",
            call. = FALSE
          )
        }
      }
    }
  }
  value
}

wlv13_v5p_manifest <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  key <- path
  observed_sha256 <- wlv_gate_sha256(path)
  if (exists(key, envir = wlv13_v5p_manifest_cache, inherits = FALSE)) {
    cached <- get(key, envir = wlv13_v5p_manifest_cache, inherits = FALSE)
    if (!identical(cached$sha256, observed_sha256)) {
      stop("Preparation equivalence manifest changed during comparison.",
        call. = FALSE
      )
    }
    return(cached$value)
  }
  if (!exists("wlv13_json_read", mode = "function", inherits = TRUE)) {
    stop("The pinned JSON reader is unavailable.", call. = FALSE)
  }
  value <- wlv13_v5p_validate_manifest(
    wlv13_json_read(path, simplify = FALSE)
  )
  assign(key, list(sha256 = observed_sha256, value = value),
    envir = wlv13_v5p_manifest_cache
  )
  value
}

wlv13_v5p_artifact_profile <- function(profile, arm, artifact) {
  profiles <- profile[[arm]]$artifacts
  index <- match(artifact, vapply(profiles, `[[`, character(1L), "artifact"))
  if (is.na(index)) {
    stop(sprintf("No preparation profile exists for `%s/%s/%s`.",
      profile$source, arm, artifact), call. = FALSE
    )
  }
  profiles[[index]]
}

wlv13_v5p_compare_artifact <- function(path, actual, expected, label) {
  actual <- wlv13_v5p_normalize_table(actual, label)
  expected_table <- wlv13_v5p_decode_table(expected$table, label)
  file_sha256 <- wlv_gate_sha256(path)
  table_sha256 <- wlv13_v5p_table_sha256(actual)
  exact <- wlv13_v5p_exact_table(actual, expected_table)
  list(
    passed = exact && identical(file_sha256, expected$file_sha256) &&
      identical(table_sha256, expected$table_sha256),
    rows = nrow(actual),
    columns = as.list(names(actual)),
    exact_table = exact,
    file_sha256 = file_sha256,
    expected_file_sha256 = expected$file_sha256,
    table_sha256 = table_sha256,
    expected_table_sha256 = expected$table_sha256
  )
}

wlv13_v5p_compare_source <- function(baseline_root, candidate_root, source,
                                      baseline_manifest_table,
                                      candidate_manifest_table,
                                      manifest_path) {
  manifest <- wlv13_v5p_manifest(manifest_path)
  profile_index <- match(source, vapply(
    manifest$profiles, `[[`, character(1L), "source"
  ))
  if (is.na(profile_index)) {
    stop(sprintf("No preparation equivalence profile exists for `%s`.", source),
      call. = FALSE
    )
  }
  profile <- manifest$profiles[[profile_index]]
  paths <- list(
    baseline = file.path(baseline_root, "_unit_contract.csv"),
    candidate = file.path(candidate_root, "_unit_contract.csv")
  )
  unit <- list(
    baseline = wlv13_v5p_compare_artifact(
      paths$baseline,
      wlv_gate_read_character_csv(paths$baseline),
      wlv13_v5p_artifact_profile(profile, "baseline", "_unit_contract.csv"),
      paste0(source, "/baseline/_unit_contract.csv")
    ),
    candidate = wlv13_v5p_compare_artifact(
      paths$candidate,
      wlv_gate_read_character_csv(paths$candidate),
      wlv13_v5p_artifact_profile(profile, "candidate", "_unit_contract.csv"),
      paste0(source, "/candidate/_unit_contract.csv")
    )
  )
  manifest_tables <- list(
    baseline = wlv13_v5p_compare_artifact(
      file.path(baseline_root, "_source_manifest.csv"),
      baseline_manifest_table,
      wlv13_v5p_artifact_profile(profile, "baseline", "_source_manifest.csv"),
      paste0(source, "/baseline/_source_manifest.csv")
    ),
    candidate = wlv13_v5p_compare_artifact(
      file.path(candidate_root, "_source_manifest.csv"),
      candidate_manifest_table,
      wlv13_v5p_artifact_profile(profile, "candidate", "_source_manifest.csv"),
      paste0(source, "/candidate/_source_manifest.csv")
    )
  )
  unit_passed <- isTRUE(unit$baseline$passed) && isTRUE(unit$candidate$passed)
  manifest_passed <- isTRUE(manifest_tables$baseline$passed) &&
    isTRUE(manifest_tables$candidate$passed)
  profile_sha256 <- wlv_gate_sha256(manifest_path)
  list(
    passed = unit_passed && manifest_passed,
    profile_sha256 = profile_sha256,
    unit_contract = list(
      passed = unit_passed,
      comparison_mode = "sealed-exhaustive-unit-contract-equivalence",
      profile_sha256 = profile_sha256,
      raw_semantic_equal = wlv13_v5p_exact_table(
        wlv_gate_read_character_csv(paths$baseline),
        wlv_gate_read_character_csv(paths$candidate)
      ),
      baseline = unit$baseline,
      candidate = unit$candidate
    ),
    source_manifest = list(
      passed = manifest_passed,
      comparison_mode = "sealed-exhaustive-source-manifest-equivalence",
      profile_sha256 = profile_sha256,
      raw_semantic_equal = wlv13_v5p_exact_table(
        wlv13_v5p_normalize_table(
          baseline_manifest_table, "Baseline source manifest"
        ),
        wlv13_v5p_normalize_table(
          candidate_manifest_table, "Candidate source manifest"
        )
      ),
      baseline = manifest_tables$baseline,
      candidate = manifest_tables$candidate
    )
  )
}

wlv13_v5p_selftest <- function(manifest_path) {
  manifest <- wlv13_v5p_manifest(manifest_path)
  assertions <- 0L
  expect_false <- function(value, label) {
    if (isTRUE(value)) {
      stop(sprintf("Preparation equivalence self-test accepted `%s`.", label),
        call. = FALSE
      )
    }
    assertions <<- assertions + 1L
  }
  for (profile in manifest$profiles) {
    for (arm in c("baseline", "candidate")) {
      for (artifact in profile[[arm]]$artifacts) {
        expected <- wlv13_v5p_decode_table(
          artifact$table,
          paste(profile$source, arm, artifact$artifact, sep = "/")
        )
        if (!wlv13_v5p_exact_table(expected, expected)) {
          stop("Preparation equivalence self-test rejected its sealed table.",
            call. = FALSE
          )
        }
        assertions <- assertions + 1L
        for (column in names(expected)) {
          mutation <- expected
          mutation[[column]][[1L]] <- paste0(mutation[[column]][[1L]], "#")
          expect_false(wlv13_v5p_exact_table(mutation, expected),
            paste(profile$source, arm, artifact$artifact, column)
          )
        }
        removed <- expected[-1L, , drop = FALSE]
        rownames(removed) <- NULL
        expect_false(wlv13_v5p_exact_table(removed, expected),
          paste(profile$source, arm, artifact$artifact, "missing-row")
        )
        added <- rbind(expected, expected[1L, , drop = FALSE])
        rownames(added) <- NULL
        expect_false(wlv13_v5p_exact_table(added, expected),
          paste(profile$source, arm, artifact$artifact, "extra-row")
        )
        reordered <- expected[c(2L, 1L, seq.int(3L, nrow(expected))),
          , drop = FALSE]
        rownames(reordered) <- NULL
        expect_false(wlv13_v5p_exact_table(reordered, expected),
          paste(profile$source, arm, artifact$artifact, "row-order")
        )
      }
    }
  }
  swapped <- manifest
  swapped$profiles <- rev(swapped$profiles)
  expect_false(tryCatch({
    wlv13_v5p_validate_manifest(swapped)
    TRUE
  }, error = function(error) FALSE), "source-swap")
  assertions
}
