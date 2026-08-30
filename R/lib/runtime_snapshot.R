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
  "wlv-runtime-resources/1.1.0"
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
  captured_state <- wlv_runtime_snapshot_state_capture(
    state_entry$value,
    target_value = value_entry$value,
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
    state_sha256 = captured_state$state_sha256,
    value = if (isTRUE(include_value)) value_entry$value else NULL,
    state = captured_state$state
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
  storage <- typeof(value)
  if (!storage %in% c("double", "integer") || is.object(value) ||
      !is.null(attributes(value))) {
    stop("A runtime snapshot numeric hash chunk is invalid.", call. = FALSE)
  }
  materialized <- switch(
    storage,
    double = double(length(value)),
    integer = integer(length(value))
  )
  if (length(value)) {
    materialized[] <- value
  }
  wlv_publication_sha256_raw(serialize(materialized, NULL, version = 3L))
}

wlv_runtime_snapshot_array_sha256_from_chunks <- function(
    dimensions,
    labels,
    chunk_sha256,
    storage = "double") {
  if (!is.numeric(dimensions) || !length(dimensions) || anyNA(dimensions) ||
      any(!is.finite(dimensions)) || any(dimensions < 0) ||
      any(dimensions != as.integer(dimensions)) || !is.list(labels) ||
      length(labels) != length(dimensions) ||
      any(vapply(labels, is.null, logical(1L))) ||
      !is.character(chunk_sha256) || anyNA(chunk_sha256) ||
      any(!grepl("^[0-9a-f]{64}$", chunk_sha256)) ||
      !is.character(storage) || length(storage) != 1L || is.na(storage) ||
      !storage %in% c("double", "integer")) {
    stop("Runtime snapshot array hash components are invalid.", call. = FALSE)
  }
  labels <- wlv_runtime_snapshot_materialize_labels(labels)
  payload <- list(
    version = "wlv-array-value/1.0.0",
    dimensions = as.integer(dimensions),
    dimnames = labels,
    storage = storage,
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
    chunk <- value[start:end]
    attributes(chunk) <- NULL
    wlv_runtime_snapshot_numeric_chunk_sha256(chunk)
  }, character(1L))
  wlv_runtime_snapshot_array_sha256_from_chunks(
    dim(value),
    dimnames(value),
    hashes,
    storage = typeof(value)
  )
}

wlv_runtime_snapshot_second_axis_slice_sha256 <- function(
    value,
    selector_index,
    labels) {
  dimensions <- dim(value)
  if (!is.numeric(value) || !is.array(value) || length(dimensions) < 2L ||
      !is.numeric(selector_index) || length(selector_index) != 1L ||
      is.na(selector_index) || selector_index < 1L ||
      selector_index > dimensions[[2L]] ||
      selector_index != as.integer(selector_index) || !is.list(labels) ||
      length(labels) != length(dimensions) - 1L ||
      any(vapply(labels, is.null, logical(1L)))) {
    stop("Runtime snapshot array-slice hash request is invalid.", call. = FALSE)
  }
  selector_index <- as.integer(selector_index)
  slice_dimensions <- dimensions[-2L]
  total <- prod(as.double(slice_dimensions))
  chunk_values <- as.integer(wlv_runtime_snapshot_hash_chunk_values())
  starts <- if (total) seq.int(1, total, by = chunk_values) else numeric()
  first_axis <- as.double(dimensions[[1L]])
  prefix <- first_axis * as.double(dimensions[[2L]])
  hashes <- vapply(starts, function(start) {
    end <- min(total, start + chunk_values - 1)
    positions <- seq.int(start, end) - 1
    indices <- (positions %/% first_axis) * prefix +
      as.double(selector_index - 1L) * first_axis +
      (positions %% first_axis) + 1
    chunk <- value[indices]
    attributes(chunk) <- NULL
    wlv_runtime_snapshot_numeric_chunk_sha256(chunk)
  }, character(1L))
  wlv_runtime_snapshot_array_sha256_from_chunks(
    slice_dimensions,
    labels,
    hashes,
    storage = typeof(value)
  )
}

