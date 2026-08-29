# Explicit semantic-state and diagnostic resources --------------------------
#
# This file intentionally contains function definitions only.  The helpers are
# pure with respect to process state: they never consult or mutate a global
# environment, and hydration returns detached values for a module-local runtime.

wlv_semantic_abort <- function(message) {
  condition <- structure(
    list(message = as.character(message), call = NULL),
    class = c("wlv_semantic_resource_error", "error", "condition")
  )
  stop(condition)
}

wlv_semantic_scalar_character <- function(value, name) {
  if (
    !is.character(value) || length(value) != 1L || is.na(value) ||
      !nzchar(value)
  ) {
    wlv_semantic_abort(sprintf("`%s` must be one non-empty string.", name))
  }
  value
}

wlv_semantic_unique_names <- function(value, name, allow_empty = TRUE) {
  if (
    !is.character(value) || anyNA(value) || any(!nzchar(value)) ||
      anyDuplicated(value) || (!allow_empty && !length(value))
  ) {
    wlv_semantic_abort(
      sprintf("`%s` must contain unique non-empty strings.", name)
    )
  }
  value
}

wlv_semantic_state_version <- function() {
  "wlv-semantic-state/1.0.0"
}

wlv_semantic_stateful_keys <- function() {
  c(
    "source/sea",
    "source/io",
    paste0(
      "io/",
      c(
        "k_composition", "k_depreciation", "values",
        "transfers_values", "consumption_basket"
      )
    ),
    paste0(
      "country_matrix/",
      c(
        "exports_values", "exports_mp", "exports_productive_mp",
        "transfers_values", "transfers_productive_values", "transfers_dp",
        "transfers_productive_dp"
      )
    ),
    paste0(
      "intermediate/",
      c("lambda", "balance_factor", "basket_zero", "lambda_zero")
    ),
    paste0(
      "artifact/",
      c("m_io", "m_countries", "sea_sectors", "sea_countries")
    )
  )
}

wlv_semantic_stateful_prefixes <- function() {
  c("sea/sector/", "sea/country/")
}

wlv_semantic_is_stateful_key <- function(key) {
  if (
    !is.character(key) || length(key) != 1L || is.na(key) || !nzchar(key)
  ) {
    return(FALSE)
  }
  if (key %in% wlv_semantic_stateful_keys()) {
    return(TRUE)
  }
  prefixes <- wlv_semantic_stateful_prefixes()
  matched <- prefixes[startsWith(key, prefixes)]
  if (length(matched) != 1L) {
    return(FALSE)
  }
  suffix <- substring(key, nchar(matched) + 1L)
  grepl("^[A-Za-z0-9][A-Za-z0-9_.-]*$", suffix)
}

wlv_semantic_assert_stateful_key <- function(key) {
  key <- wlv_semantic_scalar_character(key, "target_key")
  if (!wlv_semantic_is_stateful_key(key)) {
    wlv_semantic_abort(sprintf("Resource `%s` is not stateful.", key))
  }
  key
}

wlv_semantic_state_key <- function(target_key) {
  paste0(
    "semantic_state/",
    wlv_semantic_assert_stateful_key(target_key)
  )
}

wlv_semantic_state_target_key <- function(state_key) {
  state_key <- wlv_semantic_scalar_character(state_key, "state_key")
  prefix <- "semantic_state/"
  if (!startsWith(state_key, prefix)) {
    wlv_semantic_abort("Semantic-state keys must use the `semantic_state/` prefix.")
  }
  target_key <- substring(state_key, nchar(prefix) + 1L)
  wlv_semantic_assert_stateful_key(target_key)
}

wlv_semantic_states <- function() {
  c("finite", "uncomputed", "source_missing", "not_applicable")
}

wlv_semantic_sparse_states <- function() {
  setdiff(wlv_semantic_states(), "finite")
}

wlv_semantic_contains_reference <- function(value) {
  type <- typeof(value)
  if (
    type %in% c(
      "environment", "externalptr", "weakref", "closure", "builtin", "special"
    ) || inherits(value, "connection") || inherits(value, "data.table") ||
      isS4(value)
  ) {
    return(TRUE)
  }
  if (is.pairlist(value) || is.list(value)) {
    if (any(vapply(value, wlv_semantic_contains_reference, logical(1L)))) {
      return(TRUE)
    }
  }
  value_attributes <- attributes(value)
  if (
    length(value_attributes) &&
      any(vapply(value_attributes, wlv_semantic_contains_reference, logical(1L)))
  ) {
    return(TRUE)
  }
  FALSE
}

wlv_semantic_detach <- function(value) {
  if (wlv_semantic_contains_reference(value)) {
    wlv_semantic_abort("A semantic resource cannot contain mutable references.")
  }
  unserialize(serialize(value, NULL, version = 3L))
}

wlv_semantic_plain_data_frame <- function(value, columns) {
  result <- as.data.frame(
    stats::setNames(
      lapply(columns, function(column) as.character(value[[column]])),
      columns
    ),
    stringsAsFactors = FALSE
  )
  row.names(result) <- NULL
  result
}

wlv_semantic_assert_value <- function(value, axes) {
  axes <- wlv_semantic_unique_names(axes, "axes", allow_empty = FALSE)
  if (!is.numeric(value) || is.null(dim(value)) || length(dim(value)) != length(axes)) {
    wlv_semantic_abort("A stateful value must be a numeric array with declared axes.")
  }
  if (any(dim(value) < 1L)) {
    wlv_semantic_abort("Stateful value axes cannot be empty.")
  }
  labels <- dimnames(value)
  if (
    is.null(labels) || !identical(names(labels), axes) ||
      any(vapply(labels, is.null, logical(1L)))
  ) {
    wlv_semantic_abort("Stateful value dimnames must match the declared axes.")
  }
  for (index in seq_along(labels)) {
    current <- labels[[index]]
    if (
      !is.character(current) || length(current) != dim(value)[[index]] ||
        anyNA(current) || any(!nzchar(current)) || anyDuplicated(current)
    ) {
      wlv_semantic_abort(
        sprintf("Axis `%s` requires unique non-empty character labels.", axes[[index]])
      )
    }
  }
  chunk_values <- 2^20
  for (start in seq.int(1L, length(value), by = chunk_values)) {
    end <- min(length(value), start + chunk_values - 1L)
    chunk <- value[start:end]
    if (any(is.nan(chunk))) {
      wlv_semantic_abort("Stateful values cannot contain NaN.")
    }
    if (any(is.infinite(chunk))) {
      wlv_semantic_abort("Stateful values cannot contain infinite values.")
    }
  }
  invisible(value)
}

wlv_semantic_state_array <- function(value, axes, fill = "finite") {
  wlv_semantic_assert_value(value, axes)
  fill <- wlv_semantic_scalar_character(fill, "fill")
  if (!fill %in% wlv_semantic_states()) {
    wlv_semantic_abort(sprintf("Unknown semantic state `%s`.", fill))
  }
  array(
    rep(fill, length(value)),
    dim = dim(value),
    dimnames = dimnames(value)
  )
}

wlv_semantic_assert_state_array <- function(states, value, axes) {
  wlv_semantic_assert_value(value, axes)
  if (
    !is.character(states) || !identical(dim(states), dim(value)) ||
      !identical(dimnames(states), dimnames(value))
  ) {
    wlv_semantic_abort(
      "Semantic-state arrays must have the value's exact shape and labels."
    )
  }
  normalized <- states
  normalized[is.na(normalized)] <- "finite"
  if (any(!normalized %in% wlv_semantic_states())) {
    wlv_semantic_abort("Semantic-state arrays contain an unknown state.")
  }
  normalized
}

wlv_semantic_order_rows <- function(rows, columns) {
  if (!nrow(rows)) {
    row.names(rows) <- NULL
    return(rows)
  }
  ordering_columns <- lapply(rows[columns], function(value) {
    encoded <- enc2utf8(as.character(value))
    match(encoded, sort(unique(encoded), method = "radix"))
  })
  ordering <- do.call(
    order,
    c(ordering_columns, list(na.last = TRUE, method = "radix"))
  )
  result <- rows[ordering, , drop = FALSE]
  row.names(result) <- NULL
  result
}

