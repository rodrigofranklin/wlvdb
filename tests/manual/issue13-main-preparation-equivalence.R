# Narrow preparation-equivalence override for the reduced Issue #13 gate.
#
# The historical profile remains immutable.  For the e2f4 baseline only, this
# helper derives the expected versioned source manifests from sealed profile
# cells and the pinned e2f4 manifest implementation.  It also replaces the
# historical legacy-vs-versioned sidecar rule with an exact
# versioned-vs-versioned rule for the two supported WIOD sources.

wlv13_main_prep_constants <- function() {
  list(
    schema = "wlv-issue13-main-preparation-equivalence/1",
    baseline_commit = "e2f4d6dae9a6d35c966b305fabac52e489faa3e7",
    candidate_commit = "654959715f9484adb15e16946c27ddbc9648ffa2",
    original_profile_sha256 =
      "e64b5a94b99417822621ec8d73ddb290ed88d7a000dec1e47073a4b1b147e6a1",
    source_manifest_sha256 =
      "eb986753356ff936286fa69d9014f2968a8be028f375a7b01a152fca04d7aba5",
    sources = c("wiodr13", "wiodr16"),
    sidecars = c("m_io.fst.meta", "sea.fst.meta")
  )
}

wlv13_main_prep_namespace_function <- function(namespace, name) {
  if (!is.environment(namespace) ||
      !exists(name, envir = namespace, inherits = FALSE)) {
    stop(sprintf("Required preparation function `%s` is unavailable.", name),
      call. = FALSE)
  }
  value <- get(name, envir = namespace, inherits = FALSE)
  if (!is.function(value)) {
    stop(sprintf("Required preparation binding `%s` is not a function.", name),
      call. = FALSE)
  }
  value
}

wlv13_main_prep_same_path <- function(left, right) {
  left <- normalizePath(left, winslash = "/", mustWork = TRUE)
  right <- normalizePath(right, winslash = "/", mustWork = TRUE)
  if (.Platform$OS.type == "windows") {
    left <- tolower(left)
    right <- tolower(right)
  }
  identical(left, right)
}

wlv13_main_prep_profile_artifact <- function(profile, arm, artifact) {
  records <- profile[[arm]]$artifacts
  index <- match(
    artifact,
    vapply(records, `[[`, character(1L), "artifact")
  )
  if (is.na(index)) {
    stop(sprintf("Missing sealed profile artifact `%s/%s/%s`.",
      profile$source, arm, artifact), call. = FALSE)
  }
  records[[index]]
}

wlv13_main_prep_table_differences <- function(left, right) {
  if (!is.data.frame(left) || !is.data.frame(right) ||
      !identical(names(left), names(right)) ||
      !identical(dim(left), dim(right))) {
    stop("Cannot audit preparation tables with different schemas or sizes.",
      call. = FALSE)
  }
  differences <- list()
  cursor <- 0L
  for (row in seq_len(nrow(left))) {
    for (column in names(left)) {
      if (!identical(left[[column]][[row]], right[[column]][[row]])) {
        cursor <- cursor + 1L
        differences[[cursor]] <- list(
          row = row,
          artifact = left$artifact[[row]],
          column = column,
          before = left[[column]][[row]],
          after = right[[column]][[row]]
        )
      }
    }
  }
  differences
}

wlv13_main_prep_json_sha256 <- function(namespace, value) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package `jsonlite` is required for preparation derivation.",
      call. = FALSE)
  }
  hash_text <- wlv13_main_prep_namespace_function(
    namespace, "wlv13_sha256_text"
  )
  hash_text(as.character(jsonlite::toJSON(
    value,
    auto_unbox = TRUE,
    digits = NA,
    null = "null",
    na = "string"
  )))
}

