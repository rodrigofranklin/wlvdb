# Build the exact two-method metadata equivalence profile used by the main
# Issue #13 comparison.  This utility reads only tracked runtime definitions,
# catalog entries and method configuration.  It never opens scientific data or
# result payloads.

EXPECTED_BASELINE_COMMIT <- "cc2c86189a06676bcb9f0e05e08033d710a92509"
EXPECTED_ORACLE_COMMIT <- "e2f4d6dae9a6d35c966b305fabac52e489faa3e7"
EXPECTED_CANDIDATE_COMMIT <- "972d9f8fc7a887b3db485080264f2958cce13cdd"
EXPECTED_OLD_CANDIDATE_COMMIT <- "3ae99a848156a28431ff44cf4d9e619c6de84a83"
METHODS <- c("wiodr13", "wiodr16")
ARTIFACTS <- c(
  `_method_assumptions.csv` = "assumptions",
  `_method_matrices.csv` = "matrices",
  `_method_solutions.csv` = "solutions"
)
COLUMNS <- list(
  `_method_assumptions.csv` = c("names", "computation", "order"),
  `_method_matrices.csv` = c("names", "computation", "order"),
  `_method_solutions.csv` = c(
    "names", "sector_solution", "country_solution", "stage", "order"
  )
)
DERIVATION_TEXT <- paste(
  "Exact engine-reconstructed sidecars paired by method and artifact;",
  "no category, wildcard, tolerance or row-order projection."
)
PLANNER_FORMALS <- c(
  "methods", "repeat_pp", "papern", "prepaper", "workers", "channel",
  "mode", "at_stage", "sea_vars", "root", "allow_experimental",
  "requested_operations", "catalog"
)

fail <- function(message) {
  stop(message, call. = FALSE)
}

scalar_text <- function(value, name, pattern = NULL) {
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !nzchar(value)) {
    fail(sprintf("`%s` must be one non-empty string.", name))
  }
  value <- enc2utf8(value)
  if (!is.null(pattern) && !grepl(pattern, value)) {
    fail(sprintf("`%s` has an invalid value.", name))
  }
  value
}

script_path <- function() {
  argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(argument) != 1L) {
    fail("Cannot identify this metadata generator script.")
  }
  normalizePath(sub("^--file=", "", argument), winslash = "/", mustWork = TRUE)
}

normalize_existing_file <- function(path, name) {
  path <- normalizePath(scalar_text(path, name), winslash = "/", mustWork = TRUE)
  if (isTRUE(file.info(path)$isdir)) {
    fail(sprintf("`%s` must identify a regular file.", name))
  }
  path
}

normalize_existing_directory <- function(path, name) {
  path <- normalizePath(scalar_text(path, name), winslash = "/", mustWork = TRUE)
  if (!isTRUE(file.info(path)$isdir)) {
    fail(sprintf("`%s` must identify a directory.", name))
  }
  path
}