wlv_semantic_assert_ordered_unique_rows <- function(rows, columns) {
  if (nrow(rows) <= 1L) {
    return(invisible(rows))
  }
  unresolved <- rep(TRUE, nrow(rows) - 1L)
  for (column in columns) {
    encoded <- enc2utf8(rows[[column]])
    ranks <- match(encoded, sort(unique(encoded), method = "radix"))
    previous <- ranks[-length(ranks)]
    following <- ranks[-1L]
    if (any(unresolved & previous > following)) {
      wlv_semantic_abort("Sparse semantic states are not in canonical order.")
    }
    unresolved <- unresolved & previous == following
  }
  if (any(unresolved)) {
    wlv_semantic_abort("Sparse semantic states contain duplicate coordinates.")
  }
  invisible(rows)
}

wlv_semantic_new_state_resource <- function(rows, target_key, axes) {
  target_key <- wlv_semantic_assert_stateful_key(target_key)
  axes <- wlv_semantic_unique_names(axes, "axes", allow_empty = FALSE)
  expected <- c(axes, "state")
  if (
    !is.data.frame(rows) || !identical(names(rows), expected) ||
      any(!vapply(rows, is.character, logical(1L))) || anyNA(rows) ||
      (nrow(rows) && any(vapply(
        rows,
        function(column) any(!nzchar(column)),
        logical(1L)
      )))
  ) {
    wlv_semantic_abort(
      "Sparse semantic states require character coordinate columns followed by `state`."
    )
  }
  if (any(!rows$state %in% wlv_semantic_sparse_states())) {
    wlv_semantic_abort("Sparse semantic states contain an invalid state.")
  }
  rows <- wlv_semantic_order_rows(rows, axes)
  wlv_semantic_assert_ordered_unique_rows(rows, axes)
  row_count <- nrow(rows)
  columns <- stats::setNames(
    lapply(expected, function(column) rows[[column]]),
    expected
  )
  structure(
    columns,
    class = c("wlv_semantic_state", "data.frame"),
    row.names = if (row_count) {
      c(NA_integer_, -row_count)
    } else {
      integer()
    },
    target_key = target_key,
    axes = axes,
    version = wlv_semantic_state_version()
  )
}

wlv_semantic_empty_state <- function(target_key, axes) {
  axes <- wlv_semantic_unique_names(axes, "axes", allow_empty = FALSE)
  rows <- as.data.frame(
    stats::setNames(
      rep(list(character()), length(axes) + 1L),
      c(axes, "state")
    ),
    stringsAsFactors = FALSE
  )
  wlv_semantic_new_state_resource(rows, target_key, axes)
}

wlv_semantic_state_linear_indices <- function(resource, value) {
  axes <- attr(resource, "axes", exact = TRUE)
  labels <- dimnames(value)
  if (!nrow(resource)) {
    return(integer())
  }
  dimensions <- dim(value)
  positions <- rep(1, nrow(resource))
  multiplier <- 1
  for (index in seq_along(axes)) {
    coordinate <- match(resource[[axes[[index]]]], labels[[index]])
    if (anyNA(coordinate)) {
      wlv_semantic_abort("Sparse semantic states reference unknown coordinates.")
    }
    positions <- positions + (coordinate - 1L) * multiplier
    multiplier <- multiplier * dimensions[[index]]
  }
  as.integer(positions)
}

wlv_semantic_assert_ordinary_na_covered <- function(
    value,
    positions,
    chunk_values = 2^20) {
  if (!is.numeric(value) || !is.numeric(positions) || anyNA(positions) ||
      any(positions < 1L) || any(positions > length(value)) ||
      !is.numeric(chunk_values) || length(chunk_values) != 1L ||
      is.na(chunk_values) || !is.finite(chunk_values) || chunk_values < 1L) {
    wlv_semantic_abort("Semantic NA coverage received invalid inputs.")
  }
  positions <- sort(unique(as.integer(positions)), method = "radix")
  chunk_values <- as.integer(chunk_values)
  total <- length(value)
  if (!total) {
    return(invisible(TRUE))
  }
  for (start in seq.int(1L, total, by = chunk_values)) {
    end <- min(total, start + chunk_values - 1L)
    chunk <- value[start:end]
    ordinary <- which(is.na(chunk) & !is.nan(chunk))
    if (length(ordinary)) {
      ordinary <- as.integer(ordinary + start - 1L)
      first <- findInterval(start - 1L, positions) + 1L
      last <- findInterval(end, positions)
      recorded <- if (first <= last) positions[first:last] else integer()
      if (anyNA(match(ordinary, recorded))) {
        wlv_semantic_abort(
          "Every ordinary NA must have exactly one sparse semantic state."
        )
      }
    }
  }
  invisible(TRUE)
}

wlv_semantic_state_validate <- function(
    resource,
    value = NULL,
    target_key = NULL,
    axes = NULL,
    state_key = NULL) {
  if (!is.data.frame(resource) || !identical(class(resource), c(
    "wlv_semantic_state", "data.frame"
  ))) {
    wlv_semantic_abort("Semantic state must be a canonical sparse-state resource.")
  }
  allowed_attributes <- c(
    "names", "class", "row.names", "target_key", "axes", "version"
  )
  if (!setequal(names(attributes(resource)), allowed_attributes)) {
    wlv_semantic_abort("Semantic-state metadata attributes are not canonical.")
  }
  expected_row_names <- if (nrow(resource)) {
    c(NA_integer_, -nrow(resource))
  } else {
    integer()
  }
  if (!identical(.row_names_info(resource, type = 0L), expected_row_names)) {
    wlv_semantic_abort("Semantic-state row names are not canonical.")
  }
  observed_target <- attr(resource, "target_key", exact = TRUE)
  observed_axes <- attr(resource, "axes", exact = TRUE)
  observed_version <- attr(resource, "version", exact = TRUE)
  observed_target <- wlv_semantic_assert_stateful_key(observed_target)
  observed_axes <- wlv_semantic_unique_names(
    observed_axes,
    "resource axes",
    allow_empty = FALSE
  )
  if (!identical(observed_version, wlv_semantic_state_version())) {
    wlv_semantic_abort("Semantic-state version is not supported.")
  }
  if (!is.null(target_key) && !identical(observed_target, target_key)) {
    wlv_semantic_abort("Semantic-state target_key does not match its contract.")
  }
  if (!is.null(axes) && !identical(observed_axes, axes)) {
    wlv_semantic_abort("Semantic-state axes do not match their contract.")
  }
  if (
    !is.null(state_key) &&
      !identical(wlv_semantic_state_key(observed_target), state_key)
  ) {
    wlv_semantic_abort("Semantic-state resource key does not match target_key.")
  }
  expected <- c(observed_axes, "state")
  if (
    !identical(names(resource), expected) ||
      any(!vapply(resource, is.character, logical(1L))) || anyNA(resource) ||
      (nrow(resource) && any(vapply(
        resource,
        function(column) any(!nzchar(column)),
        logical(1L)
      ))) ||
      any(!resource$state %in% wlv_semantic_sparse_states())
  ) {
    wlv_semantic_abort("Sparse semantic-state rows are not canonical.")
  }
  wlv_semantic_assert_ordered_unique_rows(resource, observed_axes)
  if (!is.null(value)) {
    wlv_semantic_assert_value(value, observed_axes)
    positions <- wlv_semantic_state_linear_indices(resource, value)
    wlv_semantic_assert_ordinary_na_covered(value, positions)
  }
  invisible(resource)
}

