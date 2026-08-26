# Persisted native-runtime resources ---------------------------------------
#
# Public panel arrays remain governed by wlvpanel-output/1.0.0.  This
# versioned sidecar persists the internal resources that recalculation must
# import without reconstructing scientific state from published values.  Every
# sparse state resource is cryptographically bound to the exact IO or panel
# artifact from which its coordinates are interpreted.

wlv_runtime_snapshot_filename <- function() {
  "_runtime_resources.rds"
}

wlv_runtime_snapshot_version <- function() {
  "wlv-runtime-resources/1.0.0"
}

wlv_runtime_compatibility_version <- function() {
  "wlv-runtime-compatibility/1.0.0"
}

wlv_runtime_snapshot_hash_chunk_values <- function() {
  2^20
}

wlv_runtime_snapshot_io_resources <- function() {
  c(
    "k_composition", "k_depreciation", "values",
    "transfers_values", "consumption_basket"
  )
}

wlv_runtime_snapshot_panel_definitions <- function() {
  list(
    sea_sectors = list(
      target_key = "artifact/sea_sectors",
      axes = c("year", "indicator", "sector", "country"),
      indicator_key = "sea/sector/"
    ),
    sea_countries = list(
      target_key = "artifact/sea_countries",
      axes = c("year", "indicator", "country"),
      indicator_key = "sea/country/"
    )
  )
}

wlv_runtime_snapshot_artifact_inventory <- function(paths, expected, label) {
  if (
    !is.character(paths) || is.null(names(paths)) ||
      !setequal(names(paths), expected) || anyNA(paths) ||
      anyDuplicated(names(paths)) || any(!file.exists(paths)) ||
      any(file.info(paths)$isdir) || any(!file.exists(paste0(paths, ".meta"))) ||
      any(file.info(paste0(paths, ".meta"))$isdir)
  ) {
    stop(
      sprintf("Runtime snapshot requires one existing %s artifact per ID.", label),
      call. = FALSE
    )
  }
  paths <- paths[expected]
  metadata_paths <- paste0(paths, ".meta")
  result <- data.frame(
    id = expected,
    path = basename(paths),
    sha256 = unname(vapply(
      paths,
      wlv_publication_file_sha256,
      character(1L)
    )),
    meta_sha256 = unname(vapply(
      metadata_paths,
      wlv_publication_file_sha256,
      character(1L)
    )),
    stringsAsFactors = FALSE
  )
  if (
    anyDuplicated(result$path) ||
      any(!grepl("^[0-9a-f]{64}$", result$sha256)) ||
      any(!grepl("^[0-9a-f]{64}$", result$meta_sha256))
  ) {
    stop("Runtime snapshot artifact inventory is not canonical.", call. = FALSE)
  }
  result
}

wlv_runtime_snapshot_artifact_root <- function(paths) {
  if (!is.character(paths) || !length(paths) || anyNA(paths) ||
      any(!file.exists(paths))) {
    stop("Runtime snapshot artifact paths are invalid.", call. = FALSE)
  }
  roots <- unique(vapply(dirname(paths), function(path) {
    normalizePath(path, winslash = "/", mustWork = TRUE)
  }, character(1L)))
  if (length(roots) != 1L) {
    stop("Runtime snapshot artifacts must share one staging root.", call. = FALSE)
  }
  roots[[1L]]
}

wlv_runtime_snapshot_scalar <- function(value, name) {
  if (
    !is.character(value) || length(value) != 1L || is.na(value) ||
      !nzchar(value)
  ) {
    stop(sprintf("`%s` must be one non-empty string.", name), call. = FALSE)
  }
  value
}

wlv_runtime_snapshot_materialize_character <- function(value) {
  if (!is.character(value)) {
    stop("Runtime snapshot character data is invalid.", call. = FALSE)
  }
  materialized <- character(length(value))
  if (length(value)) {
    materialized[] <- enc2utf8(value)
  }
  materialized
}

wlv_runtime_snapshot_materialize_labels <- function(labels) {
  if (!is.list(labels) || any(!vapply(labels, is.character, logical(1L)))) {
    stop("Runtime snapshot axis labels are invalid.", call. = FALSE)
  }
  result <- lapply(labels, wlv_runtime_snapshot_materialize_character)
  if (!is.null(names(labels))) {
    names(result) <- wlv_runtime_snapshot_materialize_character(names(labels))
  }
  result
}

wlv_runtime_snapshot_contract <- function(key) {
  if (!is.character(key) || length(key) != 1L || is.na(key)) {
    stop("A runtime-snapshot resource key is invalid.", call. = FALSE)
  }
  if (startsWith(key, "io/")) {
    resource <- substring(key, nchar("io/") + 1L)
    if (!resource %in% wlv_runtime_snapshot_io_resources()) {
      stop(sprintf("Runtime snapshot does not support `%s`.", key), call. = FALSE)
    }
    return(wlv_native_io_contract(resource))
  }
  if (identical(key, "intermediate/lambda")) {
    return(wlv_native_intermediate_contract(
      "lambda",
      c("year", "input"),
      "io_period"
    ))
  }
  stop(sprintf("Runtime snapshot does not support `%s`.", key), call. = FALSE)
}

wlv_runtime_snapshot_terminal <- function(store, key, partition, contract) {
  entries <- wlv_runtime_terminal_entries(store, key, partition)
  if (length(entries) != 1L) {
    stop(
      sprintf(
        "Runtime resource `%s[%s]` has %d terminal generations.",
        key,
        partition,
        length(entries)
      ),
      call. = FALSE
    )
  }
  entry <- entries[[1L]]
  if (!wlv_runtime_contract_compatible(contract, entry$contract)) {
    stop(
      sprintf("Runtime resource `%s[%s]` has an incompatible contract.", key, partition),
      call. = FALSE
    )
  }
  entry
}

wlv_runtime_snapshot_entry <- function(
    store,
    key,
    partition,
    include_value = FALSE) {
  contract <- wlv_runtime_snapshot_contract(key)
  value_entry <- wlv_runtime_snapshot_terminal(
    store,
    key,
    partition,
    contract
  )
  state_key <- wlv_semantic_state_key(key)
  state_entry <- wlv_runtime_snapshot_terminal(
    store,
    state_key,
    partition,
    wlv_native_semantic_state_contract(contract)
  )
  wlv_runtime_validate_resource_value(
    value_entry$value,
    contract,
    paste0(key, "[", partition, "]")
  )
  wlv_semantic_state_validate(
    state_entry$value,
    value = value_entry$value,
    target_key = key,
    axes = contract$axes,
    state_key = state_key
  )
  list(
    key = key,
    partition = partition,
    producer = value_entry$producer,
    state_producer = state_entry$producer,
    contract_sha256 = wlv_runtime_snapshot_contract_sha256(contract),
    axes_sha256 = wlv_runtime_snapshot_axes_sha256(
      value_entry$value,
      contract$axes
    ),
    value_sha256 = wlv_runtime_snapshot_value_sha256(value_entry$value),
    state_sha256 = wlv_runtime_snapshot_value_sha256(state_entry$value),
    value = if (isTRUE(include_value)) value_entry$value else NULL,
    state = state_entry$value
  )
}

wlv_runtime_snapshot_panel_states <- function(store) {
  definitions <- wlv_runtime_snapshot_panel_definitions()
  states <- lapply(names(definitions), function(name) {
    definition <- definitions[[name]]
    target_contract <- wlv_native_artifact_array_contract(
      name,
      definition$axes
    )
    target <- wlv_runtime_snapshot_terminal(
      store,
      definition$target_key,
      NULL,
      target_contract
    )
    state_key <- wlv_semantic_state_key(definition$target_key)
    state <- wlv_runtime_snapshot_terminal(
      store,
      state_key,
      NULL,
      wlv_native_semantic_state_contract(target_contract)
    )
    wlv_semantic_state_validate(
      state$value,
      value = target$value,
      target_key = definition$target_key,
      axes = definition$axes,
      state_key = state_key
    )
    state$value
  })
  stats::setNames(states, names(definitions))
}

wlv_runtime_snapshot_contract_sha256 <- function(contract) {
  wlv_resource_contract_assert(contract)
  wlv_publication_sha256_raw(serialize(contract, NULL, version = 3L))
}

wlv_runtime_snapshot_axes_sha256 <- function(value, axes) {
  if (
    !is.array(value) || is.null(dimnames(value)) ||
      !identical(names(dimnames(value)), axes) ||
      any(vapply(dimnames(value), is.null, logical(1L)))
  ) {
    stop("Runtime snapshot cannot fingerprint incompatible axis labels.",
      call. = FALSE
    )
  }
  wlv_runtime_snapshot_axis_labels_sha256(dimnames(value), axes)
}

wlv_runtime_snapshot_axis_labels_sha256 <- function(labels, axes) {
  if (
    !is.list(labels) || !identical(names(labels), axes) ||
      any(vapply(labels, is.null, logical(1L)))
  ) {
    stop("Runtime snapshot cannot fingerprint incompatible axis labels.",
      call. = FALSE
    )
  }
  labels <- wlv_runtime_snapshot_materialize_labels(labels)
  wlv_publication_sha256_raw(serialize(labels, NULL, version = 3L))
}