wlv_runtime_snapshot_value_sha256 <- function(value) {
  if (inherits(value, "wlv_semantic_state") ||
      inherits(value, "wlv_runtime_semantic_state_codec")) {
    return(wlv_runtime_snapshot_state_sha256(value))
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

wlv_runtime_snapshot_state_codec_version <- function() {
  "wlv-runtime-semantic-state-codec/1.0.0"
}

wlv_runtime_snapshot_state_codec_fields <- function() {
  c(
    "version", "encoding", "target_key", "axes", "state_version",
    "row_count", "selectors", "state", "rows"
  )
}

wlv_runtime_snapshot_is_state_codec <- function(value) {
  inherits(value, "wlv_runtime_semantic_state_codec")
}

wlv_runtime_snapshot_state_axis_labels <- function(
    value,
    chunk_rows = 65536L) {
  if (!is.character(value) || anyNA(value) ||
      !is.numeric(chunk_rows) || length(chunk_rows) != 1L ||
      is.na(chunk_rows) || !is.finite(chunk_rows) || chunk_rows < 1L) {
    stop("Runtime state-codec axis labels are invalid.", call. = FALSE)
  }
  chunk_rows <- as.integer(chunk_rows)
  labels <- character()
  if (length(value)) {
    for (start in seq.int(1L, length(value), by = chunk_rows)) {
      end <- min(length(value), start + chunk_rows - 1L)
      labels <- unique(c(labels, enc2utf8(value[start:end])))
    }
  }
  sort(labels, method = "radix")
}

wlv_runtime_snapshot_state_uniform_value <- function(
    value,
    chunk_rows = 65536L) {
  if (!is.character(value) || anyNA(value) || !length(value) ||
      !is.numeric(chunk_rows) || length(chunk_rows) != 1L ||
      is.na(chunk_rows) || !is.finite(chunk_rows) || chunk_rows < 1L) {
    return(NULL)
  }
  chunk_rows <- as.integer(chunk_rows)
  candidate <- value[[1L]]
  for (start in seq.int(1L, length(value), by = chunk_rows)) {
    end <- min(length(value), start + chunk_rows - 1L)
    if (any(value[start:end] != candidate)) {
      return(NULL)
    }
  }
  enc2utf8(candidate)
}

wlv_runtime_snapshot_state_cartesian_descriptor <- function(value) {
  axes <- attr(value, "axes", exact = TRUE)
  uniform_state <- wlv_runtime_snapshot_state_uniform_value(value$state)
  if (is.null(uniform_state)) {
    return(NULL)
  }
  selectors <- stats::setNames(lapply(axes, function(axis) {
    wlv_runtime_snapshot_state_axis_labels(value[[axis]])
  }), axes)
  expected_rows <- prod(vapply(selectors, length, double(1L)))
  if (!is.finite(expected_rows) || expected_rows < 1 ||
      !identical(as.double(nrow(value)), expected_rows)) {
    return(NULL)
  }
  list(selectors = selectors, state = uniform_state)
}

wlv_runtime_snapshot_state_shape <- function(
    value,
    target_key = NULL,
    axes = NULL,
    state_key = NULL) {
  allowed_attributes <- c(
    "names", "class", "row.names", "target_key", "axes", "version"
  )
  if (!is.data.frame(value) || !identical(
        class(value),
        c("wlv_semantic_state", "data.frame")
      ) || !setequal(names(attributes(value)), allowed_attributes)) {
    return(NULL)
  }
  observed_target <- attr(value, "target_key", exact = TRUE)
  observed_axes <- attr(value, "axes", exact = TRUE)
  observed_version <- attr(value, "version", exact = TRUE)
  if (!is.character(observed_target) || length(observed_target) != 1L ||
      is.na(observed_target) || !nzchar(observed_target) ||
      !wlv_semantic_is_stateful_key(observed_target) ||
      !is.character(observed_axes) || !length(observed_axes) ||
      anyNA(observed_axes) || any(!nzchar(observed_axes)) ||
      anyDuplicated(observed_axes) || !identical(
        observed_version,
        wlv_semantic_state_version()
      ) || !identical(names(value), c(observed_axes, "state")) ||
      any(!vapply(value, is.character, logical(1L))) ||
      (!is.null(target_key) && !identical(observed_target, target_key)) ||
      (!is.null(axes) && !identical(observed_axes, axes)) ||
      (!is.null(state_key) && !identical(
        wlv_semantic_state_key(observed_target),
        state_key
      ))) {
    return(NULL)
  }
  row_count <- nrow(value)
  expected_row_names <- if (row_count) {
    c(NA_integer_, -row_count)
  } else {
    integer()
  }
  if (!identical(.row_names_info(value, type = 0L), expected_row_names)) {
    return(NULL)
  }
  list(
    target_key = observed_target,
    axes = observed_axes,
    state_version = observed_version,
    row_count = as.double(row_count)
  )
}

wlv_runtime_snapshot_state_cartesian_pack <- function(
    value,
    target_key = NULL,
    axes = NULL,
    state_key = NULL,
    target_value = NULL,
    chunk_rows = 65536L,
    return_commitment = FALSE) {
  shape <- wlv_runtime_snapshot_state_shape(
    value,
    target_key = target_key,
    axes = axes,
    state_key = state_key
  )
  if (!is.logical(return_commitment) || length(return_commitment) != 1L ||
      is.na(return_commitment)) {
    stop("Runtime Cartesian state commitment flag is invalid.", call. = FALSE)
  }
  if (is.null(shape) || shape$row_count < 1 ||
      !is.numeric(chunk_rows) || length(chunk_rows) != 1L ||
      is.na(chunk_rows) || !is.finite(chunk_rows) || chunk_rows < 1L) {
    return(NULL)
  }
  chunk_rows <- if (isTRUE(return_commitment)) {
    65536L
  } else {
    as.integer(chunk_rows)
  }
  cartesian <- wlv_runtime_snapshot_state_cartesian_descriptor(value)
  if (is.null(cartesian) ||
      !cartesian$state %in% wlv_semantic_sparse_states()) {
    return(NULL)
  }
  codec <- wlv_runtime_snapshot_new_state_codec(
    encoding = "cartesian",
    target_key = shape$target_key,
    axes = shape$axes,
    state_version = shape$state_version,
    row_count = shape$row_count,
    selectors = cartesian$selectors,
    state = cartesian$state
  )
  # The descriptor has already proved a non-missing uniform state column.
  # Reconstruct every coordinate column to prove the complete canonical
  # Cartesian order without allocating global rank/order vectors.
  columns <- shape$axes
  commitment_columns <- c(columns, "state")
  starts <- seq.int(1, shape$row_count, by = chunk_rows)
  chunks <- if (isTRUE(return_commitment)) {
    stats::setNames(lapply(commitment_columns, function(column) {
      character(length(starts))
    }), commitment_columns)
  } else {
    NULL
  }
  chunk_index <- 0L
  for (start in starts) {
    chunk_index <- chunk_index + 1L
    end <- min(shape$row_count, start + chunk_rows - 1L)
    for (column in columns) {
      observed <- if (isTRUE(return_commitment)) {
        wlv_runtime_snapshot_materialize_character(
          value[[column]][start:end]
        )
      } else {
        enc2utf8(value[[column]][start:end])
      }
      expected <- wlv_runtime_snapshot_state_cartesian_column_unchecked(
        codec,
        column,
        start,
        end
      )
      if (!identical(observed, expected)) {
        return(NULL)
      }
      if (isTRUE(return_commitment)) {
        chunks[[column]][[chunk_index]] <- wlv_publication_sha256_raw(
          serialize(observed, NULL, version = 3L)
        )
      }
      rm(observed, expected)
    }
    if (isTRUE(return_commitment)) {
      state_values <- wlv_runtime_snapshot_materialize_character(rep(
        codec$state,
        as.integer(end - start + 1)
      ))
      chunks$state[[chunk_index]] <- wlv_publication_sha256_raw(
        serialize(state_values, NULL, version = 3L)
      )
      rm(state_values)
    }
  }
  wlv_runtime_snapshot_state_codec_validate(
    codec,
    target_key = target_key,
    axes = axes,
    state_key = state_key,
    target_value = target_value
  )
  if (!isTRUE(return_commitment)) {
    return(codec)
  }
  list(
    state = codec,
    state_sha256 = wlv_runtime_snapshot_state_commitment_from_chunks(
      codec,
      chunks
    )
  )
}

wlv_runtime_snapshot_state_capture <- function(
    value,
    target_value,
    target_key,
    axes,
    state_key) {
  captured <- wlv_runtime_snapshot_state_cartesian_pack(
    value,
    target_key = target_key,
    axes = axes,
    state_key = state_key,
    target_value = target_value,
    return_commitment = TRUE
  )
  if (!is.null(captured)) {
    return(captured)
  }
  wlv_semantic_state_validate(
    value,
    value = target_value,
    target_key = target_key,
    axes = axes,
    state_key = state_key
  )
  state <- wlv_runtime_snapshot_state_pack_validated(value)
  list(
    state = state,
    state_sha256 = wlv_runtime_snapshot_state_sha256(state)
  )
}

wlv_runtime_snapshot_state_capture_pack <- function(
    value,
    target_value,
    target_key,
    axes,
    state_key) {
  wlv_runtime_snapshot_state_capture(
    value,
    target_value,
    target_key,
    axes,
    state_key
  )$state
}

wlv_runtime_snapshot_new_state_codec <- function(
    encoding,
    target_key,
    axes,
    state_version,
    row_count,
    selectors = NULL,
    state = NULL,
    rows = NULL) {
  structure(list(
    version = wlv_runtime_snapshot_state_codec_version(),
    encoding = encoding,
    target_key = target_key,
    axes = axes,
    state_version = state_version,
    row_count = as.double(row_count),
    selectors = selectors,
    state = state,
    rows = rows
  ), class = "wlv_runtime_semantic_state_codec")
}

wlv_runtime_snapshot_state_codec_validate <- function(
    value,
    target_key = NULL,
    axes = NULL,
    state_key = NULL,
    target_value = NULL) {
  if (!is.list(value) || !identical(
        class(value),
        "wlv_runtime_semantic_state_codec"
      ) || !setequal(names(attributes(value)), c("names", "class")) ||
      !identical(names(value), wlv_runtime_snapshot_state_codec_fields()) ||
      !identical(value$version, wlv_runtime_snapshot_state_codec_version()) ||
      !is.character(value$encoding) || length(value$encoding) != 1L ||
      is.na(value$encoding) || !value$encoding %in% c("cartesian", "rows") ||
      !is.character(value$target_key) || length(value$target_key) != 1L ||
      is.na(value$target_key) || !nzchar(value$target_key) ||
      !is.character(value$axes) || !length(value$axes) || anyNA(value$axes) ||
      any(!nzchar(value$axes)) || anyDuplicated(value$axes) ||
      !is.character(value$state_version) || length(value$state_version) != 1L ||
      is.na(value$state_version) || !identical(
        value$state_version,
        wlv_semantic_state_version()
      ) || !is.double(value$row_count) || length(value$row_count) != 1L ||
      is.na(value$row_count) || !is.finite(value$row_count) ||
      value$row_count < 0 || value$row_count != floor(value$row_count) ||
      identical(1 / value$row_count, -Inf) ||
      value$row_count > .Machine$integer.max) {
    stop("Runtime semantic-state codec is invalid.", call. = FALSE)
  }
  wlv_semantic_assert_stateful_key(value$target_key)
  if (!is.null(target_key) && !identical(value$target_key, target_key)) {
    stop("Runtime state-codec target_key does not match its contract.",
      call. = FALSE
    )
  }
  if (!is.null(axes) && !identical(value$axes, axes)) {
    stop("Runtime state-codec axes do not match their contract.",
      call. = FALSE
    )
  }
  if (!is.null(state_key) && !identical(
        wlv_semantic_state_key(value$target_key),
        state_key
      )) {
    stop("Runtime state-codec resource key does not match target_key.",
      call. = FALSE
    )
  }
  if (identical(value$encoding, "rows")) {
    if (!is.null(value$selectors) || !is.null(value$state) ||
        !inherits(value$rows, "wlv_semantic_state")) {
      stop("Runtime rows state-codec payload is invalid.", call. = FALSE)
    }
    wlv_semantic_state_validate(
      value$rows,
      value = target_value,
      target_key = value$target_key,
      axes = value$axes,
      state_key = wlv_semantic_state_key(value$target_key)
    )
    if (!identical(value$row_count, as.double(nrow(value$rows)))) {
      stop("Runtime rows state-codec count is invalid.", call. = FALSE)
    }
    if (!is.null(wlv_runtime_snapshot_state_cartesian_descriptor(value$rows))) {
      stop("Runtime rows state-codec has a canonical cartesian encoding.",
        call. = FALSE
      )
    }
    return(invisible(value))
  }
  if (!is.null(value$rows) || !is.list(value$selectors) ||
      !identical(names(value$selectors), value$axes) ||
      !is.character(value$state) || length(value$state) != 1L ||
      is.na(value$state) || !value$state %in% wlv_semantic_sparse_states() ||
      value$row_count < 1) {
    stop("Runtime cartesian state-codec payload is invalid.", call. = FALSE)
  }
  valid_selectors <- vapply(value$selectors, function(selector) {
    is.character(selector) && length(selector) && !anyNA(selector) &&
      all(nzchar(selector)) && !anyDuplicated(selector) && identical(
        selector,
        sort(enc2utf8(selector), method = "radix")
      )
  }, logical(1L))
  if (!all(valid_selectors)) {
    stop("Runtime cartesian state-codec selectors are not canonical.",
      call. = FALSE
    )
  }
  expected_rows <- prod(vapply(value$selectors, length, double(1L)))
  if (!is.finite(expected_rows) || !identical(value$row_count, expected_rows)) {
    stop("Runtime cartesian state-codec count is invalid.", call. = FALSE)
  }
  if (!is.null(target_value)) {
    wlv_semantic_assert_value(target_value, value$axes)
    labels <- dimnames(target_value)
    unknown <- vapply(seq_along(value$axes), function(index) {
      any(!value$selectors[[index]] %in% labels[[index]])
    }, logical(1L))
    if (any(unknown)) {
      stop("Sparse semantic states reference unknown coordinates.", call. = FALSE)
    }
    dimensions <- dim(target_value)
    strides <- c(1, cumprod(as.double(dimensions)))[seq_along(dimensions)]
    selector_positions <- lapply(seq_along(value$axes), function(index) {
      match(value$selectors[[index]], labels[[index]])
    })
    chunk_values <- 2^20
    total <- length(target_value)
    if (total) {
      for (start in seq.int(1, total, by = chunk_values)) {
        end <- min(total, start + chunk_values - 1)
        current <- target_value[start:end]
        ordinary_na <- which(is.na(current) & !is.nan(current))
        if (!length(ordinary_na)) {
          next
        }
        positions <- as.double(start) + ordinary_na - 2
        covered <- rep(TRUE, length(ordinary_na))
        for (index in seq_along(value$axes)) {
          coordinate <- (positions %/% strides[[index]]) %% dimensions[[index]] + 1
          covered <- covered & coordinate %in% selector_positions[[index]]
        }
        if (any(!covered)) {
          wlv_semantic_abort(
            "Every ordinary NA requires an explicit non-finite semantic state."
          )
        }
      }
    }
  }
  invisible(value)
}

wlv_runtime_snapshot_state_pack_validated <- function(value) {
  axes <- attr(value, "axes", exact = TRUE)
  target_key <- attr(value, "target_key", exact = TRUE)
  state_version <- attr(value, "version", exact = TRUE)
  row_count <- as.double(nrow(value))
  cartesian <- wlv_runtime_snapshot_state_cartesian_descriptor(value)
  codec <- if (!is.null(cartesian)) {
    wlv_runtime_snapshot_new_state_codec(
      encoding = "cartesian",
      target_key = target_key,
      axes = axes,
      state_version = state_version,
      row_count = row_count,
      selectors = cartesian$selectors,
      state = cartesian$state
    )
  } else {
    wlv_runtime_snapshot_new_state_codec(
      encoding = "rows",
      target_key = target_key,
      axes = axes,
      state_version = state_version,
      row_count = row_count,
      rows = value
    )
  }
  codec
}

wlv_runtime_snapshot_state_pack <- function(value) {
  if (wlv_runtime_snapshot_is_state_codec(value)) {
    wlv_runtime_snapshot_state_codec_validate(value)
    return(value)
  }
  wlv_semantic_state_validate(value)
  wlv_runtime_snapshot_state_pack_validated(value)
}

wlv_runtime_snapshot_state_cartesian_column_unchecked <- function(
    value,
    column,
    start,
    end) {
  count <- as.integer(end - start + 1)
  if (identical(column, "state")) {
    return(rep(value$state, count))
  }
  axis_index <- match(column, value$axes)
  trailing <- if (axis_index == length(value$axes)) {
    1
  } else {
    prod(vapply(
      value$selectors[(axis_index + 1L):length(value$axes)],
      length,
      double(1L)
    ))
  }
  labels <- value$selectors[[axis_index]]
  positions <- seq.int(as.double(start) - 1, as.double(end) - 1)
  indices <- (positions %/% trailing) %% length(labels) + 1
  labels[as.integer(indices)]
}

wlv_runtime_snapshot_state_cartesian_column <- function(
    value,
    column,
    start,
    end) {
  wlv_runtime_snapshot_state_codec_validate(value)
  if (!identical(value$encoding, "cartesian") ||
      !is.character(column) || length(column) != 1L || is.na(column) ||
      !column %in% c(value$axes, "state") ||
      !is.numeric(start) || length(start) != 1L || is.na(start) ||
      !is.numeric(end) || length(end) != 1L || is.na(end) ||
      start < 1 || end < start || end > value$row_count) {
    stop("Runtime cartesian state-codec slice is invalid.", call. = FALSE)
  }
  wlv_runtime_snapshot_state_cartesian_column_unchecked(
    value,
    column,
    start,
    end
  )
}

wlv_runtime_snapshot_state_unpack <- function(value, target_value = NULL) {
  wlv_runtime_snapshot_state_codec_validate(
    value,
    target_value = target_value
  )
  if (identical(value$encoding, "rows")) {
    result <- value$rows
  } else {
    columns <- lapply(c(value$axes, "state"), function(column) {
      wlv_runtime_snapshot_state_cartesian_column_unchecked(
        value,
        column,
        1,
        value$row_count
      )
    })
    names(columns) <- c(value$axes, "state")
    result <- structure(
      columns,
      class = c("wlv_semantic_state", "data.frame"),
      row.names = c(NA_integer_, -as.integer(value$row_count)),
      target_key = value$target_key,
      axes = value$axes,
      version = value$state_version
    )
  }
  wlv_semantic_state_validate(
    result,
    target_key = value$target_key,
    axes = value$axes,
    state_key = wlv_semantic_state_key(value$target_key)
  )
  result
}

wlv_runtime_snapshot_state_metadata <- function(value, state_sha256 = NULL) {
  codec <- wlv_runtime_snapshot_state_pack(value)
  if (is.null(state_sha256)) {
    state_sha256 <- wlv_runtime_snapshot_state_sha256(codec)
  }
  if (!is.character(state_sha256) || length(state_sha256) != 1L ||
      is.na(state_sha256) || !grepl("^[0-9a-f]{64}$", state_sha256)) {
    stop("Runtime snapshot state metadata hash is invalid.", call. = FALSE)
  }
  list(
    codec_version = codec$version,
    encoding = codec$encoding,
    target_key = codec$target_key,
    axes = codec$axes,
    state_version = codec$state_version,
    row_count = codec$row_count,
    state_sha256 = state_sha256
  )
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
    provenance = NULL,
    state_sha256 = NULL) {
  payload <- list(
    version = "wlv-runtime-state-binding/1.0.0",
    id = id,
    artifact_sha256 = artifact_sha256,
    state = wlv_runtime_snapshot_state_metadata(state, state_sha256),
    provenance = provenance
  )
  wlv_publication_sha256_raw(serialize(payload, NULL, version = 3L))
}

wlv_runtime_snapshot_state_bindings <- function(
    snapshot,
    verify_resource_states = TRUE) {
  if (!is.logical(verify_resource_states) ||
      length(verify_resource_states) != 1L || is.na(verify_resource_states)) {
    stop("Runtime snapshot state-binding validation flag is invalid.",
      call. = FALSE
    )
  }
  definitions <- wlv_runtime_snapshot_panel_definitions()
  ids <- character()
  artifact_sha256 <- character()
  states <- list()
  state_sha256 <- list()
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
    state_sha256[length(state_sha256) + 1L] <- list(NULL)
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
    state_sha256[length(state_sha256) + 1L] <- list(if (isTRUE(
      verify_resource_states
    )) {
      NULL
    } else {
      entry$state_sha256
    })
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
      provenance[[index]],
      state_sha256[[index]]
    )
  }, character(1L))
  data.frame(
    id = ids,
    artifact_sha256 = artifact_sha256,
    binding_sha256 = unname(binding_sha256),
    stringsAsFactors = FALSE
  )
}