wlv_semantic_state_encode <- function(value, states, target_key, axes) {
  target_key <- wlv_semantic_assert_stateful_key(target_key)
  axes <- wlv_semantic_unique_names(axes, "axes", allow_empty = FALSE)
  normalized <- wlv_semantic_assert_state_array(states, value, axes)
  ordinary_na <- is.na(value) & !is.nan(value)
  recorded <- normalized != "finite"
  if (any(ordinary_na & !recorded)) {
    wlv_semantic_abort(
      "Every ordinary NA must have exactly one sparse semantic state."
    )
  }
  positions <- which(recorded)
  if (!length(positions)) {
    return(wlv_semantic_empty_state(target_key, axes))
  }
  indices <- arrayInd(positions, .dim = dim(value), useNames = FALSE)
  rows <- as.data.frame(
    stats::setNames(
      lapply(seq_along(axes), function(index) {
        dimnames(value)[[index]][indices[, index]]
      }),
      axes
    ),
    stringsAsFactors = FALSE
  )
  rows$state <- as.vector(normalized)[positions]
  resource <- wlv_semantic_new_state_resource(rows, target_key, axes)
  wlv_semantic_state_validate(
    resource,
    value = value,
    target_key = target_key,
    axes = axes,
    state_key = wlv_semantic_state_key(target_key)
  )
  resource
}

wlv_semantic_state_expand <- function(resource, value) {
  wlv_semantic_state_validate(resource, value = value)
  axes <- attr(resource, "axes", exact = TRUE)
  result <- wlv_semantic_state_array(value, axes)
  if (nrow(resource)) {
    result[wlv_semantic_state_linear_indices(resource, value)] <- resource$state
  }
  result
}

wlv_semantic_state_hydrate <- function(resource, value) {
  wlv_semantic_state_expand(resource, value)
}

wlv_semantic_legacy_runtime_state_key <- function(target_key) {
  target_key <- wlv_semantic_assert_stateful_key(target_key)
  mappings <- c(
    "sea/sector/" = "sea_sectors",
    "sea/country/" = "sea_countries",
    "io/" = "m_io",
    "country_matrix/" = "m_countries"
  )
  matched <- names(mappings)[startsWith(target_key, names(mappings))]
  if (length(matched) != 1L) {
    return(NULL)
  }
  paste(
    mappings[[matched]],
    substring(target_key, nchar(matched) + 1L),
    sep = "\034"
  )
}

wlv_semantic_runtime_state <- function(
    runtime,
    target_key,
    runtime_state_key = NULL) {
  if (is.null(runtime)) {
    return(NULL)
  }
  if (!(is.environment(runtime) || is.list(runtime))) {
    wlv_semantic_abort("A local contract runtime must be an environment or list.")
  }
  target_key <- wlv_semantic_assert_stateful_key(target_key)
  semantic_states <- runtime$semantic_states
  if (!is.null(semantic_states)) {
    if (
      !is.list(semantic_states) || is.null(names(semantic_states)) ||
        anyNA(names(semantic_states)) || anyDuplicated(names(semantic_states))
    ) {
      wlv_semantic_abort("Local runtime semantic_states must be a named list.")
    }
    candidates <- c(target_key, wlv_semantic_state_key(target_key))
    found <- candidates[candidates %in% names(semantic_states)]
    if (length(found) > 1L) {
      wlv_semantic_abort("Local runtime contains ambiguous semantic states.")
    }
    if (length(found) == 1L) {
      return(wlv_semantic_detach(semantic_states[[found]]))
    }
  }
  state_store <- runtime$states
  if (is.null(state_store)) {
    return(NULL)
  }
  if (is.null(runtime_state_key)) {
    runtime_state_key <- wlv_semantic_legacy_runtime_state_key(target_key)
  }
  if (is.null(runtime_state_key)) {
    return(NULL)
  }
  runtime_state_key <- wlv_semantic_scalar_character(
    runtime_state_key,
    "runtime_state_key"
  )
  found <- if (is.environment(state_store)) {
    if (!exists(runtime_state_key, envir = state_store, inherits = FALSE)) {
      NULL
    } else {
      get(runtime_state_key, envir = state_store, inherits = FALSE)
    }
  } else if (is.list(state_store)) {
    if (
      is.null(names(state_store)) || anyNA(names(state_store)) ||
        anyDuplicated(names(state_store))
    ) {
      wlv_semantic_abort("Local runtime states must be a named list.")
    }
    state_store[[runtime_state_key]]
  } else {
    wlv_semantic_abort("Local runtime states must be an environment or named list.")
  }
  if (is.null(found)) NULL else wlv_semantic_detach(found)
}

wlv_semantic_source_rule <- function(target_key) {
  target_key <- wlv_semantic_assert_stateful_key(target_key)
  rules <- list(
    "source/sea" = list(
      default = "source_missing",
      structural = NULL
    ),
    "source/io" = list(
      default = "source_missing",
      structural = "not_applicable"
    )
  )
  if (!target_key %in% names(rules)) {
    wlv_semantic_abort(
      sprintf("Resource `%s` has no source-state rule.", target_key)
    )
  }
  rules[[target_key]]
}

wlv_semantic_source_state_array <- function(
    value,
    target_key,
    axes,
    source_rule = NULL) {
  wlv_semantic_assert_value(value, axes)
  target_key <- wlv_semantic_assert_stateful_key(target_key)
  if (!target_key %in% c("source/sea", "source/io")) {
    wlv_semantic_abort("Source-state arrays require a source resource key.")
  }
  rule <- if (is.null(source_rule)) {
    wlv_semantic_source_rule(target_key)
  } else if (is.character(source_rule)) {
    list(
      default = wlv_semantic_scalar_character(source_rule, "source_rule"),
      structural = NULL
    )
  } else {
    source_rule
  }
  if (
    !is.list(rule) || !identical(names(rule), c("default", "structural")) ||
      !is.character(rule$default) || length(rule$default) != 1L ||
      is.na(rule$default) || !rule$default %in% wlv_semantic_sparse_states() ||
      (!is.null(rule$structural) && (
        !is.character(rule$structural) || length(rule$structural) != 1L ||
          is.na(rule$structural) ||
          !rule$structural %in% wlv_semantic_sparse_states()
      ))
  ) {
    wlv_semantic_abort("Source-state rule is not canonical.")
  }
  states <- wlv_semantic_state_array(value, axes)
  ordinary_na <- is.na(value) & !is.nan(value)
  states[ordinary_na] <- rule$default
  if (identical(target_key, "source/io")) {
    if (!all(c("input", "output") %in% axes) || is.null(rule$structural)) {
      wlv_semantic_abort(
        "source/io requires input/output axes and a structural state rule."
      )
    }
    positions <- which(ordinary_na)
    if (length(positions)) {
      coordinates <- arrayInd(positions, .dim = dim(value), useNames = FALSE)
      input_labels <- dimnames(value)[[match("input", axes)]]
      output_index <- match("output", axes)
      output_labels <- dimnames(value)[[output_index]][coordinates[, output_index]]
      structural <- !output_labels %in% input_labels
      if (any(structural)) {
        states[positions[structural]] <- rule$structural
      }
    }
  }
  states
}

wlv_semantic_align_runtime_state <- function(states, value, axes) {
  if (!is.character(states) || is.null(dim(states))) {
    return(states)
  }
  if (
    identical(dim(states), dim(value)) &&
      identical(dimnames(states), dimnames(value))
  ) {
    return(states)
  }
  state_labels <- dimnames(states)
  state_axes <- names(state_labels)
  if (
    is.null(state_labels) || is.null(state_axes) ||
      !identical(setdiff(state_axes, "indicator"), axes) ||
      sum(state_axes == "indicator") != 1L ||
      length(state_labels[[match("indicator", state_axes)]]) != 1L
  ) {
    return(states)
  }
  retained <- match(axes, state_axes)
  if (
    anyNA(retained) ||
      !identical(state_labels[retained], dimnames(value))
  ) {
    return(states)
  }
  array(
    as.vector(states),
    dim = dim(value),
    dimnames = dimnames(value)
  )
}