wlv_runtime_snapshot_panel_value_slice <- function(value, artifact, indicator) {
  definitions <- wlv_runtime_snapshot_panel_definitions()
  definition <- definitions[[artifact]]
  if (is.null(definition) || !is.array(value) || is.null(dimnames(value)) ||
      !identical(names(dimnames(value)), definition$axes) ||
      !indicator %in% dimnames(value)$indicator) {
    stop(
      sprintf("Cannot select `%s` from runtime panel `%s`.", indicator, artifact),
      call. = FALSE
    )
  }
  indicator_axis <- match("indicator", definition$axes)
  indices <- rep(list(TRUE), length(definition$axes))
  indices[[indicator_axis]] <- match(indicator, dimnames(value)$indicator)
  selected <- do.call(`[`, c(list(value), indices, list(drop = FALSE)))
  target_axes <- setdiff(definition$axes, "indicator")
  array(
    selected,
    dim = dim(value)[match(target_axes, definition$axes)],
    dimnames = dimnames(value)[target_axes]
  )
}

wlv_runtime_snapshot_panel_state_slice <- function(
    panel_state,
    artifact,
    indicator,
    value) {
  definitions <- wlv_runtime_snapshot_panel_definitions()
  definition <- definitions[[artifact]]
  if (is.null(definition)) {
    stop(sprintf("Unknown panel-state artifact `%s`.", artifact), call. = FALSE)
  }
  rows <- wlv_semantic_plain_data_frame(
    panel_state,
    c(definition$axes, "state")
  )
  rows <- rows[rows$indicator == indicator, , drop = FALSE]
  rows$indicator <- NULL
  target_axes <- setdiff(definition$axes, "indicator")
  rows <- rows[c(target_axes, "state")]
  row.names(rows) <- NULL
  target_key <- paste0(definition$indicator_key, indicator)
  state <- wlv_semantic_new_state_resource(rows, target_key, target_axes)
  wlv_semantic_state_validate(
    state,
    value = value,
    target_key = target_key,
    axes = target_axes,
    state_key = wlv_semantic_state_key(target_key)
  )
  state
}