wlv13_main_prep_build_binding <- function(
    namespace,
    baseline_root,
    candidate_root) {
  constants <- wlv13_main_prep_constants()
  baseline_root <- normalizePath(
    baseline_root, winslash = "/", mustWork = TRUE
  )
  candidate_root <- normalizePath(
    candidate_root, winslash = "/", mustWork = TRUE
  )

  git_commit <- wlv13_main_prep_namespace_function(
    namespace, "wlv_gate_git_commit"
  )
  baseline_commit <- git_commit(baseline_root)
  candidate_commit <- git_commit(candidate_root)
  if (!identical(baseline_commit, constants$baseline_commit) ||
      !identical(candidate_commit, constants$candidate_commit)) {
    stop("Preparation equivalence is bound only to e2f4 baseline and 6549597 candidate.",
      call. = FALSE)
  }

  if (!exists("preparation_equivalence_path", envir = namespace,
      inherits = FALSE)) {
    stop("The historical preparation profile path is unavailable.",
      call. = FALSE)
  }
  profile_path <- normalizePath(
    get("preparation_equivalence_path", envir = namespace, inherits = FALSE),
    winslash = "/",
    mustWork = TRUE
  )
  file_sha256 <- wlv13_main_prep_namespace_function(
    namespace, "wlv13_v5p_file_sha256"
  )
  profile_sha256 <- file_sha256(profile_path)
  if (!identical(profile_sha256, constants$original_profile_sha256)) {
    stop("The historical preparation profile is not the pinned profile.",
      call. = FALSE)
  }
  load_profile <- wlv13_main_prep_namespace_function(
    namespace, "wlv13_v5p_manifest"
  )
  original_manifest <- load_profile(profile_path)

  source_manifest_path <- file.path(
    baseline_root, "R", "lib", "source_manifest.R"
  )
  source_manifest_path <- normalizePath(
    source_manifest_path, winslash = "/", mustWork = TRUE
  )
  source_manifest_sha256 <- file_sha256(source_manifest_path)
  if (!identical(
      source_manifest_sha256,
      constants$source_manifest_sha256
  )) {
    stop("The e2f4 source-manifest implementation is not the pinned file.",
      call. = FALSE)
  }
  source_manifest_namespace <- new.env(parent = baseenv())
  sys.source(
    source_manifest_path,
    envir = source_manifest_namespace,
    chdir = FALSE
  )
  for (name in c(
      "wlv_source_manifest_schema",
      "wlv_source_manifest_generation_id",
      "wlv_validate_source_manifest",
      "wlv_write_source_manifest",
      "wlv_read_source_manifest"
  )) {
    if (!exists(name, envir = source_manifest_namespace, inherits = FALSE)) {
      stop(sprintf("Pinned source-manifest definition `%s` is unavailable.",
        name), call. = FALSE)
    }
  }

  decode_table <- wlv13_main_prep_namespace_function(
    namespace, "wlv13_v5p_decode_table"
  )
  encode_table <- wlv13_main_prep_namespace_function(
    namespace, "wlv13_v5p_encode_table"
  )
  table_sha256 <- wlv13_main_prep_namespace_function(
    namespace, "wlv13_v5p_table_sha256"
  )
  validate_profile <- wlv13_main_prep_namespace_function(
    namespace, "wlv13_v5p_validate_manifest"
  )

  derived_manifest <- original_manifest
  temporary_root <- tempfile("wlv13-main-preparation-profile-")
  if (!dir.create(temporary_root, recursive = FALSE, showWarnings = FALSE)) {
    stop("Could not create the exclusive preparation-profile workspace.",
      call. = FALSE)
  }
  on.exit(unlink(temporary_root, recursive = TRUE, force = TRUE), add = TRUE)

  derivations <- vector("list", length(constants$sources))
  names(derivations) <- constants$sources
  for (source in constants$sources) {
    profile_index <- match(source, vapply(
      original_manifest$profiles, `[[`, character(1L), "source"
    ))
    if (is.na(profile_index)) {
      stop(sprintf("The sealed profile omits `%s`.", source), call. = FALSE)
    }
    original_profile <- original_manifest$profiles[[profile_index]]
    baseline_artifact <- wlv13_main_prep_profile_artifact(
      original_profile, "baseline", "_source_manifest.csv"
    )
    candidate_artifact <- wlv13_main_prep_profile_artifact(
      original_profile, "candidate", "_source_manifest.csv"
    )
    baseline_table <- decode_table(
      baseline_artifact$table,
      paste0(source, "/sealed-baseline/_source_manifest.csv")
    )
    candidate_table <- decode_table(
      candidate_artifact$table,
      paste0(source, "/sealed-candidate/_source_manifest.csv")
    )
    expected_schema <- get(
      "wlv_source_manifest_schema",
      envir = source_manifest_namespace,
      inherits = FALSE
    )
    if (!identical(names(baseline_table), expected_schema) ||
        !identical(names(candidate_table), expected_schema) ||
        !identical(baseline_table$artifact, candidate_table$artifact)) {
      stop(sprintf("The sealed `%s` source-manifest tables are incompatible.",
        source), call. = FALSE)
    }
    source_manifest_namespace$wlv_validate_source_manifest(baseline_table)
    source_manifest_namespace$wlv_validate_source_manifest(candidate_table)

    for (payload in c("m_io.fst", "sea.fst")) {
      row <- match(payload, baseline_table$artifact)
      candidate_row <- match(payload, candidate_table$artifact)
      if (is.na(row) || is.na(candidate_row) ||
          !identical(
            baseline_table[row, c("artifact", "artifact_role", "size_bytes", "sha256")],
            candidate_table[candidate_row, c(
              "artifact", "artifact_role", "size_bytes", "sha256"
            )]
          )) {
        stop(sprintf("The sealed `%s/%s` payload identity is not cross-arm exact.",
          source, payload), call. = FALSE)
      }
    }

    derived_table <- baseline_table
    sealed_replacements <- vector("list", length(constants$sidecars))
    names(sealed_replacements) <- constants$sidecars
    for (sidecar in constants$sidecars) {
      baseline_row <- match(sidecar, derived_table$artifact)
      candidate_row <- match(sidecar, candidate_table$artifact)
      if (is.na(baseline_row) || is.na(candidate_row) ||
          sum(derived_table$artifact == sidecar) != 1L ||
          sum(candidate_table$artifact == sidecar) != 1L) {
        stop(sprintf("The sealed sidecar row `%s/%s` is not unique.",
          source, sidecar), call. = FALSE)
      }
      replacement <- candidate_table[
        candidate_row, c("size_bytes", "sha256"), drop = FALSE
      ]
      if (!grepl("^[1-9][0-9]*$", replacement$size_bytes[[1L]]) ||
          !grepl("^[0-9a-f]{64}$", replacement$sha256[[1L]])) {
        stop(sprintf("The sealed sidecar identity `%s/%s` is invalid.",
          source, sidecar), call. = FALSE)
      }
      derived_table[
        baseline_row, c("size_bytes", "sha256")
      ] <- replacement
      sealed_replacements[[sidecar]] <- list(
        size_bytes = replacement$size_bytes[[1L]],
        sha256 = replacement$sha256[[1L]]
      )
    }
    generation_id <- source_manifest_namespace$
      wlv_source_manifest_generation_id(derived_table)
    derived_table$source_generation_id <- rep(
      generation_id, nrow(derived_table)
    )
    source_manifest_namespace$wlv_validate_source_manifest(derived_table)

    differences <- wlv13_main_prep_table_differences(
      baseline_table, derived_table
    )
    observed_difference_keys <- sort(vapply(differences, function(value) {
      paste(value$artifact, value$column, sep = "|")
    }, character(1L)), method = "radix")
    expected_difference_keys <- sort(c(
      paste(baseline_table$artifact, "source_generation_id", sep = "|"),
      unlist(lapply(constants$sidecars, function(sidecar) {
        paste(sidecar, c("size_bytes", "sha256"), sep = "|")
      }), use.names = FALSE)
    ), method = "radix")
    if (!identical(observed_difference_keys, expected_difference_keys)) {
      stop(sprintf("The `%s` derivation changed fields outside its allowlist.",
        source), call. = FALSE)
    }

    serialized_path <- file.path(
      temporary_root, paste0(source, "-_source_manifest.csv")
    )
    source_manifest_namespace$wlv_write_source_manifest(
      derived_table, serialized_path
    )
    serialized_roundtrip <- source_manifest_namespace$
      wlv_read_source_manifest(serialized_path)
    if (!identical(derived_table, serialized_roundtrip)) {
      stop(sprintf("The derived `%s` manifest serialization is not exact.",
        source), call. = FALSE)
    }
    derived_file_sha256 <- file_sha256(serialized_path)
    derived_table_sha256 <- table_sha256(derived_table)

    derived_artifact <- baseline_artifact
    derived_artifact$file_sha256 <- derived_file_sha256
    derived_artifact$table_sha256 <- derived_table_sha256
    derived_artifact$table <- encode_table(derived_table)
    artifact_index <- match(
      "_source_manifest.csv",
      vapply(
        derived_manifest$profiles[[profile_index]]$baseline$artifacts,
        `[[`, character(1L), "artifact"
      )
    )
    derived_manifest$profiles[[profile_index]]$baseline$
      source_generation_id <- generation_id
    derived_manifest$profiles[[profile_index]]$baseline$
      artifacts[[artifact_index]] <- derived_artifact

    if (!identical(
        original_profile$candidate,
        derived_manifest$profiles[[profile_index]]$candidate
    ) || !identical(
        wlv13_main_prep_profile_artifact(
          original_profile, "baseline", "_unit_contract.csv"
        ),
        wlv13_main_prep_profile_artifact(
          derived_manifest$profiles[[profile_index]],
          "baseline", "_unit_contract.csv"
        )
    )) {
      stop(sprintf("The `%s` derivation changed a sealed non-manifest profile.",
        source), call. = FALSE)
    }

    derivations[[source]] <- list(
      source = source,
      original_baseline_generation_id =
        original_profile$baseline$source_generation_id,
      derived_baseline_generation_id = generation_id,
      derived_manifest_file_sha256 = derived_file_sha256,
      derived_manifest_table_sha256 = derived_table_sha256,
      sealed_candidate_sidecars = sealed_replacements,
      changed_cells = length(differences),
      changed_cell_keys = as.list(observed_difference_keys)
    )
  }

  derived_manifest <- validate_profile(derived_manifest)
  identity_payload <- list(
    schema = constants$schema,
    baseline_commit = constants$baseline_commit,
    candidate_commit = constants$candidate_commit,
    original_profile_sha256 = profile_sha256,
    source_manifest_sha256 = source_manifest_sha256,
    rule = paste(
      "Replace only size_bytes and sha256 for m_io.fst.meta and sea.fst.meta",
      "with the already sealed candidate cells; recompute source_generation_id",
      "with the pinned e2f4 implementation; preserve every other cell and order."
    ),
    profiles = derived_manifest$profiles
  )
  derived_profile_sha256 <- wlv13_main_prep_json_sha256(
    namespace, identity_payload
  )
  metadata <- list(
    schema = constants$schema,
    baseline_commit = constants$baseline_commit,
    candidate_commit = constants$candidate_commit,
    original_profile = list(
      path = profile_path,
      sha256 = profile_sha256,
      baseline_commit = original_manifest$baseline_commit,
      candidate_commit_at_derivation =
        original_manifest$candidate_commit_at_derivation
    ),
    source_manifest_implementation = list(
      path = source_manifest_path,
      sha256 = source_manifest_sha256
    ),
    derived_profile_sha256 = derived_profile_sha256,
    sidecar_rule = paste(
      "Both sides must be versioned-v1, internally bound to their FST payload,",
      "and byte-for-byte identical as R sidecar objects."
    ),
    sources = unname(derivations)
  )
  list(
    metadata = metadata,
    original_manifest = original_manifest,
    derived_manifest = derived_manifest,
    profile_path = profile_path,
    baseline_root = baseline_root,
    candidate_root = candidate_root
  )
}