wlv_semantic_capture_value_state <- function(
    value,
    target_key,
    axes,
    runtime = NULL,
    states = NULL,
    runtime_state_key = NULL,
    source_rule = NULL) {
  target_key <- wlv_semantic_assert_stateful_key(target_key)
  axes <- wlv_semantic_unique_names(axes, "axes", allow_empty = FALSE)
  wlv_semantic_assert_value(value, axes)
  is_source <- target_key %in% c("source/sea", "source/io")
  if (!is.null(source_rule) && !is_source) {
    wlv_semantic_abort("Source-state rules can only be used for source resources.")
  }
  candidate <- states
  if (is.null(candidate)) {
    candidate <- attr(value, "wlv_state", exact = TRUE)
  }
  if (is.null(candidate)) {
    candidate <- wlv_semantic_runtime_state(
      runtime,
      target_key,
      runtime_state_key
    )
  }
  if (inherits(candidate, "wlv_semantic_state")) {
    wlv_semantic_state_validate(
      candidate,
      value = value,
      target_key = target_key,
      axes = axes,
      state_key = wlv_semantic_state_key(target_key)
    )
    clean_value <- value
    transient_attributes <- c(
      "wlv_state",
      "wlv_actions",
      "wlv_aggregation_state"
    )
    present <- vapply(transient_attributes, function(attribute) {
      !is.null(attr(clean_value, attribute, exact = TRUE))
    }, logical(1L))
    if (any(present)) {
      for (attribute in transient_attributes[present]) {
        attr(clean_value, attribute) <- NULL
      }
    }
    if (wlv_semantic_contains_reference(clean_value)) {
      wlv_semantic_abort("Captured values cannot contain mutable references.")
    }
    # Canonical base values and sparse states contain no mutable references.
    # Publishing their existing R objects is an ownership transfer protected by
    # copy-on-write, and avoids serializing multi-gigabyte assembler outputs.
    return(structure(
      list(value = clean_value, state = candidate),
      class = "wlv_value_state_bundle"
    ))
  }
  candidate <- wlv_semantic_align_runtime_state(
    candidate,
    value,
    axes
  )
  if (is.null(candidate) && is_source) {
    candidate <- wlv_semantic_source_state_array(
      value,
      target_key,
      axes,
      source_rule
    )
  }
  if (is.null(candidate)) {
    candidate <- wlv_semantic_state_array(value, axes)
  }
  candidate <- wlv_semantic_assert_state_array(candidate, value, axes)
  state <- wlv_semantic_state_encode(value, candidate, target_key, axes)
  clean_value <- value
  attr(clean_value, "wlv_state") <- NULL
  attr(clean_value, "wlv_actions") <- NULL
  attr(clean_value, "wlv_aggregation_state") <- NULL
  if (wlv_semantic_contains_reference(clean_value)) {
    wlv_semantic_abort("Captured values cannot contain mutable references.")
  }
  structure(
    list(value = wlv_semantic_detach(clean_value), state = state),
    class = "wlv_value_state_bundle"
  )
}

wlv_semantic_capture_state <- function(
    value,
    target_key,
    axes,
    runtime = NULL,
    states = NULL,
    runtime_state_key = NULL,
    source_rule = NULL) {
  wlv_semantic_capture_value_state(
    value = value,
    target_key = target_key,
    axes = axes,
    runtime = runtime,
    states = states,
    runtime_state_key = runtime_state_key,
    source_rule = source_rule
  )
}

wlv_semantic_hydrate_states <- function(resources, values) {
  if (
    !is.list(resources) || !is.list(values) || is.null(names(resources)) ||
      is.null(names(values)) || anyNA(names(resources)) || anyNA(names(values)) ||
      any(!nzchar(names(resources))) || any(!nzchar(names(values))) ||
      anyDuplicated(names(resources)) || anyDuplicated(names(values))
  ) {
    wlv_semantic_abort("Hydration requires uniquely named resource and value lists.")
  }
  lapply(resources, wlv_semantic_state_validate)
  target_keys <- unname(vapply(
    resources,
    function(resource) attr(resource, "target_key", exact = TRUE),
    character(1L)
  ))
  expected_resource_names <- unname(vapply(
    target_keys,
    wlv_semantic_state_key,
    character(1L)
  ))
  if (
    !identical(names(resources), expected_resource_names) ||
      !setequal(target_keys, names(values))
  ) {
    wlv_semantic_abort("Hydration resource names do not match their target values.")
  }
  ordered_targets <- sort(target_keys, method = "radix")
  result <- lapply(ordered_targets, function(target_key) {
    resource_index <- match(target_key, target_keys)
    wlv_semantic_state_expand(
      resources[[resource_index]],
      values[[target_key]]
    )
  })
  stats::setNames(result, ordered_targets)
}

wlv_semantic_partition_labels <- function(
    partitions,
    values,
    axes,
    partition_axis,
    partition_labels) {
  if (is.null(partition_axis)) {
    if (!is.null(partition_labels)) {
      wlv_semantic_abort("partition_labels require a partition_axis.")
    }
    return(NULL)
  }
  partition_axis <- wlv_semantic_scalar_character(
    partition_axis,
    "partition_axis"
  )
  if (!partition_axis %in% axes) {
    wlv_semantic_abort("partition_axis is not a semantic-state axis.")
  }
  axis_index <- match(partition_axis, axes)
  if (is.null(partition_labels)) {
    if (is.null(values)) {
      wlv_semantic_abort(
        "Partition labels must be declared when partition values are absent."
      )
    }
    partition_labels <- lapply(values, function(value) {
      dimnames(value)[[axis_index]]
    })
  }
  if (
    !is.list(partition_labels) || is.null(names(partition_labels)) ||
      !identical(sort(names(partition_labels), method = "radix"), partitions)
  ) {
    wlv_semantic_abort("Partition labels must be named for every partition.")
  }
  partition_labels <- partition_labels[partitions]
  for (partition in partitions) {
    current <- partition_labels[[partition]]
    wlv_semantic_unique_names(
      current,
      sprintf("partition_labels[%s]", partition),
      allow_empty = FALSE
    )
    if (!is.null(values)) {
      actual <- dimnames(values[[partition]])[[axis_index]]
      if (!identical(actual, current)) {
        wlv_semantic_abort(
          sprintf("Partition `%s` labels do not match its value.", partition)
        )
      }
    }
  }
  all_labels <- unlist(partition_labels, use.names = FALSE)
  if (anyDuplicated(all_labels)) {
    wlv_semantic_abort("Partition labels must be disjoint.")
  }
  partition_labels
}

wlv_semantic_state_merge <- function(
    resources,
    values = NULL,
    partition_axis = NULL,
    partition_labels = NULL) {
  if (
    !is.list(resources) || !length(resources) || is.null(names(resources)) ||
      anyNA(names(resources)) || any(!nzchar(names(resources))) ||
      anyDuplicated(names(resources))
  ) {
    wlv_semantic_abort("Partition resources must be a non-empty uniquely named list.")
  }
  partitions <- sort(names(resources), method = "radix")
  resources <- resources[partitions]
  if (!is.null(values)) {
    if (
      !is.list(values) || is.null(names(values)) || anyNA(names(values)) ||
        anyDuplicated(names(values)) ||
        !identical(sort(names(values), method = "radix"), partitions)
    ) {
      wlv_semantic_abort("Partition values must match partition resources exactly.")
    }
    values <- values[partitions]
  }
  for (partition in partitions) {
    wlv_semantic_state_validate(
      resources[[partition]],
      value = if (is.null(values)) NULL else values[[partition]]
    )
  }
  target_key <- attr(resources[[1L]], "target_key", exact = TRUE)
  axes <- attr(resources[[1L]], "axes", exact = TRUE)
  for (partition in partitions[-1L]) {
    if (
      !identical(attr(resources[[partition]], "target_key", exact = TRUE), target_key) ||
        !identical(attr(resources[[partition]], "axes", exact = TRUE), axes)
    ) {
      wlv_semantic_abort("Partition semantic-state contracts do not match.")
    }
  }
  labels <- wlv_semantic_partition_labels(
    partitions,
    values,
    axes,
    partition_axis,
    partition_labels
  )
  if (!is.null(labels)) {
    for (partition in partitions) {
      observed <- resources[[partition]][[partition_axis]]
      if (any(!observed %in% labels[[partition]])) {
        wlv_semantic_abort(
          sprintf("Partition `%s` contains coordinates outside its labels.", partition)
        )
      }
    }
  }
  rows <- do.call(rbind, lapply(resources, function(resource) {
    wlv_semantic_plain_data_frame(resource, c(axes, "state"))
  }))
  row.names(rows) <- NULL
  result <- wlv_semantic_new_state_resource(rows, target_key, axes)
  wlv_semantic_state_validate(result)
  result
}