wlv_runtime_snapshot_panel_provenance <- function(store) {
  definitions <- wlv_runtime_snapshot_panel_definitions()
  rows <- list()
  for (artifact in names(definitions)) {
    definition <- definitions[[artifact]]
    target <- wlv_runtime_snapshot_terminal(
      store,
      definition$target_key,
      NULL,
      wlv_native_artifact_array_contract(artifact, definition$axes)
    )
    target_state <- wlv_runtime_snapshot_terminal(
      store,
      wlv_semantic_state_key(definition$target_key),
      NULL,
      wlv_native_semantic_state_contract(
        wlv_native_artifact_array_contract(artifact, definition$axes)
      )
    )
    indicator_axis <- match("indicator", definition$axes)
    indicators <- dimnames(target$value)[[indicator_axis]]
    if (!length(indicators) || anyNA(indicators) || anyDuplicated(indicators)) {
      stop(
        sprintf("Runtime panel `%s` has invalid indicator labels.", artifact),
        call. = FALSE
      )
    }
    level <- if (identical(artifact, "sea_sectors")) "sector" else "country"
    for (indicator in indicators) {
      key <- wlv_native_indicator_key(indicator, level)
      contract <- wlv_native_indicator_contract(indicator, level = level)
      value_entry <- wlv_runtime_snapshot_terminal(store, key, NULL, contract)
      state_entry <- wlv_runtime_snapshot_terminal(
        store,
        wlv_semantic_state_key(key),
        NULL,
        wlv_native_semantic_state_contract(contract)
      )
      wlv_runtime_validate_resource_value(value_entry$value, contract, key)
      wlv_semantic_state_validate(
        state_entry$value,
        value = value_entry$value,
        target_key = key,
        axes = contract$axes,
        state_key = wlv_semantic_state_key(key)
      )
      published_value <- wlv_runtime_snapshot_panel_value_slice(
        target$value,
        artifact,
        indicator
      )
      published_state <- wlv_runtime_snapshot_panel_state_slice(
        target_state$value,
        artifact,
        indicator,
        published_value
      )
      if (!identical(published_value, value_entry$value) ||
          !identical(published_state, state_entry$value)) {
        stop(
          sprintf(
            "Runtime panel `%s/%s` differs from its terminal resource generation.",
            artifact,
            indicator
          ),
          call. = FALSE
        )
      }
      rows[[length(rows) + 1L]] <- data.frame(
        artifact = artifact,
        indicator = indicator,
        key = key,
        producer = value_entry$producer,
        state_producer = state_entry$producer,
        contract_sha256 = wlv_runtime_snapshot_contract_sha256(contract),
        axes_sha256 = wlv_runtime_snapshot_axes_sha256(
          value_entry$value,
          contract$axes
        ),
        value_sha256 = wlv_runtime_snapshot_value_sha256(value_entry$value),
        state_sha256 = wlv_runtime_snapshot_value_sha256(state_entry$value),
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) {
    stop("Runtime snapshot panel provenance is empty.", call. = FALSE)
  }
  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result
}

wlv_runtime_snapshot_numeric_chunk_sha256 <- function(value) {
  if (!is.numeric(value) || is.object(value) || !is.null(attributes(value))) {
    stop("A runtime snapshot numeric hash chunk is invalid.", call. = FALSE)
  }
  materialized <- numeric(length(value))
  if (length(value)) {
    materialized[] <- value
  }
  wlv_publication_sha256_raw(serialize(materialized, NULL, version = 3L))
}

wlv_runtime_snapshot_array_sha256_from_chunks <- function(
    dimensions,
    labels,
    chunk_sha256) {
  if (!is.numeric(dimensions) || !length(dimensions) || anyNA(dimensions) ||
      any(!is.finite(dimensions)) || any(dimensions < 0) ||
      any(dimensions != as.integer(dimensions)) || !is.list(labels) ||
      length(labels) != length(dimensions) ||
      any(vapply(labels, is.null, logical(1L))) ||
      !is.character(chunk_sha256) || anyNA(chunk_sha256) ||
      any(!grepl("^[0-9a-f]{64}$", chunk_sha256))) {
    stop("Runtime snapshot array hash components are invalid.", call. = FALSE)
  }
  labels <- wlv_runtime_snapshot_materialize_labels(labels)
  payload <- list(
    version = "wlv-array-value/1.0.0",
    dimensions = as.integer(dimensions),
    dimnames = labels,
    storage = "double",
    chunk_values = as.integer(wlv_runtime_snapshot_hash_chunk_values()),
    chunks = unname(chunk_sha256)
  )
  wlv_publication_sha256_raw(serialize(payload, NULL, version = 3L))
}

wlv_runtime_snapshot_array_sha256 <- function(value) {
  if (!is.numeric(value) || !is.array(value) || is.null(dimnames(value)) ||
      any(vapply(dimnames(value), is.null, logical(1L)))) {
    stop("Runtime snapshot array values require numeric labelled arrays.",
      call. = FALSE
    )
  }
  total <- length(value)
  chunk_values <- as.integer(wlv_runtime_snapshot_hash_chunk_values())
  starts <- if (total) seq.int(1L, total, by = chunk_values) else integer()
  hashes <- vapply(starts, function(start) {
    end <- min(total, start + chunk_values - 1L)
    chunk <- as.numeric(value[start:end])
    attributes(chunk) <- NULL
    wlv_runtime_snapshot_numeric_chunk_sha256(chunk)
  }, character(1L))
  wlv_runtime_snapshot_array_sha256_from_chunks(
    dim(value),
    dimnames(value),
    hashes
  )
}

wlv_runtime_snapshot_canonical_state <- function(value) {
  wlv_semantic_state_validate(value)
  axes <- wlv_runtime_snapshot_materialize_character(
    attr(value, "axes", exact = TRUE)
  )
  target_key <- wlv_runtime_snapshot_materialize_character(
    attr(value, "target_key", exact = TRUE)
  )[[1L]]
  rows <- wlv_semantic_plain_data_frame(value, c(axes, "state"))
  rows[] <- lapply(rows, wlv_runtime_snapshot_materialize_character)
  wlv_semantic_new_state_resource(
    rows,
    target_key,
    axes
  )
}

wlv_runtime_snapshot_value_sha256 <- function(value) {
  if (inherits(value, "wlv_semantic_state")) {
    value <- wlv_runtime_snapshot_canonical_state(value)
  }
  if (is.numeric(value) && is.array(value) && !is.null(dimnames(value)) &&
      !any(vapply(dimnames(value), is.null, logical(1L)))) {
    return(wlv_runtime_snapshot_array_sha256(value))
  }
  if (is.character(value) && is.null(attributes(value))) {
    value <- wlv_runtime_snapshot_materialize_character(value)
  }
  wlv_publication_sha256_raw(serialize(value, NULL, version = 3L))
}

wlv_runtime_snapshot_parent_imports_sha256 <- function(value) {
  wlv_parent_seed_resolutions_assert(value)
  wlv_runtime_snapshot_value_sha256(value)
}

wlv_runtime_compatibility_hash_columns <- function() {
  c(
    "runtime_generation_sha256", "method_parameters_sha256",
    "method_sectors_sha256", "indicators_sha256",
    "unit_sidecar_sha256", "unit_definitions_sha256",
    "missingness_policy_sha256", "aggregation_registry_sha256",
    "scientific_profile_sha256", "configuration_sha256"
  )
}

wlv_runtime_compatibility_sha256 <- function(value) {
  expected <- c(
    "version", "method", "source", "runtime_generation_sha256",
    "method_parameters_sha256", "method_sectors_sha256",
    "indicators", "indicators_sha256",
    "unit_contract_id", "unit_sidecar_sha256", "unit_definitions_sha256",
    "missingness_policy_id", "missingness_policy_sha256",
    "aggregation_registry_sha256", "scientific_profile_sha256",
    "configuration_sha256"
  )
  if (!is.list(value) || !identical(names(value), expected)) {
    stop("Runtime compatibility has an invalid fingerprint payload.",
      call. = FALSE
    )
  }
  wlv_runtime_snapshot_value_sha256(value)
}

wlv_runtime_compatibility <- function(
    method,
    source,
    runtime_generation_sha256,
    method_parameters_sha256,
    method_sectors_sha256,
    indicators,
    unit_contract_id,
    unit_sidecar_sha256,
    unit_definitions_sha256,
    missingness_policy_id,
    missingness_policy_sha256,
    aggregation_registry_sha256,
    scientific_profile_sha256,
    configuration_sha256) {
  method <- wlv_runtime_snapshot_scalar(method, "compatibility method")
  source <- wlv_runtime_snapshot_scalar(source, "compatibility source")
  unit_contract_id <- wlv_runtime_snapshot_scalar(
    unit_contract_id,
    "unit contract ID"
  )
  missingness_policy_id <- wlv_runtime_snapshot_scalar(
    missingness_policy_id,
    "missingness policy ID"
  )
  if (!is.character(indicators) || !length(indicators) || anyNA(indicators) ||
      any(!nzchar(indicators)) || anyDuplicated(indicators)) {
    stop("Runtime compatibility requires ordered unique indicators.",
      call. = FALSE
    )
  }
  hashes <- c(
    runtime_generation_sha256 = runtime_generation_sha256,
    method_parameters_sha256 = method_parameters_sha256,
    method_sectors_sha256 = method_sectors_sha256,
    unit_sidecar_sha256 = unit_sidecar_sha256,
    unit_definitions_sha256 = unit_definitions_sha256,
    missingness_policy_sha256 = missingness_policy_sha256,
    aggregation_registry_sha256 = aggregation_registry_sha256,
    scientific_profile_sha256 = scientific_profile_sha256,
    configuration_sha256 = configuration_sha256
  )
  if (anyNA(hashes) || any(!grepl("^[0-9a-f]{64}$", hashes))) {
    stop("Runtime compatibility received an invalid concrete hash.",
      call. = FALSE
    )
  }
  payload <- list(
    version = wlv_runtime_compatibility_version(),
    method = method,
    source = source,
    runtime_generation_sha256 = unname(
      hashes[["runtime_generation_sha256"]]
    ),
    method_parameters_sha256 = unname(
      hashes[["method_parameters_sha256"]]
    ),
    method_sectors_sha256 = unname(hashes[["method_sectors_sha256"]]),
    indicators = unname(indicators),
    indicators_sha256 = wlv_runtime_snapshot_value_sha256(
      unname(indicators)
    ),
    unit_contract_id = unit_contract_id,
    unit_sidecar_sha256 = unname(hashes[["unit_sidecar_sha256"]]),
    unit_definitions_sha256 = unname(hashes[["unit_definitions_sha256"]]),
    missingness_policy_id = missingness_policy_id,
    missingness_policy_sha256 = unname(
      hashes[["missingness_policy_sha256"]]
    ),
    aggregation_registry_sha256 = unname(
      hashes[["aggregation_registry_sha256"]]
    ),
    scientific_profile_sha256 = unname(
      hashes[["scientific_profile_sha256"]]
    ),
    configuration_sha256 = unname(hashes[["configuration_sha256"]])
  )
  c(payload, list(sha256 = wlv_runtime_compatibility_sha256(payload)))
}

wlv_runtime_compatibility_assert <- function(value) {
  fields <- c(
    "version", "method", "source", "runtime_generation_sha256",
    "method_parameters_sha256", "method_sectors_sha256",
    "indicators", "indicators_sha256",
    "unit_contract_id", "unit_sidecar_sha256", "unit_definitions_sha256",
    "missingness_policy_id", "missingness_policy_sha256",
    "aggregation_registry_sha256", "scientific_profile_sha256",
    "configuration_sha256", "sha256"
  )
  if (!is.list(value) || !identical(names(value), fields) ||
      !identical(value$version, wlv_runtime_compatibility_version())) {
    stop("Runtime compatibility has an invalid schema.", call. = FALSE)
  }
  wlv_runtime_snapshot_scalar(value$method, "compatibility method")
  wlv_runtime_snapshot_scalar(value$source, "compatibility source")
  wlv_runtime_snapshot_scalar(value$unit_contract_id, "unit contract ID")
  wlv_runtime_snapshot_scalar(
    value$missingness_policy_id,
    "missingness policy ID"
  )
  if (!is.character(value$indicators) || !length(value$indicators) ||
      anyNA(value$indicators) || any(!nzchar(value$indicators)) ||
      anyDuplicated(value$indicators)) {
    stop("Runtime compatibility indicator coverage is invalid.", call. = FALSE)
  }
  hashes <- c(
    unlist(value[wlv_runtime_compatibility_hash_columns()], use.names = FALSE),
    value$sha256
  )
  if (!is.character(hashes) || anyNA(hashes) ||
      any(!grepl("^[0-9a-f]{64}$", hashes)) ||
      !identical(
        value$indicators_sha256,
        wlv_runtime_snapshot_value_sha256(unname(value$indicators))
      ) || !identical(
        value$sha256,
        wlv_runtime_compatibility_sha256(value[setdiff(fields, "sha256")])
      )) {
    stop("Runtime compatibility fingerprint is invalid.", call. = FALSE)
  }
  invisible(value)
}

wlv_runtime_snapshot_assert_compatible <- function(snapshot, current) {
  wlv_runtime_compatibility_assert(current)
  if (!is.list(snapshot) || is.null(snapshot$compatibility)) {
    stop("Parent runtime snapshot lacks a compatibility fingerprint.",
      call. = FALSE
    )
  }
  wlv_runtime_compatibility_assert(snapshot$compatibility)
  if (!identical(snapshot$compatibility, current)) {
    stop(
      paste0(
        "Parent runtime compatibility differs from the current scientific ",
        "contracts; run a full calculation."
      ),
      call. = FALSE
    )
  }
  invisible(current)
}

wlv_runtime_compatibility_manifest <- function(value) {
  wlv_runtime_compatibility_assert(value)
  result <- list(
    version = value$version,
    method = value$method,
    source = value$source,
    runtime_generation_sha256 = value$runtime_generation_sha256,
    method_parameters_sha256 = value$method_parameters_sha256,
    method_sectors_sha256 = value$method_sectors_sha256,
    indicators_count = as.character(length(value$indicators)),
    indicators_sha256 = value$indicators_sha256,
    unit_contract_id = value$unit_contract_id,
    unit_sidecar_sha256 = value$unit_sidecar_sha256,
    unit_definitions_sha256 = value$unit_definitions_sha256,
    missingness_policy_id = value$missingness_policy_id,
    missingness_policy_sha256 = value$missingness_policy_sha256,
    aggregation_registry_sha256 = value$aggregation_registry_sha256,
    scientific_profile_sha256 = value$scientific_profile_sha256,
    configuration_sha256 = value$configuration_sha256,
    sha256 = value$sha256
  )
  result[order(names(result), method = "radix")]
}

wlv_runtime_compatibility_manifest_assert <- function(value) {
  fields <- sort(c(
    "version", "method", "source", "runtime_generation_sha256",
    "method_parameters_sha256", "method_sectors_sha256",
    "indicators_count", "indicators_sha256",
    "unit_contract_id", "unit_sidecar_sha256", "unit_definitions_sha256",
    "missingness_policy_id", "missingness_policy_sha256",
    "aggregation_registry_sha256", "scientific_profile_sha256",
    "configuration_sha256", "sha256"
  ), method = "radix")
  if (!is.list(value) || !identical(names(value), fields) ||
      any(!vapply(value, function(field) {
        is.character(field) && length(field) == 1L && !is.na(field) &&
          nzchar(field)
      }, logical(1L))) ||
      !identical(value$version, wlv_runtime_compatibility_version()) ||
      !grepl("^[1-9][0-9]*$", value$indicators_count) ||
      any(!grepl(
        "^[0-9a-f]{64}$",
        unlist(value[c(
          "runtime_generation_sha256", "method_parameters_sha256",
          "method_sectors_sha256", "indicators_sha256", "unit_sidecar_sha256",
          "unit_definitions_sha256", "missingness_policy_sha256",
          "aggregation_registry_sha256", "scientific_profile_sha256",
          "configuration_sha256", "sha256"
        )], use.names = FALSE)
      ))) {
    stop("Run manifest runtime compatibility is invalid.", call. = FALSE)
  }
  invisible(value)
}

wlv_runtime_manifest_assert_compatible <- function(manifest, current) {
  wlv_runtime_compatibility_assert(current)
  observed <- if (is.list(manifest) && is.list(manifest$result) &&
      is.list(manifest$result$provenance)) {
    manifest$result$provenance$runtime_compatibility
  } else {
    NULL
  }
  if (is.null(observed)) {
    stop(
      paste0(
        "Parent run lacks authenticated runtime compatibility; run a full ",
        "calculation."
      ),
      call. = FALSE
    )
  }
  wlv_runtime_compatibility_manifest_assert(observed)
  expected <- wlv_runtime_compatibility_manifest(current)
  if (!identical(observed, expected)) {
    stop(
      paste0(
        "Parent run runtime compatibility differs from the current scientific ",
        "contracts; run a full calculation."
      ),
      call. = FALSE
    )
  }
  invisible(current)
}

wlv_runtime_snapshot_panel_provenance_update <- function(
    snapshot,
    store,
    parent_imports) {
  wlv_parent_seed_resolutions_assert(parent_imports)
  current <- wlv_runtime_snapshot_panel_provenance(store)
  for (index in seq_len(nrow(current))) {
    row <- current[index, , drop = FALSE]
    entry <- wlv_runtime_snapshot_terminal(
      store,
      row$key[[1L]],
      NULL,
      if (identical(row$artifact[[1L]], "sea_sectors")) {
        wlv_native_indicator_contract(row$indicator[[1L]], level = "sector")
      } else {
        wlv_native_indicator_contract(row$indicator[[1L]], level = "country")
      }
    )
    if (!entry$action %in% c("seed", "inherited")) {
      next
    }
    matched <- parent_imports$key == row$key[[1L]] &
      parent_imports$partition == "" &
      parent_imports$child_producer == row$producer[[1L]]
    resolution <- parent_imports[matched, , drop = FALSE]
    if (nrow(resolution) != 1L) {
      stop(
        sprintf(
          "Inherited terminal `%s@%s` lacks one parent import resolution.",
          row$key[[1L]],
          row$producer[[1L]]
        ),
        call. = FALSE
      )
    }
    parent <- snapshot$panel_provenance[
      snapshot$panel_provenance$key == row$key[[1L]],
      ,
      drop = FALSE
    ]
    if (nrow(parent) != 1L ||
        !identical(parent$producer[[1L]], resolution$origin_producer[[1L]]) ||
        !identical(
          parent$state_producer[[1L]],
          resolution$origin_state_producer[[1L]]
        ) ||
        !identical(
          parent$contract_sha256[[1L]],
          resolution$contract_sha256[[1L]]
        ) ||
        !identical(parent$axes_sha256[[1L]], resolution$axes_sha256[[1L]]) ||
        !identical(parent$value_sha256[[1L]], resolution$value_sha256[[1L]]) ||
        !identical(parent$state_sha256[[1L]], resolution$state_sha256[[1L]]) ||
        !identical(row$value_sha256[[1L]], resolution$value_sha256[[1L]]) ||
        !identical(row$state_sha256[[1L]], resolution$state_sha256[[1L]])) {
      stop(
        sprintf(
          "Inherited terminal `%s` differs from its authenticated parent origin.",
          row$key[[1L]]
        ),
        call. = FALSE
      )
    }
    current[index, ] <- parent[1L, names(current), drop = FALSE]
  }
  if (any(current$producer == wlv_runtime_seed_producer()) ||
      any(current$state_producer == wlv_runtime_seed_producer())) {
    stop("A recalculated panel cannot publish a child seed alias as provenance.",
      call. = FALSE
    )
  }
  current
}

wlv_runtime_snapshot_artifact_sha256 <- function(sha256, meta_sha256) {
  if (
    !is.character(sha256) || length(sha256) != 1L || is.na(sha256) ||
      !grepl("^[0-9a-f]{64}$", sha256) ||
      !is.character(meta_sha256) || length(meta_sha256) != 1L ||
      is.na(meta_sha256) || !grepl("^[0-9a-f]{64}$", meta_sha256)
  ) {
    stop("Runtime snapshot received an invalid artifact bundle hash.",
      call. = FALSE
    )
  }
  wlv_publication_sha256_raw(charToRaw(enc2utf8(paste(
    sha256,
    meta_sha256,
    sep = "\034"
  ))))
}

wlv_runtime_snapshot_binding_sha256 <- function(
    id,
    artifact_sha256,
    state,
    provenance = NULL) {
  state <- wlv_runtime_snapshot_canonical_state(state)
  payload <- list(
    id = id,
    artifact_sha256 = artifact_sha256,
    state = state,
    provenance = provenance
  )
  wlv_publication_sha256_raw(serialize(payload, NULL, version = 3L))
}

wlv_runtime_snapshot_state_bindings <- function(snapshot) {
  definitions <- wlv_runtime_snapshot_panel_definitions()
  ids <- character()
  artifact_sha256 <- character()
  states <- list()
  provenance <- list()
  for (name in names(definitions)) {
    ids <- c(ids, paste("panel", name, sep = "\034"))
    row <- match(name, snapshot$panel_artifacts$id)
    artifact_sha256 <- c(
      artifact_sha256,
      wlv_runtime_snapshot_artifact_sha256(
        snapshot$panel_artifacts$sha256[[row]],
        snapshot$panel_artifacts$meta_sha256[[row]]
      )
    )
    states[[length(states) + 1L]] <- snapshot$panel_states[[name]]
    provenance[[length(provenance) + 1L]] <- snapshot$panel_provenance[
      snapshot$panel_provenance$artifact == name,
      ,
      drop = FALSE
    ]
  }
  for (id in names(snapshot$resources)) {
    entry <- snapshot$resources[[id]]
    ids <- c(ids, id)
    token <- if (identical(entry$key, "intermediate/lambda")) {
      wlv_runtime_snapshot_value_sha256(entry$value)
    } else {
      row <- match(entry$partition, snapshot$io_artifacts$partition)
      wlv_runtime_snapshot_artifact_sha256(
        snapshot$io_artifacts$sha256[[row]],
        snapshot$io_artifacts$meta_sha256[[row]]
      )
    }
    artifact_sha256 <- c(artifact_sha256, token)
    states[[length(states) + 1L]] <- entry$state
    provenance[[length(provenance) + 1L]] <- list(
      key = entry$key,
      partition = entry$partition,
      producer = entry$producer,
      state_producer = entry$state_producer,
      contract_sha256 = entry$contract_sha256,
      axes_sha256 = entry$axes_sha256,
      value_sha256 = entry$value_sha256,
      state_sha256 = entry$state_sha256
    )
  }
  binding_sha256 <- vapply(seq_along(ids), function(index) {
    wlv_runtime_snapshot_binding_sha256(
      ids[[index]],
      artifact_sha256[[index]],
      states[[index]],
      provenance[[index]]
    )
  }, character(1L))
  data.frame(
    id = ids,
    artifact_sha256 = artifact_sha256,
    binding_sha256 = unname(binding_sha256),
    stringsAsFactors = FALSE
  )
}

wlv_runtime_snapshot_create <- function(
    store,
    method,
    source,
    partitions,
    io_artifacts,
    panel_artifacts,
    compatibility) {
  method <- wlv_runtime_snapshot_scalar(method, "method")
  source <- wlv_runtime_snapshot_scalar(source, "source")
  wlv_runtime_compatibility_assert(compatibility)
  if (!identical(compatibility$method, method) ||
      !identical(compatibility$source, source)) {
    stop("Runtime snapshot compatibility identity differs from the run.",
      call. = FALSE
    )
  }
  if (
    !is.character(partitions) || !length(partitions) || anyNA(partitions) ||
      any(!nzchar(partitions)) || anyDuplicated(partitions)
  ) {
    stop("Runtime snapshot requires unique IO partitions.", call. = FALSE)
  }
  partitions <- sort(partitions, method = "radix")
  if (
    !is.character(io_artifacts) || is.null(names(io_artifacts)) ||
      !setequal(names(io_artifacts), partitions) || anyNA(io_artifacts) ||
      anyDuplicated(names(io_artifacts)) || any(!file.exists(io_artifacts)) ||
      any(file.info(io_artifacts)$isdir) ||
      any(!file.exists(paste0(io_artifacts, ".meta"))) ||
      any(file.info(paste0(io_artifacts, ".meta"))$isdir)
  ) {
    stop("Runtime snapshot requires one existing IO artifact per partition.", call. = FALSE)
  }
  io_artifacts <- io_artifacts[partitions]
  artifact_rows <- data.frame(
    partition = partitions,
    path = basename(io_artifacts),
    sha256 = unname(vapply(
      io_artifacts,
      wlv_publication_file_sha256,
      character(1L)
    )),
    meta_sha256 = unname(vapply(
      paste0(io_artifacts, ".meta"),
      wlv_publication_file_sha256,
      character(1L)
    )),
    stringsAsFactors = FALSE
  )
  if (anyDuplicated(artifact_rows$path)) {
    stop("Runtime snapshot IO artifact names are not unique.", call. = FALSE)
  }
  resources <- list()
  for (partition in partitions) {
    for (resource in wlv_runtime_snapshot_io_resources()) {
      entry <- wlv_runtime_snapshot_entry(
        store,
        paste0("io/", resource),
        partition,
        include_value = FALSE
      )
      id <- paste(entry$key, partition, sep = "\034")
      resources[[id]] <- entry
    }
    entry <- wlv_runtime_snapshot_entry(
      store,
      "intermediate/lambda",
      partition,
      include_value = TRUE
    )
    id <- paste(entry$key, partition, sep = "\034")
    resources[[id]] <- entry
  }
  snapshot <- list(
    version = wlv_runtime_snapshot_version(),
    method = method,
    source = source,
    partitions = partitions,
    compatibility = compatibility,
    io_artifacts = artifact_rows,
    panel_artifacts = wlv_runtime_snapshot_artifact_inventory(
      panel_artifacts,
      names(wlv_runtime_snapshot_panel_definitions()),
      "panel"
    ),
    panel_states = wlv_runtime_snapshot_panel_states(store),
    panel_provenance = wlv_runtime_snapshot_panel_provenance(store),
    parent_imports = wlv_parent_seed_empty_resolutions(),
    parent_imports_sha256 = wlv_runtime_snapshot_parent_imports_sha256(
      wlv_parent_seed_empty_resolutions()
    ),
    resources = resources,
    state_bindings = NULL
  )
  snapshot$state_bindings <- wlv_runtime_snapshot_state_bindings(snapshot)
  wlv_runtime_snapshot_validate(snapshot)
  wlv_runtime_snapshot_validate_bound_artifacts(
    snapshot,
    wlv_runtime_snapshot_artifact_root(c(io_artifacts, panel_artifacts)),
    read_fst_array,
    validate_io = TRUE
  )
  snapshot
}

wlv_runtime_snapshot_update_panel <- function(
    snapshot,
    store,
    panel_artifacts,
    parent_imports,
    compatibility) {
  wlv_runtime_snapshot_validate(snapshot)
  wlv_parent_seed_resolutions_assert(parent_imports)
  wlv_runtime_snapshot_assert_compatible(snapshot, compatibility)
  snapshot$panel_states <- wlv_runtime_snapshot_panel_states(store)
  snapshot$panel_provenance <- wlv_runtime_snapshot_panel_provenance_update(
    snapshot,
    store,
    parent_imports
  )
  snapshot$parent_imports <- parent_imports
  snapshot$parent_imports_sha256 <-
    wlv_runtime_snapshot_parent_imports_sha256(parent_imports)
  snapshot$panel_artifacts <- wlv_runtime_snapshot_artifact_inventory(
    panel_artifacts,
    names(wlv_runtime_snapshot_panel_definitions()),
    "panel"
  )
  snapshot$state_bindings <- wlv_runtime_snapshot_state_bindings(snapshot)
  wlv_runtime_snapshot_validate(snapshot)
  wlv_runtime_snapshot_validate_bound_artifacts(
    snapshot,
    wlv_runtime_snapshot_artifact_root(panel_artifacts),
    read_fst_array,
    validate_io = FALSE
  )
  snapshot
}

wlv_runtime_snapshot_indicator_state_validated <- function(
    snapshot,
    artifact,
    indicator,
    value) {
  definitions <- wlv_runtime_snapshot_panel_definitions()
  definition <- definitions[[artifact]]
  if (is.null(definition)) {
    stop(sprintf("Unknown panel-state artifact `%s`.", artifact), call. = FALSE)
  }
  indicator <- wlv_runtime_snapshot_scalar(indicator, "indicator")
  state <- wlv_runtime_snapshot_panel_state_slice(
    snapshot$panel_states[[artifact]],
    artifact,
    indicator,
    value
  )
  provenance <- snapshot$panel_provenance[
    snapshot$panel_provenance$artifact == artifact &
      snapshot$panel_provenance$indicator == indicator,
    ,
    drop = FALSE
  ]
  if (nrow(provenance) != 1L || !identical(
    provenance$state_sha256[[1L]],
    wlv_runtime_snapshot_value_sha256(state)
  )) {
    stop(
      sprintf("Runtime snapshot state provenance differs for `%s/%s`.",
        artifact,
        indicator
      ),
      call. = FALSE
    )
  }
  state
}

wlv_runtime_snapshot_indicator_state <- function(
    snapshot,
    artifact,
    indicator,
    value) {
  wlv_runtime_snapshot_validate(snapshot)
  wlv_runtime_snapshot_indicator_state_validated(
    snapshot,
    artifact,
    indicator,
    value
  )
}

wlv_runtime_snapshot_indicator_provenance_validated <- function(
    snapshot,
    artifact,
    indicator,
    value,
    contract) {
  artifact <- wlv_runtime_snapshot_scalar(artifact, "artifact")
  indicator <- wlv_runtime_snapshot_scalar(indicator, "indicator")
  wlv_resource_contract_assert(contract)
  rows <- snapshot$panel_provenance[
    snapshot$panel_provenance$artifact == artifact &
      snapshot$panel_provenance$indicator == indicator,
    ,
    drop = FALSE
  ]
  if (nrow(rows) != 1L) {
    stop(
      sprintf(
        "Runtime snapshot lacks unique provenance for `%s/%s`.",
        artifact,
        indicator
      ),
      call. = FALSE
    )
  }
  if (!identical(
    rows$contract_sha256[[1L]],
    wlv_runtime_snapshot_contract_sha256(contract)
  ) || !identical(
    rows$axes_sha256[[1L]],
    wlv_runtime_snapshot_axes_sha256(value, contract$axes)
  ) || !identical(
    rows$value_sha256[[1L]],
    wlv_runtime_snapshot_value_sha256(value)
  )) {
    stop(
      sprintf(
        "Runtime snapshot provenance for `%s/%s` has an incompatible contract or axes.",
        artifact,
        indicator
      ),
      call. = FALSE
    )
  }
  rows
}

wlv_runtime_snapshot_indicator_provenance <- function(
    snapshot,
    artifact,
    indicator,
    value,
    contract) {
  wlv_runtime_snapshot_validate(snapshot)
  wlv_runtime_snapshot_indicator_provenance_validated(
    snapshot,
    artifact,
    indicator,
    value,
    contract
  )
}

wlv_runtime_snapshot_resource_validated <- function(snapshot, key, partition) {
  key <- wlv_runtime_snapshot_scalar(key, "key")
  partition <- wlv_runtime_snapshot_scalar(partition, "partition")
  id <- paste(key, partition, sep = "\034")
  value <- snapshot$resources[[id]]
  if (is.null(value)) {
    stop(
      sprintf("Runtime snapshot lacks `%s[%s]`.", key, partition),
      call. = FALSE
    )
  }
  value
}

wlv_runtime_snapshot_resource <- function(snapshot, key, partition) {
  wlv_runtime_snapshot_validate(snapshot)
  wlv_runtime_snapshot_resource_validated(snapshot, key, partition)
}

wlv_runtime_snapshot_read_bound_array <- function(
    root,
    filename,
    sha256,
    meta_sha256,
    reader) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  if (!is.character(filename) || length(filename) != 1L || is.na(filename) ||
      !nzchar(filename) || !identical(basename(filename), filename)) {
    stop("Runtime snapshot artifact filename is invalid.", call. = FALSE)
  }
  path <- file.path(root, filename)
  metadata_path <- paste0(path, ".meta")
  if (
    !file.exists(path) || isTRUE(file.info(path)$isdir) ||
      !file.exists(metadata_path) || isTRUE(file.info(metadata_path)$isdir)
  ) {
    stop(
      sprintf("Runtime snapshot lacks bound artifact `%s`.", filename),
      call. = FALSE
    )
  }
  before <- c(
    sha256 = wlv_publication_file_sha256(path),
    meta_sha256 = wlv_publication_file_sha256(metadata_path)
  )
  expected <- c(sha256 = sha256, meta_sha256 = meta_sha256)
  if (!identical(before, expected)) {
    stop(
      sprintf("Runtime snapshot artifact `%s` failed provenance verification.", filename),
      call. = FALSE
    )
  }
  value <- reader(path)
  after <- c(
    sha256 = wlv_publication_file_sha256(path),
    meta_sha256 = wlv_publication_file_sha256(metadata_path)
  )
  if (!identical(after, expected)) {
    stop(
      sprintf("Runtime snapshot artifact `%s` changed while it was read.", filename),
      call. = FALSE
    )
  }
  if (!is.numeric(value) || is.null(dim(value)) || is.null(dimnames(value))) {
    stop(
      sprintf("Runtime snapshot artifact `%s` is not a numeric array.", filename),
      call. = FALSE
    )
  }
  value
}

wlv_runtime_snapshot_read_bound_slices <- function(
    root,
    filename,
    sha256,
    meta_sha256,
    axes,
    selectors,
    max_chunk_values = 2^23,
    materialize = TRUE) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  if (!is.character(filename) || length(filename) != 1L || is.na(filename) ||
      !nzchar(filename) || !identical(basename(filename), filename)) {
    stop("Runtime snapshot artifact filename is invalid.", call. = FALSE)
  }
  path <- file.path(root, filename)
  metadata_path <- paste0(path, ".meta")
  if (
    !file.exists(path) || isTRUE(file.info(path)$isdir) ||
      !file.exists(metadata_path) || isTRUE(file.info(metadata_path)$isdir)
  ) {
    stop(
      sprintf("Runtime snapshot lacks bound artifact `%s`.", filename),
      call. = FALSE
    )
  }
  if (!is.character(axes) || length(axes) < 3L || anyNA(axes) ||
      any(!nzchar(axes)) || anyDuplicated(axes) ||
      !is.character(selectors) || anyNA(selectors) ||
      anyDuplicated(selectors) ||
      !is.numeric(max_chunk_values) || length(max_chunk_values) != 1L ||
      is.na(max_chunk_values) || !is.finite(max_chunk_values) ||
      max_chunk_values < 1 || !is.logical(materialize) ||
      length(materialize) != 1L || is.na(materialize)) {
    stop("Runtime snapshot slice request is invalid.", call. = FALSE)
  }
  expected <- c(sha256 = sha256, meta_sha256 = meta_sha256)
  before <- c(
    sha256 = wlv_publication_file_sha256(path),
    meta_sha256 = wlv_publication_file_sha256(metadata_path)
  )
  if (!identical(before, expected)) {
    stop(
      sprintf("Runtime snapshot artifact `%s` failed provenance verification.", filename),
      call. = FALSE
    )
  }
  metadata <- tryCatch(
    readRDS(metadata_path),
    error = function(error) {
      stop(
        sprintf(
          "Cannot read runtime snapshot metadata `%s`: %s",
          filename,
          conditionMessage(error)
        ),
        call. = FALSE
      )
    }
  )
  contract <- wlv_fst_parse_sidecar(metadata, path)
  if (isTRUE(contract$legacy) ||
      !identical(contract$fst_sha256, sha256) ||
      length(contract$dimensions) != length(axes) ||
      is.null(contract$dimnames) ||
      any(vapply(contract$dimnames, is.null, logical(1L)))) {
    stop(
      sprintf("Runtime snapshot artifact `%s` has an invalid sidecar contract.", filename),
      call. = FALSE
    )
  }
  observed_axis_names <- names(contract$dimnames)
  if (!is.null(observed_axis_names) &&
      !identical(observed_axis_names, axes)) {
    stop(
      sprintf("Runtime snapshot artifact `%s` axes are incompatible.", filename),
      call. = FALSE
    )
  }
  labels <- contract$dimnames
  names(labels) <- axes
  selector_labels <- labels[[2L]]
  selector_indices <- match(selectors, selector_labels)
  if (anyNA(selector_indices)) {
    stop(
      sprintf("Runtime snapshot artifact `%s` lacks requested slices.", filename),
      call. = FALSE
    )
  }
  slice_dimensions <- contract$dimensions[-2L]
  slice_labels <- labels[-2L]
  values <- if (isTRUE(materialize)) {
    lapply(selectors, function(selector) {
      array(
        0,
        dim = slice_dimensions,
        dimnames = slice_labels
      )
    })
  } else {
    rep(list(NULL), length(selectors))
  }
  names(values) <- selectors
  hash_buffers <- rep(list(numeric()), length(selectors))
  chunk_hashes <- rep(list(character()), length(selectors))
  hash_chunk_values <- as.integer(wlv_runtime_snapshot_hash_chunk_values())
  if (length(selectors)) {
    prefix_size <- prod(as.double(contract$dimensions[seq_len(2L)]))
    tail_size <- prod(as.double(contract$dimensions[-seq_len(2L)]))
    if (!is.finite(prefix_size) || !is.finite(tail_size) ||
        prefix_size < 1 || tail_size < 1 ||
        prefix_size * tail_size > .Machine$integer.max) {
      stop(
        sprintf("Runtime snapshot artifact `%s` is too large to stream safely.", filename),
        call. = FALSE
      )
    }
    blocks_per_chunk <- max(
      1L,
      as.integer(floor(max_chunk_values / prefix_size))
    )
    block_start <- 1L
    while (block_start <= tail_size) {
      block_end <- min(tail_size, block_start + blocks_per_chunk - 1L)
      from <- as.integer((block_start - 1) * prefix_size + 1)
      to <- as.integer(block_end * prefix_size)
      table <- tryCatch(
        fst::read_fst(path, columns = "Data", from = from, to = to),
        error = function(error) {
          stop(
            sprintf(
              "Cannot stream runtime snapshot artifact `%s`: %s",
              filename,
              conditionMessage(error)
            ),
            call. = FALSE
          )
        }
      )
      expected_rows <- to - from + 1L
      if (!is.data.frame(table) || !identical(names(table), "Data") ||
          nrow(table) != expected_rows || !is.numeric(table[[1L]])) {
        stop(
          sprintf("Runtime snapshot artifact `%s` has invalid streamed data.", filename),
          call. = FALSE
        )
      }
      chunk <- table[[1L]]
      dim(chunk) <- c(
        contract$dimensions[[1L]],
        contract$dimensions[[2L]],
        block_end - block_start + 1L
      )
      target_positions <- seq.int(
        from = as.integer((block_start - 1L) * contract$dimensions[[1L]] + 1L),
        to = as.integer(block_end * contract$dimensions[[1L]])
      )
      for (selector_index in seq_along(selectors)) {
        selected <- chunk[, selector_indices[[selector_index]], , drop = FALSE]
        selected <- as.numeric(selected)
        attributes(selected) <- NULL
        if (isTRUE(materialize)) {
          values[[selector_index]][target_positions] <- selected
        }
        buffer <- c(hash_buffers[[selector_index]], selected)
        while (length(buffer) >= hash_chunk_values) {
          current <- buffer[seq_len(hash_chunk_values)]
          attributes(current) <- NULL
          chunk_hashes[[selector_index]] <- c(
            chunk_hashes[[selector_index]],
            wlv_runtime_snapshot_numeric_chunk_sha256(current)
          )
          if (length(buffer) == hash_chunk_values) {
            buffer <- numeric()
          } else {
            buffer <- buffer[-seq_len(hash_chunk_values)]
          }
        }
        hash_buffers[[selector_index]] <- buffer
      }
      rm(table, chunk)
      block_start <- block_end + 1L
    }
  }
  after <- c(
    sha256 = wlv_publication_file_sha256(path),
    meta_sha256 = wlv_publication_file_sha256(metadata_path)
  )
  if (!identical(after, expected)) {
    stop(
      sprintf("Runtime snapshot artifact `%s` changed while it was read.", filename),
      call. = FALSE
    )
  }
  for (selector_index in seq_along(selectors)) {
    if (length(hash_buffers[[selector_index]])) {
      current <- hash_buffers[[selector_index]]
      attributes(current) <- NULL
      chunk_hashes[[selector_index]] <- c(
        chunk_hashes[[selector_index]],
        wlv_runtime_snapshot_numeric_chunk_sha256(current)
      )
    }
  }
  value_sha256 <- vapply(seq_along(selectors), function(selector_index) {
    wlv_runtime_snapshot_array_sha256_from_chunks(
      slice_dimensions,
      slice_labels,
      chunk_hashes[[selector_index]]
    )
  }, character(1L))
  names(value_sha256) <- selectors
  list(
    values = values,
    dimnames = labels,
    value_sha256 = value_sha256
  )
}