wlv13_main_prep_sidecar_format <- function(contract) {
  if (isTRUE(contract$legacy)) {
    return("legacy-positional")
  }
  if (identical(contract$schema_version, "1")) {
    return("versioned-v1")
  }
  "unsupported"
}

wlv13_main_prep_sidecar_policy <- function(
    left_contract,
    right_contract,
    left_sha256,
    right_sha256) {
  is.list(left_contract) && is.list(right_contract) &&
    !isTRUE(left_contract$legacy) && !isTRUE(right_contract$legacy) &&
    identical(left_contract$schema_version, "1") &&
    identical(right_contract$schema_version, "1") &&
    is.character(left_contract$fst_sha256) &&
    length(left_contract$fst_sha256) == 1L &&
    identical(left_contract$fst_sha256, left_sha256) &&
    is.character(right_contract$fst_sha256) &&
    length(right_contract$fst_sha256) == 1L &&
    identical(right_contract$fst_sha256, right_sha256) &&
    identical(left_contract$raw, right_contract$raw)
}

wlv13_main_install_preparation_equivalence <- function(
    namespace,
    baseline_root,
    candidate_root) {
  if (!is.environment(namespace)) {
    stop("`namespace` must be the preparation-comparator environment.",
      call. = FALSE)
  }
  marker <- ".wlv13_main_preparation_equivalence_binding"
  if (exists(marker, envir = namespace, inherits = FALSE)) {
    stop("Preparation equivalence is already installed.", call. = FALSE)
  }
  binding <- wlv13_main_prep_build_binding(
    namespace, baseline_root, candidate_root
  )
  original_source <- wlv13_main_prep_namespace_function(
    namespace, "wlv13_v5p_compare_source"
  )
  original_array <- wlv13_main_prep_namespace_function(
    namespace, "wlv_gate_compare_fst_array"
  )
  parse_sidecar <- wlv13_main_prep_namespace_function(
    namespace, "wlv_gate_fst_sidecar"
  )

  manifest_environment <- new.env(parent = environment(original_source))
  manifest_environment$wlv13_v5p_manifest <- local({
    profile_path <- binding$profile_path
    expected_sha256 <- binding$metadata$original_profile$sha256
    derived_manifest <- binding$derived_manifest
    hash_file <- wlv13_main_prep_namespace_function(
      namespace, "wlv13_v5p_file_sha256"
    )
    function(path) {
      if (!wlv13_main_prep_same_path(path, profile_path) ||
          !identical(hash_file(path), expected_sha256)) {
        stop("Preparation comparison requested an unbound profile.",
          call. = FALSE)
      }
      derived_manifest
    }
  })
  derived_source <- original_source
  environment(derived_source) <- manifest_environment

  source_override <- local({
    compare_source <- derived_source
    bound_baseline <- binding$baseline_root
    bound_candidate <- binding$candidate_root
    metadata <- binding$metadata
    function(baseline_root, candidate_root, source,
             baseline_manifest_table, candidate_manifest_table,
             manifest_path) {
      if (!source %in% c("wiodr13", "wiodr16") ||
          !wlv13_main_prep_same_path(
            baseline_root,
            file.path(bound_baseline, "source_data", source, "normalized")
          ) ||
          !wlv13_main_prep_same_path(
            candidate_root,
            file.path(bound_candidate, "source_data", source, "normalized")
          )) {
        stop("Preparation source comparison is outside its derived binding.",
          call. = FALSE)
      }
      result <- compare_source(
        baseline_root,
        candidate_root,
        source,
        baseline_manifest_table,
        candidate_manifest_table,
        manifest_path
      )
      source_metadata <- metadata$sources[[match(
        source, vapply(metadata$sources, `[[`, character(1L), "source")
      )]]
      result$source_manifest$comparison_mode <-
        "sealed-derived-versioned-source-manifest-equivalence"
      result$source_manifest$original_profile_sha256 <-
        metadata$original_profile$sha256
      result$source_manifest$derived_profile_sha256 <-
        metadata$derived_profile_sha256
      result$source_manifest$derivation <- source_metadata
      result$equivalence_derivation <- list(
        schema = metadata$schema,
        baseline_commit = metadata$baseline_commit,
        candidate_commit = metadata$candidate_commit,
        source_manifest_implementation_sha256 =
          metadata$source_manifest_implementation$sha256,
        derived_profile_sha256 = metadata$derived_profile_sha256
      )
      result
    }
  })

  allowed_arrays <- list()
  for (source in c("wiodr13", "wiodr16")) {
    for (name in c("m_io.fst", "sea.fst")) {
      key <- paste(source, name, sep = "/")
      allowed_arrays[[key]] <- list(
        artifact = paste0(source, "/normalized/", name),
        baseline = normalizePath(file.path(
          binding$baseline_root, "source_data", source, "normalized", name
        ), winslash = "/", mustWork = TRUE),
        candidate = normalizePath(file.path(
          binding$candidate_root, "source_data", source, "normalized", name
        ), winslash = "/", mustWork = TRUE)
      )
    }
  }
  array_override <- local({
    compare_array <- original_array
    sidecar <- parse_sidecar
    allowed <- allowed_arrays
    function(left_path, right_path, artifact, chunk_rows = 1000000L) {
      match_index <- which(vapply(allowed, function(record) {
        identical(artifact, record$artifact) &&
          wlv13_main_prep_same_path(left_path, record$baseline) &&
          wlv13_main_prep_same_path(right_path, record$candidate)
      }, logical(1L)))
      if (length(match_index) != 1L) {
        stop("FST preparation comparison is outside its e2f4/6549597 binding.",
          call. = FALSE)
      }
      result <- compare_array(
        left_path, right_path, artifact, chunk_rows = chunk_rows
      )
      left_contract <- sidecar(left_path)
      right_contract <- sidecar(right_path)
      left_sha256 <- result$baseline_sha256
      right_sha256 <- result$candidate_sha256
      policy_passed <- wlv13_main_prep_sidecar_policy(
        left_contract, right_contract, left_sha256, right_sha256
      )
      result$baseline_sidecar_format <-
        wlv13_main_prep_sidecar_format(left_contract)
      result$candidate_sidecar_format <-
        wlv13_main_prep_sidecar_format(right_contract)
      result$baseline_internal_hash_ok <- identical(
        left_contract$fst_sha256, left_sha256
      )
      result$candidate_internal_hash_ok <- identical(
        right_contract$fst_sha256, right_sha256
      )
      result$sidecar_architecture_valid <- policy_passed
      result$sidecars_semantically_identical <- identical(
        left_contract$raw, right_contract$raw
      )
      result$sidecar_policy <- "both-versioned-v1-exact"
      result$passed <- isTRUE(result$dimension_names_identical) &&
        isTRUE(result$fst_column_schema_identical) &&
        isTRUE(result$bitwise_values_identical) &&
        identical(
          as.double(result$compared_values),
          as.double(result$flattened_values)
        ) &&
        isTRUE(result$baseline_internal_hash_ok) &&
        isTRUE(result$candidate_internal_hash_ok) &&
        isTRUE(policy_passed)
      result
    }
  })

  assign("wlv13_v5p_compare_source", source_override, envir = namespace)
  assign("wlv_gate_compare_fst_array", array_override, envir = namespace)
  assign(marker, binding, envir = namespace)
  binding$metadata
}