wlv_semantic_module_parts <- function(module) {
  if (!(is.list(module) || is.environment(module))) {
    wlv_semantic_abort("A resolved module must be a list or environment.")
  }
  requires <- module$requires
  provides <- module$provides
  if (
    !is.list(requires) || !is.list(provides) ||
      (length(requires) && (
        is.null(names(requires)) || anyNA(names(requires)) ||
          any(!nzchar(names(requires))) || anyDuplicated(names(requires))
      )) ||
      (length(provides) && (
        is.null(names(provides)) || anyNA(names(provides)) ||
          any(!nzchar(names(provides))) || anyDuplicated(names(provides))
      ))
  ) {
    wlv_semantic_abort("Resolved module requires/provides must be named lists.")
  }
  list(requires = requires, provides = provides)
}

wlv_semantic_ref <- function(value, output = FALSE) {
  ref <- if (isTRUE(output)) value$ref else value
  if (
    !is.list(ref) || !is.character(ref$key) || length(ref$key) != 1L ||
      is.na(ref$key) || !nzchar(ref$key) || !is.list(ref$contract)
  ) {
    wlv_semantic_abort("Module resource references are not canonical.")
  }
  ref
}

wlv_semantic_ref_role <- function(ref) {
  role <- ref$contract$role
  if (is.null(role)) {
    if (startsWith(ref$key, "semantic_state/")) {
      return("semantic_state")
    }
    return("value")
  }
  wlv_semantic_scalar_character(role, "resource role")
}

wlv_semantic_module_id <- function(module) {
  candidates <- c(module$module_id, module$id, module$instance_id)
  candidates <- candidates[
    vapply(candidates, function(value) {
      is.character(value) && length(value) == 1L && !is.na(value) && nzchar(value)
    }, logical(1L))
  ]
  if (!length(candidates)) "unknown.module" else candidates[[1L]]
}

wlv_semantic_module_runtime <- function(
    inputs,
    module,
    semantic_input_mode = c("hydrated", "explicit")) {
  semantic_input_mode <- match.arg(semantic_input_mode)
  parts <- wlv_semantic_module_parts(module)
  if (
    !is.list(inputs) || (length(inputs) && (
      is.null(names(inputs)) || anyNA(names(inputs)) ||
        any(!nzchar(names(inputs))) || anyDuplicated(names(inputs))
    )) ||
      !setequal(names(inputs), names(parts$requires))
  ) {
    wlv_semantic_abort("Module inputs must match the declared input aliases exactly.")
  }
  refs <- lapply(parts$requires, wlv_semantic_ref)
  ref_keys <- vapply(refs, function(ref) ref$key, character(1L))
  ref_roles <- vapply(refs, wlv_semantic_ref_role, character(1L))
  state_aliases <- names(refs)[
    ref_roles == "semantic_state" | startsWith(ref_keys, "semantic_state/")
  ]
  hydrated <- stats::setNames(list(), character())
  for (state_alias in sort(state_aliases, method = "radix")) {
    state_ref <- refs[[state_alias]]
    target_key <- wlv_semantic_state_target_key(state_ref$key)
    target_aliases <- names(refs)[ref_keys == target_key]
    if (length(target_aliases) != 1L) {
      wlv_semantic_abort(
        sprintf(
          "State input `%s` requires exactly one target input `%s`.",
          state_alias,
          target_key
        )
      )
    }
    target_alias <- target_aliases[[1L]]
    target_ref <- refs[[target_alias]]
    if (
      !isTRUE(target_ref$contract$semantic_state) ||
        !identical(state_ref$partition, target_ref$partition) ||
        !identical(state_ref$producer, target_ref$producer)
    ) {
      wlv_semantic_abort(
        sprintf("State input `%s` does not share target lineage.", state_alias)
      )
    }
    state_value <- inputs[[state_alias]]
    target_value <- inputs[[target_alias]]
    if (is.null(state_value) || is.null(target_value)) {
      if (is.null(state_value) && is.null(target_value)) {
        next
      }
      wlv_semantic_abort(
        sprintf("State input `%s` and its target must be jointly available.", state_alias)
      )
    }
    if (is.list(state_value) && !inherits(state_value, "wlv_semantic_state")) {
      if (
        !is.list(target_value) || is.null(names(state_value)) ||
          is.null(names(target_value)) ||
          !identical(names(state_value), names(target_value))
      ) {
        wlv_semantic_abort(
          sprintf("Collected state input `%s` does not match its values.", state_alias)
        )
      }
      if (identical(semantic_input_mode, "explicit")) {
        invisible(Map(function(state, value) {
          wlv_semantic_state_validate(
            state,
            value = value,
            target_key = target_key,
            axes = target_ref$contract$axes,
            state_key = state_ref$key
          )
        }, state_value, target_value))
      } else {
        hydrated[[target_key]] <- Map(
          wlv_semantic_state_expand,
          state_value,
          target_value
        )
      }
    } else {
      if (identical(semantic_input_mode, "explicit")) {
        wlv_semantic_state_validate(
          state_value,
          value = target_value,
          target_key = target_key,
          axes = target_ref$contract$axes,
          state_key = state_ref$key
        )
      } else {
        hydrated[[target_key]] <- wlv_semantic_state_expand(
          state_value,
          target_value
        )
      }
    }
  }
  control_key_map <- c(
    "request/method" = "method",
    "request/source" = "source",
    "configuration/missingness_policy" = "policy",
    "control/missingness_policy" = "policy",
    "configuration/scientific_profile" = "scientific_profile",
    "control/scientific_profile" = "scientific_profile"
  )
  controls <- list()
  for (alias in names(refs)) {
    key <- refs[[alias]]$key
    if (key %in% names(control_key_map)) {
      field <- unname(control_key_map[[key]])
      if (!is.null(controls[[field]])) {
        wlv_semantic_abort(sprintf("Module declares duplicate `%s` controls.", field))
      }
      controls[[field]] <- wlv_semantic_detach(inputs[[alias]])
    }
  }
  declared_controls <- module$semantic_controls
  if (!is.null(declared_controls)) {
    if (
      !is.character(declared_controls) || is.null(names(declared_controls)) ||
        anyNA(declared_controls) || any(!nzchar(declared_controls)) ||
        anyNA(names(declared_controls)) || any(!nzchar(names(declared_controls))) ||
        anyDuplicated(names(declared_controls)) ||
        any(!names(declared_controls) %in% c(
          "method", "source", "policy", "scientific_profile"
        )) || any(!declared_controls %in% names(inputs))
    ) {
      wlv_semantic_abort("module$semantic_controls is not a canonical field-to-alias map.")
    }
    for (field in names(declared_controls)) {
      alias <- declared_controls[[field]]
      controls[[field]] <- wlv_semantic_detach(inputs[[alias]])
    }
  }
  runtime <- new.env(parent = emptyenv())
  runtime$method <- controls$method
  runtime$source <- controls$source
  runtime$policy <- controls$policy
  runtime$scientific_profile <- controls$scientific_profile
  runtime$module_id <- wlv_semantic_module_id(module)
  runtime$instance_id <- if (is.null(module$instance_id)) {
    runtime$module_id
  } else {
    as.character(module$instance_id)
  }
  runtime$partition <- module$partition
  runtime$semantic_input_mode <- semantic_input_mode
  runtime$input_aliases <- sort(names(inputs), method = "radix")
  runtime$semantic_states <- wlv_semantic_detach(hydrated)
  runtime$states <- new.env(parent = emptyenv())
  for (target_key in names(hydrated)) {
    legacy_key <- wlv_semantic_legacy_runtime_state_key(target_key)
    if (!is.null(legacy_key) && !is.list(hydrated[[target_key]])) {
      assign(
        legacy_key,
        wlv_semantic_detach(hydrated[[target_key]]),
        envir = runtime$states
      )
    }
  }
  runtime$anomalies <- as.data.frame(
    stats::setNames(
      rep(list(character()), length(wlv_semantic_anomaly_columns())),
      wlv_semantic_anomaly_columns()
    ),
    stringsAsFactors = FALSE
  )
  runtime$diagnostics <- list()
  class(runtime) <- "wlv_semantic_module_runtime"
  runtime
}