wlv_runtime_snapshot_io_slices <- function(
    snapshot,
    root,
    partition,
    resources,
    materialize = TRUE) {
  row <- match(partition, snapshot$io_artifacts$partition)
  if (is.na(row)) {
    stop(sprintf("Unknown runtime IO partition `%s`.", partition), call. = FALSE)
  }
  wlv_runtime_snapshot_read_bound_slices(
    root = root,
    filename = snapshot$io_artifacts$path[[row]],
    sha256 = snapshot$io_artifacts$sha256[[row]],
    meta_sha256 = snapshot$io_artifacts$meta_sha256[[row]],
    axes = c("year", "variable", "input", "output"),
    selectors = resources,
    materialize = materialize
  )
}

wlv_runtime_snapshot_panel_array <- function(
    snapshot,
    root,
    artifact,
    reader = read_fst_array) {
  definitions <- wlv_runtime_snapshot_panel_definitions()
  definition <- definitions[[artifact]]
  row <- match(artifact, snapshot$panel_artifacts$id)
  if (is.null(definition) || is.na(row)) {
    stop(sprintf("Unknown runtime panel artifact `%s`.", artifact), call. = FALSE)
  }
  value <- wlv_runtime_snapshot_read_bound_array(
    root,
    snapshot$panel_artifacts$path[[row]],
    snapshot$panel_artifacts$sha256[[row]],
    snapshot$panel_artifacts$meta_sha256[[row]],
    reader
  )
  wlv_runtime_snapshot_restore_axes(value, definition$axes, artifact)
}