wlv_runtime_snapshot_capture_version <- function() {
  "wlv-runtime-snapshot-capture/1.1.0"
}

wlv_runtime_snapshot_capture_resource_ids <- function(partitions) {
  unlist(lapply(partitions, function(partition) {
    paste(
      c(
        paste0("io/", wlv_runtime_snapshot_io_resources()),
        "intermediate/lambda"
      ),
      partition,
      sep = "\034"
    )
  }), use.names = FALSE)
}

wlv_runtime_snapshot_capture_requests <- function(store, partitions) {
  requests <- lapply(partitions, function(partition) {
    keys <- c(
      paste0("io/", wlv_runtime_snapshot_io_resources()),
      "intermediate/lambda"
    )
    do.call(rbind, lapply(keys, function(key) {
      state <- wlv_runtime_snapshot_terminal(
        store,
        wlv_semantic_state_key(key),
        partition,
        wlv_native_semantic_state_contract(
          wlv_runtime_snapshot_contract(key)
        )
      )
      data.frame(
        id = paste(key, partition, sep = "\034"),
        key = key,
        partition = partition,
        include_value = identical(key, "intermediate/lambda"),
        state_rows = as.double(NROW(state$value)),
        stringsAsFactors = FALSE
      )
    }))
  })
  requests <- do.call(rbind, requests)
  row.names(requests) <- NULL
  requests
}

wlv_runtime_snapshot_capture_store_assert_owned <- function(store) {
  if (!inherits(store, "wlv_resource_store") || !is.environment(store) ||
      environmentIsLocked(store) || isTRUE(store$sealed) ||
      bindingIsLocked("entries", store)) {
    stop(
      "An owned runtime snapshot capture requires a mutable resource store.",
      call. = FALSE
    )
  }
  wlv_runtime_store_identity_assert(store, "wlv_store_error")
  invisible(store)
}

wlv_runtime_snapshot_capture_store_retain <- function(store, requests) {
  wlv_runtime_snapshot_capture_store_assert_owned(store)
  retained_keys <- unique(c(
    requests$key,
    vapply(requests$key, wlv_semantic_state_key, character(1L))
  ))
  retained_partitions <- unique(as.character(requests$partition))
  retain <- vapply(store$entries, function(entry) {
    entry$key %in% retained_keys &&
      !is.null(entry$partition) && entry$partition %in% retained_partitions
  }, logical(1L))
  store$entries <- store$entries[retain]
  invisible(store)
}

wlv_runtime_snapshot_capture_store_release <- function(
    store,
    key,
    partition) {
  wlv_runtime_snapshot_capture_store_assert_owned(store)
  released_keys <- c(key, wlv_semantic_state_key(key))
  release <- vapply(store$entries, function(entry) {
    entry$key %in% released_keys && identical(entry$partition, partition)
  }, logical(1L))
  store$entries <- store$entries[!release]
  invisible(sum(release))
}

wlv_runtime_snapshot_capture_assert <- function(capture) {
  fields <- c(
    "version", "mode", "method", "source", "partitions", "compatibility",
    "io_artifacts", "panel_states", "panel_provenance", "parent_imports",
    "parent_imports_sha256", "resources"
  )
  if (!inherits(capture, "wlv_runtime_snapshot_capture") ||
      !is.list(capture) || !identical(names(capture), fields) ||
      !identical(capture$version, wlv_runtime_snapshot_capture_version()) ||
      !capture$mode %in% c("calculate", "recalculate")) {
    stop("Runtime snapshot capture is invalid.", call. = FALSE)
  }
  wlv_runtime_snapshot_scalar(capture$method, "capture method")
  wlv_runtime_snapshot_scalar(capture$source, "capture source")
  wlv_runtime_compatibility_assert(capture$compatibility)
  if (!identical(capture$compatibility$method, capture$method) ||
      !identical(capture$compatibility$source, capture$source)) {
    stop("Runtime snapshot capture compatibility identity is invalid.",
      call. = FALSE
    )
  }
  if (!is.character(capture$partitions) || !length(capture$partitions) ||
      anyNA(capture$partitions) || any(!nzchar(capture$partitions)) ||
      anyDuplicated(capture$partitions) || !identical(
        capture$partitions,
        sort(capture$partitions, method = "radix")
      )) {
    stop("Runtime snapshot capture partitions are invalid.", call. = FALSE)
  }
  expected_resources <- wlv_runtime_snapshot_capture_resource_ids(
    capture$partitions
  )
  if (!is.list(capture$resources) ||
      !identical(names(capture$resources), expected_resources) ||
      !is.list(capture$panel_states) || !identical(
        names(capture$panel_states),
        names(wlv_runtime_snapshot_panel_definitions())
      ) || !is.data.frame(capture$panel_provenance)) {
    stop("Runtime snapshot capture coverage is incomplete.", call. = FALSE)
  }
  wlv_parent_seed_resolutions_assert(capture$parent_imports)
  if (!is.character(capture$parent_imports_sha256) ||
      length(capture$parent_imports_sha256) != 1L ||
      is.na(capture$parent_imports_sha256) || !identical(
        capture$parent_imports_sha256,
        wlv_runtime_snapshot_parent_imports_sha256(capture$parent_imports)
      )) {
    stop("Runtime snapshot capture parent imports are invalid.", call. = FALSE)
  }
  if (identical(capture$mode, "calculate") &&
      !is.null(capture$io_artifacts)) {
    stop("A calculation snapshot capture cannot contain an IO inventory.",
      call. = FALSE
    )
  }
  if (identical(capture$mode, "recalculate") &&
      (!is.data.frame(capture$io_artifacts) || !identical(
        names(capture$io_artifacts),
        c("partition", "path", "sha256", "meta_sha256")
      ) || !identical(
        as.character(capture$io_artifacts$partition),
        capture$partitions
      ))) {
    stop("A recalculation snapshot capture lacks its parent IO inventory.",
      call. = FALSE
    )
  }
  invisible(capture)
}

wlv_runtime_snapshot_capture_inputs <- function(
    method,
    source,
    partitions,
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
  list(
    method = method,
    source = source,
    partitions = sort(partitions, method = "radix"),
    compatibility = compatibility
  )
}

wlv_runtime_snapshot_capture_new <- function(
    inputs,
    panel_states,
    panel_provenance,
    resources) {
  parent_imports <- wlv_parent_seed_empty_resolutions()
  capture <- structure(list(
    version = wlv_runtime_snapshot_capture_version(),
    mode = "calculate",
    method = inputs$method,
    source = inputs$source,
    partitions = inputs$partitions,
    compatibility = inputs$compatibility,
    io_artifacts = NULL,
    panel_states = panel_states,
    panel_provenance = panel_provenance,
    parent_imports = parent_imports,
    parent_imports_sha256 = wlv_runtime_snapshot_parent_imports_sha256(
      parent_imports
    ),
    resources = resources
  ), class = "wlv_runtime_snapshot_capture")
  wlv_runtime_snapshot_capture_assert(capture)
  capture
}

wlv_runtime_snapshot_capture_preparation_version <- function() {
  "wlv-runtime-snapshot-capture-preparation/1.0.0"
}

wlv_runtime_snapshot_capture_preparation_assert <- function(
    preparation,
    store) {
  fields <- c(
    "canonical_ids", "inputs", "lifecycle", "panel_provenance",
    "panel_states", "remaining_entry_ids", "requests", "resources",
    "store_identity_token", "store_reference", "version"
  )
  if (!inherits(preparation, "wlv_runtime_snapshot_capture_preparation") ||
      !is.environment(preparation) || !environmentIsLocked(preparation) ||
      !identical(parent.env(preparation), emptyenv()) || !identical(
        ls(preparation, all.names = TRUE, sorted = TRUE),
        fields
      ) || !all(vapply(
        fields,
        bindingIsLocked,
        logical(1L),
        env = preparation
      )) ||
      !identical(
        preparation$version,
        wlv_runtime_snapshot_capture_preparation_version()
      )) {
    stop("Runtime snapshot capture preparation is invalid.", call. = FALSE)
  }
  wlv_runtime_snapshot_capture_store_assert_owned(store)
  if (!identical(store, preparation$store_reference) ||
      !inherits(preparation$store_identity_token, "wlv_store_identity") ||
      !is.environment(preparation$store_identity_token) ||
      !environmentIsLocked(preparation$store_identity_token) ||
      !identical(store$identity_token, preparation$store_identity_token)) {
    stop("Runtime snapshot capture preparation belongs to another store.",
      call. = FALSE
    )
  }
  lifecycle <- preparation$lifecycle
  if (!inherits(lifecycle, "wlv_runtime_snapshot_capture_lifecycle") ||
      !is.environment(lifecycle) || !environmentIsLocked(lifecycle) ||
      !identical(parent.env(lifecycle), emptyenv()) || !identical(
        ls(lifecycle, all.names = TRUE, sorted = TRUE),
        "active"
      ) || !is.logical(lifecycle$active) || length(lifecycle$active) != 1L ||
      is.na(lifecycle$active) || !isTRUE(lifecycle$active)) {
    stop("Runtime snapshot capture preparation is no longer active.",
      call. = FALSE
    )
  }
  inputs <- preparation$inputs
  if (!is.list(inputs) || !identical(
        names(inputs),
        c("method", "source", "partitions", "compatibility")
      )) {
    stop("Runtime snapshot capture preparation inputs are invalid.",
      call. = FALSE
    )
  }
  validated_inputs <- wlv_runtime_snapshot_capture_inputs(
    inputs$method,
    inputs$source,
    inputs$partitions,
    inputs$compatibility
  )
  if (!identical(validated_inputs, inputs)) {
    stop("Runtime snapshot capture preparation inputs are not canonical.",
      call. = FALSE
    )
  }
  requests <- preparation$requests
  request_fields <- c(
    "id", "key", "partition", "include_value", "state_rows"
  )
  if (!is.data.frame(requests) || !identical(names(requests), request_fields) ||
      !is.character(requests$id) || !is.character(requests$key) ||
      !is.character(requests$partition) ||
      !is.logical(requests$include_value) || anyNA(requests$include_value) ||
      !is.double(requests$state_rows) || anyNA(requests$state_rows) ||
      any(!is.finite(requests$state_rows)) || any(requests$state_rows < 0) ||
      any(requests$state_rows != floor(requests$state_rows))) {
    stop("Runtime snapshot capture requests are invalid.", call. = FALSE)
  }
  canonical_ids <- wlv_runtime_snapshot_capture_resource_ids(
    inputs$partitions
  )
  if (!identical(preparation$canonical_ids, canonical_ids) ||
      !identical(as.character(requests$id), canonical_ids)) {
    stop("Runtime snapshot capture preparation is not canonical.",
      call. = FALSE
    )
  }
  zero_ids <- canonical_ids[requests$state_rows == 0]
  resource_ids <- names(preparation$resources)
  if (is.null(resource_ids)) {
    resource_ids <- character()
  }
  if (!is.list(preparation$resources) ||
      !identical(resource_ids, zero_ids) ||
      !is.list(preparation$panel_states) || !identical(
        names(preparation$panel_states),
        names(wlv_runtime_snapshot_panel_definitions())
      ) || !is.data.frame(preparation$panel_provenance)) {
    stop("Runtime snapshot capture preparation coverage is invalid.",
      call. = FALSE
    )
  }
  if (!identical(names(store$entries), preparation$remaining_entry_ids)) {
    stop("Runtime snapshot capture store inventory changed between phases.",
      call. = FALSE
    )
  }
  remaining <- requests$state_rows > 0
  if (length(store$entries)) {
    retained <- vapply(store$entries, function(entry) {
      any(
        requests$key[remaining] == entry$key &
          requests$partition[remaining] == entry$partition
      ) || any(
        vapply(
          requests$key[remaining],
          wlv_semantic_state_key,
          character(1L)
        ) == entry$key & requests$partition[remaining] == entry$partition
      )
    }, logical(1L))
    if (!all(retained)) {
      stop("Runtime snapshot capture store contains an unexpected resource.",
        call. = FALSE
      )
    }
  }
  invisible(preparation)
}