wlv_semantic_materialize_output <- function(module, alias, value, store) {
  output <- module$provides[[alias]]
  ref <- wlv_semantic_ref(output, output = TRUE)
  if (!identical(output$action, "patch")) {
    if (inherits(value, "wlv_resource_patch")) {
      wlv_semantic_abort(
        sprintf("Non-patch output `%s` returned a resource patch.", alias)
      )
    }
    return(value)
  }
  if (
    is.null(store) || is.null(output$predecessor) ||
      !exists("wlv_runtime_entry", mode = "function", inherits = TRUE) ||
      !exists("wlv_runtime_apply_patch", mode = "function", inherits = TRUE)
  ) {
    wlv_semantic_abort(
      sprintf("Patch output `%s` cannot be materialized without its store.", alias)
    )
  }
  predecessor <- list(
    key = output$predecessor$key,
    partition = output$predecessor$partition,
    producer = output$predecessor$producer
  )
  base <- wlv_runtime_entry(store, predecessor)$value
  label <- paste0(ref$key, "@", wlv_semantic_module_id(module))
  wlv_runtime_apply_patch(base, value, ref$contract, label)
}

wlv_semantic_derive_conformable_input_state <- function(
    module,
    inputs,
    target_value,
    target_key) {
  parts <- wlv_semantic_module_parts(module)
  refs <- lapply(parts$requires, wlv_semantic_ref)
  keys <- vapply(refs, function(ref) ref$key, character(1L))
  roles <- vapply(refs, wlv_semantic_ref_role, character(1L))
  state_aliases <- names(refs)[roles == "semantic_state"]
  candidates <- list()
  for (state_alias in state_aliases) {
    state_ref <- refs[[state_alias]]
    input_target_key <- wlv_semantic_state_target_key(state_ref$key)
    value_alias <- names(refs)[keys == input_target_key]
    if (length(value_alias) != 1L) {
      wlv_semantic_abort(
        sprintf("State input `%s` has ambiguous value lineage.", state_alias)
      )
    }
    input_value <- inputs[[value_alias[[1L]]]]
    input_state <- inputs[[state_alias]]
    if (is.list(input_value) || is.list(input_state) &&
        !inherits(input_state, "wlv_semantic_state")) {
      next
    }
    if (
      !identical(dim(input_value), dim(target_value)) ||
        !identical(dimnames(input_value), dimnames(target_value))
    ) {
      next
    }
    candidates[[state_alias]] <- wlv_semantic_state_expand(
      input_state,
      input_value
    )
  }
  if (!length(candidates)) {
    return(NULL)
  }
  axes <- names(dimnames(target_value))
  derived <- wlv_semantic_state_array(target_value, axes)
  missing_positions <- which(is.na(target_value) & !is.nan(target_value))
  for (position in missing_positions) {
    observed <- unique(vapply(
      candidates,
      function(candidate) candidate[[position]],
      character(1L)
    ))
    observed <- observed[observed != "finite"]
    if (length(observed) > 1L) {
      wlv_semantic_abort(
        "Conformable declared inputs disagree on an output missingness state."
      )
    }
    if (length(observed) == 1L) {
      derived[[position]] <- observed[[1L]]
    }
  }
  if (startsWith(target_key, "io/") && length(missing_positions)) {
    axes <- names(dimnames(target_value))
    input_axis <- match("input", axes)
    output_axis <- match("output", axes)
    if (is.na(input_axis) || is.na(output_axis)) {
      wlv_semantic_abort("Stateful IO outputs require input/output axes.")
    }
    coordinates <- arrayInd(
      missing_positions,
      .dim = dim(target_value),
      useNames = FALSE
    )
    input_labels <- dimnames(target_value)[[input_axis]]
    selected_input_labels <- input_labels[coordinates[, input_axis]]
    output_labels <- dimnames(target_value)[[output_axis]][
      coordinates[, output_axis]
    ]
    structural <- !output_labels %in% input_labels
    if (target_key %in% c("io/k_composition", "io/k_depreciation")) {
      input_countries <- sub("[.].*$", "", selected_input_labels)
      output_countries <- sub("[.].*$", "", output_labels)
      structural <- structural | input_countries != output_countries
    }
    if (any(structural)) {
      selected <- missing_positions[structural]
      unresolved <- derived[selected] == "finite"
      derived[selected[unresolved]] <- "not_applicable"
    }
  }
  unresolved <- missing_positions[derived[missing_positions] == "finite"]
  if (length(unresolved)) {
    coordinates <- arrayInd(
      utils::head(unresolved, 3L),
      .dim = dim(target_value),
      .dimnames = dimnames(target_value)
    )
    coordinate_text <- apply(coordinates, 1L, paste, collapse = "/")
    wlv_semantic_abort(sprintf(
      paste0(
        "Declared input states do not cover %d missing output cells in `%s` ",
        "(first: %s)."
      ),
      length(unresolved),
      target_key,
      paste(coordinate_text, collapse = ", ")
    ))
  }
  derived
}

