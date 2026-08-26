# Issue #13 V5 exhaustive scientific-diagnostic bridge.
#
# This file is sourced after issue13-v5-compare-override.R.  It replaces the
# permissive cross-engine projections for scientific checks, unit contracts,
# anomalies and candidate-only non-finite diagnostics with closed, typed
# transformations.  Every published column remains part of the comparison.

wlv13_v5d_previous_compare_config <- wlv13_cross_engine_compare_config
wlv13_v5d_previous_validate_nonfinite <-
  wlv13_cross_engine_validate_nonfinite

wlv13_v5d_architecture_check_ids <- c(
  "aggregation_contract",
  "aggregation_legacy_adapter",
  "nonfinite_resolution"
)

wlv13_v5d_stage5_profile_schema <-
  "issue13-v5-stage5-multiplicity-profile/1"

wlv13_v5d_stage5_profile_columns <- c(
  "schema_version", "profile_id", "scenario_id", "method", "mode",
  "at_stage", "sea_vars_sha256", "workers", "request_sha256",
  "candidate_stage5_rows", "candidate_stage5_sha256",
  "baseline_stage5_rows", "baseline_stage5_sha256",
  "difference_key_count", "difference_sha256",
  "evidence_candidate_reference_run_id",
  "evidence_candidate_reference_anomalies_sha256",
  "evidence_candidate_reference_request_sha256",
  "evidence_candidate_reference_commit",
  "evidence_candidate_reference_tree",
  "evidence_candidate_reference_source_sha256",
  "evidence_candidate_reference_run_manifest_sha256",
  "evidence_candidate_reference_run_inventory_sha256",
  "evidence_baseline_reference_run_id",
  "evidence_baseline_reference_anomalies_sha256",
  "evidence_baseline_reference_request_sha256",
  "evidence_baseline_reference_commit",
  "evidence_baseline_reference_tree",
  "evidence_baseline_reference_source_sha256",
  "evidence_baseline_reference_run_manifest_sha256",
  "evidence_baseline_reference_run_inventory_sha256",
  "evidence_baseline_target_run_id",
  "evidence_baseline_target_anomalies_sha256",
  "evidence_baseline_target_request_sha256",
  "evidence_baseline_target_commit",
  "evidence_baseline_target_tree",
  "evidence_baseline_target_source_sha256",
  "evidence_baseline_target_run_manifest_sha256",
  "evidence_baseline_target_run_inventory_sha256",
  "evidence_capture_record_sha256",
  "reference_stage5_sha256",
  "derivation_sha256"
)

wlv13_v5d_bridge_schema <- "issue13-v5-diagnostic-module-bridge/1"

wlv13_v5d_methods <- c(
  "wiodr13", "wiodr16", "alternative_1", "alternative_2",
  "norow_w13", "ochoa_1", "ochoa_2", "petrovic", "wiodr13v09",
  "wiodr16v09", "zerodep_1", "zerodep_2"
)

wlv13_v5d_methods_by_source <- list(
  wiodr13 = c(
    "wiodr13", "alternative_1", "alternative_2", "norow_w13",
    "ochoa_1", "ochoa_2", "petrovic", "wiodr13v09",
    "zerodep_1", "zerodep_2"
  ),
  wiodr16 = c("wiodr16", "wiodr16v09")
)

wlv13_v5d_bridge_columns <- c(
  "schema_version", "bridge_id", "artifact_name", "method", "source",
  "artifact", "indicator", "checkpoint", "stage", "action", "output",
  "original_value", "policy_id", "level", "strategy",
  "baseline_module", "candidate_module", "candidate_producer_id",
  "candidate_write_action",
  "evidence_baseline_run_id", "evidence_baseline_artifact_sha256",
  "evidence_baseline_request_sha256", "evidence_baseline_source_sha256",
  "evidence_baseline_commit", "evidence_baseline_tree",
  "evidence_candidate_run_id", "evidence_candidate_artifact_sha256",
  "evidence_candidate_request_sha256", "evidence_candidate_source_sha256",
  "evidence_candidate_commit", "evidence_candidate_tree",
  "expected_baseline_evidence_rows", "expected_candidate_evidence_rows",
  "derivation_sha256"
)

wlv13_v5d_bridge_context_columns <- function(artifact_name) {
  if (identical(artifact_name, "_unit_contract.csv")) {
    c("source", "indicator", "strategy")
  } else if (identical(artifact_name, "_anomalies.csv")) {
    c(
      "artifact", "indicator", "checkpoint", "stage", "action", "output",
      "original_value", "policy_id"
    )
  } else {
    stop("Unsupported diagnostic bridge artifact.", call. = FALSE)
  }
}

wlv13_v5d_owner_contract_cache <- new.env(parent = emptyenv())

wlv13_v5d_scalar <- function(value, label, pattern = NULL) {
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !nzchar(value) ||
      (!is.null(pattern) && !grepl(pattern, value, perl = TRUE))) {
    stop(sprintf("Invalid %s.", label), call. = FALSE)
  }
  enc2utf8(value)
}

wlv13_v5d_normalize_table <- function(value, columns, label) {
  if (!is.data.frame(value) || !identical(names(value), columns)) {
    stop(sprintf("%s has an invalid schema.", label), call. = FALSE)
  }
  result <- as.data.frame(lapply(value, function(column) {
    column <- as.character(column)
    column[is.na(column)] <- ""
    enc2utf8(column)
  }), stringsAsFactors = FALSE, check.names = FALSE)
  row.names(result) <- NULL
  result
}

wlv13_v5d_exact_ordered <- function(left, right) {
  is.data.frame(left) && is.data.frame(right) && identical(left, right)
}

wlv13_v5d_raw_row_keys <- function(value) {
  if (!is.data.frame(value)) {
    stop("Diagnostic row keys require a data frame.", call. = FALSE)
  }
  if (!nrow(value)) return(character())
  columns <- lapply(value, function(column) {
    column <- enc2utf8(as.character(column))
    paste0(nchar(column, type = "bytes"), ":", column)
  })
  do.call(paste, c(columns, sep = "|"))
}

wlv13_v5d_sha256_text <- function(value) {
  if (!exists("wlv13_sha256_text", mode = "function", inherits = TRUE)) {
    stop("The pinned SHA-256 helper is unavailable.", call. = FALSE)
  }
  wlv13_sha256_text(enc2utf8(value))
}

wlv13_v5d_length_record <- function(...) {
  fields <- list(...)
  fields <- lapply(fields, function(value) {
    value <- enc2utf8(as.character(value))
    paste0(nchar(value, type = "bytes"), ":", value)
  })
  do.call(paste, c(fields, sep = "|"))
}

wlv13_v5d_bridge_derivation <- function(value) {
  columns <- setdiff(
    wlv13_v5d_bridge_columns,
    c("bridge_id", "derivation_sha256")
  )
  if (!is.data.frame(value) || nrow(value) != 1L ||
      !all(columns %in% names(value))) {
    stop("Invalid diagnostic bridge derivation row.", call. = FALSE)
  }
  records <- vapply(columns, function(column) {
    wlv13_v5d_length_record(column, value[[column]][[1L]])
  }, character(1L))
  wlv13_v5d_sha256_text(paste(records, collapse = "\n"))
}

wlv13_v5d_bridge_order <- function(value) {
  columns <- c(
    "artifact_name", "method", "source", "artifact", "indicator",
    "checkpoint", "stage", "action", "output", "original_value",
    "policy_id", "strategy", "baseline_module", "candidate_module",
    "candidate_producer_id", "candidate_write_action"
  )
  if (!is.data.frame(value) || any(!columns %in% names(value))) {
    stop("Diagnostic bridge ordering lacks its exact fields.",
      call. = FALSE
    )
  }
  do.call(order, c(unname(value[columns]), list(method = "radix")))
}