wlv_runtime_snapshot_capture_begin <- function(
    store,
    method,
    source,
    partitions,
    compatibility) {
  wlv_runtime_snapshot_capture_store_assert_owned(store)
  inputs <- wlv_runtime_snapshot_capture_inputs(
    method,
    source,
    partitions,
    compatibility
  )
  panel_states <- wlv_runtime_snapshot_panel_states(store)
  panel_provenance <- wlv_runtime_snapshot_panel_provenance(store)
  requests <- wlv_runtime_snapshot_capture_requests(store, inputs$partitions)
  canonical_ids <- wlv_runtime_snapshot_capture_resource_ids(
    inputs$partitions
  )
  if (!identical(as.character(requests$id), canonical_ids)) {
    stop("Runtime snapshot resource requests are not canonical.", call. = FALSE)
  }
  wlv_runtime_snapshot_capture_store_retain(store, requests)
  # Retention drops the assembled m_io artifact and every unrelated terminal
  # from the owned fork. Reclaim those large values before hashing any retained
  # resource so capture and publication do not overlap their memory footprints.
  invisible(gc(full = TRUE))
  zero_order <- which(requests$state_rows == 0)
  zero_order <- zero_order[order(
    requests$include_value[zero_order],
    requests$id[zero_order],
    method = "radix"
  )]
  resources <- list()
  for (request_index in zero_order) {
    request <- requests[request_index, , drop = FALSE]
    entry <- wlv_runtime_snapshot_entry(
      store,
      request$key[[1L]],
      request$partition[[1L]],
      include_value = request$include_value[[1L]]
    )
    resources[[request$id[[1L]]]] <- entry
    released <- wlv_runtime_snapshot_capture_store_release(
      store,
      request$key[[1L]],
      request$partition[[1L]]
    )
    if (released < 2L) {
      stop(
        sprintf(
          "Owned snapshot fork did not release `%s[%s]` completely.",
          request$key[[1L]],
          request$partition[[1L]]
        ),
        call. = FALSE
      )
    }
  }
  resources <- resources[canonical_ids[canonical_ids %in% names(resources)]]
  lifecycle <- new.env(parent = emptyenv())
  lifecycle$active <- TRUE
  class(lifecycle) <- "wlv_runtime_snapshot_capture_lifecycle"
  lockEnvironment(lifecycle, bindings = FALSE)
  preparation <- new.env(parent = emptyenv())
  preparation$version <- wlv_runtime_snapshot_capture_preparation_version()
  preparation$store_reference <- store
  preparation$store_identity_token <- store$identity_token
  preparation$lifecycle <- lifecycle
  preparation$inputs <- inputs
  preparation$requests <- requests
  preparation$canonical_ids <- canonical_ids
  preparation$remaining_entry_ids <- names(store$entries)
  preparation$panel_states <- panel_states
  preparation$panel_provenance <- panel_provenance
  preparation$resources <- resources
  class(preparation) <- "wlv_runtime_snapshot_capture_preparation"
  lockEnvironment(preparation, bindings = TRUE)
  wlv_runtime_snapshot_capture_preparation_assert(preparation, store)
  preparation
}

wlv_runtime_snapshot_capture_finish <- function(preparation, store) {
  wlv_runtime_snapshot_capture_preparation_assert(preparation, store)
  lifecycle <- preparation$lifecycle
  lifecycle$active <- FALSE
  lockBinding("active", lifecycle)
  requests <- preparation$requests
  request_order <- which(requests$state_rows > 0)
  request_order <- request_order[order(
    -requests$state_rows[request_order],
    requests$include_value[request_order],
    requests$id[request_order],
    method = "radix"
  )]
  resources <- preparation$resources
  for (position in seq_along(request_order)) {
    request_index <- request_order[[position]]
    request <- requests[request_index, , drop = FALSE]
    entry <- wlv_runtime_snapshot_entry(
      store,
      request$key[[1L]],
      request$partition[[1L]],
      include_value = request$include_value[[1L]]
    )
    resources[[request$id[[1L]]]] <- entry
    released <- wlv_runtime_snapshot_capture_store_release(
      store,
      request$key[[1L]],
      request$partition[[1L]]
    )
    if (released < 2L) {
      stop(
        sprintf(
          "Owned snapshot fork did not release `%s[%s]` completely.",
          request$key[[1L]],
          request$partition[[1L]]
        ),
        call. = FALSE
      )
    }
    rm(entry, released)
    remaining <- if (position < length(request_order)) {
      request_order[(position + 1L):length(request_order)]
    } else {
      integer()
    }
    if (length(remaining) && any(requests$state_rows[remaining] >= 2^20)) {
      invisible(gc(full = TRUE))
    }
  }
  resources <- resources[preparation$canonical_ids]
  if (length(store$entries)) {
    stop("Owned snapshot fork was not consumed completely.", call. = FALSE)
  }
  wlv_runtime_snapshot_capture_new(
    preparation$inputs,
    preparation$panel_states,
    preparation$panel_provenance,
    resources
  )
}

wlv_runtime_snapshot_capture <- function(
    store,
    method,
    source,
    partitions,
    compatibility,
    consume_store = FALSE) {
  if (!is.logical(consume_store) || length(consume_store) != 1L ||
      is.na(consume_store)) {
    stop("Runtime snapshot store-consumption flag is invalid.", call. = FALSE)
  }
  if (isTRUE(consume_store)) {
    preparation <- wlv_runtime_snapshot_capture_begin(
      store,
      method,
      source,
      partitions,
      compatibility
    )
    invisible(gc(full = TRUE))
    return(wlv_runtime_snapshot_capture_finish(preparation, store))
  }
  inputs <- wlv_runtime_snapshot_capture_inputs(
    method,
    source,
    partitions,
    compatibility
  )
  panel_states <- wlv_runtime_snapshot_panel_states(store)
  panel_provenance <- wlv_runtime_snapshot_panel_provenance(store)
  requests <- wlv_runtime_snapshot_capture_requests(store, inputs$partitions)
  canonical_ids <- wlv_runtime_snapshot_capture_resource_ids(
    inputs$partitions
  )
  if (!identical(as.character(requests$id), canonical_ids)) {
    stop("Runtime snapshot resource requests are not canonical.", call. = FALSE)
  }
  request_order <- seq_len(nrow(requests))
  resources <- list()
  for (request_index in request_order) {
    request <- requests[request_index, , drop = FALSE]
    entry <- wlv_runtime_snapshot_entry(
      store,
      request$key[[1L]],
      request$partition[[1L]],
      include_value = request$include_value[[1L]]
    )
    resources[[request$id[[1L]]]] <- entry
    rm(entry)
    invisible(gc(full = TRUE))
  }
  resources <- resources[canonical_ids]
  wlv_runtime_snapshot_capture_new(
    inputs,
    panel_states,
    panel_provenance,
    resources
  )
}

wlv_runtime_snapshot_capture_update_panel <- function(
    snapshot,
    store,
    parent_imports,
    compatibility,
    validate_parent = TRUE) {
  if (!is.logical(validate_parent) || length(validate_parent) != 1L ||
      is.na(validate_parent)) {
    stop("Runtime snapshot parent-validation flag is invalid.", call. = FALSE)
  }
  if (isTRUE(validate_parent)) {
    wlv_runtime_snapshot_validate(snapshot)
  } else if (!is.list(snapshot) ||
      !identical(snapshot$version, wlv_runtime_snapshot_version())) {
    stop("Parent runtime snapshot is invalid.", call. = FALSE)
  }
  wlv_parent_seed_resolutions_assert(parent_imports)
  wlv_runtime_snapshot_assert_compatible(snapshot, compatibility)
  panel_states <- wlv_runtime_snapshot_panel_states(store)
  panel_provenance <- wlv_runtime_snapshot_panel_provenance_update(
    snapshot,
    store,
    parent_imports
  )
  capture <- structure(list(
    version = wlv_runtime_snapshot_capture_version(),
    mode = "recalculate",
    method = snapshot$method,
    source = snapshot$source,
    partitions = snapshot$partitions,
    compatibility = compatibility,
    io_artifacts = snapshot$io_artifacts,
    panel_states = panel_states,
    panel_provenance = panel_provenance,
    parent_imports = parent_imports,
    parent_imports_sha256 = wlv_runtime_snapshot_parent_imports_sha256(
      parent_imports
    ),
    resources = snapshot$resources
  ), class = "wlv_runtime_snapshot_capture")
  wlv_runtime_snapshot_capture_assert(capture)
  capture
}