wlv_runtime_snapshot_io_array <- function(
    snapshot,
    root,
    partition,
    reader = read_fst_array) {
  row <- match(partition, snapshot$io_artifacts$partition)
  if (is.na(row)) {
    stop(sprintf("Unknown runtime IO partition `%s`.", partition), call. = FALSE)
  }
  value <- wlv_runtime_snapshot_read_bound_array(
    root,
    snapshot$io_artifacts$path[[row]],
    snapshot$io_artifacts$sha256[[row]],
    snapshot$io_artifacts$meta_sha256[[row]],
    reader
  )
  wlv_runtime_snapshot_restore_axes(
    value,
    c("year", "variable", "input", "output"),
    paste0("IO/", partition)
  )
}

wlv_runtime_snapshot_restore_axes <- function(value, axes, label) {
  observed <- names(dimnames(value))
  if (
    length(dim(value)) != length(axes) ||
      (!is.null(observed) && !identical(observed, axes))
  ) {
    stop(
      sprintf("Runtime snapshot artifact `%s` axes are incompatible.", label),
      call. = FALSE
    )
  }
  labels <- dimnames(value)
  names(labels) <- axes
  dimnames(value) <- labels
  value
}

wlv_runtime_snapshot_io_slice <- function(value, resource) {
  axes <- c("year", "variable", "input", "output")
  value <- wlv_runtime_snapshot_restore_axes(value, axes, "IO")
  variables <- dimnames(value)$variable
  if (!identical(variables, wlv_runtime_snapshot_io_resources())) {
    stop(
      "Runtime snapshot IO artifact variables are not canonical.",
      call. = FALSE
    )
  }
  index <- match(resource, variables)
  selected <- value[, index, , , drop = FALSE]
  array(
    as.numeric(selected),
    dim = dim(selected)[c(1L, 3L, 4L)],
    dimnames = dimnames(selected)[c(1L, 3L, 4L)]
  )
}