wlv13_v5d_bridge_manifest_path <- function() {
  scope <- environment(wlv13_v5d_bridge_manifest_path)
  root <- if (exists("script_dir", envir = scope, inherits = TRUE)) {
    get("script_dir", envir = scope, inherits = TRUE)
  } else {
    NULL
  }
  if (!is.character(root) || length(root) != 1L || !nzchar(root)) {
    stop("The diagnostic bridge manifest root is unavailable.",
      call. = FALSE
    )
  }
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  path <- file.path(root, "issue13-v5-diagnostic-module-bridges.csv")
  if (!file.exists(path) || isTRUE(file.info(path)$isdir)) {
    stop("The pinned diagnostic bridge manifest is missing.",
      call. = FALSE
    )
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

wlv13_v5d_validate_bridge_manifest <- function(value) {
  value <- wlv13_v5d_normalize_table(
    value, wlv13_v5d_bridge_columns, "Diagnostic module bridges"
  )
  if (!nrow(value)) {
    stop("The diagnostic bridge manifest cannot be empty.", call. = FALSE)
  }
  integer_columns <- c(
    "expected_baseline_evidence_rows", "expected_candidate_evidence_rows"
  )
  integers <- lapply(integer_columns, function(column) {
    suppressWarnings(as.integer(value[[column]]))
  })
  method_sources <- unlist(lapply(names(wlv13_v5d_methods_by_source),
    function(source) stats::setNames(
      rep(source, length(wlv13_v5d_methods_by_source[[source]])),
      wlv13_v5d_methods_by_source[[source]]
    )
  ), use.names = TRUE)
  valid <- all(value$schema_version == wlv13_v5d_bridge_schema) &&
    all(value$artifact_name %in% c(
      "_unit_contract.csv", "_anomalies.csv"
    )) &&
    all(value$method %in% wlv13_v5d_methods) &&
    all(value$source %in% c("wiodr13", "wiodr16")) &&
    all(value$source == unname(method_sources[value$method])) &&
    all(nzchar(value$indicator)) &&
    all(nzchar(value$baseline_module)) &&
    all(nzchar(value$candidate_module)) &&
    all(value$baseline_module != value$candidate_module) &&
    all(grepl("^run-[0-9A-Za-z-]+$", value$evidence_baseline_run_id)) &&
    all(grepl("^run-[0-9A-Za-z-]+$", value$evidence_candidate_run_id)) &&
    all(vapply(c(
      "evidence_baseline_artifact_sha256",
      "evidence_baseline_request_sha256",
      "evidence_baseline_source_sha256",
      "evidence_candidate_artifact_sha256",
      "evidence_candidate_request_sha256",
      "evidence_candidate_source_sha256",
      "derivation_sha256"
    ), function(column) {
      all(grepl("^[0-9a-f]{64}$", value[[column]]))
    }, logical(1L))) &&
    all(vapply(c(
      "evidence_baseline_commit", "evidence_baseline_tree",
      "evidence_candidate_commit", "evidence_candidate_tree"
    ), function(column) {
      all(grepl("^[0-9a-f]{40}$", value[[column]]))
    }, logical(1L))) &&
    all(vapply(seq_along(integer_columns), function(index) {
      parsed <- integers[[index]]
      !anyNA(parsed) && all(parsed > 0L) && identical(
        as.character(parsed), value[[integer_columns[[index]]]]
      )
    }, logical(1L)))
  unit <- value$artifact_name == "_unit_contract.csv"
  anomaly <- value$artifact_name == "_anomalies.csv"
  valid <- valid &&
    all(value$artifact[unit] == "") &&
    all(value$checkpoint[unit] == "") &&
    all(value$stage[unit] == "") &&
    all(value$action[unit] == "") &&
    all(value$output[unit] == "") &&
    all(value$original_value[unit] == "") &&
    all(value$policy_id[unit] == "") &&
    all(value$level[unit] == "") &&
    all(nzchar(value$strategy[unit])) &&
    all(value$candidate_producer_id[unit] == "") &&
    all(value$candidate_write_action[unit] == "") &&
    all(nzchar(value$artifact[anomaly])) &&
    all(nzchar(value$checkpoint[anomaly])) &&
    all(value$stage[anomaly] %in% as.character(1:5)) &&
    all(nzchar(value$action[anomaly])) &&
    all(nzchar(value$original_value[anomaly])) &&
    all(nzchar(value$policy_id[anomaly])) &&
    all(value$level[anomaly] == "") &&
    all(value$strategy[anomaly] == "") &&
    all(nzchar(value$candidate_producer_id[anomaly])) &&
    all(value$candidate_write_action[anomaly] %in%
      c("create", "patch", "replace"))
  derivations <- if (valid) vapply(seq_len(nrow(value)), function(index) {
    wlv13_v5d_bridge_derivation(value[index, , drop = FALSE])
  }, character(1L)) else character()
  valid <- valid && identical(derivations, value$derivation_sha256) &&
    identical(
      paste0("bridge-", substr(derivations, 1L, 24L)),
      value$bridge_id
    )
  identity_columns <- c(
    "artifact_name", "method", "source", "artifact", "indicator",
    "checkpoint", "stage", "action", "output", "original_value",
    "policy_id", "level", "strategy", "baseline_module"
  )
  if (!valid || anyDuplicated(value[identity_columns]) ||
      anyDuplicated(value$bridge_id) ||
      !identical(wlv13_v5d_bridge_order(value), seq_len(nrow(value)))) {
    stop("The diagnostic bridge manifest is invalid.", call. = FALSE)
  }
  evidence_columns <- c(
    "evidence_baseline_run_id", "evidence_baseline_artifact_sha256",
    "evidence_baseline_request_sha256", "evidence_baseline_source_sha256",
    "evidence_baseline_commit", "evidence_baseline_tree",
    "evidence_candidate_run_id", "evidence_candidate_artifact_sha256",
    "evidence_candidate_request_sha256", "evidence_candidate_source_sha256",
    "evidence_candidate_commit", "evidence_candidate_tree"
  )
  groups <- split(seq_len(nrow(value)), paste(
    value$artifact_name, value$method, sep = "|"
  ))
  if (any(vapply(groups, function(index) {
      any(vapply(evidence_columns, function(column) {
        length(unique(value[[column]][index])) != 1L
      }, logical(1L)))
    }, logical(1L)))) {
    stop("Diagnostic bridge evidence is not singular per method/artifact.",
      call. = FALSE
    )
  }
  row.names(value) <- NULL
  value
}

wlv13_v5d_read_bridge_manifest <- function() {
  wlv13_v5d_validate_bridge_manifest(
    wlv13_read_csv_semantic(wlv13_v5d_bridge_manifest_path())
  )
}

wlv13_v5d_candidate_owner_contract <- function(project_root, method) {
  if (!exists("wlv_gate_load_runtime", mode = "function", inherits = TRUE)) {
    stop("The sealed runtime loader is unavailable for owner validation.",
      call. = FALSE
    )
  }
  root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  cache_key <- paste(root, method, sep = "|")
  if (exists(cache_key, envir = wlv13_v5d_owner_contract_cache,
      inherits = FALSE)) {
    return(get(cache_key, envir = wlv13_v5d_owner_contract_cache,
      inherits = FALSE
    ))
  }
  metadata <- wlv13_v5_metadata_profile(
    method, wlv13_v5_metadata_artifacts[[1L]]
  )
  loaded <- wlv_gate_load_runtime(root)
  runtime <- loaded$runtime
  required <- c(
    "wlv_validate_request", "wlv_native_plan_instances",
    "wlv_native_preflight_plan", "wlv_native_recalculated_anomaly_targets",
    "wlv_catalog_unit_contract_sidecar"
  )
  if (!is.environment(runtime) ||
      any(!vapply(required, exists, logical(1L), envir = runtime,
        mode = "function", inherits = FALSE))) {
    stop("The candidate runtime lacks closed owner-contract functions.",
      call. = FALSE
    )
  }
  plan <- runtime$wlv_validate_request(
    methods = method, repeat_pp = FALSE, papern = 0L, prepaper = FALSE,
    workers = 1L, channel = "stable", mode = "calculate", at_stage = 1L,
    sea_vars = NULL, root = root, allow_experimental = TRUE,
    requested_operations = "calculate", catalog = NULL
  )
  method_index <- match(method, plan$methods$method)
  if (is.na(method_index) ||
      !identical(plan$methods$source[[method_index]], metadata$source)) {
    stop("The candidate owner plan has a mismatched method/source.",
      call. = FALSE
    )
  }
  instances <- runtime$wlv_native_plan_instances(
    registry = plan$native_registry,
    config = plan$configuration[[method]],
    aggregation_registry = plan$aggregation_registries[[method]],
    indicators = plan$indicators[[method]],
    partitions = metadata$partition,
    mode = "calculate", at_stage = 1L, sea_vars = NULL
  )
  module_plan <- runtime$wlv_native_preflight_plan(
    registry = plan$native_registry, instances = instances,
    partitions = metadata$partition, mode = "calculate",
    source = metadata$source, at_stage = 1L,
    indicators = plan$indicators[[method]]
  )
  targets <- runtime$wlv_native_recalculated_anomaly_targets(module_plan)
  target_columns <- c(
    "artifact", "indicator", "stage", "module", "producer_id", "action"
  )
  targets <- wlv13_v5d_normalize_table(
    targets, target_columns, "Candidate anomaly owner targets"
  )
  aggregation_rows <- plan$aggregation_registries[[method]]$rows
  if (!is.data.frame(aggregation_rows) ||
      any(!c("strategy", "module") %in% names(aggregation_rows))) {
    stop("The candidate aggregation owner registry is invalid.",
      call. = FALSE
    )
  }
  # The public unit contract records the formula operation (sum/mean), while
  # the registry's `strategy` column identifies the formula route.  Recover
  # that operation from the module-free resolved sidecar, not from a name.
  method_row <- plan$methods[method_index, , drop = FALSE]
  resolved_unit <- runtime$wlv_catalog_unit_contract_sidecar(
    plan$catalog, method_row$unit_contract[[1L]],
    indicators = plan$indicators[[method]],
    resolved_aggregations = plan$aggregation_registries[[method]]$rows
  )
  resolved_unit <- resolved_unit[
    resolved_unit$level %in% c("sector_to_country", "country_to_world") &
      nzchar(resolved_unit$module),
    c("indicator", "level", "strategy", "module"), drop = FALSE
  ]
  aggregation_rows <- wlv13_v5d_normalize_table(
    resolved_unit, c("indicator", "level", "strategy", "module"),
    "Candidate aggregation owner targets"
  )
  aggregation_modules <- sort(unique(aggregation_rows$module),
    method = "radix"
  )
  if (!length(aggregation_modules) || any(!nzchar(aggregation_modules))) {
    stop("The candidate aggregation owner registry is incomplete.",
      call. = FALSE
    )
  }
  value <- list(
    method = method,
    source = metadata$source,
    partition = metadata$partition,
    anomaly_targets = targets,
    unit_targets = aggregation_rows,
    aggregation_modules = aggregation_modules,
    anomaly_targets_sha256 = wlv13_v5d_sha256_text(paste(
      wlv13_v5d_raw_row_keys(targets), collapse = "\n"
    )),
    aggregation_modules_sha256 = wlv13_v5d_sha256_text(paste(
      aggregation_modules, collapse = "\n"
    )),
    unit_targets_sha256 = wlv13_v5d_sha256_text(paste(
      wlv13_v5d_raw_row_keys(aggregation_rows), collapse = "\n"
    ))
  )
  assign(cache_key, value, envir = wlv13_v5d_owner_contract_cache)
  value
}

wlv13_v5d_bridge_targets_valid <- function(
    bridges, method, artifact_name, owner_contract) {
  selected <- bridges[
    bridges$method == method & bridges$artifact_name == artifact_name,
    , drop = FALSE
  ]
  if (!nrow(selected) || !is.list(owner_contract) ||
      !identical(owner_contract$method, method) ||
      !identical(unique(selected$source), owner_contract$source)) {
    return(FALSE)
  }
  if (identical(artifact_name, "_unit_contract.csv")) {
    targets <- owner_contract$unit_targets
    if (!is.data.frame(targets) || !identical(names(targets), c(
        "indicator", "level", "strategy", "module"
      ))) {
      return(FALSE)
    }
    return(all(vapply(seq_len(nrow(selected)), function(index) {
      matches <- targets$indicator == selected$indicator[[index]] &
        targets$strategy == selected$strategy[[index]] &
        targets$module == selected$candidate_module[[index]]
      identical(
        sort(targets$level[matches], method = "radix"),
        sort(c("country_to_world", "sector_to_country"), method = "radix")
      )
    }, logical(1L))))
  }
  targets <- owner_contract$anomaly_targets
  if (!is.data.frame(targets) || !identical(names(targets), c(
      "artifact", "indicator", "stage", "module", "producer_id", "action"
    ))) {
    return(FALSE)
  }
  all(vapply(seq_len(nrow(selected)), function(index) {
    matches <- targets$artifact == selected$artifact[[index]] &
      targets$indicator == selected$indicator[[index]] &
      targets$stage == selected$stage[[index]] &
      (targets$module == selected$candidate_module[[index]] |
        targets$producer_id == selected$candidate_module[[index]]) &
      targets$producer_id == selected$candidate_producer_id[[index]] &
      targets$action == selected$candidate_write_action[[index]]
    sum(matches) == 1L
  }, logical(1L)))
}

wlv13_v5d_bridge_key <- function(value, artifact_name, include_module = TRUE) {
  columns <- wlv13_v5d_bridge_context_columns(artifact_name)
  if (isTRUE(include_module)) columns <- c(columns, "module")
  if (!is.data.frame(value) || any(!columns %in% names(value))) {
    stop("A diagnostic bridge input lacks its exact context columns.",
      call. = FALSE
    )
  }
  wlv13_v5d_raw_row_keys(value[, columns, drop = FALSE])
}

wlv13_v5d_closed_module_bridge <- function(
    value, bridges, method, artifact_name, mode = "calculate",
    valid_candidate_modules = NULL) {
  if (!is.data.frame(value) || !"module" %in% names(value) ||
      !method %in% wlv13_v5d_methods ||
      !artifact_name %in% c("_unit_contract.csv", "_anomalies.csv") ||
      !mode %in% c("calculate", "recalculate", "preparation")) {
    stop("Invalid closed diagnostic bridge request.", call. = FALSE)
  }
  selected <- bridges[
    bridges$method == method & bridges$artifact_name == artifact_name,
    , drop = FALSE
  ]
  if (!nrow(selected)) {
    stop("The method lacks a closed diagnostic bridge profile.",
      call. = FALSE
    )
  }
  if (!is.null(valid_candidate_modules) &&
      (!is.character(valid_candidate_modules) ||
        any(!selected$candidate_module %in% valid_candidate_modules))) {
    stop("A closed bridge targets a nonexistent candidate module.",
      call. = FALSE
    )
  }
  candidate_shape <- selected
  candidate_shape$module <- candidate_shape$candidate_module
  baseline_shape <- selected
  baseline_shape$module <- baseline_shape$baseline_module
  candidate_profile_keys <- wlv13_v5d_bridge_key(
    candidate_shape, artifact_name
  )
  baseline_profile_keys <- wlv13_v5d_bridge_key(
    baseline_shape, artifact_name
  )
  suspect <- value$module %in% unique(c(
    selected$baseline_module, selected$candidate_module
  ))
  observed_keys <- rep("", nrow(value))
  if (any(suspect)) {
    observed_keys[suspect] <- wlv13_v5d_bridge_key(
      value[suspect, , drop = FALSE], artifact_name
    )
  }
  baseline_match <- match(observed_keys, baseline_profile_keys, nomatch = 0L)
  target_match <- match(observed_keys, candidate_profile_keys, nomatch = 0L)
  if (any(baseline_match > 0L & target_match > 0L)) {
    stop("A diagnostic bridge is not directionally unique.", call. = FALSE)
  }
  result <- value
  transformed <- baseline_match > 0L
  if (any(transformed)) {
    result$module[transformed] <- selected$candidate_module[
      baseline_match[transformed]
    ]
  }
  counts <- tabulate(baseline_match[transformed], nbins = nrow(selected))
  if (identical(mode, "calculate")) {
    expected <- as.integer(selected$expected_baseline_evidence_rows)
    if (!identical(counts, expected)) {
      stop("Calculate bridge coverage differs from its sealed evidence.",
        call. = FALSE
      )
    }
  }
  records <- if (any(transformed)) vapply(which(transformed), function(index) {
    wlv13_v5d_length_record(
      selected$bridge_id[[baseline_match[[index]]]], as.character(index)
    )
  }, character(1L)) else character()
  list(
    value = result,
    changed_rows = sum(transformed),
    used_profile_rows = sum(counts > 0L),
    coverage_complete = if (identical(mode, "calculate")) {
      all(counts == as.integer(selected$expected_baseline_evidence_rows))
    } else {
      TRUE
    },
    target_generation_rows = sum(target_match > 0L),
    bridge_sha256 = wlv13_v5d_sha256_text(paste(records, collapse = "\n"))
  )
}

wlv13_v5d_canonical_integer <- function(value, label, minimum = 0L) {
  parsed <- suppressWarnings(as.integer(value))
  if (length(value) != 1L || length(parsed) != 1L || is.na(parsed) ||
      parsed < minimum || !identical(as.character(parsed),
        as.character(value))) {
    stop(sprintf("Invalid %s.", label), call. = FALSE)
  }
  parsed
}

wlv13_v5d_run_request <- function(context) {
  if (!is.list(context) || !is.character(context$run_root) ||
      length(context$run_root) != 1L || !is.character(context$method) ||
      length(context$method) != 1L) {
    stop("Invalid sealed run request context.", call. = FALSE)
  }
  manifest_path <- file.path(context$run_root, "run_manifest.json")
  if (!file.exists(manifest_path) || isTRUE(file.info(manifest_path)$isdir)) {
    stop("The sealed run manifest is missing.", call. = FALSE)
  }
  manifest <- wlv13_json_read(manifest_path, simplify = FALSE)
  request <- if (is.list(manifest) && is.list(manifest$result)) {
    manifest$result$request
  } else {
    NULL
  }
  required <- c("at_stage", "method", "mode", "sea_vars", "workers")
  if (!is.list(request) ||
      !identical(sort(names(request), method = "radix"),
        sort(required, method = "radix")) ||
      !identical(request$method, context$method) ||
      !is.character(request$mode) || length(request$mode) != 1L ||
      !request$mode %in% c("calculate", "recalculate")) {
    stop("The sealed run request is invalid.", call. = FALSE)
  }
  stage <- if (is.null(request$at_stage)) {
    ""
  } else {
    as.character(wlv13_v5d_canonical_integer(
      request$at_stage, "run request stage", 1L
    ))
  }
  if ((request$mode == "calculate" && nzchar(stage)) ||
      (request$mode == "recalculate" && !stage %in% c("1", "4", "5"))) {
    stop("The sealed run request mode/stage is invalid.", call. = FALSE)
  }
  sea_vars <- if (is.null(request$sea_vars)) {
    character()
  } else {
    tryCatch(vapply(request$sea_vars, function(value) {
      wlv13_v5d_scalar(value, "selective recalculation target",
        "^[a-z][a-z0-9_.]*$"
      )
    }, character(1L)), error = function(error) character())
  }
  if (!is.null(request$sea_vars) &&
      (!length(sea_vars) || anyDuplicated(sea_vars))) {
    stop("The sealed selective recalculation targets are invalid.",
      call. = FALSE
    )
  }
  sea_vars <- sort(sea_vars, method = "radix")
  workers <- wlv13_v5d_canonical_integer(
    request$workers, "run request worker count", 1L
  )
  sea_var_records <- if (length(sea_vars)) {
    vapply(sea_vars, wlv13_v5d_length_record, character(1L))
  } else {
    character()
  }
  sea_vars_sha256 <- wlv13_v5d_sha256_text(paste(
    sea_var_records, collapse = "\n"
  ))
  request_record <- wlv13_v5d_length_record(
    context$method, request$mode, stage, sea_vars_sha256,
    as.character(workers)
  )
  request_sha256 <- wlv13_v5d_sha256_text(request_record)
  target_label <- if (length(sea_vars)) {
    paste0("selected-", substr(sea_vars_sha256, 1L, 16L))
  } else {
    "all"
  }
  list(
    method = context$method,
    mode = request$mode,
    at_stage = stage,
    sea_vars = sea_vars,
    sea_vars_sha256 = sea_vars_sha256,
    workers = workers,
    request_sha256 = request_sha256,
    scenario_id = if (request$mode == "calculate") {
      sprintf("calculate/workers-%s", workers)
    } else {
      sprintf("recalculate/stage-%s/%s/workers-%s",
        stage, target_label, workers
      )
    },
    run_id = basename(context$run_root),
    run_manifest_sha256 = wlv13_sha256_file(manifest_path)
  )
}

wlv13_v5d_parent_context <- function(child_context, child_execution) {
  if (!is.list(child_context) || !is.list(child_execution) ||
      !identical(child_execution$mode, "recalculate")) {
    stop("A sealed recalculation parent is required.", call. = FALSE)
  }
  child_manifest <- wlv13_json_read(
    file.path(child_context$run_root, "run_manifest.json"), simplify = FALSE
  )
  parent_id <- if (is.list(child_manifest)) {
    child_manifest$parent_run_id
  } else {
    NULL
  }
  parent_id <- wlv13_v5d_scalar(
    parent_id, "recalculation parent run ID", "^run-[0-9A-Za-z-]+$"
  )
  project_root <- normalizePath(
    child_context$project_root, winslash = "/", mustWork = TRUE
  )
  parent_root <- normalizePath(file.path(
    project_root, "results", "runs", child_context$method, parent_id
  ), winslash = "/", mustWork = TRUE)
  expected_parent <- normalizePath(file.path(
    project_root, "results", "runs", child_context$method, parent_id
  ), winslash = "/", mustWork = TRUE)
  if (!identical(parent_root, expected_parent) ||
      !wlv13_is_within(parent_root, project_root)) {
    stop("The recalculation parent path is invalid.", call. = FALSE)
  }
  manifest_path <- file.path(parent_root, "run_manifest.json")
  anomalies_path <- file.path(parent_root, "_anomalies.csv")
  if (!file.exists(manifest_path) || !file.exists(anomalies_path)) {
    stop("The recalculation parent evidence is missing.", call. = FALSE)
  }
  inventory <- wlv13_run_inventory(parent_root)
  manifest <- inventory$manifest
  provenance <- if (is.list(manifest) && is.list(manifest$result)) {
    manifest$result$provenance
  } else {
    NULL
  }
  inputs <- if (is.list(provenance)) provenance$inputs else NULL
  anomaly_record <- inventory$records[
    inventory$records$path == "_anomalies.csv", , drop = FALSE
  ]
  valid <- identical(inventory$manifest_path,
      normalizePath(manifest_path, winslash = "/", mustWork = TRUE)) &&
    nrow(anomaly_record) == 1L &&
    identical(anomaly_record$sha256[[1L]], wlv13_sha256_file(anomalies_path)) &&
    identical(manifest$run_id, parent_id) &&
    identical(manifest$method, child_context$method) &&
    is.null(manifest$parent_run_id) &&
    is.list(provenance) && isTRUE(provenance$complete) &&
    is.list(provenance$git) &&
    identical(provenance$git$commit, child_context$expected_commit) &&
    identical(child_context$observed_commit, child_context$expected_commit) &&
    identical(provenance$git$dirty, FALSE) &&
    is.list(inputs) && length(inputs) > 0L
  input_records <- if (valid) tryCatch(vapply(inputs, function(input) {
    relative <- wlv13_v5d_scalar(input$path, "parent provenance path")
    expected_sha256 <- wlv13_v5d_scalar(
      input$sha256, "parent provenance hash", "^[0-9a-f]{64}$"
    )
    if (grepl("^([A-Za-z]:|[/\\\\])", relative) ||
        grepl("(^|[/\\\\])[.][.]($|[/\\\\])", relative)) {
      stop("Unsafe parent provenance path.", call. = FALSE)
    }
    path <- normalizePath(file.path(project_root, relative),
      winslash = "/", mustWork = TRUE
    )
    if (!wlv13_is_within(path, project_root) ||
        !identical(wlv13_sha256_file(path), expected_sha256)) {
      stop("Parent provenance input differs.", call. = FALSE)
    }
    paste(relative, expected_sha256, sep = "|")
  }, character(1L)), error = function(error) character()) else character()
  valid <- valid && length(input_records) == length(inputs) &&
    !anyDuplicated(sub("[|].*$", "", input_records)) &&
    !anyDuplicated(input_records)
  if (!valid) {
    stop("The recalculation parent is not authenticated.", call. = FALSE)
  }
  context <- list(
    arm = child_context$arm,
    project_root = project_root,
    expected_commit = child_context$expected_commit,
    observed_commit = child_context$observed_commit,
    method = child_context$method,
    run_root = parent_root,
    input_count = length(input_records),
    input_binding_sha256 = wlv13_v5d_sha256_text(paste(
      input_records, collapse = "\n"
    )),
    inputs = inputs
  )
  execution <- wlv13_v5d_run_request(context)
  if (!identical(execution$mode, "calculate")) {
    stop("The sealed recalculation parent is not a calculate run.",
      call. = FALSE
    )
  }
  list(
    context = context,
    execution = execution,
    anomalies_path = normalizePath(
      anomalies_path, winslash = "/", mustWork = TRUE
    ),
    anomalies_sha256 = wlv13_sha256_file(anomalies_path)
  )
}

wlv13_v5d_context <- function(descriptor, arm, method) {
  if (!exists("wlv13_v5_metadata_context", mode = "function",
      inherits = TRUE)) {
    stop("The sealed V5 engine-context validator is unavailable.",
      call. = FALSE
    )
  }
  context <- wlv13_v5_metadata_context(descriptor, arm, method)
  if (!is.list(context) || !identical(context$arm, arm) ||
      !identical(context$method, method)) {
    stop(sprintf("Invalid sealed %s diagnostic context.", arm),
      call. = FALSE
    )
  }
  context
}

wlv13_v5d_read_contract_table <- function(root, relative, columns, label) {
  path <- file.path(root, relative)
  if (!file.exists(path) || isTRUE(file.info(path)$isdir)) {
    stop(sprintf("%s is missing.", label), call. = FALSE)
  }
  wlv13_v5d_normalize_table(
    wlv13_read_csv_semantic(path), columns, label
  )
}

wlv13_v5d_scientific_profile <- function(project_root, method) {
  maps <- wlv13_v5d_read_contract_table(
    project_root,
    file.path("config", "contracts", "scientific_method_profiles.csv"),
    c("method", "output_profile", "scientific_profile"),
    "Scientific method profiles"
  )
  declarations <- wlv13_v5d_read_contract_table(
    project_root,
    file.path("config", "contracts", "scientific_profiles.csv"),
    c(
      "scientific_profile", "source", "leontief_zero_profile",
      "leontief_signed_profile", "nonfinite_resolution_profile"
    ),
    "Scientific profile declarations"
  )
  profiles <- wlv13_v5d_read_contract_table(
    project_root,
    file.path("config", "contracts", "nonfinite_resolution_profiles.csv"),
    c("nonfinite_resolution_profile", "action", "expected_count"),
    "Non-finite resolution profiles"
  )
  groups <- wlv13_v5d_read_contract_table(
    project_root,
    file.path("config", "contracts", "nonfinite_resolution_groups.csv"),
    c(
      "nonfinite_resolution_profile", "binding", "indicator", "kind",
      "module", "expected_count", "coordinate_sha256"
    ),
    "Non-finite resolution groups"
  )
  selected_map <- maps[maps$method == method, , drop = FALSE]
  if (nrow(selected_map) != 1L || anyDuplicated(maps$method)) {
    stop(sprintf("Method `%s` lacks one scientific profile.", method),
      call. = FALSE
    )
  }
  selected_declaration <- declarations[
    declarations$scientific_profile == selected_map$scientific_profile[[1L]],
    , drop = FALSE
  ]
  if (nrow(selected_declaration) != 1L ||
      anyDuplicated(declarations$scientific_profile)) {
    stop(sprintf("Scientific profile for `%s` is ambiguous.", method),
      call. = FALSE
    )
  }
  profile_id <- selected_declaration$nonfinite_resolution_profile[[1L]]
  selected_profile <- profiles[
    profiles$nonfinite_resolution_profile == profile_id,
    , drop = FALSE
  ]
  if (nrow(selected_profile) != 1L ||
      anyDuplicated(profiles$nonfinite_resolution_profile)) {
    stop(sprintf("Non-finite profile for `%s` is ambiguous.", method),
      call. = FALSE
    )
  }
  expected_count <- suppressWarnings(as.integer(
    selected_profile$expected_count[[1L]]
  ))
  if (is.na(expected_count) || expected_count < 0L ||
      !identical(as.character(expected_count),
        selected_profile$expected_count[[1L]]) ||
      !selected_profile$action[[1L]] %in% c(
        "reject", "replace_nan_with_zero",
        "replace_zero_denominator_with_zero"
      ) ||
      (selected_profile$action[[1L]] == "reject") !=
        (expected_count == 0L)) {
    stop(sprintf("Non-finite profile for `%s` is invalid.", method),
      call. = FALSE
    )
  }
  selected_groups <- groups[
    groups$nonfinite_resolution_profile == profile_id,
    , drop = FALSE
  ]
  group_counts <- suppressWarnings(as.integer(selected_groups$expected_count))
  group_valid <- if (!nrow(selected_groups)) TRUE else
    !anyNA(group_counts) && all(group_counts > 0L) &&
      identical(as.character(group_counts), selected_groups$expected_count) &&
      all(selected_groups$kind %in% c("NaN", "Inf")) &&
      all(grepl("^[a-z][a-z0-9_.]*$", selected_groups$module)) &&
      all(grepl("^[0-9a-f]{64}$", selected_groups$coordinate_sha256)) &&
      !anyDuplicated(selected_groups[c("binding", "indicator", "kind")])
  if (!group_valid || sum(group_counts) != expected_count ||
      (expected_count > 0L) != (nrow(selected_groups) > 0L)) {
    stop(sprintf("Non-finite groups for `%s` are invalid.", method),
      call. = FALSE
    )
  }
  selected_groups$expected_count <- as.character(group_counts)
  selected_groups <- selected_groups[order(
    selected_groups$binding, selected_groups$kind, method = "radix"
  ), , drop = FALSE]
  row.names(selected_groups) <- NULL
  list(
    method = method,
    scientific_profile = selected_map$scientific_profile[[1L]],
    source = selected_declaration$source[[1L]],
    leontief_zero_profile = selected_declaration$leontief_zero_profile[[1L]],
    id = profile_id,
    action = selected_profile$action[[1L]],
    expected_count = expected_count,
    groups = selected_groups
  )
}

wlv13_v5d_expected_nonfinite <- function(profile) {
  columns <- wlv13_cross_engine_schema(
    "_nonfinite_resolution_diagnostics.csv"
  )
  if (!nrow(profile$groups)) {
    return(wlv13_v5d_normalize_table(
      as.data.frame(stats::setNames(replicate(
        length(columns), character(), simplify = FALSE
      ), columns), stringsAsFactors = FALSE, check.names = FALSE),
      columns,
      "Empty expected non-finite diagnostics"
    ))
  }
  groups <- profile$groups
  result <- data.frame(
    method = rep(profile$method, nrow(groups)),
    scientific_profile = rep(profile$scientific_profile, nrow(groups)),
    nonfinite_resolution_profile = rep(profile$id, nrow(groups)),
    action = rep(profile$action, nrow(groups)),
    module = groups$module,
    binding = groups$binding,
    indicator = groups$indicator,
    kind = groups$kind,
    resolved_count = groups$expected_count,
    coordinate_sha256 = groups$coordinate_sha256,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  wlv13_v5d_normalize_table(result[columns], columns,
    "Expected non-finite diagnostics"
  )
}

wlv13_v5d_validate_nonfinite_value <- function(
    value, method, profile, anomalies = NULL) {
  columns <- wlv13_cross_engine_schema(
    "_nonfinite_resolution_diagnostics.csv"
  )
  observed <- wlv13_v5d_normalize_table(
    value, columns, "Candidate non-finite diagnostics"
  )
  expected <- wlv13_v5d_expected_nonfinite(profile)
  exact_profile <- profile$expected_count > 0L &&
    wlv13_v5d_exact_ordered(observed, expected)
  resolution_mask <- if (is.null(anomalies)) NULL else
    rep(FALSE, nrow(anomalies))
  coordinate_valid <- is.null(anomalies)
  coordinate_records <- character()
  if (!is.null(anomalies)) {
    anomaly_columns <- wlv13_cross_engine_schema("_anomalies.csv")
    anomalies <- wlv13_v5d_normalize_table(
      anomalies, anomaly_columns, "Candidate anomalies"
    )
    anomaly_action <- switch(
      profile$action,
      replace_nan_with_zero =
        "replace_profiled_historical_nan_with_zero",
      replace_zero_denominator_with_zero =
        "replace_zero_denominator_with_zero",
      stop("A rejecting profile cannot publish resolution diagnostics.",
        call. = FALSE
      )
    )
    coordinate_valid <- exact_profile
    for (index in seq_len(nrow(expected))) {
      record <- expected[index, , drop = FALSE]
      selected <-
        anomalies$artifact == "sea_sectors" &
        anomalies$checkpoint == "after_stage_2" &
        anomalies$stage == "2" &
        anomalies$module == record$module[[1L]] &
        anomalies$indicator == record$indicator[[1L]] &
        anomalies$original_value == record$kind[[1L]] &
        anomalies$policy_id == profile$id &
        anomalies$action == anomaly_action
      if (any(resolution_mask & selected)) coordinate_valid <- FALSE
      keys <- sort(paste(
        anomalies$year[selected],
        anomalies$country[selected],
        anomalies$sector[selected],
        sep = "|"
      ), method = "radix")
      observed_hash <- wlv13_v5d_sha256_text(paste(keys, collapse = "\n"))
      expected_count <- as.integer(record$resolved_count[[1L]])
      row_valid <- length(keys) == expected_count &&
        identical(observed_hash, record$coordinate_sha256[[1L]])
      coordinate_valid <- coordinate_valid && row_valid
      coordinate_records <- c(coordinate_records, paste(
        record$binding[[1L]], record$indicator[[1L]], record$kind[[1L]],
        as.character(length(keys)), observed_hash, sep = "|"
      ))
      resolution_mask <- resolution_mask | selected
    }
    claimed <- anomalies$policy_id == profile$id
    coordinate_valid <- coordinate_valid &&
      identical(which(claimed), which(resolution_mask)) &&
      sum(resolution_mask) == profile$expected_count
  }
  list(
    passed = exact_profile && coordinate_valid,
    exact_profile = exact_profile,
    coordinate_valid = coordinate_valid,
    resolution_mask = resolution_mask,
    coordinate_binding_sha256 = if (length(coordinate_records)) {
      wlv13_v5d_sha256_text(paste(coordinate_records, collapse = "\n"))
    } else {
      wlv13_v5d_sha256_text("")
    },
    observed = observed,
    expected = expected
  )
}

wlv13_v5d_validate_nonfinite_descriptor <- function(descriptor, method) {
  parsed <- wlv13_cross_engine_read(
    descriptor, "_nonfinite_resolution_diagnostics.csv"
  )
  context <- wlv13_v5d_context(descriptor, "candidate", method)
  profile <- wlv13_v5d_scientific_profile(context$project_root, method)
  validation <- wlv13_v5d_validate_nonfinite_value(
    parsed$value, method, profile
  )
  list(
    passed = parsed$schema_valid && validation$passed,
    comparison_mode = "contract-bound-exact-candidate-diagnostic",
    schema_valid = parsed$schema_valid,
    rows = nrow(parsed$value),
    resolved_count = if (nrow(parsed$value)) {
      sum(as.integer(parsed$value$resolved_count))
    } else {
      0L
    },
    method = method,
    scientific_profile = profile$scientific_profile,
    nonfinite_resolution_profile = profile$id,
    profile_action = profile$action,
    profile_expected_count = profile$expected_count,
    profile_exact = validation$exact_profile,
    coordinate_binding_required = TRUE,
    architecture_difference = TRUE,
    value = parsed$value
  )
}

wlv13_cross_engine_validate_nonfinite <- function(descriptor, method) {
  if (identical(
      descriptor$relative,
      "_nonfinite_resolution_diagnostics.csv"
    )) {
    return(tryCatch(
      wlv13_v5d_validate_nonfinite_descriptor(descriptor, method),
      error = function(error) list(
        passed = FALSE,
        comparison_mode = "contract-bound-exact-candidate-diagnostic",
        reason = conditionMessage(error),
        architecture_difference = TRUE
      )
    ))
  }
  wlv13_v5d_previous_validate_nonfinite(descriptor, method)
}

wlv13_v5d_transform_unit_baseline <- function(
    value, method, bridges, mode = "calculate",
    valid_candidate_modules = NULL) {
  bridged <- wlv13_v5d_closed_module_bridge(
    value, bridges, method, "_unit_contract.csv", mode,
    valid_candidate_modules
  )
  list(
    value = bridged$value,
    module_bridge_rows = bridged$changed_rows,
    note_bridge_rows = 0L,
    module_bridge_sha256 = bridged$bridge_sha256,
    coverage_complete = bridged$coverage_complete,
    used_profile_rows = bridged$used_profile_rows
  )
}

wlv13_v5d_source_unit_bridge_profile <- function(bridges, source) {
  bridges <- wlv13_v5d_validate_bridge_manifest(bridges)
  expected_methods <- wlv13_v5d_methods_by_source[[source]]
  if (is.null(expected_methods)) {
    stop("Unsupported source-level unit-contract profile.", call. = FALSE)
  }
  selected <- bridges[
    bridges$artifact_name == "_unit_contract.csv" &
      bridges$source == source, , drop = FALSE
  ]
  if (!identical(
      sort(unique(selected$method), method = "radix"),
      sort(expected_methods, method = "radix")
    )) {
    stop("Source-level unit bridges lack exact method coverage.",
      call. = FALSE
    )
  }
  signature_columns <- c(
    "source", "indicator", "strategy", "baseline_module",
    "candidate_module", "expected_baseline_evidence_rows",
    "expected_candidate_evidence_rows"
  )
  signatures <- lapply(expected_methods, function(method) {
    value <- selected[selected$method == method, signature_columns,
      drop = FALSE
    ]
    order_index <- do.call(order, c(value, list(method = "radix")))
    value <- value[order_index, , drop = FALSE]
    row.names(value) <- NULL
    value
  })
  if (!all(vapply(signatures[-1L], identical, logical(1L),
      signatures[[1L]]))) {
    stop("Source-level unit bridges differ across source methods.",
      call. = FALSE
    )
  }
  selected[selected$method == expected_methods[[1L]], , drop = FALSE]
}

wlv13_v5d_compare_source_unit_contract <- function(
    baseline, candidate, source, bridges = NULL) {
  columns <- wlv13_cross_engine_schema("_unit_contract.csv")
  baseline <- wlv13_v5d_normalize_table(
    baseline, columns, "Baseline source-level unit contract"
  )
  candidate <- wlv13_v5d_normalize_table(
    candidate, columns, "Candidate source-level unit contract"
  )
  if (is.null(bridges)) bridges <- wlv13_v5d_read_bridge_manifest()
  profile <- wlv13_v5d_source_unit_bridge_profile(bridges, source)
  method <- unique(profile$method)
  transformed <- wlv13_v5d_transform_unit_baseline(
    baseline, method, profile, "calculate",
    unique(profile$candidate_module)
  )
  candidate_generation <- wlv13_v5d_closed_module_bridge(
    candidate, profile, method, "_unit_contract.csv", "preparation",
    unique(profile$candidate_module)
  )
  candidate_expected <- sum(as.integer(
    profile$expected_candidate_evidence_rows
  ))
  passed <- all(baseline$source == source) &&
    all(candidate$source == source) &&
    !anyDuplicated(wlv13_v5d_raw_row_keys(baseline)) &&
    !anyDuplicated(wlv13_v5d_raw_row_keys(candidate)) &&
    transformed$coverage_complete &&
    candidate_generation$changed_rows == 0L &&
    candidate_generation$target_generation_rows == candidate_expected &&
    wlv13_v5d_exact_ordered(candidate, transformed$value)
  list(
    passed = passed,
    comparison_mode = "exhaustive-source-unit-contract-bridge",
    source = source,
    all_columns_compared = identical(names(baseline), columns) &&
      identical(names(candidate), columns),
    exact_order_after_bridge = wlv13_v5d_exact_ordered(
      candidate, transformed$value
    ),
    baseline_rows = nrow(baseline),
    candidate_rows = nrow(candidate),
    bridge_rows = transformed$module_bridge_rows,
    aggregation_note_bridge_rows = transformed$note_bridge_rows,
    bridge_sha256 = transformed$module_bridge_sha256
  )
}

wlv13_v5d_compare_unit <- function(left, right, name) {
  method <- basename(dirname(dirname(left$path)))
  if (!identical(method, basename(dirname(dirname(right$path))))) {
    stop("Cross-engine unit-contract methods differ.", call. = FALSE)
  }
  candidate_context <- wlv13_v5d_context(left, "candidate", method)
  baseline_context <- wlv13_v5d_context(right, "baseline", method)
  left_parsed <- wlv13_cross_engine_read(left, name)
  right_parsed <- wlv13_cross_engine_read(right, name)
  columns <- wlv13_cross_engine_schema(name)
  candidate <- wlv13_v5d_normalize_table(
    left_parsed$value, columns, "Candidate unit contract"
  )
  baseline <- wlv13_v5d_normalize_table(
    right_parsed$value, columns, "Baseline unit contract"
  )
  execution <- wlv13_v5d_run_request(candidate_context)
  baseline_execution <- wlv13_v5d_run_request(baseline_context)
  execution_fields <- c(
    "method", "mode", "at_stage", "sea_vars_sha256", "workers",
    "request_sha256", "scenario_id"
  )
  execution_match <- identical(
    execution[execution_fields], baseline_execution[execution_fields]
  )
  profile <- wlv13_v5d_scientific_profile(
    candidate_context$project_root, method
  )
  source_valid <- all(candidate$source == profile$source) &&
    all(baseline$source == profile$source)
  bridges <- wlv13_v5d_read_bridge_manifest()
  owner_contract <- wlv13_v5d_candidate_owner_contract(
    candidate_context$project_root, method
  )
  owner_contract_valid <- wlv13_v5d_bridge_targets_valid(
    bridges, method, "_unit_contract.csv", owner_contract
  )
  candidate_modules <- owner_contract$aggregation_modules
  transformed <- wlv13_v5d_transform_unit_baseline(
    baseline, method, bridges, execution$mode, candidate_modules
  )
  candidate_generation <- wlv13_v5d_closed_module_bridge(
    candidate, bridges, method, "_unit_contract.csv", "recalculate",
    candidate_modules
  )
  selected_bridges <- bridges[
    bridges$method == method &
      bridges$artifact_name == "_unit_contract.csv", , drop = FALSE
  ]
  candidate_generation_valid <- candidate_generation$changed_rows == 0L &&
    (!identical(execution$mode, "calculate") ||
      candidate_generation$target_generation_rows == sum(as.integer(
        selected_bridges$expected_candidate_evidence_rows
      )))
  required <- c(
    "contract", "schema_version", "source", "indicator", "quantity_kind",
    "source_unit", "source_scale", "canonical_unit", "display_unit",
    "display_multiplier", "level", "strategy"
  )
  nonempty <- nrow(candidate) > 0L && nrow(baseline) > 0L &&
    all(vapply(required, function(column) {
      all(nzchar(candidate[[column]])) && all(nzchar(baseline[[column]]))
    }, logical(1L)))
  candidate_keys <- wlv13_v5d_raw_row_keys(candidate)
  baseline_keys <- wlv13_v5d_raw_row_keys(baseline)
  valid <- left_parsed$schema_valid && right_parsed$schema_valid &&
    execution_match && source_valid && nonempty &&
    !anyDuplicated(candidate_keys) && !anyDuplicated(baseline_keys) &&
    transformed$coverage_complete && owner_contract_valid &&
    candidate_generation_valid &&
    wlv13_v5d_exact_ordered(candidate, transformed$value)
  list(
    summary = list(
      passed = valid,
      comparison_mode = "exhaustive-typed-unit-contract-bridge",
      method = method,
      candidate_schema_valid = left_parsed$schema_valid,
      baseline_schema_valid = right_parsed$schema_valid,
      candidate_rows = nrow(candidate),
      baseline_rows = nrow(baseline),
      all_columns_compared = identical(names(candidate), columns) &&
        identical(names(baseline), columns),
      exact_order_after_bridge = wlv13_v5d_exact_ordered(
        candidate, transformed$value
      ),
      module_bridge_rows = transformed$module_bridge_rows,
      aggregation_note_bridge_rows = transformed$note_bridge_rows,
      legacy_adapter_profile = transformed$module_bridge_rows > 0L,
      module_pairs_valid = transformed$coverage_complete,
      aggregation_note_pairs_valid = identical(
        candidate$aggregation_notes, baseline$aggregation_notes
      ),
      candidate_module_generation_valid = candidate_generation_valid,
      candidate_owner_contract_valid = owner_contract_valid,
      candidate_owner_contract_sha256 =
        owner_contract$aggregation_modules_sha256,
      bridge_profile_rows = nrow(selected_bridges),
      bridge_profile_rows_used = transformed$used_profile_rows,
      execution_context_match = execution_match,
      source_profile_valid = source_valid,
      module_bridge_sha256 = transformed$module_bridge_sha256,
      candidate_artifact_sha256 = left$sha256,
      baseline_artifact_sha256 = right$sha256,
      raw_semantic_equal = identical(candidate, baseline),
      architecture_difference = !identical(candidate, baseline)
    ),
    transitions = data.frame(),
    indicators = data.frame()
  )
}

wlv13_v5d_expected_check_row <- function(
    method, check_id, artifact, observations, detail) {
  data.frame(
    method = method,
    check_id = check_id,
    artifact = artifact,
    indicator = "",
    scope = "global",
    status = "pass",
    observations = as.character(observations),
    maximum_absolute_error = "",
    maximum_scaled_error = "",
    tolerance = "exact",
    detail = detail,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )[wlv13_cross_engine_schema("_scientific_checks.csv")]
}

wlv13_v5d_architecture_checks <- function(
    candidate, baseline, method, candidate_root, baseline_root, profile) {
  unit_columns <- wlv13_cross_engine_schema("_unit_contract.csv")
  candidate_units <- wlv13_v5d_read_contract_table(
    candidate_root, "_unit_contract.csv", unit_columns,
    "Candidate run unit contract"
  )
  baseline_units <- wlv13_v5d_read_contract_table(
    baseline_root, "_unit_contract.csv", unit_columns,
    "Baseline run unit contract"
  )
  candidate_arch <- candidate[
    candidate$check_id %in% wlv13_v5d_architecture_check_ids,
    , drop = FALSE
  ]
  baseline_arch <- baseline[
    baseline$check_id %in% wlv13_v5d_architecture_check_ids,
    , drop = FALSE
  ]
  row.names(candidate_arch) <- NULL
  row.names(baseline_arch) <- NULL
  candidate_expected <- wlv13_v5d_expected_check_row(
    method, "aggregation_contract", "_unit_contract.csv",
    nrow(candidate_units),
    "Persisted typed aggregation rows exactly cover the result."
  )
  if (profile$expected_count > 0L) {
    candidate_expected <- rbind(
      candidate_expected,
      wlv13_v5d_expected_check_row(
        method, "nonfinite_resolution",
        "_nonfinite_resolution_diagnostics.csv",
        profile$expected_count,
        sprintf(
          "Profile `%s` closed %s declared historical transition(s).",
          profile$id, profile$expected_count
        )
      )
    )
  }
  baseline_legacy <- baseline_arch$check_id ==
    "aggregation_legacy_adapter"
  legacy_present <- sum(baseline_legacy) == 1L
  baseline_expected <- wlv13_v5d_expected_check_row(
    method, "aggregation_contract", "_unit_contract.csv",
    if (legacy_present) 0L else nrow(baseline_units),
    paste0(
      "Persisted typed aggregation rows are distinct from any legacy ",
      "adapter route."
    )
  )
  if (legacy_present) {
    baseline_expected <- rbind(
      baseline_expected,
      wlv13_v5d_expected_check_row(
        method, "aggregation_legacy_adapter", "_method_solutions.csv",
        nrow(baseline_units),
        paste0(
          "Experimental legacy rows are independently recomputed without ",
          "being classified as typed unit-contract aggregations."
        )
      )
    )
  }
  row.names(candidate_expected) <- NULL
  row.names(baseline_expected) <- NULL
  list(
    passed = wlv13_v5d_exact_ordered(candidate_arch, candidate_expected) &&
      wlv13_v5d_exact_ordered(baseline_arch, baseline_expected),
    candidate = candidate_arch,
    baseline = baseline_arch,
    candidate_expected = candidate_expected,
    baseline_expected = baseline_expected,
    legacy_adapter_present = legacy_present
  )
}

wlv13_v5d_transform_scientific_core <- function(value) {
  result <- value[
    !value$check_id %in% wlv13_v5d_architecture_check_ids,
    , drop = FALSE
  ]
  scope_map <- c(
    "legacy_adapter:sum" = "sum",
    "legacy_adapter:mean" = "mean"
  )
  selected_scope <- result$scope %in% names(scope_map)
  result$scope[selected_scope] <- unname(scope_map[result$scope[selected_scope]])
  detail_map <- c(
    "Independent `sum` reference aggregation over countries (legacy adapter route)." =
      "Independent `sum` typed reference aggregation over countries.",
    "Independent `mean` reference aggregation over countries (legacy adapter route)." =
      "Independent `mean` typed reference aggregation over countries.",
    "Independent `sum` reference aggregation over sectors (legacy adapter route)." =
      "Independent `sum` typed reference aggregation over sectors.",
    "Independent `mean` reference aggregation over sectors (legacy adapter route)." =
      "Independent `mean` typed reference aggregation over sectors."
  )
  typed_strategies <- c(
    "invariant", "not_applicable", "ratio_of_sums", "sum",
    "weighted_mean", "mean"
  )
  typed_domains <- c("countries", "sectors")
  for (strategy in typed_strategies) {
    for (domain in typed_domains) {
      legacy_detail <- sprintf(
        "Independent `%s` reference aggregation over %s (typed contract route).",
        strategy, domain
      )
      native_detail <- sprintf(
        "Independent `%s` typed reference aggregation over %s.",
        strategy, domain
      )
      detail_map[[legacy_detail]] <- native_detail
    }
  }
  selected_detail <- result$detail %in% names(detail_map)
  result$detail[selected_detail] <- unname(detail_map[result$detail[selected_detail]])
  row.names(result) <- NULL
  list(
    value = result,
    scope_bridge_rows = sum(selected_scope),
    detail_bridge_rows = sum(selected_detail),
    bridge_sha256 = wlv13_v5d_sha256_text(paste(
      c(
        paste(names(scope_map), unname(scope_map), sep = "=>"),
        paste(names(detail_map), unname(detail_map), sep = "=>")
      ),
      collapse = "\n"
    ))
  )
}

wlv13_v5d_compare_scientific <- function(left, right, name) {
  method <- basename(dirname(dirname(left$path)))
  if (!identical(method, basename(dirname(dirname(right$path))))) {
    stop("Cross-engine scientific-check methods differ.", call. = FALSE)
  }
  candidate_context <- wlv13_v5d_context(left, "candidate", method)
  baseline_context <- wlv13_v5d_context(right, "baseline", method)
  profile <- wlv13_v5d_scientific_profile(
    candidate_context$project_root, method
  )
  left_parsed <- wlv13_cross_engine_read(left, name)
  right_parsed <- wlv13_cross_engine_read(right, name)
  columns <- wlv13_cross_engine_schema(name)
  candidate <- wlv13_v5d_normalize_table(
    left_parsed$value, columns, "Candidate scientific checks"
  )
  baseline <- wlv13_v5d_normalize_table(
    right_parsed$value, columns, "Baseline scientific checks"
  )
  architecture <- wlv13_v5d_architecture_checks(
    candidate, baseline, method,
    candidate_context$run_root, baseline_context$run_root, profile
  )
  candidate_core <- candidate[
    !candidate$check_id %in% wlv13_v5d_architecture_check_ids,
    , drop = FALSE
  ]
  row.names(candidate_core) <- NULL
  baseline_core <- wlv13_v5d_transform_scientific_core(baseline)
  status_valid <- nrow(candidate) > 0L && nrow(baseline) > 0L &&
    all(candidate$status %in% c("pass", "warning", "not_applicable")) &&
    all(baseline$status %in% c("pass", "warning", "not_applicable"))
  candidate_keys <- wlv13_v5d_raw_row_keys(candidate)
  baseline_keys <- wlv13_v5d_raw_row_keys(baseline)
  core_exact <- wlv13_v5d_exact_ordered(
    candidate_core, baseline_core$value
  )
  valid <- left_parsed$schema_valid && right_parsed$schema_valid &&
    status_valid && !anyDuplicated(candidate_keys) &&
    !anyDuplicated(baseline_keys) && architecture$passed && core_exact
  list(
    summary = list(
      passed = valid,
      comparison_mode = "exhaustive-scientific-check-bridge",
      method = method,
      candidate_schema_valid = left_parsed$schema_valid,
      baseline_schema_valid = right_parsed$schema_valid,
      candidate_rows = nrow(candidate),
      baseline_rows = nrow(baseline),
      candidate_core_rows = nrow(candidate_core),
      baseline_core_rows = nrow(baseline_core$value),
      all_columns_compared = identical(names(candidate), columns) &&
        identical(names(baseline), columns),
      exact_order_after_bridge = core_exact,
      architecture_checks_exact = architecture$passed,
      legacy_adapter_present = architecture$legacy_adapter_present,
      scope_bridge_rows = baseline_core$scope_bridge_rows,
      detail_bridge_rows = baseline_core$detail_bridge_rows,
      bridge_sha256 = baseline_core$bridge_sha256,
      scientific_profile = profile$scientific_profile,
      nonfinite_resolution_profile = profile$id,
      candidate_artifact_sha256 = left$sha256,
      baseline_artifact_sha256 = right$sha256,
      raw_semantic_equal = identical(candidate, baseline),
      architecture_difference = !identical(candidate, baseline)
    ),
    transitions = data.frame(),
    indicators = data.frame()
  )
}

wlv13_cross_engine_compare_config <- function(left, right, name) {
  if (identical(name, "_scientific_checks.csv")) {
    return(wlv13_v5d_compare_scientific(left, right, name))
  }
  if (identical(name, "_unit_contract.csv")) {
    return(wlv13_v5d_compare_unit(left, right, name))
  }
  wlv13_v5d_previous_compare_config(left, right, name)
}

wlv13_v5d_normalize_baseline_anomaly_modules <- function(
    value, profile, bridges = NULL, mode = "calculate",
    valid_candidate_modules = NULL) {
  if (!is.list(profile) || !profile$method %in% wlv13_v5d_methods) {
    stop("Anomaly module normalization lacks its method profile.",
      call. = FALSE
    )
  }
  if (is.null(bridges)) bridges <- wlv13_v5d_read_bridge_manifest()
  transformed <- wlv13_v5d_closed_module_bridge(
    value, bridges, profile$method, "_anomalies.csv", mode,
    valid_candidate_modules
  )
  list(
    value = transformed$value,
    changed_rows = transformed$changed_rows,
    rules = if (transformed$changed_rows) {
      "closed-controller-profile"
    } else {
      character()
    },
    bridge_sha256 = transformed$bridge_sha256,
    coverage_complete = transformed$coverage_complete,
    used_profile_rows = transformed$used_profile_rows,
    target_generation_rows = transformed$target_generation_rows
  )
}

wlv13_v5d_normalize_baseline_anomaly_policy <- function(value, profile) {
  result <- value
  expected <- profile$leontief_zero_profile
  legacy <- sub("_v09_", "_", expected, fixed = TRUE)
  selected <- legacy != expected & result$policy_id == legacy
  result$policy_id[selected] <- expected
  list(
    value = result,
    changed_rows = sum(selected),
    bridge = if (any(selected)) paste(legacy, expected, sep = "=>") else ""
  )
}

wlv13_v5d_bridge_baseline_nonfinite <- function(value, profile) {
  result <- value
  selected_all <- rep(FALSE, nrow(result))
  records <- character()
  if (!identical(profile$action, "replace_nan_with_zero")) {
    return(list(
      value = result,
      passed = TRUE,
      rows = 0L,
      binding_sha256 = wlv13_v5d_sha256_text("")
    ))
  }
  legacy_policy <- "issue13_cc2_historical_nan_clean_v1"
  legacy_action <- "replace_historical_nan_with_zero"
  legacy_module <- sprintf(
    "reduction/%s-complex_labour_multiplier.empe.r.un.R",
    profile$method
  )
  valid <- TRUE
  for (index in seq_len(nrow(profile$groups))) {
    group <- profile$groups[index, , drop = FALSE]
    selected <-
      result$artifact == "sea_sectors" &
      result$checkpoint == "after_stage_2" &
      result$stage == "2" &
      result$module == legacy_module &
      result$indicator == group$indicator[[1L]] &
      result$original_value == group$kind[[1L]] &
      result$policy_id == legacy_policy &
      result$action == legacy_action
    if (any(selected_all & selected)) valid <- FALSE
    keys <- sort(paste(
      result$year[selected], result$country[selected], result$sector[selected],
      sep = "|"
    ), method = "radix")
    observed_hash <- wlv13_v5d_sha256_text(paste(keys, collapse = "\n"))
    expected_count <- as.integer(group$expected_count[[1L]])
    valid <- valid && length(keys) == expected_count &&
      identical(observed_hash, group$coordinate_sha256[[1L]])
    result$module[selected] <- group$module[[1L]]
    result$policy_id[selected] <- profile$id
    result$action[selected] <- "replace_profiled_historical_nan_with_zero"
    selected_all <- selected_all | selected
    records <- c(records, paste(
      group$binding[[1L]], group$indicator[[1L]], group$kind[[1L]],
      length(keys), observed_hash, sep = "|"
    ))
  }
  legacy_claimed <- value$policy_id == legacy_policy |
    value$action == legacy_action |
    value$module == legacy_module
  valid <- valid && identical(which(legacy_claimed), which(selected_all)) &&
    sum(selected_all) == profile$expected_count
  list(
    value = result,
    passed = valid,
    rows = sum(selected_all),
    binding_sha256 = wlv13_v5d_sha256_text(paste(records, collapse = "\n"))
  )
}

wlv13_v5d_parent_stage5_binding <- function(
    candidate_parent, baseline_parent, profile) {
  columns <- wlv13_cross_engine_schema("_anomalies.csv")
  candidate <- wlv13_v5d_normalize_table(
    wlv13_read_csv_semantic(candidate_parent$anomalies_path),
    columns, "Candidate parent anomalies"
  )
  baseline <- wlv13_v5d_normalize_table(
    wlv13_read_csv_semantic(baseline_parent$anomalies_path),
    columns, "Baseline parent anomalies"
  )
  candidate_stage <- wlv13_v5d_validate_anomaly_shape(
    candidate, "Candidate parent anomalies"
  )
  baseline_stage <- wlv13_v5d_validate_anomaly_shape(
    baseline, "Baseline parent anomalies"
  )
  baseline_resolution <- wlv13_v5d_bridge_baseline_nonfinite(
    baseline, profile
  )
  policy <- wlv13_v5d_normalize_baseline_anomaly_policy(
    baseline_resolution$value, profile
  )
  bridges <- wlv13_v5d_read_bridge_manifest()
  owner_contract <- wlv13_v5d_candidate_owner_contract(
    candidate_parent$context$project_root, profile$method
  )
  owner_contract_valid <- wlv13_v5d_bridge_targets_valid(
    bridges, profile$method, "_anomalies.csv", owner_contract
  )
  modules <- wlv13_v5d_normalize_baseline_anomaly_modules(
    policy$value, profile, bridges, "calculate"
  )
  candidate_modules <- wlv13_v5d_normalize_baseline_anomaly_modules(
    candidate, profile, bridges, "recalculate"
  )
  selected_bridges <- bridges[
    bridges$method == profile$method &
      bridges$artifact_name == "_anomalies.csv", , drop = FALSE
  ]
  candidate_generation_valid <- candidate_modules$changed_rows == 0L &&
    candidate_modules$target_generation_rows == sum(as.integer(
      selected_bridges$expected_candidate_evidence_rows
    ))
  candidate_keys <- wlv13_v5d_raw_row_keys(
    candidate[candidate_stage >= 5L, , drop = FALSE]
  )
  baseline_keys <- wlv13_v5d_raw_row_keys(
    modules$value[baseline_stage >= 5L, , drop = FALSE]
  )
  candidate_counts <- wlv13_v5d_stage5_counts(candidate_keys)
  baseline_counts <- wlv13_v5d_stage5_counts(baseline_keys)
  difference <- wlv13_v5d_stage5_difference(
    candidate_counts, baseline_counts
  )
  list(
    passed = baseline_resolution$passed &&
      owner_contract_valid && modules$coverage_complete &&
      candidate_generation_valid &&
      modules$target_generation_rows == 0L &&
      difference$same_keys && difference$exact,
    reference_sha256 = candidate_counts$sha256,
    candidate_rows = candidate_counts$rows,
    baseline_rows = baseline_counts$rows,
    difference_sha256 = difference$sha256
  )
}

wlv13_v5d_stage5_counts <- function(keys) {
  counts <- table(enc2utf8(as.character(keys)))
  names <- names(counts)
  values <- as.integer(counts)
  records <- if (length(values)) vapply(seq_along(values), function(index) {
    wlv13_v5d_length_record(names[[index]], as.character(values[[index]]))
  }, character(1L)) else character()
  list(
    names = names,
    counts = values,
    rows = length(keys),
    sha256 = wlv13_v5d_sha256_text(paste(records, collapse = "\n"))
  )
}

wlv13_v5d_stage5_difference <- function(candidate, baseline) {
  same_keys <- identical(candidate$names, baseline$names)
  if (!same_keys) {
    return(list(
      same_keys = FALSE,
      structurally_valid = FALSE,
      exact = FALSE,
      key_count = NA_integer_,
      sha256 = wlv13_v5d_sha256_text(""),
      ratios = integer()
    ))
  }
  changed <- candidate$counts != baseline$counts
  records <- if (any(changed)) vapply(which(changed), function(index) {
    wlv13_v5d_length_record(
      candidate$names[[index]],
      as.character(candidate$counts[[index]]),
      as.character(baseline$counts[[index]])
    )
  }, character(1L)) else character()
  ratios <- if (length(candidate$counts)) {
    ifelse(
      baseline$counts %% candidate$counts == 0L,
      baseline$counts %/% candidate$counts,
      NA_integer_
    )
  } else {
    integer()
  }
  list(
    same_keys = TRUE,
    structurally_valid = !anyNA(ratios) && all(ratios %in% c(1L, 2L)),
    exact = !any(changed),
    key_count = sum(changed),
    sha256 = wlv13_v5d_sha256_text(paste(records, collapse = "\n")),
    ratios = sort(unique(ratios))
  )
}

wlv13_v5d_stage5_profile_derivation <- function(value) {
  columns <- setdiff(
    wlv13_v5d_stage5_profile_columns,
    c("profile_id", "derivation_sha256")
  )
  if (!is.data.frame(value) || nrow(value) != 1L ||
      !all(columns %in% names(value))) {
    stop("Invalid stage-five profile derivation row.", call. = FALSE)
  }
  records <- vapply(columns, function(column) {
    wlv13_v5d_length_record(column, value[[column]][[1L]])
  }, character(1L))
  wlv13_v5d_sha256_text(paste(records, collapse = "\n"))
}

wlv13_v5d_stage5_profile_path <- function() {
  scope <- environment(wlv13_v5d_stage5_profile_path)
  root <- if (exists("script_dir", envir = scope, inherits = TRUE)) {
    get("script_dir", envir = scope, inherits = TRUE)
  } else {
    NULL
  }
  if (!is.character(root) || length(root) != 1L || !nzchar(root)) {
    stop("The stage-five profile root is unavailable.", call. = FALSE)
  }
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  path <- file.path(root, "issue13-v5-stage5-multiplicity-profiles.csv")
  if (!file.exists(path) || isTRUE(file.info(path)$isdir)) {
    stop("The pinned stage-five profile manifest is missing.",
      call. = FALSE
    )
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

wlv13_v5d_read_stage5_profiles <- function(path = NULL) {
  if (is.null(path)) {
    path <- wlv13_v5d_stage5_profile_path()
  } else {
    path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  }
  value <- wlv13_v5d_normalize_table(
    wlv13_read_csv_semantic(path),
    wlv13_v5d_stage5_profile_columns,
    "Stage-five multiplicity profiles"
  )
  if (!nrow(value)) return(value)
  sha_columns <- grep("sha256$", names(value), value = TRUE)
  integer_columns <- c(
    "workers", "candidate_stage5_rows", "baseline_stage5_rows",
    "difference_key_count"
  )
  valid <- all(value$schema_version == wlv13_v5d_stage5_profile_schema) &&
    all(grepl("^stage5-[0-9a-f]{24}$", value$profile_id)) &&
    all(grepl("^recalculate/stage-(1|4|5)/", value$scenario_id)) &&
    all(value$method %in% wlv13_v5d_methods) &&
    all(value$mode == "recalculate") &&
    all(value$at_stage %in% c("1", "4", "5")) &&
    all(vapply(sha_columns, function(column) {
      all(grepl("^[0-9a-f]{64}$", value[[column]]))
    }, logical(1L))) &&
    all(vapply(integer_columns, function(column) {
      parsed <- suppressWarnings(as.integer(value[[column]]))
      !anyNA(parsed) && all(parsed > 0L) &&
        identical(as.character(parsed), value[[column]])
    }, logical(1L))) &&
    all(grepl("^run-[0-9A-Za-z-]+$",
      value$evidence_candidate_reference_run_id)) &&
    all(grepl("^run-[0-9A-Za-z-]+$",
      value$evidence_baseline_reference_run_id)) &&
    all(grepl("^run-[0-9A-Za-z-]+$",
      value$evidence_baseline_target_run_id)) &&
    all(vapply(c(
      "evidence_candidate_reference_commit",
      "evidence_candidate_reference_tree",
      "evidence_baseline_reference_commit",
      "evidence_baseline_reference_tree",
      "evidence_baseline_target_commit",
      "evidence_baseline_target_tree"
    ), function(column) {
      all(grepl("^[0-9a-f]{40}$", value[[column]]))
    }, logical(1L))) &&
    all(value$evidence_candidate_reference_request_sha256 ==
      value$evidence_baseline_reference_request_sha256) &&
    all(value$evidence_baseline_target_request_sha256 ==
      value$request_sha256) &&
    all(value$reference_stage5_sha256 == value$candidate_stage5_sha256) &&
    all(as.integer(value$baseline_stage5_rows) >
      as.integer(value$candidate_stage5_rows)) &&
    all(as.integer(value$difference_key_count) > 0L) &&
    !anyDuplicated(value[c("method", "request_sha256")]) &&
    identical(order(
      match(value$method, wlv13_v5d_methods), as.integer(value$at_stage),
      value$request_sha256, method = "radix"
    ), seq_len(nrow(value)))
  if (!valid) {
    stop("The stage-five multiplicity profile manifest is invalid.",
      call. = FALSE
    )
  }
  derivations <- vapply(seq_len(nrow(value)), function(index) {
    wlv13_v5d_stage5_profile_derivation(value[index, , drop = FALSE])
  }, character(1L))
  if (!identical(derivations, value$derivation_sha256) ||
      !identical(paste0("stage5-", substr(derivations, 1L, 24L)),
        value$profile_id)) {
    stop("The stage-five multiplicity profile derivation is invalid.",
      call. = FALSE
    )
  }
  value
}

wlv13_v5d_stage5_bridge_reference_binding <- function(
    bridges, method, candidate_reference, baseline_reference) {
  selected <- bridges[
    bridges$method == method &
      bridges$artifact_name == "_anomalies.csv", , drop = FALSE
  ]
  side_valid <- function(value, prefix) {
    expected_columns <- c(
      run_id = paste0(prefix, "_run_id"),
      anomalies_sha256 = paste0(prefix, "_artifact_sha256"),
      request_sha256 = paste0(prefix, "_request_sha256"),
      source_sha256 = paste0(prefix, "_source_sha256"),
      commit = paste0(prefix, "_commit"),
      tree = paste0(prefix, "_tree")
    )
    if (!is.list(value) || !is.list(value$execution) ||
        is.null(value$anomalies) || !is.list(value$anomalies)) {
      return(FALSE)
    }
    observed <- c(
      run_id = value$run_id,
      anomalies_sha256 = value$anomalies$sha256,
      request_sha256 = value$execution$request_sha256,
      source_sha256 = value$source_sha256,
      commit = value$commit,
      tree = value$tree
    )
    all(vapply(seq_along(expected_columns), function(index) {
      column <- unname(expected_columns[[index]])
      sealed <- unique(selected[[column]])
      length(sealed) == 1L && identical(
        unname(observed[[names(expected_columns)[[index]]]]), sealed[[1L]]
      )
    }, logical(1L)))
  }
  is.data.frame(bridges) && nrow(selected) > 0L &&
    side_valid(candidate_reference, "evidence_candidate") &&
    side_valid(baseline_reference, "evidence_baseline")
}

wlv13_v5d_select_stage5_profile <- function(profiles, execution) {
  selected <- profiles[
    profiles$method == execution$method &
      profiles$request_sha256 == execution$request_sha256,
    , drop = FALSE
  ]
  if (!nrow(selected)) {
    return(list(found = FALSE, binding_valid = TRUE, authorization = NULL))
  }
  if (nrow(selected) != 1L) {
    return(list(found = TRUE, binding_valid = FALSE, authorization = NULL))
  }
  binding_valid <-
    identical(selected$scenario_id[[1L]], execution$scenario_id) &&
    identical(selected$mode[[1L]], execution$mode) &&
    identical(selected$at_stage[[1L]], execution$at_stage) &&
    identical(selected$sea_vars_sha256[[1L]],
      execution$sea_vars_sha256) &&
    identical(selected$workers[[1L]], as.character(execution$workers)) &&
    identical(
      selected$evidence_baseline_target_request_sha256[[1L]],
      execution$request_sha256
    )
  list(
    found = TRUE,
    binding_valid = binding_valid,
    profile_id = selected$profile_id[[1L]],
    authorization = list(
      candidate_rows = as.integer(selected$candidate_stage5_rows[[1L]]),
      candidate_sha256 = selected$candidate_stage5_sha256[[1L]],
      baseline_rows = as.integer(selected$baseline_stage5_rows[[1L]]),
      baseline_sha256 = selected$baseline_stage5_sha256[[1L]],
      difference_key_count = as.integer(
        selected$difference_key_count[[1L]]
      ),
      difference_sha256 = selected$difference_sha256[[1L]],
      reference_sha256 = selected$reference_stage5_sha256[[1L]],
      candidate_reference_request_sha256 =
        selected$evidence_candidate_reference_request_sha256[[1L]],
      baseline_reference_request_sha256 =
        selected$evidence_baseline_reference_request_sha256[[1L]],
      profile_id = selected$profile_id[[1L]],
      derivation_sha256 = selected$derivation_sha256[[1L]]
    )
  )
}

wlv13_v5d_current_parent_binding <- function(
    candidate_parent, baseline_parent, parent_stage5, authorization) {
  required_authorization <- c(
    "candidate_rows", "candidate_sha256", "baseline_rows",
    "baseline_sha256", "difference_key_count", "difference_sha256",
    "reference_sha256", "candidate_reference_request_sha256",
    "baseline_reference_request_sha256", "profile_id",
    "derivation_sha256"
  )
  parent_valid <- function(value, reference_request_sha256) {
    is.list(value) && is.list(value$context) && is.list(value$execution) &&
      identical(value$execution$mode, "calculate") &&
      identical(value$execution$at_stage, "") &&
      identical(value$execution$request_sha256,
        reference_request_sha256) &&
      identical(value$context$expected_commit,
        value$context$observed_commit) &&
      is.character(value$anomalies_sha256) &&
      length(value$anomalies_sha256) == 1L &&
      grepl("^[0-9a-f]{64}$", value$anomalies_sha256)
  }
  is.list(authorization) &&
    identical(sort(names(authorization), method = "radix"),
      sort(required_authorization, method = "radix")) &&
    parent_valid(candidate_parent,
      authorization$candidate_reference_request_sha256) &&
    parent_valid(baseline_parent,
      authorization$baseline_reference_request_sha256) &&
    identical(candidate_parent$execution$method,
      baseline_parent$execution$method) &&
    is.list(parent_stage5) && isTRUE(parent_stage5$passed) &&
    identical(parent_stage5$reference_sha256,
      authorization$reference_sha256)
}

# Builds one controller-reviewable profile from pre-existing evidence only.
# The candidate and baseline references must be authenticated calculate runs
# whose normalized stage-five multisets are exactly equal.  The baseline
# target must be an authenticated recalculation whose only difference from
# that reference is an exact, key-bound 1x/2x legacy generation count.  The
# future candidate recalculation is then required to equal the already sealed
# candidate reference fingerprint; it is never used to learn its own oracle.
wlv13_v5d_derive_stage5_profile <- function(
    candidate_reference_keys, baseline_reference_keys, baseline_target_keys,
    candidate_reference_execution, baseline_reference_execution,
    baseline_target_execution, candidate_reference_anomalies_sha256,
    baseline_reference_anomalies_sha256,
    baseline_target_anomalies_sha256, candidate_reference_auth,
    baseline_reference_auth, baseline_target_auth,
    evidence_capture_record_sha256) {
  execution_fields <- c(
    "method", "mode", "at_stage", "sea_vars_sha256", "workers",
    "request_sha256", "scenario_id", "run_id"
  )
  executions <- list(
    candidate_reference_execution, baseline_reference_execution,
    baseline_target_execution
  )
  auth_columns <- c(
    "run_id", "commit", "tree", "source_sha256", "run_manifest_sha256",
    "run_inventory_sha256"
  )
  authentications <- list(
    candidate_reference_auth, baseline_reference_auth, baseline_target_auth
  )
  if (!all(vapply(executions, function(value) {
      is.list(value) && all(execution_fields %in% names(value))
    }, logical(1L)))) {
    stop("Stage-five profile evidence has invalid executions.",
      call. = FALSE
    )
  }
  reference_fields <- setdiff(execution_fields, c("run_id"))
  reference_match <- identical(
    candidate_reference_execution[reference_fields],
    baseline_reference_execution[reference_fields]
  )
  method <- candidate_reference_execution$method
  evidence_valid <- reference_match &&
    identical(candidate_reference_execution$mode, "calculate") &&
    identical(candidate_reference_execution$at_stage, "") &&
    identical(baseline_target_execution$method, method) &&
    identical(baseline_target_execution$mode, "recalculate") &&
    baseline_target_execution$at_stage %in% c("1", "4", "5") &&
    all(vapply(c(
      candidate_reference_anomalies_sha256,
      baseline_reference_anomalies_sha256,
      baseline_target_anomalies_sha256
    ), function(value) {
      is.character(value) && length(value) == 1L &&
        grepl("^[0-9a-f]{64}$", value)
    }, logical(1L))) &&
    all(vapply(executions, function(value) {
      grepl("^run-[0-9A-Za-z-]+$", value$run_id)
    }, logical(1L))) &&
    all(vapply(authentications, function(value) {
      is.list(value) && identical(
        sort(names(value), method = "radix"),
        sort(auth_columns, method = "radix")
      ) &&
        grepl("^[0-9a-f]{40}$", value$commit) &&
        grepl("^[0-9a-f]{40}$", value$tree) &&
        grepl("^run-[0-9A-Za-z-]+$", value$run_id) &&
        all(vapply(value[setdiff(
          auth_columns, c("run_id", "commit", "tree")
        )],
          function(field) {
            is.character(field) && length(field) == 1L &&
              grepl("^[0-9a-f]{64}$", field)
          }, logical(1L)))
    }, logical(1L))) &&
    all(vapply(seq_along(authentications), function(index) {
      identical(authentications[[index]]$run_id,
        executions[[index]]$run_id)
    }, logical(1L))) &&
    is.character(evidence_capture_record_sha256) &&
    length(evidence_capture_record_sha256) == 1L &&
    grepl("^[0-9a-f]{64}$", evidence_capture_record_sha256)
  candidate_reference <- wlv13_v5d_stage5_counts(
    candidate_reference_keys
  )
  baseline_reference <- wlv13_v5d_stage5_counts(
    baseline_reference_keys
  )
  baseline_target <- wlv13_v5d_stage5_counts(baseline_target_keys)
  reference_difference <- wlv13_v5d_stage5_difference(
    candidate_reference, baseline_reference
  )
  target_difference <- wlv13_v5d_stage5_difference(
    candidate_reference, baseline_target
  )
  evidence_valid <- evidence_valid && reference_difference$same_keys &&
    reference_difference$exact && target_difference$same_keys &&
    target_difference$structurally_valid && !target_difference$exact &&
    target_difference$key_count > 0L
  if (!evidence_valid) {
    stop("Stage-five profile evidence does not prove the migration rule.",
      call. = FALSE
    )
  }
  row <- as.data.frame(stats::setNames(
    as.list(rep("", length(wlv13_v5d_stage5_profile_columns))),
    wlv13_v5d_stage5_profile_columns
  ), stringsAsFactors = FALSE, check.names = FALSE)
  row$schema_version <- wlv13_v5d_stage5_profile_schema
  row$scenario_id <- baseline_target_execution$scenario_id
  row$method <- method
  row$mode <- baseline_target_execution$mode
  row$at_stage <- baseline_target_execution$at_stage
  row$sea_vars_sha256 <- baseline_target_execution$sea_vars_sha256
  row$workers <- as.character(baseline_target_execution$workers)
  row$request_sha256 <- baseline_target_execution$request_sha256
  row$candidate_stage5_rows <- as.character(candidate_reference$rows)
  row$candidate_stage5_sha256 <- candidate_reference$sha256
  row$baseline_stage5_rows <- as.character(baseline_target$rows)
  row$baseline_stage5_sha256 <- baseline_target$sha256
  row$difference_key_count <- as.character(target_difference$key_count)
  row$difference_sha256 <- target_difference$sha256
  row$evidence_candidate_reference_run_id <-
    candidate_reference_execution$run_id
  row$evidence_candidate_reference_anomalies_sha256 <-
    candidate_reference_anomalies_sha256
  row$evidence_candidate_reference_request_sha256 <-
    candidate_reference_execution$request_sha256
  row$evidence_candidate_reference_commit <- candidate_reference_auth$commit
  row$evidence_candidate_reference_tree <- candidate_reference_auth$tree
  row$evidence_candidate_reference_source_sha256 <-
    candidate_reference_auth$source_sha256
  row$evidence_candidate_reference_run_manifest_sha256 <-
    candidate_reference_auth$run_manifest_sha256
  row$evidence_candidate_reference_run_inventory_sha256 <-
    candidate_reference_auth$run_inventory_sha256
  row$evidence_baseline_reference_run_id <-
    baseline_reference_execution$run_id
  row$evidence_baseline_reference_anomalies_sha256 <-
    baseline_reference_anomalies_sha256
  row$evidence_baseline_reference_request_sha256 <-
    baseline_reference_execution$request_sha256
  row$evidence_baseline_reference_commit <- baseline_reference_auth$commit
  row$evidence_baseline_reference_tree <- baseline_reference_auth$tree
  row$evidence_baseline_reference_source_sha256 <-
    baseline_reference_auth$source_sha256
  row$evidence_baseline_reference_run_manifest_sha256 <-
    baseline_reference_auth$run_manifest_sha256
  row$evidence_baseline_reference_run_inventory_sha256 <-
    baseline_reference_auth$run_inventory_sha256
  row$evidence_baseline_target_run_id <- baseline_target_execution$run_id
  row$evidence_baseline_target_anomalies_sha256 <-
    baseline_target_anomalies_sha256
  row$evidence_baseline_target_request_sha256 <-
    baseline_target_execution$request_sha256
  row$evidence_baseline_target_commit <- baseline_target_auth$commit
  row$evidence_baseline_target_tree <- baseline_target_auth$tree
  row$evidence_baseline_target_source_sha256 <-
    baseline_target_auth$source_sha256
  row$evidence_baseline_target_run_manifest_sha256 <-
    baseline_target_auth$run_manifest_sha256
  row$evidence_baseline_target_run_inventory_sha256 <-
    baseline_target_auth$run_inventory_sha256
  row$evidence_capture_record_sha256 <- evidence_capture_record_sha256
  row$reference_stage5_sha256 <- candidate_reference$sha256
  row$derivation_sha256 <- wlv13_v5d_stage5_profile_derivation(row)
  row$profile_id <- paste0(
    "stage5-", substr(row$derivation_sha256, 1L, 24L)
  )
  row
}

wlv13_v5d_stage5_multiplicity <- function(
    candidate_keys, baseline_keys, authorization = NULL) {
  candidate <- wlv13_v5d_stage5_counts(candidate_keys)
  baseline <- wlv13_v5d_stage5_counts(baseline_keys)
  difference <- wlv13_v5d_stage5_difference(candidate, baseline)
  default_exact <- is.null(authorization) && difference$same_keys &&
    difference$exact
  authorized <- FALSE
  if (!is.null(authorization) && is.list(authorization)) {
    required <- c(
      "candidate_rows", "candidate_sha256", "baseline_rows",
      "baseline_sha256", "difference_key_count", "difference_sha256",
      "reference_sha256", "candidate_reference_request_sha256",
      "baseline_reference_request_sha256", "profile_id",
      "derivation_sha256"
    )
    authorized <- identical(sort(names(authorization), method = "radix"),
      sort(required, method = "radix")) &&
      difference$same_keys && difference$structurally_valid &&
      !difference$exact &&
      identical(candidate$rows, authorization$candidate_rows) &&
      identical(candidate$sha256, authorization$candidate_sha256) &&
      identical(baseline$rows, authorization$baseline_rows) &&
      identical(baseline$sha256, authorization$baseline_sha256) &&
      identical(difference$key_count,
        authorization$difference_key_count) &&
      identical(difference$sha256, authorization$difference_sha256) &&
      identical(candidate$sha256, authorization$reference_sha256) &&
      grepl("^stage5-[0-9a-f]{24}$", authorization$profile_id) &&
      grepl("^[0-9a-f]{64}$", authorization$derivation_sha256)
  }
  list(
    passed = default_exact || authorized,
    profile = if (default_exact) {
      "exact-generation"
    } else if (authorized) {
      "sealed-exact-legacy-generation"
    } else if (!difference$same_keys) {
      "key-mismatch"
    } else if (!is.null(authorization)) {
      "sealed-profile-mismatch"
    } else {
      "unauthorized-generation-difference"
    },
    ratio = difference$ratios,
    key_count = length(candidate$counts),
    difference_key_count = difference$key_count,
    difference_sha256 = difference$sha256,
    candidate_sha256 = candidate$sha256,
    baseline_sha256 = baseline$sha256,
    authorization_valid = authorized,
    profile_id = if (authorized) authorization$profile_id else "",
    multiplicity_sha256 = wlv13_v5d_sha256_text(paste(
      candidate$sha256, baseline$sha256, difference$sha256, sep = "|"
    ))
  )
}

wlv13_v5d_validate_anomaly_shape <- function(value, label) {
  required <- c(
    "artifact", "indicator", "checkpoint", "stage", "module",
    "original_value", "policy_id", "action"
  )
  stages <- suppressWarnings(as.integer(value$stage))
  valid <- nrow(value) > 0L &&
    all(vapply(required, function(column) all(nzchar(value[[column]])),
      logical(1L))) &&
    !anyNA(stages) && all(stages >= 1L & stages <= 5L) &&
    identical(as.character(stages), value$stage) &&
    all(grepl("^[0-9]{4}$", value$year))
  if (!valid) {
    stop(sprintf("%s has invalid required fields.", label), call. = FALSE)
  }
  stages
}

wlv13_cross_engine_compare_anomalies <- function(
    left, right, candidate_descriptors, method) {
  candidate_context <- wlv13_v5d_context(left, "candidate", method)
  baseline_context <- wlv13_v5d_context(right, "baseline", method)
  candidate_execution <- wlv13_v5d_run_request(candidate_context)
  baseline_execution <- wlv13_v5d_run_request(baseline_context)
  execution_fields <- c(
    "method", "mode", "at_stage", "sea_vars_sha256", "workers",
    "request_sha256", "scenario_id"
  )
  execution_match <- identical(
    candidate_execution[execution_fields],
    baseline_execution[execution_fields]
  )
  left_parsed <- wlv13_cross_engine_read(left, "_anomalies.csv")
  right_parsed <- wlv13_cross_engine_read(right, "_anomalies.csv")
  columns <- wlv13_cross_engine_schema("_anomalies.csv")
  candidate <- wlv13_v5d_normalize_table(
    left_parsed$value, columns, "Candidate anomalies"
  )
  baseline <- wlv13_v5d_normalize_table(
    right_parsed$value, columns, "Baseline anomalies"
  )
  candidate_stage <- wlv13_v5d_validate_anomaly_shape(
    candidate, "Candidate anomalies"
  )
  baseline_stage <- wlv13_v5d_validate_anomaly_shape(
    baseline, "Baseline anomalies"
  )
  profile <- wlv13_v5d_scientific_profile(
    candidate_context$project_root, method
  )
  diagnostic_key <- "file:_nonfinite_resolution_diagnostics.csv"
  diagnostic <- candidate_descriptors[[diagnostic_key]]
  if ((profile$expected_count > 0L) != !is.null(diagnostic)) {
    stop("Candidate non-finite diagnostic presence differs from its profile.",
      call. = FALSE
    )
  }
  resolution <- if (profile$expected_count > 0L) {
    parsed_diagnostic <- wlv13_cross_engine_read(
      diagnostic, "_nonfinite_resolution_diagnostics.csv"
    )
    wlv13_v5d_validate_nonfinite_value(
      parsed_diagnostic$value, method, profile, candidate
    )
  } else {
    claimed <- candidate$policy_id == profile$id
    list(
      passed = !any(claimed),
      exact_profile = !any(claimed),
      coordinate_valid = !any(claimed),
      resolution_mask = rep(FALSE, nrow(candidate)),
      coordinate_binding_sha256 = wlv13_v5d_sha256_text("")
    )
  }
  baseline_resolution <- wlv13_v5d_bridge_baseline_nonfinite(
    baseline, profile
  )
  candidate_keep <- if (identical(profile$action, "replace_nan_with_zero")) {
    rep(TRUE, nrow(candidate))
  } else {
    !resolution$resolution_mask
  }
  candidate_core <- candidate[candidate_keep, , drop = FALSE]
  row.names(candidate_core) <- NULL
  policy <- wlv13_v5d_normalize_baseline_anomaly_policy(
    baseline_resolution$value, profile
  )
  bridges <- wlv13_v5d_read_bridge_manifest()
  owner_contract <- wlv13_v5d_candidate_owner_contract(
    candidate_context$project_root, method
  )
  owner_contract_valid <- wlv13_v5d_bridge_targets_valid(
    bridges, method, "_anomalies.csv", owner_contract
  )
  modules <- wlv13_v5d_normalize_baseline_anomaly_modules(
    policy$value, profile, bridges, candidate_execution$mode
  )
  baseline_core <- modules$value
  candidate_module_normalization <-
    wlv13_v5d_normalize_baseline_anomaly_modules(
      candidate_core, profile, bridges, "recalculate"
    )
  selected_bridges <- bridges[
    bridges$method == method &
      bridges$artifact_name == "_anomalies.csv", , drop = FALSE
  ]
  candidate_module_generation_valid <-
    candidate_module_normalization$changed_rows == 0L &&
    (!identical(candidate_execution$mode, "calculate") ||
      candidate_module_normalization$target_generation_rows ==
        sum(as.integer(
          selected_bridges$expected_candidate_evidence_rows
        )))
  baseline_module_generation_valid <-
    modules$coverage_complete && modules$target_generation_rows == 0L
  expected_zero <- profile$leontief_zero_profile
  legacy_zero <- sub("_v09_", "_", expected_zero, fixed = TRUE)
  policy_generation_valid <- if (legacy_zero != expected_zero) {
    policy$changed_rows > 0L &&
      !any(baseline$policy_id == expected_zero) &&
      !any(candidate_core$policy_id == legacy_zero)
  } else {
    policy$changed_rows == 0L
  }

  candidate_lower <- candidate_core[candidate_stage[candidate_keep] < 5L,
    , drop = FALSE
  ]
  baseline_lower <- baseline_core[baseline_stage < 5L, , drop = FALSE]
  candidate_stage5 <- candidate_core[candidate_stage[candidate_keep] >= 5L,
    , drop = FALSE
  ]
  baseline_stage5 <- baseline_core[baseline_stage >= 5L, , drop = FALSE]
  lower_equal <- identical(
    wlv13_table_row_keys(candidate_lower),
    wlv13_table_row_keys(baseline_lower)
  )
  stage5_profiles <- wlv13_v5d_read_stage5_profiles()
  profile_declared <- any(
    stage5_profiles$method == method &
      stage5_profiles$request_sha256 == candidate_execution$request_sha256
  )
  candidate_parent <- if (profile_declared) {
    wlv13_v5d_parent_context(candidate_context, candidate_execution)
  } else {
    NULL
  }
  baseline_parent <- if (profile_declared) {
    wlv13_v5d_parent_context(baseline_context, baseline_execution)
  } else {
    NULL
  }
  stage5_selection <- wlv13_v5d_select_stage5_profile(
    stage5_profiles, candidate_execution
  )
  parent_stage5 <- if (profile_declared &&
      stage5_selection$binding_valid) {
    wlv13_v5d_parent_stage5_binding(
      candidate_parent, baseline_parent, profile
    )
  } else {
    list(passed = !profile_declared, reference_sha256 = "")
  }
  parent_profile_binding_valid <- if (profile_declared) {
    wlv13_v5d_current_parent_binding(
      candidate_parent, baseline_parent, parent_stage5,
      stage5_selection$authorization
    )
  } else {
    isTRUE(parent_stage5$passed)
  }
  multiplicity <- wlv13_v5d_stage5_multiplicity(
    wlv13_v5d_raw_row_keys(candidate_stage5),
    wlv13_v5d_raw_row_keys(baseline_stage5),
    authorization = if (stage5_selection$found) {
      stage5_selection$authorization
    } else {
      NULL
    }
  )
  valid <- left_parsed$schema_valid && right_parsed$schema_valid &&
    execution_match && stage5_selection$binding_valid &&
    parent_profile_binding_valid &&
    resolution$passed && baseline_resolution$passed &&
    candidate_module_generation_valid &&
    baseline_module_generation_valid && owner_contract_valid &&
    policy_generation_valid &&
    lower_equal && multiplicity$passed
  list(
    summary = list(
      passed = valid,
      comparison_mode = "exhaustive-contract-bound-anomaly-bridge",
      method = method,
      candidate_schema_valid = left_parsed$schema_valid,
      baseline_schema_valid = right_parsed$schema_valid,
      candidate_rows = nrow(candidate),
      baseline_rows = nrow(baseline),
      candidate_resolution_rows = sum(resolution$resolution_mask),
      nonfinite_profile_exact = resolution$exact_profile,
      nonfinite_coordinate_binding_valid = resolution$coordinate_valid,
      nonfinite_coordinate_binding_sha256 =
        resolution$coordinate_binding_sha256,
      baseline_nonfinite_bridge_valid = baseline_resolution$passed,
      baseline_nonfinite_bridge_rows = baseline_resolution$rows,
      baseline_nonfinite_binding_sha256 =
        baseline_resolution$binding_sha256,
      normalized_core_rows = nrow(candidate_core),
      lower_stage_multiset_equal = lower_equal,
      stage5_same_semantic_rows = multiplicity$profile != "key-mismatch",
      stage5_multiplicity_valid = multiplicity$passed,
      stage5_multiplicity_profile = multiplicity$profile,
      stage5_multiplicity_ratio = as.list(multiplicity$ratio),
      stage5_multiplicity_sha256 = multiplicity$multiplicity_sha256,
      stage5_difference_key_count = multiplicity$difference_key_count,
      stage5_difference_sha256 = multiplicity$difference_sha256,
      stage5_candidate_fingerprint = multiplicity$candidate_sha256,
      stage5_baseline_fingerprint = multiplicity$baseline_sha256,
      stage5_profile_found = stage5_selection$found,
      stage5_profile_binding_valid = stage5_selection$binding_valid,
      stage5_parent_binding_valid = parent_profile_binding_valid,
      stage5_parent_reference_sha256 = parent_stage5$reference_sha256,
      stage5_profile_id = if (is.null(stage5_selection$profile_id)) "" else
        stage5_selection$profile_id,
      execution_context_match = execution_match,
      execution_scenario_id = candidate_execution$scenario_id,
      execution_request_sha256 = candidate_execution$request_sha256,
      candidate_stage5_rows = nrow(candidate_stage5),
      baseline_stage5_rows = nrow(baseline_stage5),
      module_bridge_rows = modules$changed_rows,
      module_bridge_profile_rows = nrow(selected_bridges),
      module_bridge_profile_rows_used = modules$used_profile_rows,
      candidate_module_generation_valid = candidate_module_generation_valid,
      baseline_module_generation_valid = baseline_module_generation_valid,
      candidate_owner_contract_valid = owner_contract_valid,
      candidate_owner_contract_sha256 =
        owner_contract$anomaly_targets_sha256,
      module_bridge_rules = as.list(modules$rules),
      module_bridge_sha256 = modules$bridge_sha256,
      policy_bridge_rows = policy$changed_rows,
      policy_bridge = policy$bridge,
      policy_generation_valid = policy_generation_valid,
      candidate_artifact_sha256 = left$sha256,
      baseline_artifact_sha256 = right$sha256,
      normalized_core_equal = valid,
      architecture_difference = !identical(candidate, baseline)
    ),
    transitions = data.frame(),
    indicators = data.frame()
  )
}

# Mutation-oriented tests for all strict primitives.  The harness self-test
# calls this after sourcing the override; no real run or external data is used.
wlv13_v5d_selftest <- function() {
  assertions <- 0L
  expect_true <- function(value, label) {
    if (!isTRUE(value)) {
      stop(sprintf("V5 diagnostic self-test failed: %s.", label),
        call. = FALSE
      )
    }
    assertions <<- assertions + 1L
  }
  expect_false <- function(value, label) {
    expect_true(!isTRUE(value), label)
  }
  expect_error <- function(expression, label) {
    failed <- tryCatch({
      force(expression)
      FALSE
    }, error = function(error) TRUE)
    expect_true(failed, label)
  }

  fixture_bridge_row <- function(
      method, source, artifact_name, indicator, baseline_module,
      candidate_module, expected_rows, artifact = "", checkpoint = "",
      stage = "", action = "", output = "", original_value = "",
      policy_id = "", strategy = "", producer_id = "",
      write_action = "") {
    row <- as.data.frame(stats::setNames(
      as.list(rep("", length(wlv13_v5d_bridge_columns))),
      wlv13_v5d_bridge_columns
    ), stringsAsFactors = FALSE, check.names = FALSE)
    safe_method <- gsub("_", "-", method, fixed = TRUE)
    row$schema_version <- wlv13_v5d_bridge_schema
    row$artifact_name <- artifact_name
    row$method <- method
    row$source <- source
    row$artifact <- artifact
    row$indicator <- indicator
    row$checkpoint <- checkpoint
    row$stage <- stage
    row$action <- action
    row$output <- output
    row$original_value <- original_value
    row$policy_id <- policy_id
    row$strategy <- strategy
    row$baseline_module <- baseline_module
    row$candidate_module <- candidate_module
    row$candidate_producer_id <- producer_id
    row$candidate_write_action <- write_action
    row$evidence_baseline_run_id <- paste0("run-baseline-", safe_method)
    row$evidence_baseline_artifact_sha256 <- paste(rep("a", 64L),
      collapse = ""
    )
    row$evidence_baseline_request_sha256 <- paste(rep("b", 64L),
      collapse = ""
    )
    row$evidence_baseline_source_sha256 <- paste(rep("9", 64L),
      collapse = ""
    )
    row$evidence_baseline_commit <- paste(rep("c", 40L), collapse = "")
    row$evidence_baseline_tree <- paste(rep("7", 40L), collapse = "")
    row$evidence_candidate_run_id <- paste0("run-candidate-", safe_method)
    row$evidence_candidate_artifact_sha256 <- paste(rep("d", 64L),
      collapse = ""
    )
    row$evidence_candidate_request_sha256 <- paste(rep("e", 64L),
      collapse = ""
    )
    row$evidence_candidate_source_sha256 <- paste(rep("8", 64L),
      collapse = ""
    )
    row$evidence_candidate_commit <- paste(rep("f", 40L), collapse = "")
    row$evidence_candidate_tree <- paste(rep("6", 40L), collapse = "")
    row$expected_baseline_evidence_rows <- as.character(expected_rows)
    row$expected_candidate_evidence_rows <- as.character(expected_rows)
    row$derivation_sha256 <- wlv13_v5d_bridge_derivation(row)
    row$bridge_id <- paste0(
      "bridge-", substr(row$derivation_sha256, 1L, 24L)
    )
    row
  }

  fixture_unit_bridges <- do.call(rbind, lapply(
    names(wlv13_v5d_methods_by_source), function(source) {
      do.call(rbind, lapply(wlv13_v5d_methods_by_source[[source]],
        function(method) fixture_bridge_row(
          method, source, "_unit_contract.csv", "value.m.mv",
          "common/value.m.mv-country.R", "indicator.value.m.mv", 2L,
          strategy = "sum"
        )
      ))
    }
  ))
  fixture_anomaly_bridge <- fixture_bridge_row(
    "wiodr13", "wiodr13", "_anomalies.csv", "value.m.mv",
    "common/value.m.mv-country.R", "indicator.value.m.mv", 1L,
    artifact = "sea_sectors", checkpoint = "after_stage_5", stage = "5",
    action = "mark_not_applicable", original_value = "0",
    policy_id = "fixture_v1", producer_id = "indicator.value.m.mv",
    write_action = "replace"
  )
  fixture_bridges <- rbind(fixture_unit_bridges, fixture_anomaly_bridge)
  fixture_bridges <- fixture_bridges[
    wlv13_v5d_bridge_order(fixture_bridges), , drop = FALSE
  ]
  row.names(fixture_bridges) <- NULL
  fixture_bridges <- wlv13_v5d_validate_bridge_manifest(fixture_bridges)
  expect_true(nrow(fixture_bridges) == 13L,
    "closed bridge fixture validation"
  )
  anomaly_bridge <- fixture_bridges[
    fixture_bridges$artifact_name == "_anomalies.csv", , drop = FALSE
  ]
  fixture_bridge_reference <- function(prefix) list(
    run_id = anomaly_bridge[[paste0(prefix, "_run_id")]][[1L]],
    anomalies = list(sha256 = anomaly_bridge[[paste0(
      prefix, "_artifact_sha256"
    )]][[1L]]),
    execution = list(request_sha256 = anomaly_bridge[[paste0(
      prefix, "_request_sha256"
    )]][[1L]]),
    source_sha256 = anomaly_bridge[[paste0(
      prefix, "_source_sha256"
    )]][[1L]],
    commit = anomaly_bridge[[paste0(prefix, "_commit")]][[1L]],
    tree = anomaly_bridge[[paste0(prefix, "_tree")]][[1L]]
  )
  fixture_candidate_reference <- fixture_bridge_reference(
    "evidence_candidate"
  )
  fixture_baseline_reference <- fixture_bridge_reference(
    "evidence_baseline"
  )
  expect_true(wlv13_v5d_stage5_bridge_reference_binding(
    fixture_bridges, "wiodr13", fixture_candidate_reference,
    fixture_baseline_reference
  ), "stage5 references bound to sealed diagnostic bridge")
  for (field in c(
      "run_id", "anomalies_sha256", "request_sha256", "source_sha256",
      "commit", "tree")) {
    mutation <- fixture_candidate_reference
    if (identical(field, "anomalies_sha256")) {
      mutation$anomalies$sha256 <- paste0(
        substr(mutation$anomalies$sha256, 1L, 63L), "0"
      )
    } else if (identical(field, "request_sha256")) {
      mutation$execution$request_sha256 <- paste0(
        substr(mutation$execution$request_sha256, 1L, 63L), "0"
      )
    } else {
      mutation[[field]] <- paste0(mutation[[field]], "0")
    }
    expect_false(wlv13_v5d_stage5_bridge_reference_binding(
      fixture_bridges, "wiodr13", mutation, fixture_baseline_reference
    ), paste0("stage5 sealed candidate reference ", field, " mutation"))
  }
  expect_false(wlv13_v5d_stage5_bridge_reference_binding(
    fixture_bridges, "wiodr16", fixture_candidate_reference,
    fixture_baseline_reference
  ), "stage5 sealed reference method mutation")
  for (column in wlv13_v5d_bridge_columns) {
    mutation <- fixture_bridges
    mutation[[column]][[1L]] <- paste0(mutation[[column]][[1L]], "#")
    expect_error(wlv13_v5d_validate_bridge_manifest(mutation),
      paste0("bridge manifest column ", column)
    )
  }
  expect_error(wlv13_v5d_validate_bridge_manifest(
    fixture_bridges[c(2L, 1L, seq.int(3L, nrow(fixture_bridges))),
      , drop = FALSE]
  ), "bridge manifest order mutation")

  unit_columns <- wlv13_cross_engine_schema("_unit_contract.csv")
  unit_row <- as.data.frame(stats::setNames(as.list(rep(
    "", length(unit_columns)
  )), unit_columns), stringsAsFactors = FALSE, check.names = FALSE)
  unit_row$contract <- "fixture_v1"
  unit_row$schema_version <- "1"
  unit_row$source <- "wiodr13"
  unit_row$indicator <- "value.m.mv"
  unit_row$quantity_kind <- "monetary_flow"
  unit_row$source_unit <- "million_usd"
  unit_row$source_scale <- "1"
  unit_row$canonical_unit <- "million_usd"
  unit_row$display_unit <- "million_usd"
  unit_row$display_multiplier <- "1"
  unit_row$level <- "sector_to_country"
  unit_row$strategy <- "sum"
  unit_row$module <- "common/value.m.mv-country.R"
  unit_row$aggregation_notes <- "Experimental legacy aggregation adapter."
  unit_baseline <- rbind(
    unit_row,
    transform(unit_row, level = "country_to_world"),
    transform(unit_row, indicator = "gross_output.s.mv", module = "",
      level = "identity", strategy = "identity")
  )
  row.names(unit_baseline) <- NULL
  unit_candidate <- unit_baseline
  unit_candidate$module[1:2] <- "indicator.value.m.mv"
  transformed_unit <- wlv13_v5d_transform_unit_baseline(
    unit_baseline, "wiodr13", fixture_bridges, "calculate",
    "indicator.value.m.mv"
  )
  expect_true(transformed_unit$coverage_complete &&
      transformed_unit$module_bridge_rows == 2L,
    "unit bridge exact sealed coverage"
  )
  expect_true(wlv13_v5d_exact_ordered(unit_candidate,
    transformed_unit$value),
  "unit bridge pass")
  for (column in unit_columns) {
    mutation <- unit_candidate
    mutation[[column]][[1L]] <- paste0(mutation[[column]][[1L]], "#")
    expect_false(wlv13_v5d_exact_ordered(
      mutation, transformed_unit$value
    ), paste0("unit column ", column))
    baseline_mutation <- unit_baseline
    baseline_mutation[[column]][[1L]] <- paste0(
      baseline_mutation[[column]][[1L]], "#"
    )
    expect_false(wlv13_v5d_exact_ordered(
      unit_candidate,
      wlv13_v5d_transform_unit_baseline(
        baseline_mutation, "wiodr13", fixture_bridges, "recalculate",
        "indicator.value.m.mv"
      )$value
    ), paste0("baseline unit column ", column))
  }
  expect_false(wlv13_v5d_exact_ordered(
    unit_candidate[c(2L, 1L), ], unit_candidate
  ), "unit row order")
  expect_false(wlv13_v5d_exact_ordered(
    unit_candidate[-1L, ], unit_candidate
  ), "unit missing row")
  expect_false(wlv13_v5d_exact_ordered(
    rbind(unit_candidate, unit_candidate[1L, ]), unit_candidate
  ), "unit duplicate row")
  expect_true(wlv13_v5d_compare_source_unit_contract(
    unit_baseline, unit_candidate, "wiodr13", fixture_bridges
  )$passed, "source-level unit contract exact bridge")
  source_note_mutation <- unit_candidate
  source_note_mutation$aggregation_notes[[1L]] <- "mutated note"
  expect_false(wlv13_v5d_compare_source_unit_contract(
    unit_baseline, source_note_mutation, "wiodr13", fixture_bridges
  )$passed, "source-level aggregation notes mutation")
  plausible_unit_path <- unit_baseline
  plausible_unit_path$module[1:2] <- "common/plausible-country.R"
  expect_error(wlv13_v5d_compare_source_unit_contract(
    plausible_unit_path, unit_candidate, "wiodr13", fixture_bridges
  ), "unlisted plausible unit path")
  missing_unit_bridge <- fixture_bridges[-which(
    fixture_bridges$artifact_name == "_unit_contract.csv" &
      fixture_bridges$method == "wiodr13"
  ), , drop = FALSE]
  expect_error(wlv13_v5d_compare_source_unit_contract(
    unit_baseline, unit_candidate, "wiodr13", missing_unit_bridge
  ), "removed source unit bridge")
  swapped_method_bridge <- fixture_bridges
  swap_index <- which(
    swapped_method_bridge$artifact_name == "_unit_contract.csv" &
      swapped_method_bridge$method == "wiodr13"
  )
  swapped_method_bridge$method[[swap_index]] <- "wiodr16"
  swapped_method_bridge$derivation_sha256[[swap_index]] <-
    wlv13_v5d_bridge_derivation(swapped_method_bridge[swap_index, ,
      drop = FALSE
    ])
  swapped_method_bridge$bridge_id[[swap_index]] <- paste0(
    "bridge-", substr(
      swapped_method_bridge$derivation_sha256[[swap_index]], 1L, 24L
    )
  )
  swapped_method_bridge <- swapped_method_bridge[
    wlv13_v5d_bridge_order(swapped_method_bridge), , drop = FALSE
  ]
  expect_error(wlv13_v5d_source_unit_bridge_profile(
    swapped_method_bridge, "wiodr13"
  ), "unit bridge method mutation")

  check_columns <- wlv13_cross_engine_schema("_scientific_checks.csv")
  core_baseline <- data.frame(
    method = rep("fixture", 2L),
    check_id = rep("sector_to_country", 2L),
    artifact = rep("sea_countries", 2L),
    indicator = c("a", "b"),
    scope = c("legacy_adapter:sum", "legacy_adapter:mean"),
    status = rep("pass", 2L),
    observations = rep("1", 2L),
    maximum_absolute_error = rep("0", 2L),
    maximum_scaled_error = rep("0", 2L),
    tolerance = rep("exact", 2L),
    detail = c(
      "Independent `sum` reference aggregation over sectors (legacy adapter route).",
      "Independent `mean` reference aggregation over sectors (legacy adapter route)."
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )[check_columns]
  core_candidate <- wlv13_v5d_transform_scientific_core(core_baseline)$value
  expect_true(wlv13_v5d_exact_ordered(
    core_candidate,
    wlv13_v5d_transform_scientific_core(core_baseline)$value
  ), "scientific bridge pass")
  for (column in check_columns) {
    mutation <- core_candidate
    mutation[[column]][[1L]] <- paste0(mutation[[column]][[1L]], "#")
    expect_false(wlv13_v5d_exact_ordered(
      mutation, wlv13_v5d_transform_scientific_core(core_baseline)$value
    ), paste0("scientific column ", column))
    baseline_mutation <- core_baseline
    baseline_mutation[[column]][[1L]] <- paste0(
      baseline_mutation[[column]][[1L]], "#"
    )
    expect_false(wlv13_v5d_exact_ordered(
      core_candidate,
      wlv13_v5d_transform_scientific_core(baseline_mutation)$value
    ), paste0("baseline scientific column ", column))
  }
  expect_false(wlv13_v5d_exact_ordered(
    core_candidate[c(2L, 1L), ], core_candidate
  ), "scientific row order")

  nonfinite_columns <- wlv13_cross_engine_schema(
    "_nonfinite_resolution_diagnostics.csv"
  )
  fixture_coordinate_sha256 <- wlv13_v5d_sha256_text("2000|AAA|S1")
  nonfinite <- data.frame(
    method = "fixture",
    scientific_profile = "fixture_science_v1",
    nonfinite_resolution_profile = "fixture_nonfinite_v1",
    action = "replace_nan_with_zero",
    module = "indicator.fixture",
    binding = "fixture.value",
    indicator = "fixture.value",
    kind = "NaN",
    resolved_count = "1",
    coordinate_sha256 = fixture_coordinate_sha256,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )[nonfinite_columns]
  for (column in nonfinite_columns) {
    mutation <- nonfinite
    mutation[[column]][[1L]] <- paste0(mutation[[column]][[1L]], "#")
    expect_false(wlv13_v5d_exact_ordered(mutation, nonfinite),
      paste0("nonfinite column ", column)
    )
  }
  nonfinite_second <- nonfinite
  nonfinite_second$binding <- "fixture.value.second"
  nonfinite_second$indicator <- "fixture.value.second"
  nonfinite_second$module <- "indicator.fixture.second"
  nonfinite_two <- rbind(nonfinite, nonfinite_second)
  expect_false(wlv13_v5d_exact_ordered(
    nonfinite_two[c(2L, 1L), ], nonfinite_two
  ), "nonfinite row order")
  expect_false(wlv13_v5d_exact_ordered(
    nonfinite_two[-1L, ], nonfinite_two
  ), "nonfinite missing row")

  anomaly_columns <- wlv13_cross_engine_schema("_anomalies.csv")
  baseline_anomaly <- data.frame(
    artifact = "sea_sectors",
    indicator = "value.m.mv",
    checkpoint = "after_stage_5",
    stage = "5",
    module = "common/value.m.mv-country.R",
    year = "2000",
    country = "AAA",
    sector = "S1",
    output = "",
    original_value = "0",
    policy_id = "fixture_v1",
    action = "mark_not_applicable",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )[anomaly_columns]
  candidate_anomaly <- baseline_anomaly
  candidate_anomaly$module <- "indicator.value.m.mv"
  normalized_anomaly <- wlv13_v5d_normalize_baseline_anomaly_modules(
    baseline_anomaly, list(method = "wiodr13"), fixture_bridges,
    "calculate", "indicator.value.m.mv"
  )$value
  expect_true(identical(
    wlv13_table_row_keys(candidate_anomaly),
    wlv13_table_row_keys(normalized_anomaly)
  ), "anomaly module bridge pass")
  candidate_generation <- wlv13_v5d_normalize_baseline_anomaly_modules(
    candidate_anomaly, list(method = "wiodr13"), fixture_bridges,
    "recalculate", "indicator.value.m.mv"
  )
  expect_true(candidate_generation$changed_rows == 0L &&
      candidate_generation$target_generation_rows == 1L,
    "anomaly native module generation"
  )
  fixture_owner_contract <- list(
    method = "wiodr13", source = "wiodr13",
    unit_targets = data.frame(
      indicator = rep("value.m.mv", 2L),
      level = c("sector_to_country", "country_to_world"),
      strategy = rep("sum", 2L),
      module = rep("indicator.value.m.mv", 2L),
      stringsAsFactors = FALSE, check.names = FALSE
    ),
    anomaly_targets = data.frame(
      artifact = "sea_sectors", indicator = "value.m.mv", stage = "5",
      module = "indicator.value.m.mv",
      producer_id = "indicator.value.m.mv", action = "replace",
      stringsAsFactors = FALSE, check.names = FALSE
    )
  )
  expect_true(wlv13_v5d_bridge_targets_valid(
    fixture_bridges, "wiodr13", "_unit_contract.csv",
    fixture_owner_contract
  ), "unit owner exact target membership")
  expect_true(wlv13_v5d_bridge_targets_valid(
    fixture_bridges, "wiodr13", "_anomalies.csv",
    fixture_owner_contract
  ), "anomaly owner exact DAG membership")
  missing_owner <- fixture_owner_contract
  missing_owner$anomaly_targets <- missing_owner$anomaly_targets[-1L, ,
    drop = FALSE
  ]
  expect_false(wlv13_v5d_bridge_targets_valid(
    fixture_bridges, "wiodr13", "_anomalies.csv", missing_owner
  ), "anomaly owner missing")
  extra_owner <- fixture_owner_contract
  extra_owner$anomaly_targets <- rbind(
    extra_owner$anomaly_targets, extra_owner$anomaly_targets
  )
  expect_false(wlv13_v5d_bridge_targets_valid(
    fixture_bridges, "wiodr13", "_anomalies.csv", extra_owner
  ), "anomaly owner duplicate")
  swapped_owner <- fixture_owner_contract
  swapped_owner$anomaly_targets$producer_id <- "indicator.other"
  expect_false(wlv13_v5d_bridge_targets_valid(
    fixture_bridges, "wiodr13", "_anomalies.csv", swapped_owner
  ), "anomaly owner producer mutation")
  missing_unit_owner <- fixture_owner_contract
  missing_unit_owner$unit_targets <- missing_unit_owner$unit_targets[-1L, ,
    drop = FALSE
  ]
  expect_false(wlv13_v5d_bridge_targets_valid(
    fixture_bridges, "wiodr13", "_unit_contract.csv", missing_unit_owner
  ), "unit owner level missing")
  swapped_unit_owner <- fixture_owner_contract
  swapped_unit_owner$unit_targets$module <- "indicator.other"
  expect_false(wlv13_v5d_bridge_targets_valid(
    fixture_bridges, "wiodr13", "_unit_contract.csv", swapped_unit_owner
  ), "unit owner module mutation")
  plausible_anomaly_path <- baseline_anomaly
  plausible_anomaly_path$module <- "common/plausible-country.R"
  expect_false(identical(
    wlv13_table_row_keys(candidate_anomaly),
    wlv13_table_row_keys(
      wlv13_v5d_normalize_baseline_anomaly_modules(
        plausible_anomaly_path, list(method = "wiodr13"),
        fixture_bridges, "recalculate", "indicator.value.m.mv"
      )$value
    )
  ), "unlisted plausible anomaly path")
  module_mutation <- candidate_anomaly
  module_mutation$module <- "indicator.unrelated"
  expect_false(identical(
    wlv13_table_row_keys(module_mutation),
    wlv13_table_row_keys(normalized_anomaly)
  ), "anomaly module mutation")
  anomaly_second <- candidate_anomaly
  anomaly_second$indicator <- "value.second"
  anomaly_two <- rbind(candidate_anomaly, anomaly_second)
  expect_false(wlv13_v5d_exact_ordered(
    anomaly_two[c(2L, 1L), ], anomaly_two
  ), "anomaly raw row order")
  removed_anomaly_bridge <- fixture_bridges[-which(
    fixture_bridges$artifact_name == "_anomalies.csv"
  ), , drop = FALSE]
  expect_error(wlv13_v5d_normalize_baseline_anomaly_modules(
    baseline_anomaly, list(method = "wiodr13"),
    removed_anomaly_bridge, "calculate", "indicator.value.m.mv"
  ), "removed anomaly bridge")
  extra_anomaly_bridge <- fixture_anomaly_bridge
  extra_anomaly_bridge$indicator <- "value.extra"
  extra_anomaly_bridge$derivation_sha256 <-
    wlv13_v5d_bridge_derivation(extra_anomaly_bridge)
  extra_anomaly_bridge$bridge_id <- paste0(
    "bridge-", substr(extra_anomaly_bridge$derivation_sha256, 1L, 24L)
  )
  expect_false(wlv13_v5d_bridge_targets_valid(
    rbind(fixture_bridges, extra_anomaly_bridge), "wiodr13",
    "_anomalies.csv", fixture_owner_contract
  ), "extra nonexistent anomaly bridge")

  resolution_anomaly <- candidate_anomaly
  resolution_anomaly$checkpoint <- "after_stage_2"
  resolution_anomaly$stage <- "2"
  resolution_anomaly$module <- "indicator.fixture"
  resolution_anomaly$indicator <- "fixture.value"
  resolution_anomaly$original_value <- "NaN"
  resolution_anomaly$policy_id <- "fixture_nonfinite_v1"
  resolution_anomaly$action <- "replace_profiled_historical_nan_with_zero"
  fixture_profile <- list(
    method = "fixture",
    scientific_profile = "fixture_science_v1",
    id = "fixture_nonfinite_v1",
    action = "replace_nan_with_zero",
    expected_count = 1L,
    groups = data.frame(
      nonfinite_resolution_profile = "fixture_nonfinite_v1",
      binding = "fixture.value",
      indicator = "fixture.value",
      kind = "NaN",
      module = "indicator.fixture",
      expected_count = "1",
      coordinate_sha256 = fixture_coordinate_sha256,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  bound <- wlv13_v5d_validate_nonfinite_value(
    nonfinite, "fixture", fixture_profile, resolution_anomaly
  )
  expect_true(bound$passed, "nonfinite coordinate binding pass")
  for (column in c(
      "scientific_profile", "nonfinite_resolution_profile", "module",
      "binding", "indicator", "kind", "coordinate_sha256")) {
    mutation <- nonfinite
    mutation[[column]][[1L]] <- paste0(mutation[[column]][[1L]], "#")
    expect_false(wlv13_v5d_validate_nonfinite_value(
      mutation, "fixture", fixture_profile, resolution_anomaly
    )$passed, paste0("bound nonfinite ", column))
  }
  exact_stage5 <- wlv13_v5d_raw_row_keys(candidate_anomaly)
  doubled_stage5 <- c(exact_stage5, exact_stage5)
  candidate_stage5_profile <- wlv13_v5d_stage5_counts(exact_stage5)
  baseline_stage5_profile <- wlv13_v5d_stage5_counts(doubled_stage5)
  stage5_difference <- wlv13_v5d_stage5_difference(
    candidate_stage5_profile, baseline_stage5_profile
  )
  stage5_authorization <- list(
    candidate_rows = candidate_stage5_profile$rows,
    candidate_sha256 = candidate_stage5_profile$sha256,
    baseline_rows = baseline_stage5_profile$rows,
    baseline_sha256 = baseline_stage5_profile$sha256,
    difference_key_count = stage5_difference$key_count,
    difference_sha256 = stage5_difference$sha256,
    reference_sha256 = candidate_stage5_profile$sha256,
    candidate_reference_request_sha256 = paste(rep("1", 64L), collapse = ""),
    baseline_reference_request_sha256 = paste(rep("1", 64L), collapse = ""),
    profile_id = "stage5-0123456789abcdef01234567",
    derivation_sha256 = paste(rep("a", 64L), collapse = "")
  )
  expect_true(wlv13_v5d_stage5_multiplicity(
    exact_stage5, exact_stage5
  )$passed, "stage5 exact multiplicity")
  expect_false(wlv13_v5d_stage5_multiplicity(
    exact_stage5, doubled_stage5
  )$passed, "stage5 unauthorized doubled multiplicity")
  expect_true(wlv13_v5d_stage5_multiplicity(
    exact_stage5, doubled_stage5, stage5_authorization
  )$passed, "stage5 sealed doubled multiplicity")
  expect_false(wlv13_v5d_stage5_multiplicity(
    exact_stage5, exact_stage5, stage5_authorization
  )$passed, "stage5 removed duplicate against sealed profile")
  expect_false(wlv13_v5d_stage5_multiplicity(
    exact_stage5, c(doubled_stage5, exact_stage5), stage5_authorization
  )$passed, "stage5 altered count against sealed profile")
  expect_false(wlv13_v5d_stage5_multiplicity(
    exact_stage5, c(exact_stage5, paste0(exact_stage5, "#other")),
    stage5_authorization
  )$passed, "stage5 altered key against sealed profile")
  mutated_stage5_authorization <- stage5_authorization
  mutated_stage5_authorization$difference_sha256 <- paste(
    rep("b", 64L), collapse = ""
  )
  expect_false(wlv13_v5d_stage5_multiplicity(
    exact_stage5, doubled_stage5, mutated_stage5_authorization
  )$passed, "stage5 altered sealed difference hash")
  fixture_execution <- list(
    method = "fixture", mode = "recalculate", at_stage = "4",
    sea_vars_sha256 = paste(rep("c", 64L), collapse = ""), workers = 1L,
    request_sha256 = paste(rep("d", 64L), collapse = ""),
    scenario_id = "recalculate/stage-4/all/workers-1",
    run_id = "run-fixture-baseline-target"
  )
  fixture_stage5_profile <- as.data.frame(stats::setNames(
    as.list(rep("", length(wlv13_v5d_stage5_profile_columns))),
    wlv13_v5d_stage5_profile_columns
  ), stringsAsFactors = FALSE, check.names = FALSE)
  fixture_stage5_profile$method <- fixture_execution$method
  fixture_stage5_profile$mode <- fixture_execution$mode
  fixture_stage5_profile$at_stage <- fixture_execution$at_stage
  fixture_stage5_profile$sea_vars_sha256 <-
    fixture_execution$sea_vars_sha256
  fixture_stage5_profile$workers <- as.character(fixture_execution$workers)
  fixture_stage5_profile$request_sha256 <-
    fixture_execution$request_sha256
  fixture_stage5_profile$scenario_id <- fixture_execution$scenario_id
  fixture_stage5_profile$profile_id <- stage5_authorization$profile_id
  fixture_stage5_profile$candidate_stage5_rows <-
    as.character(stage5_authorization$candidate_rows)
  fixture_stage5_profile$candidate_stage5_sha256 <-
    stage5_authorization$candidate_sha256
  fixture_stage5_profile$baseline_stage5_rows <-
    as.character(stage5_authorization$baseline_rows)
  fixture_stage5_profile$baseline_stage5_sha256 <-
    stage5_authorization$baseline_sha256
  fixture_stage5_profile$difference_key_count <-
    as.character(stage5_authorization$difference_key_count)
  fixture_stage5_profile$difference_sha256 <-
    stage5_authorization$difference_sha256
  fixture_stage5_profile$reference_stage5_sha256 <-
    stage5_authorization$reference_sha256
  fixture_stage5_profile$derivation_sha256 <-
    stage5_authorization$derivation_sha256
  fixture_candidate_parent <- list(
    context = list(
      expected_commit = paste(rep("e", 40L), collapse = ""),
      observed_commit = paste(rep("e", 40L), collapse = "")
    ),
    execution = list(
      run_id = "run-current-candidate-parent", method = "fixture",
      mode = "calculate", at_stage = "",
      request_sha256 = paste(rep("1", 64L), collapse = "")
    ),
    anomalies_sha256 = paste(rep("2", 64L), collapse = "")
  )
  fixture_baseline_parent <- list(
    context = list(
      expected_commit = paste(rep("f", 40L), collapse = ""),
      observed_commit = paste(rep("f", 40L), collapse = "")
    ),
    execution = list(
      run_id = "run-current-baseline-parent", method = "fixture",
      mode = "calculate", at_stage = "",
      request_sha256 = paste(rep("1", 64L), collapse = "")
    ),
    anomalies_sha256 = paste(rep("3", 64L), collapse = "")
  )
  fixture_stage5_profile$evidence_candidate_reference_run_id <-
    "run-historical-candidate-reference"
  fixture_stage5_profile$evidence_candidate_reference_anomalies_sha256 <-
    fixture_candidate_parent$anomalies_sha256
  fixture_stage5_profile$evidence_candidate_reference_request_sha256 <-
    fixture_candidate_parent$execution$request_sha256
  fixture_stage5_profile$evidence_candidate_reference_commit <-
    paste(rep("1", 40L), collapse = "")
  fixture_stage5_profile$evidence_candidate_reference_tree <-
    paste(rep("2", 40L), collapse = "")
  fixture_stage5_profile$evidence_candidate_reference_source_sha256 <-
    paste(rep("3", 64L), collapse = "")
  fixture_stage5_profile$evidence_candidate_reference_run_manifest_sha256 <-
    paste(rep("4", 64L), collapse = "")
  fixture_stage5_profile$evidence_candidate_reference_run_inventory_sha256 <-
    paste(rep("5", 64L), collapse = "")
  fixture_stage5_profile$evidence_baseline_reference_run_id <-
    "run-historical-baseline-reference"
  fixture_stage5_profile$evidence_baseline_reference_anomalies_sha256 <-
    fixture_baseline_parent$anomalies_sha256
  fixture_stage5_profile$evidence_baseline_reference_request_sha256 <-
    fixture_baseline_parent$execution$request_sha256
  fixture_stage5_profile$evidence_baseline_reference_commit <-
    paste(rep("6", 40L), collapse = "")
  fixture_stage5_profile$evidence_baseline_reference_tree <-
    paste(rep("7", 40L), collapse = "")
  fixture_stage5_profile$evidence_baseline_reference_source_sha256 <-
    paste(rep("8", 64L), collapse = "")
  fixture_stage5_profile$evidence_baseline_reference_run_manifest_sha256 <-
    paste(rep("9", 64L), collapse = "")
  fixture_stage5_profile$evidence_baseline_reference_run_inventory_sha256 <-
    paste(rep("a", 64L), collapse = "")
  fixture_stage5_profile$evidence_baseline_target_run_id <-
    fixture_execution$run_id
  fixture_stage5_profile$evidence_baseline_target_anomalies_sha256 <-
    paste(rep("4", 64L), collapse = "")
  fixture_stage5_profile$evidence_baseline_target_request_sha256 <-
    fixture_execution$request_sha256
  fixture_stage5_profile$evidence_baseline_target_commit <-
    paste(rep("b", 40L), collapse = "")
  fixture_stage5_profile$evidence_baseline_target_tree <-
    paste(rep("c", 40L), collapse = "")
  fixture_stage5_profile$evidence_baseline_target_source_sha256 <-
    paste(rep("d", 64L), collapse = "")
  fixture_stage5_profile$evidence_baseline_target_run_manifest_sha256 <-
    paste(rep("e", 64L), collapse = "")
  fixture_stage5_profile$evidence_baseline_target_run_inventory_sha256 <-
    paste(rep("f", 64L), collapse = "")
  fixture_stage5_profile$evidence_capture_record_sha256 <-
    paste(rep("0", 64L), collapse = "")
  fixture_stage5_profile$schema_version <- wlv13_v5d_stage5_profile_schema
  fixture_stage5_profile$derivation_sha256 <-
    wlv13_v5d_stage5_profile_derivation(fixture_stage5_profile)
  fixture_stage5_profile$profile_id <- paste0(
    "stage5-", substr(fixture_stage5_profile$derivation_sha256, 1L, 24L)
  )
  for (column in wlv13_v5d_stage5_profile_columns) {
    mutation <- fixture_stage5_profile
    mutation[[column]][[1L]] <- paste0(mutation[[column]][[1L]], "0")
    mutation_derivation <- wlv13_v5d_stage5_profile_derivation(mutation)
    expect_false(
      identical(mutation$derivation_sha256[[1L]], mutation_derivation) &&
        identical(mutation$profile_id[[1L]], paste0(
          "stage5-", substr(mutation_derivation, 1L, 24L)
        )),
      paste0("stage5 profile column seal mutation ", column)
    )
  }
  selected_stage5_profile <- wlv13_v5d_select_stage5_profile(
    fixture_stage5_profile, fixture_execution
  )
  fixture_parent_stage5 <- list(
    passed = TRUE,
    reference_sha256 = stage5_authorization$reference_sha256
  )
  expect_true(selected_stage5_profile$found &&
      selected_stage5_profile$binding_valid &&
      wlv13_v5d_current_parent_binding(
        fixture_candidate_parent, fixture_baseline_parent,
        fixture_parent_stage5, selected_stage5_profile$authorization
      ),
    "stage5 sealed request selection with distinct current parent IDs"
  )
  expect_false(wlv13_v5d_select_stage5_profile(
    rbind(fixture_stage5_profile, fixture_stage5_profile),
    fixture_execution
  )$binding_valid, "stage5 duplicate profile row mutation")
  mutated_execution <- fixture_execution
  mutated_execution$request_sha256 <- paste(rep("0", 64L), collapse = "")
  expect_false(wlv13_v5d_select_stage5_profile(
    fixture_stage5_profile, mutated_execution
  )$found, "stage5 request hash mutation")
  mutated_execution <- fixture_execution
  mutated_execution$scenario_id <- "recalculate/stage-5/all/workers-1"
  expect_false(wlv13_v5d_select_stage5_profile(
    fixture_stage5_profile, mutated_execution
  )$binding_valid, "stage5 checkpoint mutation")
  mutated_parent_stage5 <- fixture_parent_stage5
  mutated_parent_stage5$reference_sha256 <- paste(rep("5", 64L), collapse = "")
  expect_false(wlv13_v5d_current_parent_binding(
    fixture_candidate_parent, fixture_baseline_parent,
    mutated_parent_stage5, selected_stage5_profile$authorization
  ), "stage5 current parent fingerprint mutation")
  mutated_parent <- fixture_candidate_parent
  mutated_parent$execution$request_sha256 <- paste(rep("6", 64L), collapse = "")
  expect_false(wlv13_v5d_current_parent_binding(
    mutated_parent, fixture_baseline_parent,
    fixture_parent_stage5, selected_stage5_profile$authorization
  ), "stage5 current parent request mutation")
  mutated_parent <- fixture_baseline_parent
  mutated_parent$context$observed_commit <- paste(rep("7", 40L), collapse = "")
  expect_false(wlv13_v5d_current_parent_binding(
    fixture_candidate_parent, mutated_parent,
    fixture_parent_stage5, selected_stage5_profile$authorization
  ), "stage5 current parent commit mutation")
  mutated_profile <- fixture_stage5_profile
  mutated_profile$evidence_candidate_reference_run_id <-
    "run-forged-historical-reference"
  expect_false(identical(
    mutated_profile$derivation_sha256,
    wlv13_v5d_stage5_profile_derivation(mutated_profile)
  ), "stage5 historical evidence seal mutation")
  reference_execution <- fixture_execution
  reference_execution$mode <- "calculate"
  reference_execution$at_stage <- ""
  reference_execution$request_sha256 <- paste(rep("1", 64L), collapse = "")
  reference_execution$scenario_id <- "calculate/workers-1"
  reference_execution$run_id <- "run-fixture-candidate-reference"
  baseline_reference_execution <- reference_execution
  baseline_reference_execution$run_id <- "run-fixture-baseline-reference"
  fixture_auth <- function(run_id, digit) list(
    run_id = run_id,
    commit = paste(rep(digit, 40L), collapse = ""),
    tree = paste(rep(digit, 40L), collapse = ""),
    source_sha256 = paste(rep(digit, 64L), collapse = ""),
    run_manifest_sha256 = paste(rep(digit, 64L), collapse = ""),
    run_inventory_sha256 = paste(rep(digit, 64L), collapse = "")
  )
  candidate_reference_auth <- fixture_auth(
    reference_execution$run_id, "1"
  )
  baseline_reference_auth <- fixture_auth(
    baseline_reference_execution$run_id, "2"
  )
  baseline_target_auth <- fixture_auth(fixture_execution$run_id, "3")
  derived_profile <- wlv13_v5d_derive_stage5_profile(
    exact_stage5, exact_stage5, doubled_stage5,
    reference_execution, baseline_reference_execution, fixture_execution,
    paste(rep("2", 64L), collapse = ""),
    paste(rep("3", 64L), collapse = ""),
    paste(rep("4", 64L), collapse = ""),
    candidate_reference_auth, baseline_reference_auth,
    baseline_target_auth, paste(rep("0", 64L), collapse = "")
  )
  expect_true(
    nrow(derived_profile) == 1L &&
      grepl("^stage5-[0-9a-f]{24}$", derived_profile$profile_id) &&
      identical(
        derived_profile$derivation_sha256,
        wlv13_v5d_stage5_profile_derivation(derived_profile)
      ),
    "stage5 pre-gate evidence derivation"
  )
  expect_error(wlv13_v5d_derive_stage5_profile(
    paste0(exact_stage5, "#lost"), exact_stage5, doubled_stage5,
    reference_execution, baseline_reference_execution, fixture_execution,
    paste(rep("2", 64L), collapse = ""),
    paste(rep("3", 64L), collapse = ""),
    paste(rep("4", 64L), collapse = ""),
    candidate_reference_auth, baseline_reference_auth,
    baseline_target_auth, paste(rep("0", 64L), collapse = "")
  ), "stage5 reference parity mutation")
  expect_error(wlv13_v5d_derive_stage5_profile(
    exact_stage5, exact_stage5, c(doubled_stage5, exact_stage5),
    reference_execution, baseline_reference_execution, fixture_execution,
    paste(rep("2", 64L), collapse = ""),
    paste(rep("3", 64L), collapse = ""),
    paste(rep("4", 64L), collapse = ""),
    candidate_reference_auth, baseline_reference_auth,
    baseline_target_auth, paste(rep("0", 64L), collapse = "")
  ), "stage5 target multiplicity mutation")

  hash <- fixture_coordinate_sha256
  expect_true(grepl("^[0-9a-f]{64}$", hash), "coordinate hash shape")
  expect_false(identical(paste0(substr(hash, 1L, 63L), "0"), hash),
    "coordinate hash mutation"
  )
  assertions
}