normalize_new_directory <- function(path, name) {
  path <- scalar_text(path, name)
  parent <- normalizePath(dirname(path), winslash = "/", mustWork = TRUE)
  path <- file.path(parent, basename(path))
  if (file.exists(path) || dir.exists(path)) {
    fail(sprintf("Refusing to overwrite existing output `%s`.", path))
  }
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

initialize_dependencies <- function(helper_path) {
  sys.source(helper_path, envir = .GlobalEnv, chdir = FALSE)
  wlv_gate_use_library()
  wlv_gate_require_namespaces(c("jsonlite", "openssl"))
  invisible(TRUE)
}

sha256_raw <- function(value) {
  tolower(sprintf("%s", openssl::sha256(value)))
}

sha256_text <- function(value) {
  sha256_raw(charToRaw(enc2utf8(scalar_text(value, "text"))))
}

canonical_json <- function(value) {
  enc2utf8(as.character(jsonlite::toJSON(
    value,
    auto_unbox = TRUE,
    pretty = FALSE,
    digits = NA,
    null = "null",
    na = "string"
  )))
}

sha256_json <- function(value) {
  sha256_text(canonical_json(value))
}

read_json <- function(path) {
  path <- normalize_existing_file(path, "JSON path")
  size <- file.info(path)$size
  payload <- readBin(path, what = "raw", n = size)
  text <- tryCatch(
    iconv(rawToChar(payload), from = "UTF-8", to = "UTF-8", sub = NA_character_),
    error = function(error) NA_character_
  )
  if (length(text) != 1L || is.na(text) || grepl("\ufffd", text, fixed = TRUE)) {
    fail(sprintf("JSON is not strict UTF-8: `%s`.", path))
  }
  jsonlite::fromJSON(
    text,
    simplifyVector = FALSE,
    simplifyDataFrame = FALSE,
    simplifyMatrix = FALSE
  )
}

normalized_json_value <- function(value) {
  jsonlite::fromJSON(
    canonical_json(value),
    simplifyVector = FALSE,
    simplifyDataFrame = FALSE,
    simplifyMatrix = FALSE
  )
}

write_json_once <- function(value, path) {
  if (file.exists(path) || dir.exists(path)) {
    fail(sprintf("Refusing to overwrite `%s`.", path))
  }
  payload <- charToRaw(enc2utf8(paste0(as.character(jsonlite::toJSON(
    value,
    auto_unbox = TRUE,
    pretty = TRUE,
    digits = NA,
    null = "null",
    na = "string"
  )), "\n")))
  connection <- file(path, open = "wb")
  tryCatch(writeBin(payload, connection), finally = close(connection))
  observed_raw <- readBin(path, what = "raw", n = file.info(path)$size)
  if (!identical(observed_raw, payload)) {
    fail(sprintf("Byte round trip failed for `%s`.", path))
  }
  observed <- read_json(path)
  expected <- normalized_json_value(value)
  if (!identical(observed, expected)) {
    fail(sprintf("JSON semantic round trip failed for `%s`.", path))
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

write_utf8_once <- function(value, path) {
  if (file.exists(path) || dir.exists(path)) {
    fail(sprintf("Refusing to overwrite `%s`.", path))
  }
  value <- paste(enc2utf8(value), collapse = "\n")
  if (nzchar(value)) value <- paste0(value, "\n")
  payload <- charToRaw(value)
  connection <- file(path, open = "wb")
  tryCatch(writeBin(payload, connection), finally = close(connection))
  observed <- readBin(path, what = "raw", n = file.info(path)$size)
  if (!identical(observed, payload)) {
    fail(sprintf("UTF-8 log round trip failed for `%s`.", path))
  }
  invisible(path)
}

normalize_table <- function(value, expected_columns) {
  if (!is.data.frame(value) || !identical(names(value), expected_columns)) {
    fail("Reconstructed metadata has an unexpected schema.")
  }
  value <- as.data.frame(lapply(value, function(column) {
    column <- as.character(column)
    column[is.na(column)] <- ""
    enc2utf8(column)
  }), stringsAsFactors = FALSE, check.names = FALSE)
  rownames(value) <- NULL
  value
}

encode_table <- function(value) {
  list(
    columns = as.list(names(value)),
    rows = lapply(seq_len(nrow(value)), function(index) {
      as.list(unname(vapply(
        value[index, , drop = FALSE],
        function(column) as.character(column[[1L]]),
        character(1L)
      )))
    })
  )
}

validate_encoded_table <- function(value, expected_columns, context) {
  if (!is.list(value) || !identical(names(value), c("columns", "rows"))) {
    fail(sprintf("Encoded table envelope is invalid for %s.", context))
  }
  observed_columns <- unlist(value$columns, use.names = FALSE)
  if (!identical(observed_columns, expected_columns) || !is.list(value$rows)) {
    fail(sprintf("Encoded table schema is invalid for %s.", context))
  }
  valid_rows <- vapply(value$rows, function(row) {
    is.list(row) && length(row) == length(expected_columns) &&
      all(vapply(row, function(cell) {
        is.character(cell) && length(cell) == 1L && !is.na(cell) &&
          identical(enc2utf8(cell), cell)
      }, logical(1L)))
  }, logical(1L))
  if (any(!valid_rows)) {
    fail(sprintf("Encoded table cells are invalid for %s.", context))
  }
  invisible(TRUE)
}

baseline_sidecars <- function(plan, method) {
  configuration <- plan$configuration[[method]]
  assumptions <- configuration$assumptions[
    order(configuration$assumptions$order), , drop = FALSE
  ]
  matrices <- configuration$matrices[
    order(configuration$matrices$order), , drop = FALSE
  ]
  solutions <- configuration$solutions[
    order(configuration$solutions$order), , drop = FALSE
  ]
  solutions <- solutions[order(solutions$stage), , drop = FALSE]
  list(
    assumptions = assumptions,
    matrices = matrices,
    solutions = solutions
  )
}

partition_for <- function(source) {
  switch(source,
    wiodr13 = "1995-2009",
    wiodr16 = "2000-2014",
    fail(sprintf("No sealed partition is registered for `%s`.", source))
  )
}

plan_arguments <- function(method, root) {
  list(
    methods = method,
    repeat_pp = FALSE,
    papern = 0L,
    prepaper = FALSE,
    workers = 1L,
    channel = "stable",
    mode = "calculate",
    at_stage = 1L,
    sea_vars = NULL,
    root = root,
    allow_experimental = TRUE,
    requested_operations = "calculate",
    catalog = NULL
  )
}

validate_plan <- function(plan, root, method) {
  if (!inherits(plan, "wlv_run_plan") ||
      !identical(
        normalizePath(plan$root, winslash = "/", mustWork = TRUE),
        root
      ) ||
      !identical(plan$mode, "calculate") ||
      !identical(plan$requested_operations, "calculate") ||
      !identical(plan$method_names, method) ||
      !identical(plan$allow_experimental, TRUE)) {
    fail(sprintf("Metadata derivation produced an unexpected plan for `%s`.", method))
  }
  invisible(TRUE)
}

derive_arm <- function(arm, root, helper_path, output_path) {
  arm <- match.arg(arm, c("baseline", "oracle", "candidate"))
  root <- normalize_existing_directory(root, "arm root")
  helper_path <- normalize_existing_file(helper_path, "helper path")
  output_path <- normalizePath(output_path, winslash = "/", mustWork = FALSE)
  if (file.exists(output_path) || dir.exists(output_path)) {
    fail(sprintf("Refusing to overwrite arm output `%s`.", output_path))
  }
  initialize_dependencies(helper_path)

  loaded <- wlv_gate_load_runtime(root)
  expected_kind <- if (identical(arm, "candidate")) "candidate" else "baseline"
  if (!identical(loaded$kind, expected_kind)) {
    fail(sprintf("The `%s` root loaded as `%s`.", arm, loaded$kind))
  }
  runtime <- loaded$runtime
  if (!identical(names(formals(runtime$wlv_validate_request)), PLANNER_FORMALS)) {
    fail(sprintf("The `%s` planner signature is unexpected.", arm))
  }

  runtime_generation <- NULL
  if (identical(arm, "candidate")) {
    runtime_generation <- unname(unclass(as.character(
      runtime$.wlv_runtime_compatibility_generation()
    )))
    scalar_text(
      runtime_generation,
      "candidate runtime generation",
      "^[0-9a-f]{64}$"
    )
  }

  profiles <- lapply(METHODS, function(method) {
    plan <- do.call(runtime$wlv_validate_request, plan_arguments(method, root))
    validate_plan(plan, root, method)
    source <- scalar_text(plan$methods$source[[1L]], "method source")
    partition <- partition_for(source)
    sidecars <- if (!identical(arm, "candidate")) {
      baseline_sidecars(plan, method)
    } else {
      runtime$wlv_native_configuration_sidecars(
        plan,
        method,
        list(partitions = partition)
      )
    }
    artifact_profiles <- lapply(names(ARTIFACTS), function(artifact) {
      group <- unname(ARTIFACTS[[artifact]])
      table <- encode_table(normalize_table(sidecars[[group]], COLUMNS[[artifact]]))
      validate_encoded_table(
        table,
        COLUMNS[[artifact]],
        paste(arm, method, artifact, sep = "/")
      )
      list(artifact = artifact, table = table)
    })
    list(
      method = method,
      source = source,
      partition = partition,
      artifacts = artifact_profiles
    )
  })

  integrity_check <- identical(arm, "candidate")
  if (integrity_check) runtime$wlv_assert_loaded_runtime_unchanged()
  payload <- list(
    schema = "wlv-issue13-main-metadata-arm/1",
    arm = arm,
    runtime_kind = loaded$kind,
    runtime_generation_sha256 = runtime_generation,
    methods = as.list(METHODS),
    artifacts = as.list(names(ARTIFACTS)),
    planner_formals = as.list(PLANNER_FORMALS),
    plan_arguments = list(
      repeat_pp = FALSE,
      papern = 0L,
      prepaper = FALSE,
      workers = 1L,
      channel = "stable",
      mode = "calculate",
      at_stage = 1L,
      sea_vars = NULL,
      allow_experimental = TRUE,
      requested_operations = "calculate",
      catalog = NULL
    ),
    runtime_integrity_check = integrity_check,
    profiles = profiles
  )
  write_json_once(payload, output_path)
  cat(sprintf("issue13 main metadata arm: %s, %d methods\n", arm, length(profiles)))
  invisible(payload)
}

validate_arm_payload <- function(value, arm) {
  expected_kind <- if (identical(arm, "candidate")) "candidate" else "baseline"
  if (!is.list(value) ||
      !identical(value$schema, "wlv-issue13-main-metadata-arm/1") ||
      !identical(value$arm, arm) ||
      !identical(value$runtime_kind, expected_kind) ||
      !identical(unlist(value$methods, use.names = FALSE), METHODS) ||
      !identical(unlist(value$artifacts, use.names = FALSE), names(ARTIFACTS)) ||
      !identical(unlist(value$planner_formals, use.names = FALSE), PLANNER_FORMALS) ||
      !is.list(value$profiles) || length(value$profiles) != length(METHODS) ||
      !identical(vapply(value$profiles, `[[`, character(1L), "method"), METHODS)) {
    fail(sprintf("The `%s` arm payload has an invalid envelope.", arm))
  }
  if (identical(arm, "candidate")) {
    scalar_text(
      value$runtime_generation_sha256,
      "candidate runtime generation",
      "^[0-9a-f]{64}$"
    )
    if (!identical(value$runtime_integrity_check, TRUE)) {
      fail("The candidate runtime integrity check was not recorded.")
    }
  } else if (!is.null(value$runtime_generation_sha256) ||
             !identical(value$runtime_integrity_check, FALSE)) {
    fail("The baseline arm contains an invalid candidate-only field.")
  }
  for (profile in value$profiles) {
    method <- profile$method
    if (!identical(names(profile), c("method", "source", "partition", "artifacts")) ||
        !identical(profile$source, method) ||
        !identical(profile$partition, partition_for(method)) ||
        !is.list(profile$artifacts) ||
        !identical(
          vapply(profile$artifacts, `[[`, character(1L), "artifact"),
          names(ARTIFACTS)
        )) {
      fail(sprintf("The `%s` arm profile for `%s` is invalid.", arm, method))
    }
    for (artifact_profile in profile$artifacts) {
      validate_encoded_table(
        artifact_profile$table,
        COLUMNS[[artifact_profile$artifact]],
        paste(arm, method, artifact_profile$artifact, sep = "/")
      )
    }
  }
  invisible(TRUE)
}

arm_profile <- function(value, method) {
  value$profiles[[match(
    method,
    vapply(value$profiles, `[[`, character(1L), "method")
  )]]
}

arm_artifact <- function(profile, artifact) {
  profile$artifacts[[match(
    artifact,
    vapply(profile$artifacts, `[[`, character(1L), "artifact")
  )]]$table
}

build_manifest <- function(baseline, candidate) {
  validate_arm_payload(baseline, "baseline")
  validate_arm_payload(candidate, "candidate")
  profiles <- lapply(METHODS, function(method) {
    baseline_profile <- arm_profile(baseline, method)
    candidate_profile <- arm_profile(candidate, method)
    if (!identical(baseline_profile$source, candidate_profile$source) ||
        !identical(baseline_profile$partition, candidate_profile$partition)) {
      fail(sprintf("The two arm envelopes differ for `%s`.", method))
    }
    list(
      method = method,
      source = baseline_profile$source,
      partition = baseline_profile$partition,
      artifacts = lapply(names(ARTIFACTS), function(artifact) {
        list(
          artifact = artifact,
          baseline = arm_artifact(baseline_profile, artifact),
          candidate = arm_artifact(candidate_profile, artifact)
        )
      })
    )
  })
  list(
    schema = "wlv-issue13-metadata-equivalence/1",
    baseline_commit = EXPECTED_BASELINE_COMMIT,
    candidate_commit_at_derivation = EXPECTED_CANDIDATE_COMMIT,
    candidate_runtime_generation_sha256 = candidate$runtime_generation_sha256,
    derivation = DERIVATION_TEXT,
    methods = as.list(METHODS),
    artifacts = as.list(names(ARTIFACTS)),
    profiles = profiles
  )
}

validate_manifest <- function(value, exact_methods = METHODS) {
  if (!is.list(value) ||
      !identical(value$schema, "wlv-issue13-metadata-equivalence/1") ||
      !is.character(value$baseline_commit) || length(value$baseline_commit) != 1L ||
      !is.character(value$candidate_commit_at_derivation) ||
      length(value$candidate_commit_at_derivation) != 1L ||
      !is.character(value$candidate_runtime_generation_sha256) ||
      length(value$candidate_runtime_generation_sha256) != 1L ||
      !grepl("^[0-9a-f]{64}$", value$candidate_runtime_generation_sha256) ||
      !identical(value$derivation, DERIVATION_TEXT) ||
      !identical(unlist(value$methods, use.names = FALSE), exact_methods) ||
      !identical(unlist(value$artifacts, use.names = FALSE), names(ARTIFACTS)) ||
      !is.list(value$profiles) || length(value$profiles) != length(exact_methods) ||
      !identical(
        vapply(value$profiles, `[[`, character(1L), "method"),
        exact_methods
      )) {
    fail("Metadata equivalence manifest has an invalid envelope.")
  }
  for (profile in value$profiles) {
    method <- profile$method
    if (!identical(names(profile), c("method", "source", "partition", "artifacts")) ||
        !identical(profile$source, method) ||
        !identical(profile$partition, partition_for(method)) ||
        !is.list(profile$artifacts) ||
        !identical(
          vapply(profile$artifacts, `[[`, character(1L), "artifact"),
          names(ARTIFACTS)
        )) {
      fail(sprintf("Metadata profile envelope is invalid for `%s`.", method))
    }
    for (artifact_profile in profile$artifacts) {
      artifact <- artifact_profile$artifact
      if (!identical(names(artifact_profile), c("artifact", "baseline", "candidate"))) {
        fail(sprintf("Artifact envelope is invalid for `%s`/`%s`.", method, artifact))
      }
      for (arm in c("baseline", "candidate")) {
        validate_encoded_table(
          artifact_profile[[arm]],
          COLUMNS[[artifact]],
          paste(method, artifact, arm, sep = "/")
        )
      }
    }
  }
  invisible(TRUE)
}

profile_from_manifest <- function(value, method) {
  methods <- vapply(value$profiles, `[[`, character(1L), "method")
  index <- match(method, methods)
  if (is.na(index)) fail(sprintf("Metadata profile is missing `%s`.", method))
  value$profiles[[index]]
}

artifact_from_profile <- function(profile, artifact) {
  artifacts <- vapply(profile$artifacts, `[[`, character(1L), "artifact")
  index <- match(artifact, artifacts)
  if (is.na(index)) {
    fail(sprintf("Metadata artifact is missing `%s`/`%s`.", profile$method, artifact))
  }
  profile$artifacts[[index]]
}

validate_old_manifest <- function(value) {
  if (!is.list(value) ||
      !identical(value$schema, "wlv-issue13-metadata-equivalence/1") ||
      !identical(value$baseline_commit, EXPECTED_BASELINE_COMMIT) ||
      !identical(value$candidate_commit_at_derivation, EXPECTED_OLD_CANDIDATE_COMMIT) ||
      !is.character(value$candidate_runtime_generation_sha256) ||
      length(value$candidate_runtime_generation_sha256) != 1L ||
      !grepl("^[0-9a-f]{64}$", value$candidate_runtime_generation_sha256) ||
      !identical(value$derivation, DERIVATION_TEXT) ||
      !identical(unlist(value$artifacts, use.names = FALSE), names(ARTIFACTS)) ||
      !all(METHODS %in% unlist(value$methods, use.names = FALSE)) ||
      !is.list(value$profiles)) {
    fail("The prior V5 metadata equivalence manifest is invalid.")
  }
  observed_methods <- vapply(value$profiles, `[[`, character(1L), "method")
  if (anyDuplicated(observed_methods) || !all(METHODS %in% observed_methods)) {
    fail("The prior V5 manifest does not contain unique main-method profiles.")
  }
  for (method in METHODS) {
    profile <- profile_from_manifest(value, method)
    if (!identical(profile$source, method) ||
        !identical(profile$partition, partition_for(method)) ||
        !is.list(profile$artifacts) ||
        !identical(
          vapply(profile$artifacts, `[[`, character(1L), "artifact"),
          names(ARTIFACTS)
        )) {
      fail(sprintf("The prior V5 profile is invalid for `%s`.", method))
    }
    for (artifact in names(ARTIFACTS)) {
      artifact_profile <- artifact_from_profile(profile, artifact)
      for (arm in c("baseline", "candidate")) {
        validate_encoded_table(
          artifact_profile[[arm]],
          COLUMNS[[artifact]],
          paste("old", method, artifact, arm, sep = "/")
        )
      }
    }
  }
  invisible(TRUE)
}

make_difference_report <- function(old, new, old_sha256, new_sha256) {
  differences <- list()
  table_comparisons <- list()
  add_difference <- function(kind, path, old_value, new_value) {
    differences[[length(differences) + 1L]] <<- list(
      kind = kind,
      path = path,
      old = old_value,
      new = new_value
    )
  }
  compare_value <- function(kind, path, old_value, new_value) {
    if (!identical(old_value, new_value)) {
      add_difference(kind, path, old_value, new_value)
    }
  }

  compare_value("manifest", "schema", old$schema, new$schema)
  compare_value(
    "manifest", "baseline_commit", old$baseline_commit, new$baseline_commit
  )
  compare_value(
    "manifest", "candidate_commit_at_derivation",
    old$candidate_commit_at_derivation,
    new$candidate_commit_at_derivation
  )
  compare_value(
    "manifest", "candidate_runtime_generation_sha256",
    old$candidate_runtime_generation_sha256,
    new$candidate_runtime_generation_sha256
  )
  compare_value("manifest", "derivation", old$derivation, new$derivation)
  compare_value(
    "manifest", "methods",
    unlist(old$methods, use.names = FALSE),
    unlist(new$methods, use.names = FALSE)
  )
  compare_value(
    "manifest", "artifacts",
    unlist(old$artifacts, use.names = FALSE),
    unlist(new$artifacts, use.names = FALSE)
  )

  for (method in METHODS) {
    old_profile <- profile_from_manifest(old, method)
    new_profile <- profile_from_manifest(new, method)
    compare_value(
      "profile_envelope", paste(method, "source", sep = "/"),
      old_profile$source, new_profile$source
    )
    compare_value(
      "profile_envelope", paste(method, "partition", sep = "/"),
      old_profile$partition, new_profile$partition
    )
    compare_value(
      "profile_envelope", paste(method, "artifacts", sep = "/"),
      vapply(old_profile$artifacts, `[[`, character(1L), "artifact"),
      vapply(new_profile$artifacts, `[[`, character(1L), "artifact")
    )
    for (artifact in names(ARTIFACTS)) {
      old_artifact <- artifact_from_profile(old_profile, artifact)
      new_artifact <- artifact_from_profile(new_profile, artifact)
      for (arm in c("baseline", "candidate")) {
        old_table <- old_artifact[[arm]]
        new_table <- new_artifact[[arm]]
        old_columns <- unlist(old_table$columns, use.names = FALSE)
        new_columns <- unlist(new_table$columns, use.names = FALSE)
        old_rows <- old_table$rows
        new_rows <- new_table$rows
        base_path <- paste(method, artifact, arm, sep = "/")
        compare_value(
          "schema", paste(base_path, "columns", sep = "/"),
          old_columns, new_columns
        )
        if (length(old_rows) != length(new_rows)) {
          add_difference(
            "row_count", paste(base_path, "rows", sep = "/"),
            length(old_rows), length(new_rows)
          )
        }
        row_limit <- max(length(old_rows), length(new_rows))
        column_limit <- max(length(old_columns), length(new_columns))
        if (row_limit && column_limit) {
          for (row_index in seq_len(row_limit)) {
            for (column_index in seq_len(column_limit)) {
              old_present <- row_index <= length(old_rows) &&
                column_index <= length(old_columns)
              new_present <- row_index <= length(new_rows) &&
                column_index <= length(new_columns)
              old_value <- if (old_present) old_rows[[row_index]][[column_index]] else NULL
              new_value <- if (new_present) new_rows[[row_index]][[column_index]] else NULL
              if (!identical(old_present, new_present) ||
                  (old_present && !identical(old_value, new_value))) {
                differences[[length(differences) + 1L]] <- list(
                  kind = "cell",
                  path = paste(base_path, sprintf("row[%d]", row_index),
                    sprintf("column[%d]", column_index), sep = "/"),
                  row = row_index,
                  column = column_index,
                  old_column = if (column_index <= length(old_columns))
                    old_columns[[column_index]] else NULL,
                  new_column = if (column_index <= length(new_columns))
                    new_columns[[column_index]] else NULL,
                  old = list(present = old_present, value = old_value),
                  new = list(present = new_present, value = new_value)
                )
              }
            }
          }
        }
        table_comparisons[[length(table_comparisons) + 1L]] <- list(
          method = method,
          artifact = artifact,
          arm = arm,
          old_rows = length(old_rows),
          new_rows = length(new_rows),
          columns = length(new_columns),
          old_cells = length(old_rows) * length(old_columns),
          new_cells = length(new_rows) * length(new_columns),
          old_canonical_sha256 = sha256_json(old_table),
          new_canonical_sha256 = sha256_json(new_table),
          identical = identical(old_table, new_table)
        )
      }
    }
  }

  kinds <- if (length(differences)) {
    vapply(differences, `[[`, character(1L), "kind")
  } else {
    character()
  }
  list(
    schema = "wlv-issue13-main-metadata-profile-diff/1",
    scope = list(
      methods = as.list(METHODS),
      artifacts = as.list(names(ARTIFACTS)),
      arms = as.list(c("baseline", "candidate")),
      comparison = "ordered schema, row count and every cell by position"
    ),
    old_manifest_sha256 = old_sha256,
    new_manifest_sha256 = new_sha256,
    old_candidate_commit_at_derivation = old$candidate_commit_at_derivation,
    new_candidate_commit_at_derivation = new$candidate_commit_at_derivation,
    old_candidate_runtime_generation_sha256 =
      old$candidate_runtime_generation_sha256,
    new_candidate_runtime_generation_sha256 =
      new$candidate_runtime_generation_sha256,
    table_comparisons = table_comparisons,
    differences = differences,
    summary = list(
      table_count = length(table_comparisons),
      identical_table_count = sum(vapply(
        table_comparisons, `[[`, logical(1L), "identical"
      )),
      manifest_difference_count = sum(kinds == "manifest"),
      profile_envelope_difference_count = sum(kinds == "profile_envelope"),
      schema_difference_count = sum(kinds == "schema"),
      row_count_difference_count = sum(kinds == "row_count"),
      cell_difference_count = sum(kinds == "cell"),
      total_difference_count = length(differences),
      all_scoped_tables_identical = all(vapply(
        table_comparisons, `[[`, logical(1L), "identical"
      ))
    )
  )
}

make_arm_equivalence <- function(baseline, oracle) {
  validate_arm_payload(baseline, "baseline")
  validate_arm_payload(oracle, "oracle")
  differences <- list()
  tables <- list()
  add_difference <- function(kind, path, baseline_value, oracle_value) {
    differences[[length(differences) + 1L]] <<- list(
      kind = kind,
      path = path,
      baseline = baseline_value,
      oracle = oracle_value
    )
  }
  for (method in METHODS) {
    baseline_profile <- arm_profile(baseline, method)
    oracle_profile <- arm_profile(oracle, method)
    for (field in c("source", "partition")) {
      if (!identical(baseline_profile[[field]], oracle_profile[[field]])) {
        add_difference(
          "profile_envelope", paste(method, field, sep = "/"),
          baseline_profile[[field]], oracle_profile[[field]]
        )
      }
    }
    for (artifact in names(ARTIFACTS)) {
      baseline_table <- arm_artifact(baseline_profile, artifact)
      oracle_table <- arm_artifact(oracle_profile, artifact)
      baseline_columns <- unlist(baseline_table$columns, use.names = FALSE)
      oracle_columns <- unlist(oracle_table$columns, use.names = FALSE)
      path <- paste(method, artifact, sep = "/")
      if (!identical(baseline_columns, oracle_columns)) {
        add_difference(
          "schema", paste(path, "columns", sep = "/"),
          baseline_columns, oracle_columns
        )
      }
      if (length(baseline_table$rows) != length(oracle_table$rows)) {
        add_difference(
          "row_count", paste(path, "rows", sep = "/"),
          length(baseline_table$rows), length(oracle_table$rows)
        )
      }
      row_limit <- max(length(baseline_table$rows), length(oracle_table$rows))
      column_limit <- max(length(baseline_columns), length(oracle_columns))
      if (row_limit && column_limit) {
        for (row_index in seq_len(row_limit)) {
          for (column_index in seq_len(column_limit)) {
            baseline_present <- row_index <= length(baseline_table$rows) &&
              column_index <= length(baseline_columns)
            oracle_present <- row_index <= length(oracle_table$rows) &&
              column_index <= length(oracle_columns)
            baseline_value <- if (baseline_present) {
              baseline_table$rows[[row_index]][[column_index]]
            } else NULL
            oracle_value <- if (oracle_present) {
              oracle_table$rows[[row_index]][[column_index]]
            } else NULL
            if (!identical(baseline_present, oracle_present) ||
                (baseline_present && !identical(baseline_value, oracle_value))) {
              differences[[length(differences) + 1L]] <- list(
                kind = "cell",
                path = paste(path, sprintf("row[%d]", row_index),
                  sprintf("column[%d]", column_index), sep = "/"),
                row = row_index,
                column = column_index,
                baseline = list(present = baseline_present, value = baseline_value),
                oracle = list(present = oracle_present, value = oracle_value)
              )
            }
          }
        }
      }
      tables[[length(tables) + 1L]] <- list(
        method = method,
        artifact = artifact,
        baseline_rows = length(baseline_table$rows),
        oracle_rows = length(oracle_table$rows),
        baseline_canonical_sha256 = sha256_json(baseline_table),
        oracle_canonical_sha256 = sha256_json(oracle_table),
        identical = identical(baseline_table, oracle_table)
      )
    }
  }
  result <- list(
    schema = "wlv-issue13-main-oracle-metadata-applicability/1",
    metadata_baseline_commit = EXPECTED_BASELINE_COMMIT,
    executed_oracle_commit = EXPECTED_ORACLE_COMMIT,
    comparison = "ordered schema, row count and every cell by position",
    table_comparisons = tables,
    differences = differences,
    summary = list(
      table_count = length(tables),
      identical_table_count = sum(vapply(tables, `[[`, logical(1L), "identical")),
      difference_count = length(differences),
      all_tables_identical = all(vapply(tables, `[[`, logical(1L), "identical"))
    )
  )
  result$canonical_sha256 <- sha256_json(result)
  result
}

expect_error <- function(expression) {
  tryCatch(
    {
      force(expression)
      FALSE
    },
    error = function(error) TRUE
  )
}

profile_negative_smoke <- function(manifest) {
  bad_method <- manifest
  bad_method$methods[[1L]] <- "not-a-main-method"
  method_rejected <- expect_error(validate_manifest(bad_method))

  bad_generation <- manifest
  bad_generation$candidate_runtime_generation_sha256 <- "not-a-sha256"
  generation_rejected <- expect_error(validate_manifest(bad_generation))

  bad_cell <- manifest
  original_cell <- bad_cell$profiles[[1L]]$artifacts[[1L]]$candidate$rows[[1L]][[1L]]
  bad_cell$profiles[[1L]]$artifacts[[1L]]$candidate$rows[[1L]][[1L]] <-
    paste0(original_cell, ".negative-smoke")
  cell_report <- make_difference_report(
    manifest, bad_cell, sha256_json(manifest), sha256_json(bad_cell)
  )
  cell_detected <- cell_report$summary$cell_difference_count == 1L &&
    !cell_report$summary$all_scoped_tables_identical

  bad_order <- manifest
  rows <- bad_order$profiles[[1L]]$artifacts[[1L]]$candidate$rows
  if (length(rows) < 2L) fail("Negative order smoke requires two metadata rows.")
  bad_order$profiles[[1L]]$artifacts[[1L]]$candidate$rows[1:2] <- rows[2:1]
  order_report <- make_difference_report(
    manifest, bad_order, sha256_json(manifest), sha256_json(bad_order)
  )
  order_detected <- order_report$summary$cell_difference_count > 0L &&
    !order_report$summary$all_scoped_tables_identical

  result <- list(
    schema = "wlv-issue13-main-metadata-negative-smoke/1",
    method_mutation_rejected = method_rejected,
    generation_mutation_rejected = generation_rejected,
    cell_mutation_detected = cell_detected,
    order_mutation_detected = order_detected,
    passed = all(c(
      method_rejected, generation_rejected, cell_detected, order_detected
    ))
  )
  if (!result$passed) fail("The metadata negative smoke did not detect every mutation.")
  result
}

run_process <- function(executable, arguments, stdout_path, stderr_path) {
  status <- system2(
    executable,
    args = arguments,
    stdout = stdout_path,
    stderr = stderr_path,
    wait = TRUE
  )
  if (is.null(status)) status <- 0L
  as.integer(status)
}

command_output <- function(executable, arguments, label) {
  value <- system2(
    executable,
    args = arguments,
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(value, "status", exact = TRUE)
  if (!is.null(status) && status != 0L) {
    fail(sprintf("Cannot read %s.", label))
  }
  enc2utf8(value)
}

git_output <- function(git_executable, root, arguments, label) {
  command_output(
    git_executable,
    c("-C", shQuote(root), arguments),
    label
  )
}

git_scalar <- function(git_executable, root, arguments, label) {
  value <- git_output(git_executable, root, arguments, label)
  if (length(value) != 1L || !nzchar(trimws(value[[1L]]))) {
    fail(sprintf("Git returned a non-scalar %s.", label))
  }
  trimws(value[[1L]])
}

git_record <- function(git_executable, root, expected_commit, arm) {
  top_level <- normalizePath(
    git_scalar(git_executable, root, c("rev-parse", "--show-toplevel"),
      paste(arm, "top level")),
    winslash = "/",
    mustWork = TRUE
  )
  if (!identical(top_level, root)) {
    fail(sprintf("The `%s` root is not its Git top level.", arm))
  }
  commit <- git_scalar(
    git_executable, root, c("rev-parse", "HEAD"), paste(arm, "commit")
  )
  if (!identical(commit, expected_commit)) {
    fail(sprintf(
      "The `%s` commit differs: expected %s, found %s.",
      arm, expected_commit, commit
    ))
  }
  status <- git_output(
    git_executable,
    root,
    c("status", "--porcelain=v1", "--untracked-files=all"),
    paste(arm, "status")
  )
  if (length(status)) {
    fail(sprintf("The `%s` metadata worktree is not clean.", arm))
  }
  prohibited <- c(
    "source_data", "source_datax", "results", "resultsx", "results_nuvem",
    "temp", "renv/library", "renv/local", "renv/staging", "renv/cellar"
  )
  present <- prohibited[file.exists(file.path(root, prohibited)) |
    dir.exists(file.path(root, prohibited))]
  if (length(present)) {
    fail(sprintf(
      "The `%s` metadata worktree is not code-only: %s.",
      arm, paste(present, collapse = ", ")
    ))
  }
  inventory <- git_output(
    git_executable,
    root,
    c("ls-files", "--stage"),
    paste(arm, "tracked inventory")
  )
  list(
    arm = arm,
    root = root,
    commit = commit,
    tree = git_scalar(
      git_executable, root, c("rev-parse", "HEAD^{tree}"), paste(arm, "tree")
    ),
    tracked_status_clean = TRUE,
    untracked_status_clean = TRUE,
    code_only = TRUE,
    prohibited_directories_absent = as.list(prohibited),
    tracked_file_count = length(inventory),
    tracked_inventory_sha256 = sha256_text(paste(inventory, collapse = "\n"))
  )
}

file_record <- function(path) {
  path <- normalize_existing_file(path, "provenance file")
  list(
    path = path,
    size_bytes = unname(file.info(path)$size),
    sha256 = wlv_gate_sha256(path)
  )
}

read_log_lines <- function(path) {
  if (!file.exists(path) || file.info(path)$size == 0) return(character())
  value <- readLines(path, warn = FALSE, encoding = "UTF-8")
  enc2utf8(value)
}

main <- function(arguments) {
  if (length(arguments) != 6L) {
    fail(paste(
      "Usage: issue13-main-build-metadata.R",
      "<baseline-code-worktree> <oracle-code-worktree>",
      "<candidate-code-worktree>",
      "<helper.R> <old-profile.json> <new-output-directory>"
    ))
  }
  baseline_root <- normalize_existing_directory(arguments[[1L]], "baseline root")
  oracle_root <- normalize_existing_directory(arguments[[2L]], "oracle root")
  candidate_root <- normalize_existing_directory(arguments[[3L]], "candidate root")
  helper_path <- normalize_existing_file(arguments[[4L]], "helper path")
  old_profile_path <- normalize_existing_file(arguments[[5L]], "old profile path")
  output_root <- normalize_new_directory(arguments[[6L]], "output root")
  roots <- c(baseline_root, oracle_root, candidate_root)
  comparable_roots <- if (.Platform$OS.type == "windows") tolower(roots) else roots
  if (anyDuplicated(comparable_roots)) {
    fail("Baseline, oracle and candidate metadata worktrees must be distinct.")
  }
  generator_path <- script_path()
  initialize_dependencies(helper_path)

  previous_collate <- Sys.getlocale("LC_COLLATE")
  observed_collate <- suppressWarnings(Sys.setlocale("LC_COLLATE", "C"))
  if (!identical(observed_collate, "C")) {
    fail("The metadata derivation requires the C collation locale.")
  }
  on.exit(suppressWarnings(Sys.setlocale("LC_COLLATE", previous_collate)), add = TRUE)

  git_executable <- Sys.getenv("WLV_ISSUE13_GIT_EXECUTABLE", unset = "")
  if (!nzchar(git_executable)) git_executable <- Sys.which("git")
  git_executable <- normalize_existing_file(git_executable, "Git executable")
  rscript_executable <- normalize_existing_file(
    file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"),
    "Rscript executable"
  )
  library_root <- Sys.getenv("WLV_ISSUE13_R_LIBRARY", unset = "")
  if (!nzchar(library_root)) {
    fail("WLV_ISSUE13_R_LIBRARY must pin the metadata derivation library.")
  }
  library_root <- normalize_existing_directory(library_root, "R library")

  baseline_git <- git_record(
    git_executable, baseline_root, EXPECTED_BASELINE_COMMIT, "baseline"
  )
  oracle_git <- git_record(
    git_executable, oracle_root, EXPECTED_ORACLE_COMMIT, "oracle"
  )
  candidate_git <- git_record(
    git_executable, candidate_root, EXPECTED_CANDIDATE_COMMIT, "candidate"
  )
  old_manifest <- read_json(old_profile_path)
  validate_old_manifest(old_manifest)

  staging_root <- tempfile(
    pattern = paste0(".", basename(output_root), ".staging-"),
    tmpdir = dirname(output_root)
  )
  if (!dir.create(staging_root, recursive = FALSE, showWarnings = FALSE)) {
    fail(sprintf("Cannot create staging directory `%s`.", staging_root))
  }
  staging_root <- normalizePath(staging_root, winslash = "/", mustWork = TRUE)
  on.exit({
    if (dir.exists(staging_root)) unlink(staging_root, recursive = TRUE, force = TRUE)
  }, add = TRUE)

  arm_outputs <- list()
  arm_processes <- list()
  for (arm in c("baseline", "oracle", "candidate")) {
    root <- switch(arm,
      baseline = baseline_root,
      oracle = oracle_root,
      candidate = candidate_root
    )
    arm_path <- file.path(staging_root, paste0(".", arm, "-arm.json"))
    stdout_path <- file.path(staging_root, paste0(".", arm, ".stdout.log"))
    stderr_path <- file.path(staging_root, paste0(".", arm, ".stderr.log"))
    status <- run_process(
      rscript_executable,
      c(
        "--vanilla", shQuote(generator_path), "--derive-arm", arm,
        shQuote(root), shQuote(helper_path), shQuote(arm_path)
      ),
      stdout_path,
      stderr_path
    )
    stdout_lines <- read_log_lines(stdout_path)
    stderr_lines <- read_log_lines(stderr_path)
    if (status != 0L) {
      fail(sprintf(
        "The isolated `%s` metadata derivation failed with exit status %d: %s",
        arm, status, paste(stderr_lines, collapse = " | ")
      ))
    }
    arm_payload <- read_json(arm_path)
    validate_arm_payload(arm_payload, arm)
    arm_outputs[[arm]] <- arm_payload
    arm_processes[[arm]] <- list(
      arm = arm,
      exit_status = status,
      payload_sha256 = wlv_gate_sha256(arm_path),
      stdout_sha256 = wlv_gate_sha256(stdout_path),
      stderr_sha256 = wlv_gate_sha256(stderr_path),
      stdout = as.list(stdout_lines),
      stderr = as.list(stderr_lines)
    )
  }

  input_reverification <- list(
    baseline = git_record(
      git_executable, baseline_root, EXPECTED_BASELINE_COMMIT, "baseline"
    ),
    oracle = git_record(
      git_executable, oracle_root, EXPECTED_ORACLE_COMMIT, "oracle"
    ),
    candidate = git_record(
      git_executable, candidate_root, EXPECTED_CANDIDATE_COMMIT, "candidate"
    )
  )
  if (!identical(input_reverification$baseline, baseline_git) ||
      !identical(input_reverification$oracle, oracle_git) ||
      !identical(input_reverification$candidate, candidate_git)) {
    fail("A metadata code worktree changed during isolated derivation.")
  }

  manifest <- build_manifest(arm_outputs$baseline, arm_outputs$candidate)
  validate_manifest(manifest)
  oracle_equivalence <- make_arm_equivalence(
    arm_outputs$baseline, arm_outputs$oracle
  )
  if (!identical(oracle_equivalence$summary$all_tables_identical, TRUE)) {
    details <- vapply(oracle_equivalence$differences, function(difference) {
      sprintf("%s: %s", difference$kind, difference$path)
    }, character(1L))
    fail(paste(
      "The cc2c861 metadata is not applicable to the e2f4d6d oracle:",
      paste(details, collapse = "; ")
    ))
  }
  negative_smoke <- profile_negative_smoke(manifest)
  metadata_path <- file.path(staging_root, "metadata-derived.json")
  write_json_once(manifest, metadata_path)
  metadata_sha256 <- wlv_gate_sha256(metadata_path)
  old_profile_sha256 <- wlv_gate_sha256(old_profile_path)

  difference_report <- make_difference_report(
    old_manifest,
    manifest,
    old_profile_sha256,
    metadata_sha256
  )
  difference_path <- file.path(staging_root, "metadata-diff-vs-v5.json")
  write_json_once(difference_report, difference_path)

  table_hashes <- unlist(lapply(manifest$profiles, function(profile) {
    unlist(lapply(profile$artifacts, function(artifact) {
      lapply(c("baseline", "candidate"), function(arm) {
        list(
          method = profile$method,
          artifact = artifact$artifact,
          arm = arm,
          row_count = length(artifact[[arm]]$rows),
          column_count = length(artifact[[arm]]$columns),
          cell_count = length(artifact[[arm]]$rows) *
            length(artifact[[arm]]$columns),
          canonical_sha256 = sha256_json(artifact[[arm]])
        )
      })
    }), recursive = FALSE)
  }), recursive = FALSE)

  provenance <- list(
    schema = "wlv-issue13-main-metadata-derivation-provenance/1",
    generated_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC"),
    purpose = paste(
      "Code-only reconstruction of the exact metadata profiles for the two",
      "main public methods; no scientific payload was opened or calculated."
    ),
    derivation = list(
      isolated_r_process_per_arm = TRUE,
      scientific_payloads_opened = FALSE,
      calculations_executed = FALSE,
      methods = as.list(METHODS),
      artifacts = as.list(names(ARTIFACTS)),
      planner_formals = as.list(PLANNER_FORMALS),
      allow_experimental = TRUE,
      allow_experimental_rationale = paste(
        "Matches the frozen comparison reconstruction call; both selected",
        "methods are stable and calculable at the pinned candidate commit."
      )
    ),
    inputs = list(
      baseline = baseline_git,
      oracle = oracle_git,
      candidate = candidate_git,
      generator = file_record(generator_path),
      helper = file_record(helper_path),
      old_profile = file_record(old_profile_path)
    ),
    runtime = list(
      rscript = file_record(rscript_executable),
      r_version = R.version.string,
      platform = R.version$platform,
      git = file_record(git_executable),
      git_version = paste(command_output(
        git_executable, "--version", "Git version"
      ), collapse = "\n"),
      library_root = library_root,
      jsonlite_version = as.character(utils::packageVersion("jsonlite")),
      openssl_version = as.character(utils::packageVersion("openssl")),
      lc_collate = Sys.getlocale("LC_COLLATE")
    ),
    isolated_processes = arm_processes,
    input_reverification = input_reverification,
    oracle_applicability = oracle_equivalence,
    profile_negative_smoke = negative_smoke,
    table_hashes = table_hashes,
    outputs = list(
      metadata = list(
        relative_path = "metadata-derived.json",
        size_bytes = unname(file.info(metadata_path)$size),
        sha256 = metadata_sha256
      ),
      difference_report = list(
        relative_path = "metadata-diff-vs-v5.json",
        size_bytes = unname(file.info(difference_path)$size),
        sha256 = wlv_gate_sha256(difference_path)
      )
    ),
    validation = list(
      exact_commits = TRUE,
      clean_code_only_worktrees = TRUE,
      exact_methods_and_order = TRUE,
      exact_artifacts_and_order = TRUE,
      exact_schemas = TRUE,
      every_cell_is_utf8_scalar_text = TRUE,
      oracle_metadata_exactly_matches_baseline = TRUE,
      candidate_runtime_unchanged = TRUE,
      json_byte_round_trip = TRUE,
      json_semantic_round_trip = TRUE,
      old_profiles_compared_exhaustively = TRUE,
      negative_method_generation_cell_order_smoke = TRUE
    )
  )
  provenance_path <- file.path(staging_root, "metadata-derivation-provenance.json")
  write_json_once(provenance, provenance_path)

  expected_files <- c(
    "metadata-derived.json",
    "metadata-diff-vs-v5.json",
    "metadata-derivation-provenance.json"
  )
  temporary_files <- list.files(staging_root, all.files = TRUE, no.. = TRUE)
  removable <- setdiff(temporary_files, expected_files)
  for (name in removable) {
    path <- file.path(staging_root, name)
    if (file.exists(path) && !isTRUE(file.info(path)$isdir)) unlink(path, force = TRUE)
  }
  if (!identical(sort(list.files(staging_root)), sort(expected_files))) {
    fail("The metadata output staging directory has an unexpected inventory.")
  }

  validate_manifest(read_json(metadata_path))
  if (!identical(read_json(difference_path), normalized_json_value(difference_report)) ||
      !identical(read_json(provenance_path), normalized_json_value(provenance))) {
    fail("A final metadata report failed semantic verification.")
  }
  if (file.exists(output_root) || dir.exists(output_root)) {
    fail(sprintf("Output appeared concurrently: `%s`.", output_root))
  }
  if (!file.rename(staging_root, output_root)) {
    fail(sprintf("Cannot atomically install metadata output `%s`.", output_root))
  }
  output_root <- normalizePath(output_root, winslash = "/", mustWork = TRUE)
  final_metadata <- file.path(output_root, "metadata-derived.json")
  final_difference <- file.path(output_root, "metadata-diff-vs-v5.json")
  final_provenance <- file.path(output_root, "metadata-derivation-provenance.json")
  validate_manifest(read_json(final_metadata))
  if (!identical(wlv_gate_sha256(final_metadata), metadata_sha256) ||
      !identical(
        wlv_gate_sha256(final_difference),
        provenance$outputs$difference_report$sha256
      )) {
    fail("Installed metadata output hashes differ from staged hashes.")
  }
  cat(sprintf(
    paste0(
      "issue13 main metadata: %d methods, %d artifact pairs, ",
      "%d scoped cell differences versus V5\n%s\n"
    ),
    length(METHODS),
    length(METHODS) * length(ARTIFACTS),
    difference_report$summary$cell_difference_count,
    output_root
  ))
  invisible(output_root)
}

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) && identical(arguments[[1L]], "--derive-arm")) {
  if (length(arguments) != 5L) {
    fail(paste(
      "Internal usage: issue13-main-build-metadata.R --derive-arm",
      "<baseline|oracle|candidate> <root> <helper.R> <output.json>"
    ))
  }
  derive_arm(
    arguments[[2L]], arguments[[3L]], arguments[[4L]], arguments[[5L]]
  )
} else {
  main(arguments)
}