wlv_runtime_snapshot_validate_bound_artifacts <- function(
    snapshot,
    root,
    reader,
    validate_io = TRUE) {
  if (!is.function(reader)) {
    stop("Runtime snapshot artifact reader must be a function.", call. = FALSE)
  }
  if (!is.logical(validate_io) || length(validate_io) != 1L ||
      is.na(validate_io)) {
    stop("Runtime snapshot IO validation flag is invalid.", call. = FALSE)
  }
  definitions <- wlv_runtime_snapshot_panel_definitions()
  for (name in names(definitions)) {
    definition <- definitions[[name]]
    value <- wlv_runtime_snapshot_panel_array(snapshot, root, name, reader)
    contract <- wlv_native_artifact_array_contract(name, definition$axes)
    wlv_runtime_validate_resource_value(value, contract, name)
    wlv_semantic_state_validate(
      snapshot$panel_states[[name]],
      value = value,
      target_key = definition$target_key,
      axes = definition$axes,
      state_key = wlv_semantic_state_key(definition$target_key)
    )
    indicators <- dimnames(value)[[match("indicator", definition$axes)]]
    provenance <- snapshot$panel_provenance[
      snapshot$panel_provenance$artifact == name,
      ,
      drop = FALSE
    ]
    if (!identical(as.character(provenance$indicator), indicators)) {
      stop(
        sprintf("Runtime snapshot panel provenance differs for `%s`.", name),
        call. = FALSE
      )
    }
    target_axes <- setdiff(definition$axes, "indicator")
    target_labels <- dimnames(value)[target_axes]
    expected_axes_sha256 <- wlv_runtime_snapshot_axis_labels_sha256(
      target_labels,
      target_axes
    )
    if (any(provenance$axes_sha256 != expected_axes_sha256)) {
      stop(
        sprintf(
          "Runtime snapshot panel axes provenance differs for `%s`.",
          name
        ),
        call. = FALSE
      )
    }
    for (indicator in indicators) {
      row <- provenance[provenance$indicator == indicator, , drop = FALSE]
      selected <- wlv_runtime_snapshot_panel_value_slice(
        value,
        name,
        indicator
      )
      state <- wlv_runtime_snapshot_panel_state_slice(
        snapshot$panel_states[[name]],
        name,
        indicator,
        selected
      )
      if (nrow(row) != 1L || !identical(
        row$value_sha256[[1L]],
        wlv_runtime_snapshot_value_sha256(selected)
      ) || !identical(
        row$state_sha256[[1L]],
        wlv_runtime_snapshot_value_sha256(state)
      )) {
        stop(
          sprintf(
            "Runtime snapshot panel generation differs for `%s/%s`.",
            name,
            indicator
          ),
          call. = FALSE
        )
      }
    }
  }
  if (!isTRUE(validate_io)) {
    return(invisible(snapshot))
  }
  for (index in seq_len(nrow(snapshot$io_artifacts))) {
    artifact <- snapshot$io_artifacts[index, , drop = FALSE]
    streamed <- wlv_runtime_snapshot_io_slices(
      snapshot,
      root,
      artifact$partition[[1L]],
      wlv_runtime_snapshot_io_resources(),
      materialize = FALSE
    )
    if (!identical(
      streamed$dimnames$variable,
      wlv_runtime_snapshot_io_resources()
    )) {
      stop(
        sprintf(
          "Runtime snapshot IO resources differ for `%s`.",
          artifact$partition[[1L]]
        ),
        call. = FALSE
      )
    }
    slice_labels <- streamed$dimnames[c("year", "input", "output")]
    slice_axes_sha256 <- wlv_runtime_snapshot_axis_labels_sha256(
      slice_labels,
      c("year", "input", "output")
    )
    for (resource in wlv_runtime_snapshot_io_resources()) {
      key <- paste0("io/", resource)
      entry <- snapshot$resources[[paste(key, artifact$partition[[1L]], sep = "\034")]]
      contract <- wlv_runtime_snapshot_contract(key)
      if (!identical(entry$contract_sha256,
        wlv_runtime_snapshot_contract_sha256(contract)
      ) || !identical(entry$axes_sha256, slice_axes_sha256) ||
          !identical(entry$value_sha256, streamed$value_sha256[[resource]])) {
        stop(
          sprintf(
            "Runtime snapshot IO generation differs for `%s[%s]`.",
            key,
            artifact$partition[[1L]]
          ),
          call. = FALSE
        )
      }
      wlv_semantic_state_validate(
        entry$state,
        target_key = key,
        axes = contract$axes,
        state_key = wlv_semantic_state_key(key)
      )
    }
    lambda <- wlv_runtime_snapshot_resource_validated(
      snapshot,
      "intermediate/lambda",
      artifact$partition[[1L]]
    )
    if (!identical(dimnames(lambda$value)$year, streamed$dimnames$year) ||
        !identical(dimnames(lambda$value)$input, streamed$dimnames$input)) {
      stop(
        sprintf(
          "Runtime snapshot lambda axes differ for `%s`.",
          artifact$partition[[1L]]
        ),
        call. = FALSE
      )
    }
  }
  invisible(snapshot)
}