wlv_semantic_finalize_module_result <- function(
    module,
    result,
    runtime,
    inputs,
    store) {
  parts <- wlv_semantic_module_parts(module)
  if (
    !is.list(result) || !is.list(result$outputs) ||
      (length(result$outputs) && (
        is.null(names(result$outputs)) || anyNA(names(result$outputs)) ||
          any(!nzchar(names(result$outputs))) ||
          anyDuplicated(names(result$outputs))
      ))
  ) {
    wlv_semantic_abort("Module result outputs must be a uniquely named list.")
  }
  if (!inherits(runtime, "wlv_semantic_module_runtime") || !is.environment(runtime)) {
    wlv_semantic_abort("Result finalization requires a module-local semantic runtime.")
  }
  if (
    !is.list(inputs) || (length(inputs) && (
      is.null(names(inputs)) || anyNA(names(inputs)) ||
        any(!nzchar(names(inputs))) || anyDuplicated(names(inputs))
    )) || !setequal(names(inputs), names(parts$requires)) ||
      !identical(runtime$input_aliases, sort(names(inputs), method = "radix"))
  ) {
    wlv_semantic_abort("Finalizer inputs do not match the module-local runtime.")
  }
  undeclared <- setdiff(names(result$outputs), names(parts$provides))
  if (length(undeclared)) {
    wlv_semantic_abort(
      sprintf("Module returned undeclared outputs: %s.", paste(undeclared, collapse = ", "))
    )
  }
  output_refs <- lapply(parts$provides, wlv_semantic_ref, output = TRUE)
  output_keys <- vapply(output_refs, function(ref) ref$key, character(1L))
  output_roles <- vapply(output_refs, wlv_semantic_ref_role, character(1L))
  finalized <- result$outputs
  state_aliases <- names(output_refs)[
    output_roles == "semantic_state" | startsWith(output_keys, "semantic_state/")
  ]
  for (state_alias in sort(state_aliases, method = "radix")) {
    state_output <- parts$provides[[state_alias]]
    state_ref <- output_refs[[state_alias]]
    target_key <- wlv_semantic_state_target_key(state_ref$key)
    target_aliases <- names(output_refs)[output_keys == target_key]
    if (length(target_aliases) != 1L) {
      wlv_semantic_abort(
        sprintf(
          "State output `%s` requires exactly one target output `%s`.",
          state_alias,
          target_key
        )
      )
    }
    target_alias <- target_aliases[[1L]]
    target_output <- parts$provides[[target_alias]]
    target_ref <- output_refs[[target_alias]]
    if (
      !isTRUE(target_ref$contract$semantic_state) ||
        !identical(state_output$action, target_output$action) ||
        !identical(state_ref$partition, target_ref$partition)
    ) {
      wlv_semantic_abort(
        sprintf("State output `%s` does not share its target contract.", state_alias)
      )
    }
    if (!identical(target_output$action, "create")) {
      expected_predecessor <- wlv_semantic_state_key(target_output$predecessor$key)
      if (
        is.null(state_output$predecessor) ||
          !identical(state_output$predecessor$key, expected_predecessor) ||
          !identical(
            state_output$predecessor$partition,
            target_output$predecessor$partition
          ) ||
          !identical(
            state_output$predecessor$producer,
            target_output$predecessor$producer
          )
      ) {
        wlv_semantic_abort(
          sprintf("State output `%s` does not share target predecessor lineage.", state_alias)
        )
      }
    }
    if (!target_alias %in% names(finalized)) {
      wlv_semantic_abort(
        sprintf("Target output `%s` is missing before state finalization.", target_alias)
      )
    }
    materialized <- wlv_semantic_materialize_output(
      module,
      target_alias,
      finalized[[target_alias]],
      store
    )
    axes <- target_ref$contract$axes
    explicit_state <- finalized[[state_alias]]
    if (
      identical(module$semantic_input_mode, "explicit") &&
        is.null(explicit_state)
    ) {
      wlv_semantic_abort(sprintf(
        "Explicit semantic-input module `%s` omitted state output `%s`.",
        wlv_semantic_module_id(module),
        state_alias
      ))
    }
    state_candidate <- explicit_state
    if (is.null(state_candidate)) {
      explicit_runtime_state <- attr(
        materialized,
        "wlv_state",
        exact = TRUE
      )
      if (is.null(explicit_runtime_state)) {
        explicit_runtime_state <- wlv_semantic_runtime_state(
          runtime,
          target_key
        )
      }
      derived_state <- if (is.null(explicit_runtime_state)) {
        wlv_semantic_derive_conformable_input_state(
          module,
          inputs,
          materialized,
          target_key
        )
      } else {
        explicit_runtime_state
      }
      state_candidate <- derived_state
    }
    bundle <- tryCatch(
      wlv_semantic_capture_value_state(
        materialized,
        target_key,
        axes,
        runtime = NULL,
        states = state_candidate
      ),
      error = function(error) {
        wlv_semantic_abort(sprintf(
          "State finalization for `%s` failed: %s",
          target_key,
          conditionMessage(error)
        ))
      }
    )
    if (!identical(target_output$action, "patch")) {
      finalized[[target_alias]] <- bundle$value
    }
    finalized[[state_alias]] <- bundle$state
  }
  value_state_aliases <- names(output_refs)[vapply(output_refs, function(ref) {
    isTRUE(ref$contract$semantic_state)
  }, logical(1L))]
  for (target_alias in value_state_aliases) {
    expected_key <- wlv_semantic_state_key(output_refs[[target_alias]]$key)
    if (sum(output_keys == expected_key) != 1L) {
      wlv_semantic_abort(
        sprintf("Stateful output `%s` lacks one declared state output.", target_alias)
      )
    }
  }
  anomaly_aliases <- names(output_refs)[output_roles == "anomaly"]
  runtime_anomalies <- runtime$anomalies
  if (!is.data.frame(runtime_anomalies)) {
    wlv_semantic_abort("Module-local anomalies are not a data frame.")
  }
  if (length(anomaly_aliases) > 1L) {
    wlv_semantic_abort("A module can declare only one anomaly bundle output.")
  }
  if (length(anomaly_aliases) == 1L) {
    alias <- anomaly_aliases[[1L]]
    anomaly <- finalized[[alias]]
    producer_id <- wlv_semantic_module_id(module)
    expected_partition <- if (is.null(module$partition)) {
      NULL
    } else {
      as.character(module$partition)
    }
    if (is.null(anomaly)) {
      anomaly <- runtime_anomalies
    }
    if (!inherits(anomaly, "wlv_anomaly_resource")) {
      anomaly <- wlv_semantic_new_anomaly_resource(
        anomaly,
        producer_id = producer_id,
        partition = expected_partition
      )
    }
    wlv_semantic_anomaly_validate(
      anomaly,
      producer_id = producer_id
    )
    wlv_semantic_validate_anomaly_emission(
      anomaly,
      module$provides[[alias]],
      producer_id = producer_id,
      partition = expected_partition,
      checkpoint = module$checkpoint
    )
    finalized[[alias]] <- anomaly
  } else if (nrow(runtime_anomalies)) {
    wlv_semantic_abort("Module produced anomalies without declaring an anomaly resource.")
  }
  diagnostic_aliases <- names(output_refs)[output_roles == "diagnostic"]
  result_diagnostics <- result$diagnostics
  if (is.null(result_diagnostics)) {
    result_diagnostics <- list()
  }
  runtime_diagnostics <- runtime$diagnostics
  if (is.null(runtime_diagnostics)) {
    runtime_diagnostics <- list()
  }
  if (!is.list(runtime_diagnostics) || is.data.frame(runtime_diagnostics)) {
    wlv_semantic_abort("Module-local diagnostics must be a named list.")
  }
  if (is.data.frame(result_diagnostics)) {
    result_diagnostics <- stats::setNames(
      list(result_diagnostics),
      wlv_semantic_module_id(module)
    )
  }
  if (!is.list(result_diagnostics)) {
    wlv_semantic_abort("Result diagnostics must be a named list or data frame.")
  }
  overlap <- intersect(names(runtime_diagnostics), names(result_diagnostics))
  if (length(overlap)) {
    wlv_semantic_abort(
      sprintf("Duplicate module diagnostics: %s.", paste(overlap, collapse = ", "))
    )
  }
  diagnostics <- c(runtime_diagnostics, result_diagnostics)
  if (length(diagnostic_aliases) > 1L) {
    wlv_semantic_abort("A module can declare only one diagnostic bundle output.")
  }
  if (length(diagnostic_aliases) == 1L) {
    alias <- diagnostic_aliases[[1L]]
    explicit <- finalized[[alias]]
    if (!is.null(explicit) && length(diagnostics)) {
      wlv_semantic_abort("Diagnostics were returned both as output and lateral result data.")
    }
    bundle <- if (inherits(explicit, "wlv_diagnostic_bundle")) {
      explicit
    } else if (!is.null(explicit)) {
      wlv_semantic_diagnostic_bundle(explicit)
    } else {
      wlv_semantic_diagnostic_bundle(diagnostics)
    }
    wlv_semantic_diagnostic_bundle_validate(bundle)
    finalized[[alias]] <- bundle
  } else if (length(diagnostics)) {
    wlv_semantic_abort(
      "Module produced diagnostics without declaring a diagnostic resource."
    )
  }
  missing <- setdiff(names(parts$provides), names(finalized))
  if (length(missing)) {
    wlv_semantic_abort(
      sprintf("Module result is missing outputs: %s.", paste(missing, collapse = ", "))
    )
  }
  structure(
    list(outputs = finalized[names(parts$provides)], diagnostics = list()),
    class = class(result)
  )
}

wlv_semantic_anomaly_columns <- function() {
  c(
    "artifact", "indicator", "checkpoint", "stage", "module", "year",
    "country", "sector", "output", "original_value", "policy_id", "action"
  )
}