wlv_runtime_snapshot_finalize <- function(
    capture,
    io_artifacts = NULL,
    panel_artifacts,
    validate_snapshot = TRUE,
    validate_bound = TRUE) {
  wlv_runtime_snapshot_capture_assert(capture)
  flags <- list(
    validate_snapshot = validate_snapshot,
    validate_bound = validate_bound
  )
  if (any(!vapply(flags, function(flag) {
    is.logical(flag) && length(flag) == 1L && !is.na(flag)
  }, logical(1L)))) {
    stop("Runtime snapshot finalization flags are invalid.", call. = FALSE)
  }
  artifact_rows <- if (identical(capture$mode, "calculate")) {
    if (
      !is.character(io_artifacts) || is.null(names(io_artifacts)) ||
        !setequal(names(io_artifacts), capture$partitions) ||
        anyNA(io_artifacts) || anyDuplicated(names(io_artifacts)) ||
        any(!file.exists(io_artifacts)) || any(file.info(io_artifacts)$isdir) ||
        any(!file.exists(paste0(io_artifacts, ".meta"))) ||
        any(file.info(paste0(io_artifacts, ".meta"))$isdir)
    ) {
      stop("Runtime snapshot requires one existing IO artifact per partition.",
        call. = FALSE
      )
    }
    io_artifacts <- io_artifacts[capture$partitions]
    rows <- data.frame(
      partition = capture$partitions,
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
    if (anyDuplicated(rows$path)) {
      stop("Runtime snapshot IO artifact names are not unique.", call. = FALSE)
    }
    rows
  } else {
    if (!is.null(io_artifacts)) {
      stop("A recalculation snapshot must preserve its parent IO inventory.",
        call. = FALSE
      )
    }
    capture$io_artifacts
  }
  snapshot <- list(
    version = wlv_runtime_snapshot_version(),
    method = capture$method,
    source = capture$source,
    partitions = capture$partitions,
    compatibility = capture$compatibility,
    io_artifacts = artifact_rows,
    panel_artifacts = wlv_runtime_snapshot_artifact_inventory(
      panel_artifacts,
      names(wlv_runtime_snapshot_panel_definitions()),
      "panel"
    ),
    panel_states = capture$panel_states,
    panel_provenance = capture$panel_provenance,
    parent_imports = capture$parent_imports,
    parent_imports_sha256 = capture$parent_imports_sha256,
    resources = capture$resources,
    state_bindings = NULL
  )
  snapshot$state_bindings <- wlv_runtime_snapshot_state_bindings(
    snapshot,
    verify_resource_states = FALSE
  )
  if (isTRUE(validate_snapshot)) {
    wlv_runtime_snapshot_validate(snapshot)
  }
  if (isTRUE(validate_bound)) {
    paths <- if (identical(capture$mode, "calculate")) {
      c(io_artifacts, panel_artifacts)
    } else {
      panel_artifacts
    }
    wlv_runtime_snapshot_validate_bound_artifacts(
      snapshot,
      wlv_runtime_snapshot_artifact_root(paths),
      read_fst_array,
      validate_io = identical(capture$mode, "calculate")
    )
  }
  snapshot
}

wlv_runtime_snapshot_create <- function(
    store,
    method,
    source,
    partitions,
    io_artifacts,
    panel_artifacts,
    compatibility) {
  capture <- wlv_runtime_snapshot_capture(
    store,
    method,
    source,
    partitions,
    compatibility
  )
  wlv_runtime_snapshot_finalize(
    capture,
    io_artifacts = io_artifacts,
    panel_artifacts = panel_artifacts
  )
}

wlv_runtime_snapshot_update_panel <- function(
    snapshot,
    store,
    panel_artifacts,
    parent_imports,
    compatibility) {
  capture <- wlv_runtime_snapshot_capture_update_panel(
    snapshot,
    store,
    parent_imports,
    compatibility
  )
  wlv_runtime_snapshot_finalize(
    capture,
    panel_artifacts = panel_artifacts
  )
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
  values <- rep(list(NULL), length(selectors))
  names(values) <- selectors
  hash_buffers <- rep(list(NULL), length(selectors))
  chunk_hashes <- rep(list(character()), length(selectors))
  hash_chunk_values <- as.integer(wlv_runtime_snapshot_hash_chunk_values())
  storage <- NULL
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
          nrow(table) != expected_rows || !is.numeric(table[[1L]]) ||
          !typeof(table[[1L]]) %in% c("double", "integer")) {
        stop(
          sprintf("Runtime snapshot artifact `%s` has invalid streamed data.", filename),
          call. = FALSE
        )
      }
      current_storage <- typeof(table[[1L]])
      if (is.null(storage)) {
        storage <- current_storage
        if (isTRUE(materialize)) {
          values <- lapply(selectors, function(selector) {
            array(
              vector(storage, prod(as.double(slice_dimensions))),
              dim = slice_dimensions,
              dimnames = slice_labels
            )
          })
          names(values) <- selectors
        }
      } else if (!identical(current_storage, storage)) {
        stop(
          sprintf(
            "Runtime snapshot artifact `%s` changed storage while streaming.",
            filename
          ),
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
        selected <- as.vector(selected)
        attributes(selected) <- NULL
        if (isTRUE(materialize)) {
          values[[selector_index]][target_positions] <- selected
        }
        buffer <- if (is.null(hash_buffers[[selector_index]])) {
          selected
        } else {
          c(hash_buffers[[selector_index]], selected)
        }
        while (length(buffer) >= hash_chunk_values) {
          current <- buffer[seq_len(hash_chunk_values)]
          attributes(current) <- NULL
          chunk_hashes[[selector_index]] <- c(
            chunk_hashes[[selector_index]],
            wlv_runtime_snapshot_numeric_chunk_sha256(current)
          )
          if (length(buffer) == hash_chunk_values) {
            buffer <- vector(storage, 0L)
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
      chunk_hashes[[selector_index]],
      storage = storage
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
  if (identical(observed, axes)) {
    return(value)
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
      wlv_runtime_snapshot_state_codec_validate(
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
      wlv_runtime_snapshot_state_codec_validate(
        entry$state,
        target_key = entry$key,
        axes = contract$axes,
        state_key = wlv_semantic_state_key(entry$key),
        target_value = entry$value
      )
    } else {
      if (!is.null(entry$value)) {
        stop("IO snapshot entries must not duplicate public matrix values.", call. = FALSE)
      }
      wlv_runtime_snapshot_state_codec_validate(
        entry$state,
        target_key = entry$key,
        axes = contract$axes,
        state_key = wlv_semantic_state_key(entry$key)
      )
    }
  }
  # Every resource state was authenticated against its recorded hash in the
  # loop above. Rebuilding bindings can therefore reuse that authenticated
  # hash instead of regenerating millions of logical Cartesian rows.
  expected_bindings <- wlv_runtime_snapshot_state_bindings(
    snapshot,
    verify_resource_states = FALSE
  )
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

wlv_runtime_snapshot_authenticate_bound_files <- function(
    snapshot,
    root,
    validate_snapshot = TRUE) {
  if (!is.logical(validate_snapshot) || length(validate_snapshot) != 1L ||
      is.na(validate_snapshot)) {
    stop("Runtime snapshot authentication flag is invalid.", call. = FALSE)
  }
  if (isTRUE(validate_snapshot)) {
    wlv_runtime_snapshot_validate(snapshot)
  }
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

wlv_runtime_snapshot_state_commitment_from_chunks <- function(codec, chunks) {
  codec <- wlv_runtime_snapshot_state_pack(codec)
  axes <- codec$axes
  target_key <- codec$target_key
  state_version <- codec$state_version
  columns <- c(axes, "state")
  chunk_rows <- 65536L
  expected_chunks <- if (codec$row_count) {
    ceiling(codec$row_count / chunk_rows)
  } else {
    0
  }
  valid_chunks <- is.list(chunks) && identical(names(chunks), columns) &&
    length(chunks) == length(columns)
  if (isTRUE(valid_chunks)) {
    valid_chunks <- all(vapply(chunks, function(current) {
      is.character(current) && length(current) == expected_chunks &&
        is.null(attributes(current)) && !anyNA(current) &&
        all(grepl("^[0-9a-f]{64}$", current))
    }, logical(1L)))
  }
  if (!isTRUE(valid_chunks)) {
    stop("Runtime semantic-state commitment chunks are invalid.", call. = FALSE)
  }
  payload <- list(
    version = "wlv-runtime-state-commitment/1.0.0",
    target_key = wlv_runtime_snapshot_materialize_character(target_key)[[1L]],
    axes = wlv_runtime_snapshot_materialize_character(axes),
    state_version = wlv_runtime_snapshot_materialize_character(
      state_version
    )[[1L]],
    row_count = codec$row_count,
    chunks = chunks
  )
  wlv_publication_sha256_raw(serialize(payload, NULL, version = 3L))
}

wlv_runtime_snapshot_state_commitment_sha256 <- function(value) {
  codec <- wlv_runtime_snapshot_state_pack(value)
  columns <- c(codec$axes, "state")
  chunk_rows <- 65536L
  starts <- if (codec$row_count) {
    seq.int(1, codec$row_count, by = chunk_rows)
  } else {
    integer()
  }
  chunks <- stats::setNames(lapply(columns, function(column) {
    character(length(starts))
  }), columns)
  for (column in columns) {
    for (chunk_index in seq_along(starts)) {
      start <- starts[[chunk_index]]
      end <- min(codec$row_count, start + chunk_rows - 1L)
      source <- if (identical(codec$encoding, "rows")) {
        codec$rows[[column]][start:end]
      } else {
        wlv_runtime_snapshot_state_cartesian_column_unchecked(
          codec,
          column,
          start,
          end
        )
      }
      current <- wlv_runtime_snapshot_materialize_character(
        source
      )
      chunks[[column]][[chunk_index]] <- wlv_publication_sha256_raw(
        serialize(current, NULL, version = 3L)
      )
      rm(source, current)
    }
  }
  wlv_runtime_snapshot_state_commitment_from_chunks(codec, chunks)
}

wlv_runtime_snapshot_state_sha256 <- function(value) {
  wlv_runtime_snapshot_state_commitment_sha256(value)
}

wlv_runtime_snapshot_resource_commitment <- function(
    id,
    entry,
    verify_state = TRUE) {
  expected <- c(
    "key", "partition", "producer", "state_producer", "contract_sha256",
    "axes_sha256", "value_sha256", "state_sha256", "value", "state"
  )
  if (!is.character(id) || length(id) != 1L || is.na(id) || !nzchar(id) ||
      !is.list(entry) || !identical(names(entry), expected)) {
    stop("Runtime snapshot resource commitment input is invalid.", call. = FALSE)
  }
  value_metadata <- if (is.null(entry$value)) {
    list(present = FALSE)
  } else {
    labels <- dimnames(entry$value)
    if (!is.null(labels)) {
      labels <- wlv_runtime_snapshot_materialize_labels(labels)
    }
    extra_attributes <- attributes(entry$value)
    extra_attributes[c("dim", "dimnames")] <- NULL
    list(
      present = TRUE,
      storage = typeof(entry$value),
      dimensions = if (is.null(dim(entry$value))) {
        NULL
      } else {
        as.integer(dim(entry$value))
      },
      dimnames = labels,
      extra_attributes_sha256 = wlv_runtime_snapshot_value_sha256(
        extra_attributes
      )
    )
  }
  if (!is.logical(verify_state) || length(verify_state) != 1L ||
      is.na(verify_state)) {
    stop("Runtime snapshot resource state-validation flag is invalid.",
      call. = FALSE
    )
  }
  state_metadata <- wlv_runtime_snapshot_state_metadata(
    entry$state,
    if (isTRUE(verify_state)) NULL else entry$state_sha256
  )
  if (isTRUE(verify_state) && !identical(
        state_metadata$state_sha256,
        entry$state_sha256
      )) {
    stop("Runtime snapshot resource state commitment is invalid.",
      call. = FALSE
    )
  }
  list(
    id = id,
    key = entry$key,
    partition = entry$partition,
    producer = entry$producer,
    state_producer = entry$state_producer,
    contract_sha256 = entry$contract_sha256,
    axes_sha256 = entry$axes_sha256,
    value_sha256 = entry$value_sha256,
    state_sha256 = entry$state_sha256,
    value_metadata = value_metadata,
    state_metadata = state_metadata
  )
}

wlv_runtime_snapshot_logical_commitment_sha256 <- function(
    snapshot,
    verify_resource_states = TRUE) {
  expected <- c(
    "version", "method", "source", "partitions", "compatibility",
    "io_artifacts", "panel_artifacts", "panel_states",
    "panel_provenance", "parent_imports", "parent_imports_sha256",
    "resources", "state_bindings"
  )
  if (!is.list(snapshot) || !identical(names(snapshot), expected) ||
      !is.list(snapshot$panel_states) || is.null(names(snapshot$panel_states)) ||
      !is.list(snapshot$resources) || is.null(names(snapshot$resources))) {
    stop("Runtime snapshot commitment input is invalid.", call. = FALSE)
  }
  if (!is.logical(verify_resource_states) ||
      length(verify_resource_states) != 1L || is.na(verify_resource_states)) {
    stop("Runtime snapshot commitment validation flag is invalid.",
      call. = FALSE
    )
  }
  panel_states_sha256 <- vapply(
    snapshot$panel_states,
    wlv_runtime_snapshot_state_commitment_sha256,
    character(1L)
  )
  resources <- lapply(names(snapshot$resources), function(id) {
    wlv_runtime_snapshot_resource_commitment(
      id,
      snapshot$resources[[id]],
      verify_state = verify_resource_states
    )
  })
  names(resources) <- names(snapshot$resources)
  payload <- list(
    version = "wlv-runtime-snapshot-commitment/1.1.0",
    snapshot_version = snapshot$version,
    method = snapshot$method,
    source = snapshot$source,
    partitions = snapshot$partitions,
    compatibility_sha256 = wlv_runtime_snapshot_value_sha256(
      snapshot$compatibility
    ),
    io_artifacts_sha256 = wlv_runtime_snapshot_value_sha256(
      snapshot$io_artifacts
    ),
    panel_artifacts_sha256 = wlv_runtime_snapshot_value_sha256(
      snapshot$panel_artifacts
    ),
    panel_states_sha256 = panel_states_sha256,
    panel_provenance_sha256 = wlv_runtime_snapshot_value_sha256(
      snapshot$panel_provenance
    ),
    parent_imports_sha256 = wlv_runtime_snapshot_value_sha256(
      snapshot$parent_imports
    ),
    recorded_parent_imports_sha256 = snapshot$parent_imports_sha256,
    resources = resources,
    state_bindings_sha256 = wlv_runtime_snapshot_value_sha256(
      snapshot$state_bindings
    )
  )
  wlv_publication_sha256_raw(serialize(payload, NULL, version = 3L))
}

wlv_runtime_snapshot_receipt_version <- function() {
  "wlv-runtime-snapshot-receipt/1.1.0"
}

wlv_runtime_snapshot_receipt_files <- function(snapshot, snapshot_sha256) {
  records <- rbind(
    data.frame(
      path = wlv_runtime_snapshot_filename(),
      sha256 = snapshot_sha256,
      stringsAsFactors = FALSE
    ),
    data.frame(
      path = c(
        snapshot$panel_artifacts$path,
        paste0(snapshot$panel_artifacts$path, ".meta"),
        snapshot$io_artifacts$path,
        paste0(snapshot$io_artifacts$path, ".meta")
      ),
      sha256 = c(
        snapshot$panel_artifacts$sha256,
        snapshot$panel_artifacts$meta_sha256,
        snapshot$io_artifacts$sha256,
        snapshot$io_artifacts$meta_sha256
      ),
      stringsAsFactors = FALSE
    )
  )
  records <- records[order(records$path, method = "radix"), , drop = FALSE]
  row.names(records) <- NULL
  if (anyDuplicated(records$path)) {
    stop("Runtime snapshot receipt paths are not unique.", call. = FALSE)
  }
  records
}

wlv_runtime_snapshot_receipt_from_sha256 <- function(
    snapshot,
    snapshot_sha256,
    verify_resource_states = TRUE) {
  records <- wlv_runtime_snapshot_receipt_files(
    snapshot,
    snapshot_sha256
  )
  structure(list(
    version = wlv_runtime_snapshot_receipt_version(),
    method = snapshot$method,
    source = snapshot$source,
    partitions = snapshot$partitions,
    snapshot_commitment_sha256 =
      wlv_runtime_snapshot_logical_commitment_sha256(
        snapshot,
        verify_resource_states = verify_resource_states
      ),
    files = records
  ), class = "wlv_runtime_snapshot_receipt")
}

wlv_runtime_snapshot_receipt <- function(
    snapshot,
    path,
    verify_resource_states = TRUE) {
  wlv_runtime_snapshot_receipt_from_sha256(
    snapshot,
    wlv_publication_file_sha256(path),
    verify_resource_states = verify_resource_states
  )
}

wlv_runtime_snapshot_receipt_bindings_attribute <- function() {
  "wlv_runtime_snapshot_binding_expectations"
}

wlv_runtime_snapshot_receipt_seal_attribute <- function() {
  "wlv_runtime_snapshot_receipt_seal_sha256"
}

wlv_runtime_snapshot_binding_expectations_commitment <- function(value) {
  panel_states_sha256 <- vapply(
    value$panel_states,
    wlv_runtime_snapshot_state_commitment_sha256,
    character(1L)
  )
  list(
    version = value$version,
    snapshot_sha256 = value$snapshot_sha256,
    method = value$method,
    source = value$source,
    partitions = value$partitions,
    panel_states_sha256 = panel_states_sha256,
    panel_provenance_sha256 = wlv_runtime_snapshot_value_sha256(
      value$panel_provenance
    ),
    io_sha256 = wlv_runtime_snapshot_value_sha256(value$io),
    lambda_axes_sha256 = wlv_runtime_snapshot_value_sha256(value$lambda_axes)
  )
}

wlv_runtime_snapshot_receipt_seal_sha256 <- function(receipt, expectations) {
  payload <- list(
    version = "wlv-runtime-snapshot-receipt-seal/1.0.0",
    receipt = list(
      version = receipt$version,
      method = receipt$method,
      source = receipt$source,
      partitions = receipt$partitions,
      snapshot_commitment_sha256 = receipt$snapshot_commitment_sha256,
      files = receipt$files
    ),
    expectations = wlv_runtime_snapshot_binding_expectations_commitment(
      expectations
    )
  )
  wlv_publication_sha256_raw(serialize(payload, NULL, version = 3L))
}

wlv_runtime_snapshot_receipt_attach_bindings <- function(
    receipt,
    snapshot,
    snapshot_sha256) {
  expectations <- wlv_runtime_snapshot_binding_expectations(
    snapshot,
    snapshot_sha256
  )
  wlv_runtime_snapshot_binding_expectations_assert(
    expectations,
    validate_panel_states = FALSE
  )
  attr(
    receipt,
    wlv_runtime_snapshot_receipt_bindings_attribute()
  ) <- expectations
  attr(
    receipt,
    wlv_runtime_snapshot_receipt_seal_attribute()
  ) <- wlv_runtime_snapshot_receipt_seal_sha256(receipt, expectations)
  receipt
}

wlv_runtime_snapshot_receipt_assert <- function(
    receipt,
    method,
    source,
    partitions,
    artifacts = NULL,
    staging = NULL) {
  if (!inherits(receipt, "wlv_runtime_snapshot_receipt") ||
      !is.list(receipt) || !identical(
        names(receipt),
        c(
          "version", "method", "source", "partitions",
          "snapshot_commitment_sha256", "files"
        )
      ) || !identical(class(receipt), "wlv_runtime_snapshot_receipt") ||
      !identical(receipt$version, wlv_runtime_snapshot_receipt_version()) ||
      !is.character(receipt$snapshot_commitment_sha256) ||
      length(receipt$snapshot_commitment_sha256) != 1L ||
      is.na(receipt$snapshot_commitment_sha256) ||
      !grepl("^[0-9a-f]{64}$", receipt$snapshot_commitment_sha256)) {
    stop("Runtime snapshot receipt is invalid.", call. = FALSE)
  }
  allowed_attributes <- c(
    "names", "class", wlv_runtime_snapshot_receipt_bindings_attribute(),
    wlv_runtime_snapshot_receipt_seal_attribute()
  )
  if (any(!names(attributes(receipt)) %in% allowed_attributes)) {
    stop("Runtime snapshot receipt attributes are invalid.", call. = FALSE)
  }
  method <- wlv_runtime_snapshot_scalar(method, "receipt method")
  source <- wlv_runtime_snapshot_scalar(source, "receipt source")
  partitions <- sort(as.character(partitions), method = "radix")
  if (!identical(receipt$method, method) || !identical(receipt$source, source) ||
      !identical(receipt$partitions, partitions)) {
    stop("Runtime snapshot receipt identity differs from staged results.",
      call. = FALSE
    )
  }
  files <- receipt$files
  if (!is.data.frame(files) || !identical(names(files), c("path", "sha256")) ||
      !nrow(files) || anyNA(files) || any(!nzchar(as.matrix(files))) ||
      anyDuplicated(files$path) || !identical(
        as.character(files$path),
        sort(as.character(files$path), method = "radix")
      ) || any(basename(files$path) != files$path) ||
      any(!grepl("^[0-9a-f]{64}$", files$sha256)) ||
      sum(files$path == wlv_runtime_snapshot_filename()) != 1L ||
      nrow(files) != 1L + 2L * (2L + length(partitions))) {
    stop("Runtime snapshot receipt file inventory is invalid.", call. = FALSE)
  }
  snapshot_row <- match(wlv_runtime_snapshot_filename(), files$path)
  expected_snapshot_sha256 <- files$sha256[[snapshot_row]]
  cached_expectations <- attr(
    receipt,
    wlv_runtime_snapshot_receipt_bindings_attribute(),
    exact = TRUE
  )
  cached_seal <- attr(
    receipt,
    wlv_runtime_snapshot_receipt_seal_attribute(),
    exact = TRUE
  )
  if (xor(is.null(cached_expectations), is.null(cached_seal))) {
    stop("Runtime snapshot receipt cache is incomplete.", call. = FALSE)
  }
  if (!is.null(cached_expectations)) {
    if (!is.character(cached_seal) || length(cached_seal) != 1L ||
        is.na(cached_seal) || !grepl("^[0-9a-f]{64}$", cached_seal)) {
      stop("Runtime snapshot receipt seal is invalid.", call. = FALSE)
    }
    wlv_runtime_snapshot_binding_expectations_assert(
      cached_expectations,
      validate_panel_states = FALSE
    )
    observed_seal <- wlv_runtime_snapshot_receipt_seal_sha256(
      receipt,
      cached_expectations
    )
    if (!identical(observed_seal, cached_seal)) {
      stop("Runtime snapshot receipt seal authentication failed.", call. = FALSE)
    }
    if (!identical(
      cached_expectations$snapshot_sha256,
      expected_snapshot_sha256
    ) || !identical(cached_expectations$method, method) ||
        !identical(cached_expectations$source, source) ||
        !identical(cached_expectations$partitions, partitions)) {
      stop(
        "Runtime snapshot receipt bindings differ from the authenticated envelope.",
        call. = FALSE
      )
    }
  }
  if (!is.null(artifacts)) {
    if (!is.list(artifacts) || !length(artifacts)) {
      stop("Validated staged artifacts are invalid.", call. = FALSE)
    }
    observed_paths <- vapply(artifacts, `[[`, character(1L), "path")
    observed_sha256 <- vapply(artifacts, `[[`, character(1L), "sha256")
    positions <- match(files$path, observed_paths)
    if (anyNA(positions) || !identical(
      unname(observed_sha256[positions]),
      as.character(files$sha256)
    )) {
      stop(
        "Runtime snapshot receipt does not authenticate the staged artifacts.",
        call. = FALSE
      )
    }
  }
  if (is.null(staging)) {
    return(invisible(receipt))
  }
  if (is.null(artifacts)) {
    stop(
      "A persisted runtime snapshot receipt requires authenticated artifacts.",
      call. = FALSE
    )
  }
  staging <- normalizePath(staging, winslash = "/", mustWork = TRUE)
  snapshot_path <- file.path(staging, wlv_runtime_snapshot_filename())
  if (!file.exists(snapshot_path) || isTRUE(file.info(snapshot_path)$isdir) ||
      is.na(snapshot_row)) {
    stop("Runtime snapshot receipt lacks its persisted envelope.", call. = FALSE)
  }
  if (!is.null(cached_expectations)) {
    current_sha256 <- wlv_publication_file_sha256(snapshot_path)
    if (!identical(current_sha256, expected_snapshot_sha256)) {
      stop(
        "Runtime snapshot receipt failed persisted envelope authentication.",
        call. = FALSE
      )
    }
    return(cached_expectations)
  }
  before_sha256 <- wlv_publication_file_sha256(snapshot_path)
  if (!identical(before_sha256, expected_snapshot_sha256)) {
    stop(
      "Runtime snapshot receipt failed persisted envelope authentication.",
      call. = FALSE
    )
  }
  snapshot <- tryCatch(
    readRDS(snapshot_path),
    error = function(error) {
      stop(
        sprintf("Cannot read runtime snapshot receipt envelope: %s",
          conditionMessage(error)
        ),
        call. = FALSE
      )
    }
  )
  after_sha256 <- wlv_publication_file_sha256(snapshot_path)
  if (!identical(after_sha256, expected_snapshot_sha256)) {
    stop(
      "Runtime snapshot receipt envelope changed while it was read.",
      call. = FALSE
    )
  }
  if (!is.list(snapshot) || !identical(
        names(snapshot),
        c(
          "version", "method", "source", "partitions", "compatibility",
          "io_artifacts", "panel_artifacts", "panel_states",
          "panel_provenance", "parent_imports", "parent_imports_sha256",
          "resources", "state_bindings"
        )
      ) || !identical(snapshot$version, wlv_runtime_snapshot_version()) ||
      !identical(snapshot$method, method) || !identical(snapshot$source, source) ||
      !identical(snapshot$partitions, partitions)) {
    stop("Runtime snapshot receipt envelope is invalid.", call. = FALSE)
  }
  wlv_runtime_snapshot_validate(snapshot)
  observed_commitment_sha256 <-
    wlv_runtime_snapshot_logical_commitment_sha256(
      snapshot,
      verify_resource_states = FALSE
    )
  if (!identical(
        observed_commitment_sha256,
        receipt$snapshot_commitment_sha256
      )) {
    stop(
      "Runtime snapshot receipt logical commitment differs from its envelope.",
      call. = FALSE
    )
  }
  expected_files <- wlv_runtime_snapshot_receipt_files(
    snapshot,
    expected_snapshot_sha256
  )
  if (!identical(expected_files, files)) {
    stop("Runtime snapshot receipt inventory differs from its envelope.",
      call. = FALSE
    )
  }
  expectations <- wlv_runtime_snapshot_binding_expectations(
    snapshot,
    expected_snapshot_sha256
  )
  rm(snapshot)
  invisible(gc(full = FALSE))
  expectations
}

wlv_runtime_snapshot_binding_expectations <- function(
    snapshot,
    snapshot_sha256) {
  if (!is.character(snapshot_sha256) || length(snapshot_sha256) != 1L ||
      is.na(snapshot_sha256) || !grepl("^[0-9a-f]{64}$", snapshot_sha256)) {
    stop("Runtime snapshot binding expectations require an authenticated hash.",
      call. = FALSE
    )
  }
  io_rows <- lapply(names(snapshot$resources), function(id) {
    entry <- snapshot$resources[[id]]
    if (!startsWith(entry$key, "io/")) {
      return(NULL)
    }
    data.frame(
      partition = entry$partition,
      key = entry$key,
      contract_sha256 = entry$contract_sha256,
      axes_sha256 = entry$axes_sha256,
      value_sha256 = entry$value_sha256,
      stringsAsFactors = FALSE
    )
  })
  io_rows <- io_rows[!vapply(io_rows, is.null, logical(1L))]
  io <- do.call(rbind, io_rows)
  row.names(io) <- NULL
  lambda_axes <- lapply(snapshot$partitions, function(partition) {
    entry <- snapshot$resources[[paste(
      "intermediate/lambda",
      partition,
      sep = "\034"
    )]]
    list(
      year = as.character(dimnames(entry$value)$year),
      input = as.character(dimnames(entry$value)$input)
    )
  })
  names(lambda_axes) <- snapshot$partitions
  structure(list(
    version = "wlv-runtime-snapshot-bindings/1.0.0",
    snapshot_sha256 = snapshot_sha256,
    method = snapshot$method,
    source = snapshot$source,
    partitions = snapshot$partitions,
    panel_states = snapshot$panel_states,
    panel_provenance = snapshot$panel_provenance,
    io = io,
    lambda_axes = lambda_axes
  ), class = "wlv_runtime_snapshot_binding_expectations")
}

wlv_runtime_snapshot_panel_state_shape_assert <- function(
    value,
    target_key,
    axes) {
  allowed_attributes <- c(
    "names", "class", "row.names", "target_key", "axes", "version"
  )
  if (!is.data.frame(value) || !identical(
        class(value),
        c("wlv_semantic_state", "data.frame")
      ) || !setequal(names(attributes(value)), allowed_attributes) ||
      !identical(attr(value, "target_key", exact = TRUE), target_key) ||
      !identical(attr(value, "axes", exact = TRUE), axes) ||
      !identical(
        attr(value, "version", exact = TRUE),
        wlv_semantic_state_version()
      ) || !identical(names(value), c(axes, "state")) ||
      any(!vapply(value, is.character, logical(1L)))) {
    stop("Runtime snapshot binding panel state is invalid.", call. = FALSE)
  }
  invisible(value)
}

wlv_runtime_snapshot_binding_expectations_assert <- function(
    value,
    validate_panel_states = TRUE) {
  if (!is.logical(validate_panel_states) ||
      length(validate_panel_states) != 1L || is.na(validate_panel_states)) {
    stop("Runtime snapshot binding validation flag is invalid.", call. = FALSE)
  }
  if (!inherits(value, "wlv_runtime_snapshot_binding_expectations") ||
      !is.list(value) ||
      !identical(class(value), "wlv_runtime_snapshot_binding_expectations") ||
      !setequal(names(attributes(value)), c("names", "class")) ||
      !identical(names(attributes(value$panel_states)), "names") || !identical(
        names(value),
        c(
          "version", "snapshot_sha256", "method", "source", "partitions",
          "panel_states", "panel_provenance", "io", "lambda_axes"
        )
      ) || !identical(
        value$version,
        "wlv-runtime-snapshot-bindings/1.0.0"
      ) || !is.character(value$snapshot_sha256) ||
      length(value$snapshot_sha256) != 1L || is.na(value$snapshot_sha256) ||
      !grepl("^[0-9a-f]{64}$", value$snapshot_sha256) ||
      !is.character(value$method) || length(value$method) != 1L ||
      is.na(value$method) || !nzchar(value$method) ||
      !is.character(value$source) || length(value$source) != 1L ||
      is.na(value$source) || !nzchar(value$source) ||
      !is.character(value$partitions) || !length(value$partitions) ||
      anyNA(value$partitions) || any(!nzchar(value$partitions)) ||
      anyDuplicated(value$partitions) || !identical(
        value$partitions,
        sort(value$partitions, method = "radix")
      ) || !is.list(value$panel_states) || !identical(
        names(value$panel_states),
        names(wlv_runtime_snapshot_panel_definitions())
      ) || !is.data.frame(value$panel_provenance) ||
      !is.data.frame(value$io) || !identical(
        names(value$io),
        c(
          "partition", "key", "contract_sha256", "axes_sha256",
          "value_sha256"
        )
      ) || !is.list(value$lambda_axes) ||
      !identical(names(value$lambda_axes), value$partitions)) {
    stop("Runtime snapshot binding expectations are invalid.", call. = FALSE)
  }
  definitions <- wlv_runtime_snapshot_panel_definitions()
  for (artifact in names(definitions)) {
    definition <- definitions[[artifact]]
    if (isTRUE(validate_panel_states)) {
      wlv_semantic_state_validate(
        value$panel_states[[artifact]],
        target_key = definition$target_key,
        axes = definition$axes,
        state_key = wlv_semantic_state_key(definition$target_key)
      )
    } else {
      wlv_runtime_snapshot_panel_state_shape_assert(
        value$panel_states[[artifact]],
        definition$target_key,
        definition$axes
      )
    }
  }
  provenance_columns <- c(
    "artifact", "indicator", "key", "producer", "state_producer",
    "contract_sha256", "axes_sha256", "value_sha256", "state_sha256"
  )
  expected_io_partitions <- rep(
    value$partitions,
    each = length(wlv_runtime_snapshot_io_resources())
  )
  expected_io_keys <- rep(
    paste0("io/", wlv_runtime_snapshot_io_resources()),
    times = length(value$partitions)
  )
  if (!identical(names(value$panel_provenance), provenance_columns) ||
      !nrow(value$panel_provenance) || anyNA(value$panel_provenance) ||
      any(!nzchar(as.matrix(value$panel_provenance))) ||
      any(!value$panel_provenance$artifact %in% names(definitions)) ||
      anyDuplicated(paste(
        value$panel_provenance$artifact,
        value$panel_provenance$indicator,
        sep = "\034"
      )) || any(!grepl(
        "^[0-9a-f]{64}$",
        unlist(value$panel_provenance[c(
          "contract_sha256", "axes_sha256", "value_sha256", "state_sha256"
        )], use.names = FALSE)
      )) || !identical(as.character(value$io$partition), expected_io_partitions) ||
      !identical(as.character(value$io$key), expected_io_keys) ||
      anyNA(value$io) || any(!nzchar(as.matrix(value$io))) ||
      any(!grepl(
        "^[0-9a-f]{64}$",
        unlist(value$io[c(
          "contract_sha256", "axes_sha256", "value_sha256"
        )], use.names = FALSE)
      ))) {
    stop("Runtime snapshot binding expectations are invalid.", call. = FALSE)
  }
  for (partition in value$partitions) {
    axes <- value$lambda_axes[[partition]]
    if (!is.list(axes) || !identical(names(axes), c("year", "input")) ||
        any(!vapply(axes, is.character, logical(1L))) ||
        any(vapply(axes, function(labels) {
          !length(labels) || anyNA(labels) || any(!nzchar(labels)) ||
            anyDuplicated(labels)
        }, logical(1L)))) {
      stop("Runtime snapshot binding expectations are invalid.", call. = FALSE)
    }
  }
  invisible(value)
}

wlv_runtime_snapshot_io_binding_expectations <- function(value) {
  wlv_runtime_snapshot_binding_expectations_assert(
    value,
    validate_panel_states = FALSE
  )
  structure(list(
    version = "wlv-runtime-snapshot-io-bindings/1.0.0",
    snapshot_sha256 = value$snapshot_sha256,
    method = value$method,
    source = value$source,
    partitions = value$partitions,
    io = value$io,
    lambda_axes = value$lambda_axes
  ), class = "wlv_runtime_snapshot_io_binding_expectations")
}

wlv_runtime_snapshot_io_binding_expectations_assert <- function(value) {
  if (!inherits(value, "wlv_runtime_snapshot_io_binding_expectations") ||
      !is.list(value) || !identical(
        class(value),
        "wlv_runtime_snapshot_io_binding_expectations"
      ) || !setequal(names(attributes(value)), c("names", "class")) || !identical(
        names(value),
        c(
          "version", "snapshot_sha256", "method", "source", "partitions",
          "io", "lambda_axes"
        )
      ) || !identical(
        value$version,
        "wlv-runtime-snapshot-io-bindings/1.0.0"
      ) || !is.character(value$snapshot_sha256) ||
      length(value$snapshot_sha256) != 1L || is.na(value$snapshot_sha256) ||
      !grepl("^[0-9a-f]{64}$", value$snapshot_sha256) ||
      !is.character(value$method) || length(value$method) != 1L ||
      is.na(value$method) || !nzchar(value$method) ||
      !is.character(value$source) || length(value$source) != 1L ||
      is.na(value$source) || !nzchar(value$source) ||
      !is.character(value$partitions) || !length(value$partitions) ||
      anyNA(value$partitions) || any(!nzchar(value$partitions)) ||
      anyDuplicated(value$partitions) || !identical(
        value$partitions,
        sort(value$partitions, method = "radix")
      ) || !is.data.frame(value$io) || !identical(
        names(value$io),
        c(
          "partition", "key", "contract_sha256", "axes_sha256",
          "value_sha256"
        )
      ) || !is.list(value$lambda_axes) ||
      !identical(names(value$lambda_axes), value$partitions)) {
    stop("Runtime snapshot IO binding expectations are invalid.", call. = FALSE)
  }
  expected_io_partitions <- rep(
    value$partitions,
    each = length(wlv_runtime_snapshot_io_resources())
  )
  expected_io_keys <- rep(
    paste0("io/", wlv_runtime_snapshot_io_resources()),
    times = length(value$partitions)
  )
  if (!identical(as.character(value$io$partition), expected_io_partitions) ||
      !identical(as.character(value$io$key), expected_io_keys) ||
      anyNA(value$io) || any(!nzchar(as.matrix(value$io))) ||
      any(!grepl(
        "^[0-9a-f]{64}$",
        unlist(value$io[c(
          "contract_sha256", "axes_sha256", "value_sha256"
        )], use.names = FALSE)
      ))) {
    stop("Runtime snapshot IO binding expectations are invalid.", call. = FALSE)
  }
  for (partition in value$partitions) {
    axes <- value$lambda_axes[[partition]]
    if (!is.list(axes) || !identical(names(axes), c("year", "input")) ||
        any(!vapply(axes, is.character, logical(1L))) ||
        any(vapply(axes, function(labels) {
          !length(labels) || anyNA(labels) || any(!nzchar(labels)) ||
            anyDuplicated(labels)
        }, logical(1L)))) {
      stop("Runtime snapshot IO binding expectations are invalid.", call. = FALSE)
    }
  }
  invisible(value)
}

wlv_runtime_snapshot_validate_materialized_panel <- function(
    expectations,
    artifact,
    value) {
  wlv_runtime_snapshot_binding_expectations_assert(
    expectations,
    validate_panel_states = FALSE
  )
  definitions <- wlv_runtime_snapshot_panel_definitions()
  definition <- definitions[[artifact]]
  if (is.null(definition)) {
    stop(sprintf("Unknown runtime panel artifact `%s`.", artifact), call. = FALSE)
  }
  labels <- dimnames(value)
  observed_axes <- names(labels)
  if (!is.numeric(value) || !is.array(value) ||
      length(dim(value)) != length(definition$axes) || is.null(labels) ||
      any(vapply(labels, is.null, logical(1L))) ||
      (!is.null(observed_axes) && !identical(observed_axes, definition$axes))) {
    stop(
      sprintf("Runtime snapshot artifact `%s` axes are incompatible.", artifact),
      call. = FALSE
    )
  }
  names(labels) <- definition$axes
  indicator_axis <- match("indicator", definition$axes)
  indicators <- labels[[indicator_axis]]
  provenance <- expectations$panel_provenance[
    expectations$panel_provenance$artifact == artifact,
    ,
    drop = FALSE
  ]
  panel_state <- expectations$panel_states[[artifact]]
  wlv_semantic_state_validate(
    panel_state,
    target_key = definition$target_key,
    axes = definition$axes,
    state_key = wlv_semantic_state_key(definition$target_key)
  )
  state_positions <- wlv_semantic_state_linear_indices(panel_state, value)
  wlv_semantic_assert_ordinary_na_covered(value, state_positions)
  if (!identical(as.character(provenance$indicator), indicators)) {
    stop(
      sprintf("Runtime snapshot panel provenance differs for `%s`.", artifact),
      call. = FALSE
    )
  }
  target_axes <- setdiff(definition$axes, "indicator")
  expected_axes_sha256 <- wlv_runtime_snapshot_axis_labels_sha256(
    labels[target_axes],
    target_axes
  )
  if (any(provenance$axes_sha256 != expected_axes_sha256)) {
    stop(
      sprintf("Runtime snapshot panel axes provenance differs for `%s`.", artifact),
      call. = FALSE
    )
  }
  for (indicator in indicators) {
    row <- provenance[provenance$indicator == indicator, , drop = FALSE]
    indices <- rep(list(TRUE), length(definition$axes))
    indices[[indicator_axis]] <- match(indicator, indicators)
    selected <- do.call(`[`, c(list(value), indices, list(drop = FALSE)))
    selected <- array(
      selected,
      dim = dim(value)[match(target_axes, definition$axes)],
      dimnames = labels[target_axes]
    )
    state <- wlv_runtime_snapshot_panel_state_slice(
      panel_state,
      artifact,
      indicator,
      selected
    )
    if (nrow(row) != 1L || !identical(
      row$value_sha256[[1L]],
      wlv_runtime_snapshot_value_sha256(selected)
    )) {
      stop(
        sprintf(
          "Runtime snapshot panel generation differs for `%s/%s`.",
          artifact,
          indicator
        ),
        call. = FALSE
      )
    }
    if (!identical(
      row$state_sha256[[1L]],
      wlv_runtime_snapshot_value_sha256(state)
    )) {
      stop(
        sprintf(
          "Runtime snapshot panel state generation differs for `%s/%s`.",
          artifact,
          indicator
        ),
        call. = FALSE
      )
    }
    rm(selected, state)
  }
  invisible(value)
}

wlv_runtime_snapshot_validate_materialized_io <- function(
    expectations,
    partition,
    value) {
  if (inherits(expectations, "wlv_runtime_snapshot_binding_expectations")) {
    expectations <- wlv_runtime_snapshot_io_binding_expectations(expectations)
  }
  wlv_runtime_snapshot_io_binding_expectations_assert(expectations)
  partition <- wlv_runtime_snapshot_scalar(partition, "partition")
  if (!partition %in% expectations$partitions) {
    stop(sprintf("Unknown runtime IO partition `%s`.", partition), call. = FALSE)
  }
  axes <- c("year", "variable", "input", "output")
  labels <- dimnames(value)
  observed_axes <- names(labels)
  if (!is.numeric(value) || !is.array(value) || length(dim(value)) != 4L ||
      is.null(labels) || any(vapply(labels, is.null, logical(1L))) ||
      (!is.null(observed_axes) && !identical(observed_axes, axes))) {
    stop(
      sprintf("Runtime snapshot artifact `IO/%s` axes are incompatible.", partition),
      call. = FALSE
    )
  }
  names(labels) <- axes
  resources <- wlv_runtime_snapshot_io_resources()
  if (!identical(labels$variable, resources)) {
    stop(
      sprintf("Runtime snapshot IO resources differ for `%s`.", partition),
      call. = FALSE
    )
  }
  slice_axes <- c("year", "input", "output")
  slice_axes_sha256 <- wlv_runtime_snapshot_axis_labels_sha256(
    labels[slice_axes],
    slice_axes
  )
  for (resource in resources) {
    key <- paste0("io/", resource)
    row <- expectations$io[
      expectations$io$partition == partition & expectations$io$key == key,
      ,
      drop = FALSE
    ]
    resource_index <- match(resource, resources)
    value_sha256 <- wlv_runtime_snapshot_second_axis_slice_sha256(
      value,
      resource_index,
      labels[slice_axes]
    )
    if (nrow(row) != 1L || !identical(
      row$contract_sha256[[1L]],
      wlv_runtime_snapshot_contract_sha256(
        wlv_runtime_snapshot_contract(key)
      )
    ) || !identical(row$axes_sha256[[1L]], slice_axes_sha256) ||
        !identical(
          row$value_sha256[[1L]],
          value_sha256
        )) {
      stop(
        sprintf(
          "Runtime snapshot IO generation differs for `%s[%s]`.",
          key,
          partition
        ),
        call. = FALSE
      )
    }
  }
  lambda_axes <- expectations$lambda_axes[[partition]]
  if (!identical(lambda_axes$year, labels$year) ||
      !identical(lambda_axes$input, labels$input)) {
    stop(
      sprintf("Runtime snapshot lambda axes differ for `%s`.", partition),
      call. = FALSE
    )
  }
  invisible(value)
}

wlv_runtime_snapshot_write <- function(
    snapshot,
    staging,
    validate_snapshot = TRUE,
    authenticate_bound_files = TRUE,
    return_receipt = FALSE,
    defer_verification = FALSE) {
  flags <- list(
    validate_snapshot = validate_snapshot,
    authenticate_bound_files = authenticate_bound_files,
    return_receipt = return_receipt,
    defer_verification = defer_verification
  )
  if (any(!vapply(flags, function(flag) {
    is.logical(flag) && length(flag) == 1L && !is.na(flag)
  }, logical(1L)))) {
    stop("Runtime snapshot write flags are invalid.", call. = FALSE)
  }
  if (isTRUE(validate_snapshot)) {
    wlv_runtime_snapshot_validate(snapshot)
  }
  if (isTRUE(defer_verification) &&
      (!isTRUE(return_receipt) || isTRUE(authenticate_bound_files))) {
    stop(
      paste0(
        "Deferred runtime snapshot verification requires a receipt and ",
        "cannot authenticate bound files before the round trip."
      ),
      call. = FALSE
    )
  }
  staging <- normalizePath(staging, winslash = "/", mustWork = TRUE)
  path <- file.path(staging, wlv_runtime_snapshot_filename())
  saveRDS(snapshot, path, version = 3L, compress = "gzip")
  if (isTRUE(defer_verification)) {
    return(wlv_runtime_snapshot_receipt(
      snapshot,
      path,
      verify_resource_states = FALSE
    ))
  }
  before_sha256 <- wlv_publication_file_sha256(path)
  observed <- readRDS(path)
  after_sha256 <- wlv_publication_file_sha256(path)
  if (!identical(before_sha256, after_sha256)) {
    stop("Runtime-resource snapshot changed during its write round trip.",
      call. = FALSE
    )
  }
  if (!identical(observed, snapshot)) {
    stop("Runtime-resource snapshot failed its write round trip.", call. = FALSE)
  }
  wlv_runtime_snapshot_validate(observed)
  if (isTRUE(authenticate_bound_files)) {
    wlv_runtime_snapshot_authenticate_bound_files(
      observed,
      staging,
      validate_snapshot = FALSE
    )
  }
  if (isTRUE(return_receipt)) {
    receipt <- wlv_runtime_snapshot_receipt_from_sha256(
      observed,
      after_sha256,
      verify_resource_states = FALSE
    )
    snapshot_row <- match(wlv_runtime_snapshot_filename(), receipt$files$path)
    receipt <- wlv_runtime_snapshot_receipt_attach_bindings(
      receipt,
      observed,
      receipt$files$sha256[[snapshot_row]]
    )
    return(receipt)
  }
  invisible(path)
}

wlv_runtime_snapshot_verify_write <- function(
    receipt,
    staging,
    authenticate_bound_files = TRUE) {
  if (!is.logical(authenticate_bound_files) ||
      length(authenticate_bound_files) != 1L ||
      is.na(authenticate_bound_files)) {
    stop("Runtime snapshot verification flag is invalid.", call. = FALSE)
  }
  wlv_runtime_snapshot_receipt_assert(
    receipt,
    method = receipt$method,
    source = receipt$source,
    partitions = receipt$partitions
  )
  staging <- normalizePath(staging, winslash = "/", mustWork = TRUE)
  path <- file.path(staging, wlv_runtime_snapshot_filename())
  row <- match(wlv_runtime_snapshot_filename(), receipt$files$path)
  if (!file.exists(path) || isTRUE(file.info(path)$isdir) || is.na(row)) {
    stop("Deferred runtime snapshot envelope is missing.", call. = FALSE)
  }
  expected_sha256 <- receipt$files$sha256[[row]]
  before <- wlv_publication_file_sha256(path)
  if (!identical(before, expected_sha256)) {
    stop("Deferred runtime snapshot failed write authentication.", call. = FALSE)
  }
  observed <- tryCatch(
    readRDS(path),
    error = function(error) {
      stop(
        sprintf("Cannot read deferred runtime snapshot: %s", conditionMessage(error)),
        call. = FALSE
      )
    }
  )
  after <- wlv_publication_file_sha256(path)
  if (!identical(after, expected_sha256)) {
    stop("Deferred runtime snapshot changed during its write verification.",
      call. = FALSE
    )
  }
  wlv_runtime_snapshot_validate(observed)
  verified <- wlv_runtime_snapshot_receipt_from_sha256(
    observed,
    after,
    verify_resource_states = FALSE
  )
  unverified_receipt <- receipt
  attr(
    unverified_receipt,
    wlv_runtime_snapshot_receipt_bindings_attribute()
  ) <- NULL
  attr(
    unverified_receipt,
    wlv_runtime_snapshot_receipt_seal_attribute()
  ) <- NULL
  if (!identical(
        verified$snapshot_commitment_sha256,
        unverified_receipt$snapshot_commitment_sha256
      )) {
    stop(
      "Deferred runtime snapshot differs from its logical commitment.",
      call. = FALSE
    )
  }
  if (!identical(verified, unverified_receipt)) {
    stop("Deferred runtime snapshot differs after its write round trip.",
      call. = FALSE
    )
  }
  if (isTRUE(authenticate_bound_files)) {
    wlv_runtime_snapshot_authenticate_bound_files(
      observed,
      staging,
      validate_snapshot = FALSE
    )
  }
  verified <- wlv_runtime_snapshot_receipt_attach_bindings(
    verified,
    observed,
    after
  )
  rm(observed)
  invisible(gc(full = FALSE))
  verified
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
  wlv_runtime_snapshot_validate_bound_artifacts(
    snapshot,
    result_dir,
    if (is.null(reader)) read_fst_array else reader,
    validate_io = TRUE
  )
  snapshot
}