wlv_runtime_snapshot_validate <- function(
    snapshot,
    root = NULL,
    method = NULL,
    source = NULL,
    partitions = NULL,
    reader = NULL) {
  if (
    !is.list(snapshot) || !identical(
      names(snapshot),
      c(
        "version", "method", "source", "partitions", "compatibility",
        "io_artifacts",
        "panel_artifacts", "panel_states", "panel_provenance",
        "parent_imports", "parent_imports_sha256", "resources",
        "state_bindings"
      )
    ) || !identical(snapshot$version, wlv_runtime_snapshot_version())
  ) {
    stop("Runtime-resource snapshot has an invalid envelope.", call. = FALSE)
  }
  wlv_runtime_snapshot_scalar(snapshot$method, "snapshot method")
  wlv_runtime_snapshot_scalar(snapshot$source, "snapshot source")
  wlv_runtime_compatibility_assert(snapshot$compatibility)
  if (!identical(snapshot$compatibility$method, snapshot$method) ||
      !identical(snapshot$compatibility$source, snapshot$source)) {
    stop("Runtime-resource snapshot compatibility identity is invalid.",
      call. = FALSE
    )
  }
  observed_partitions <- snapshot$partitions
  if (
    !is.character(observed_partitions) || !length(observed_partitions) ||
      anyNA(observed_partitions) || any(!nzchar(observed_partitions)) ||
      anyDuplicated(observed_partitions) ||
      !identical(observed_partitions, sort(observed_partitions, method = "radix"))
  ) {
    stop("Runtime-resource snapshot partitions are not canonical.", call. = FALSE)
  }
  if (!is.null(method) && !identical(snapshot$method, method)) {
    stop("Runtime-resource snapshot method does not match the parent run.", call. = FALSE)
  }
  if (!is.null(source) && !identical(snapshot$source, source)) {
    stop("Runtime-resource snapshot source does not match the parent run.", call. = FALSE)
  }
  if (!is.null(partitions) && !identical(
    observed_partitions,
    sort(as.character(partitions), method = "radix")
  )) {
    stop("Runtime-resource snapshot partition coverage differs.", call. = FALSE)
  }
  artifacts <- snapshot$io_artifacts
  if (
    !is.data.frame(artifacts) || !identical(
      names(artifacts),
      c("partition", "path", "sha256", "meta_sha256")
    ) || !identical(as.character(artifacts$partition), observed_partitions) ||
      anyNA(artifacts) || any(!nzchar(as.matrix(artifacts))) ||
      anyDuplicated(artifacts$path) ||
      any(basename(artifacts$path) != artifacts$path) ||
      any(!grepl("^[0-9a-f]{64}$", artifacts$sha256)) ||
      any(!grepl("^[0-9a-f]{64}$", artifacts$meta_sha256))
  ) {
    stop("Runtime-resource snapshot IO inventory is invalid.", call. = FALSE)
  }
  definitions <- wlv_runtime_snapshot_panel_definitions()
  panel_artifacts <- snapshot$panel_artifacts
  if (
    !is.data.frame(panel_artifacts) || !identical(
      names(panel_artifacts),
      c("id", "path", "sha256", "meta_sha256")
    ) || !identical(as.character(panel_artifacts$id), names(definitions)) ||
      anyNA(panel_artifacts) || any(!nzchar(as.matrix(panel_artifacts))) ||
      anyDuplicated(panel_artifacts$path) ||
      any(basename(panel_artifacts$path) != panel_artifacts$path) ||
      any(!grepl("^[0-9a-f]{64}$", panel_artifacts$sha256)) ||
      any(!grepl("^[0-9a-f]{64}$", panel_artifacts$meta_sha256))
  ) {
    stop("Runtime-resource snapshot panel inventory is invalid.", call. = FALSE)
  }
  panel_states <- snapshot$panel_states
  if (
    !is.list(panel_states) ||
      !identical(names(panel_states), names(definitions))
  ) {
    stop("Runtime-resource snapshot panel-state coverage is incomplete.",
      call. = FALSE
    )
  }
  for (name in names(definitions)) {
    definition <- definitions[[name]]
    wlv_semantic_state_validate(
      panel_states[[name]],
      target_key = definition$target_key,
      axes = definition$axes,
      state_key = wlv_semantic_state_key(definition$target_key)
    )
  }
  panel_provenance <- snapshot$panel_provenance
  provenance_columns <- c(
    "artifact", "indicator", "key", "producer", "state_producer",
    "contract_sha256", "axes_sha256", "value_sha256", "state_sha256"
  )
  if (
    !is.data.frame(panel_provenance) ||
      !identical(names(panel_provenance), provenance_columns) ||
      !nrow(panel_provenance) || anyNA(panel_provenance) ||
      any(!nzchar(as.matrix(panel_provenance))) ||
      any(!panel_provenance$artifact %in% names(definitions)) ||
      any(panel_provenance$producer != panel_provenance$state_producer) ||
      any(panel_provenance$producer == wlv_runtime_seed_producer()) ||
      anyDuplicated(paste(
        panel_provenance$artifact,
        panel_provenance$indicator,
        sep = "\034"
      )) || anyDuplicated(panel_provenance$key) ||
      any(!grepl("^[0-9a-f]{64}$", panel_provenance$contract_sha256)) ||
      any(!grepl("^[0-9a-f]{64}$", panel_provenance$axes_sha256)) ||
      any(!grepl("^[0-9a-f]{64}$", panel_provenance$value_sha256)) ||
      any(!grepl("^[0-9a-f]{64}$", panel_provenance$state_sha256))
  ) {
    stop("Runtime-resource snapshot panel provenance is invalid.",
      call. = FALSE
    )
  }
  observed_artifact_order <- unique(as.character(panel_provenance$artifact))
  if (!identical(observed_artifact_order, names(definitions))) {
    stop("Runtime-resource snapshot panel provenance is not canonical.",
      call. = FALSE
    )
  }
  for (index in seq_len(nrow(panel_provenance))) {
    row <- panel_provenance[index, , drop = FALSE]
    level <- if (identical(row$artifact[[1L]], "sea_sectors")) {
      "sector"
    } else {
      "country"
    }
    expected_key <- wlv_native_indicator_key(row$indicator[[1L]], level)
    expected_contract <- wlv_native_indicator_contract(
      row$indicator[[1L]],
      level = level
    )
    if (!identical(row$key[[1L]], expected_key) || !identical(
      row$contract_sha256[[1L]],
      wlv_runtime_snapshot_contract_sha256(expected_contract)
    )) {
      stop("Runtime-resource snapshot panel contract provenance is invalid.",
        call. = FALSE
      )
    }
  }
  wlv_parent_seed_resolutions_assert(snapshot$parent_imports)
  if (!is.character(snapshot$parent_imports_sha256) ||
      length(snapshot$parent_imports_sha256) != 1L ||
      is.na(snapshot$parent_imports_sha256) ||
      !identical(
        snapshot$parent_imports_sha256,
        wlv_runtime_snapshot_parent_imports_sha256(snapshot$parent_imports)
      )) {
    stop("Runtime-resource snapshot parent imports are not authenticated.",
      call. = FALSE
    )
  }
  expected_keys <- unlist(lapply(observed_partitions, function(partition) {
    paste(
      c(
        paste0("io/", wlv_runtime_snapshot_io_resources()),
        "intermediate/lambda"
      ),
      partition,
      sep = "\034"
    )
  }), use.names = FALSE)
  resources <- snapshot$resources
  if (
    !is.list(resources) || is.null(names(resources)) ||
      !identical(names(resources), expected_keys)
  ) {
    stop("Runtime-resource snapshot coverage is incomplete.", call. = FALSE)
  }
  for (id in expected_keys) {
    entry <- resources[[id]]
    if (
      !is.list(entry) || !identical(
        names(entry),
        c(
          "key", "partition", "producer", "state_producer",
          "contract_sha256", "axes_sha256", "value_sha256", "state_sha256",
          "value", "state"
        )
      ) || !identical(id, paste(entry$key, entry$partition, sep = "\034")) ||
        !is.character(entry$producer) || length(entry$producer) != 1L ||
        is.na(entry$producer) || !nzchar(entry$producer) ||
        !is.character(entry$state_producer) ||
        length(entry$state_producer) != 1L || is.na(entry$state_producer) ||
        !nzchar(entry$state_producer) ||
        !identical(entry$producer, entry$state_producer) ||
        identical(entry$producer, wlv_runtime_seed_producer()) ||
        anyNA(unlist(entry[c(
          "contract_sha256", "axes_sha256", "value_sha256", "state_sha256"
        )], use.names = FALSE)) ||
        any(!grepl(
          "^[0-9a-f]{64}$",
          unlist(entry[c(
            "contract_sha256", "axes_sha256", "value_sha256", "state_sha256"
          )], use.names = FALSE)
        ))
    ) {
      stop(sprintf("Runtime-resource entry `%s` is invalid.", id), call. = FALSE)
    }
    contract <- wlv_runtime_snapshot_contract(entry$key)
    if (!identical(
      entry$contract_sha256,
      wlv_runtime_snapshot_contract_sha256(contract)
    ) || !identical(
      entry$state_sha256,
      wlv_runtime_snapshot_value_sha256(entry$state)
    )) {
      stop(sprintf("Runtime-resource entry `%s` provenance is invalid.", id),
        call. = FALSE
      )
    }
    if (identical(entry$key, "intermediate/lambda")) {
      wlv_runtime_validate_resource_value(entry$value, contract, entry$key)
      if (!identical(
        entry$axes_sha256,
        wlv_runtime_snapshot_axes_sha256(entry$value, contract$axes)
      ) || !identical(
        entry$value_sha256,
        wlv_runtime_snapshot_value_sha256(entry$value)
      )) {
        stop(sprintf("Runtime-resource entry `%s` value provenance is invalid.", id),
          call. = FALSE
        )
      }
      wlv_semantic_state_validate(
        entry$state,
        value = entry$value,
        target_key = entry$key,
        axes = contract$axes,
        state_key = wlv_semantic_state_key(entry$key)
      )
    } else {
      if (!is.null(entry$value)) {
        stop("IO snapshot entries must not duplicate public matrix values.", call. = FALSE)
      }
      wlv_semantic_state_validate(
        entry$state,
        target_key = entry$key,
        axes = contract$axes,
        state_key = wlv_semantic_state_key(entry$key)
      )
    }
  }
  expected_bindings <- wlv_runtime_snapshot_state_bindings(snapshot)
  bindings <- snapshot$state_bindings
  if (
    !is.data.frame(bindings) || !identical(
      names(bindings),
      c("id", "artifact_sha256", "binding_sha256")
    ) || anyNA(bindings) || any(!nzchar(as.matrix(bindings))) ||
      anyDuplicated(bindings$id) ||
      any(!grepl("^[0-9a-f]{64}$", bindings$artifact_sha256)) ||
      any(!grepl("^[0-9a-f]{64}$", bindings$binding_sha256)) ||
      !identical(bindings, expected_bindings)
  ) {
    stop("Runtime-resource snapshot state bindings are invalid.", call. = FALSE)
  }
  if (!is.null(root)) {
    root <- normalizePath(root, winslash = "/", mustWork = TRUE)
    if (is.null(reader)) {
      reader <- read_fst_array
    }
    wlv_runtime_snapshot_validate_bound_artifacts(snapshot, root, reader)
  }
  invisible(snapshot)
}