wlv_semantic_anomaly_version <- function() {
  "wlv-anomaly-resource/2.0.0"
}

wlv_semantic_new_anomaly_resource <- function(
    rows,
    producer_id = NULL,
    partition = NULL) {
  columns <- wlv_semantic_anomaly_columns()
  if (
    !is.data.frame(rows) || !identical(names(rows), columns) ||
      any(!vapply(rows, is.character, logical(1L))) ||
      wlv_semantic_contains_reference(rows)
  ) {
    wlv_semantic_abort("Anomaly resources require the canonical 12 character columns.")
  }
  if (!is.null(producer_id)) {
    producer_id <- wlv_semantic_scalar_character(producer_id, "producer_id")
  }
  if (!is.null(partition)) {
    partition <- wlv_semantic_scalar_character(partition, "partition")
  }
  row.names(rows) <- NULL
  class(rows) <- c("wlv_anomaly_resource", "data.frame")
  attr(rows, "producer_id") <- producer_id
  attr(rows, "partition") <- partition
  attr(rows, "version") <- wlv_semantic_anomaly_version()
  rows
}

wlv_semantic_empty_anomaly <- function(producer_id = NULL, partition = NULL) {
  rows <- as.data.frame(
    stats::setNames(
      rep(list(character()), length(wlv_semantic_anomaly_columns())),
      wlv_semantic_anomaly_columns()
    ),
    stringsAsFactors = FALSE
  )
  wlv_semantic_new_anomaly_resource(rows, producer_id, partition)
}

wlv_semantic_anomaly_validate <- function(
    resource,
    producer_id = NULL,
    partition = NULL) {
  if (!is.data.frame(resource) || !identical(class(resource), c(
    "wlv_anomaly_resource", "data.frame"
  ))) {
    wlv_semantic_abort("Anomaly value is not a canonical anomaly resource.")
  }
  observed_producer <- attr(resource, "producer_id", exact = TRUE)
  observed_partition <- attr(resource, "partition", exact = TRUE)
  if (!identical(attr(resource, "version", exact = TRUE), wlv_semantic_anomaly_version())) {
    wlv_semantic_abort("Anomaly-resource version is not supported.")
  }
  if (!is.null(producer_id) && !identical(observed_producer, producer_id)) {
    wlv_semantic_abort("Anomaly producer_id does not match its contract.")
  }
  if (!is.null(partition) && !identical(observed_partition, partition)) {
    wlv_semantic_abort("Anomaly partition does not match its contract.")
  }
  rebuilt <- wlv_semantic_new_anomaly_resource(
    wlv_semantic_plain_data_frame(resource, wlv_semantic_anomaly_columns()),
    observed_producer,
    observed_partition
  )
  if (!identical(resource, rebuilt)) {
    wlv_semantic_abort("Anomaly resource is not canonical.")
  }
  invisible(resource)
}

wlv_semantic_validate_anomaly_emission <- function(
    resource,
    output,
    producer_id,
    partition,
    checkpoint) {
  producer_id <- wlv_semantic_scalar_character(producer_id, "producer_id")
  wlv_semantic_anomaly_validate(resource, producer_id = producer_id)
  if (!identical(attr(resource, "partition", exact = TRUE), partition)) {
    wlv_semantic_abort("Anomaly partition does not match its module instance.")
  }
  targets <- wlv_native_anomaly_targets(output)
  wlv_native_anomaly_target_contract_assert(
    targets,
    checkpoint = checkpoint,
    module_id = producer_id
  )
  if (!nrow(resource)) {
    return(invisible(resource))
  }
  rows <- wlv_semantic_plain_data_frame(
    resource,
    wlv_semantic_anomaly_columns()
  )
  ownership_columns <- c("artifact", "indicator", "stage", "module")
  if (anyNA(rows[ownership_columns]) ||
      any(!nzchar(as.matrix(rows[ownership_columns])))) {
    wlv_semantic_abort(
      "Anomaly rows must declare complete artifact, indicator, stage, and module ownership."
    )
  }
  observed_keys <- paste(
    rows$artifact,
    rows$indicator,
    rows$stage,
    rows$module,
    sep = "\034"
  )
  target_keys <- paste(
    targets$artifact,
    targets$indicator,
    as.character(targets$stage),
    targets$module,
    sep = "\034"
  )
  foreign <- !observed_keys %in% target_keys
  if (any(foreign)) {
    first <- rows[which(foreign)[[1L]], ownership_columns, drop = FALSE]
    wlv_semantic_abort(sprintf(
      paste0(
        "Anomaly emission `%s/%s/stage-%s/%s` is not declared by producer `%s`."
      ),
      first$artifact[[1L]],
      first$indicator[[1L]],
      first$stage[[1L]],
      first$module[[1L]],
      producer_id
    ))
  }
  invisible(resource)
}

wlv_semantic_anomaly_merge <- function(resources) {
  if (
    !is.list(resources) || !length(resources) || is.null(names(resources)) ||
      anyNA(names(resources)) || any(!nzchar(names(resources))) ||
      anyDuplicated(names(resources))
  ) {
    wlv_semantic_abort("Anomaly resources must be a non-empty named list.")
  }
  lapply(resources, wlv_semantic_anomaly_validate)
  rows <- do.call(rbind, lapply(resources, function(resource) {
    wlv_semantic_plain_data_frame(resource, wlv_semantic_anomaly_columns())
  }))
  row.names(rows) <- NULL
  wlv_semantic_new_anomaly_resource(rows)
}

wlv_semantic_diagnostic_version <- function() {
  "wlv-diagnostic-bundle/1.0.0"
}

wlv_semantic_diagnostic_bundle <- function(diagnostics = list()) {
  if (!is.list(diagnostics) || is.data.frame(diagnostics)) {
    wlv_semantic_abort("Diagnostics must be supplied as a named list.")
  }
  diagnostic_names <- names(diagnostics)
  if (length(diagnostics)) {
    wlv_semantic_unique_names(
      diagnostic_names,
      "diagnostic names",
      allow_empty = FALSE
    )
    if (any(vapply(diagnostics, is.null, logical(1L)))) {
      wlv_semantic_abort("Named diagnostics cannot be NULL.")
    }
  }
  if (wlv_semantic_contains_reference(diagnostics)) {
    wlv_semantic_abort("Diagnostics cannot contain mutable references.")
  }
  if (length(diagnostics)) {
    diagnostics <- diagnostics[sort(diagnostic_names, method = "radix")]
  }
  diagnostics <- wlv_semantic_detach(diagnostics)
  class(diagnostics) <- c("wlv_diagnostic_bundle", "list")
  attr(diagnostics, "version") <- wlv_semantic_diagnostic_version()
  diagnostics
}

wlv_semantic_diagnostic_bundle_validate <- function(bundle) {
  if (
    !is.list(bundle) || is.data.frame(bundle) ||
      !identical(class(bundle), c("wlv_diagnostic_bundle", "list")) ||
      !identical(
        attr(bundle, "version", exact = TRUE),
        wlv_semantic_diagnostic_version()
      )
  ) {
    wlv_semantic_abort("Diagnostic bundle metadata is not canonical.")
  }
  diagnostic_names <- names(bundle)
  if (length(bundle)) {
    wlv_semantic_unique_names(
      diagnostic_names,
      "diagnostic names",
      allow_empty = FALSE
    )
    if (!identical(diagnostic_names, sort(diagnostic_names, method = "radix"))) {
      wlv_semantic_abort("Diagnostic bundle names are not in canonical order.")
    }
    if (any(vapply(bundle, is.null, logical(1L)))) {
      wlv_semantic_abort("Named diagnostics cannot be NULL.")
    }
  }
  if (wlv_semantic_contains_reference(unclass(bundle))) {
    wlv_semantic_abort("Diagnostics cannot contain mutable references.")
  }
  invisible(bundle)
}