wlv_runtime_snapshot_authenticate_bound_files <- function(snapshot, root) {
  wlv_runtime_snapshot_validate(snapshot)
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  records <- rbind(
    data.frame(
      path = snapshot$panel_artifacts$path,
      sha256 = snapshot$panel_artifacts$sha256,
      meta_sha256 = snapshot$panel_artifacts$meta_sha256,
      stringsAsFactors = FALSE
    ),
    data.frame(
      path = snapshot$io_artifacts$path,
      sha256 = snapshot$io_artifacts$sha256,
      meta_sha256 = snapshot$io_artifacts$meta_sha256,
      stringsAsFactors = FALSE
    )
  )
  if (anyDuplicated(records$path)) {
    stop("Runtime snapshot artifact paths are not unique.", call. = FALSE)
  }
  observed <- lapply(seq_len(nrow(records)), function(index) {
    data_path <- file.path(root, records$path[[index]])
    metadata_path <- paste0(data_path, ".meta")
    if (!file.exists(data_path) || isTRUE(file.info(data_path)$isdir) ||
        !file.exists(metadata_path) || isTRUE(file.info(metadata_path)$isdir)) {
      stop(
        sprintf("Runtime snapshot lacks bound artifact `%s`.",
          records$path[[index]]
        ),
        call. = FALSE
      )
    }
    actual <- c(
      sha256 = wlv_publication_file_sha256(data_path),
      meta_sha256 = wlv_publication_file_sha256(metadata_path)
    )
    expected <- c(
      sha256 = records$sha256[[index]],
      meta_sha256 = records$meta_sha256[[index]]
    )
    if (!identical(actual, expected)) {
      stop(
        sprintf("Runtime snapshot artifact `%s` failed provenance verification.",
          records$path[[index]]
        ),
        call. = FALSE
      )
    }
    actual
  })
  names(observed) <- records$path
  observed
}

wlv_runtime_snapshot_write <- function(snapshot, staging) {
  wlv_runtime_snapshot_validate(snapshot)
  staging <- normalizePath(staging, winslash = "/", mustWork = TRUE)
  path <- file.path(staging, wlv_runtime_snapshot_filename())
  saveRDS(snapshot, path, version = 3L, compress = FALSE)
  observed <- readRDS(path)
  if (!identical(observed, snapshot)) {
    stop("Runtime-resource snapshot failed its write round trip.", call. = FALSE)
  }
  wlv_runtime_snapshot_validate(observed)
  wlv_runtime_snapshot_authenticate_bound_files(observed, staging)
  invisible(path)
}

wlv_runtime_snapshot_read_envelope <- function(
    result_dir,
    method = NULL,
    source = NULL,
    partitions = NULL,
    expected_sha256 = NULL) {
  result_dir <- normalizePath(result_dir, winslash = "/", mustWork = TRUE)
  path <- file.path(result_dir, wlv_runtime_snapshot_filename())
  if (!file.exists(path) || isTRUE(file.info(path)$isdir)) {
    stop(
      sprintf("Parent run lacks `%s`.", wlv_runtime_snapshot_filename()),
      call. = FALSE
    )
  }
  if (!is.null(expected_sha256) && (
    !is.character(expected_sha256) || length(expected_sha256) != 1L ||
      is.na(expected_sha256) || !grepl("^[0-9a-f]{64}$", expected_sha256)
  )) {
    stop("Runtime snapshot expected hash is invalid.", call. = FALSE)
  }
  before <- wlv_publication_file_sha256(path)
  if (!is.null(expected_sha256) && !identical(before, expected_sha256)) {
    stop("Runtime-resource snapshot failed parent-manifest authentication.",
      call. = FALSE
    )
  }
  snapshot <- readRDS(path)
  after <- wlv_publication_file_sha256(path)
  if (!identical(after, before)) {
    stop("Runtime-resource snapshot changed while it was read.", call. = FALSE)
  }
  wlv_runtime_snapshot_validate(
    snapshot,
    method = method,
    source = source,
    partitions = partitions
  )
  snapshot
}

wlv_runtime_snapshot_read <- function(
    result_dir,
    method = NULL,
    source = NULL,
    partitions = NULL,
    reader = NULL) {
  result_dir <- normalizePath(result_dir, winslash = "/", mustWork = TRUE)
  snapshot <- wlv_runtime_snapshot_read_envelope(
    result_dir,
    method = method,
    source = source,
    partitions = partitions
  )
  wlv_runtime_snapshot_validate(
    snapshot,
    root = result_dir,
    reader = reader
  )
  snapshot
}
