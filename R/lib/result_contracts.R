wlv_scientific_profile_contract <- function(
    id,
    method,
    source,
    output_profile,
    leontief_zero,
    leontief_signed,
    nonfinite_resolution) {
  scalar_identifier <- function(value, name, allow_empty = FALSE) {
    valid <- is.character(value) && length(value) == 1L && !is.na(value) &&
      (allow_empty && !nzchar(value) ||
        grepl("^[a-z][a-z0-9_]*$", value))
    if (!valid) {
      stop(sprintf("`%s` must be one valid identifier.", name), call. = FALSE)
    }
    value
  }
  id <- scalar_identifier(id, "id")
  method <- scalar_identifier(method, "method")
  source <- scalar_identifier(source, "source")
  output_profile <- scalar_identifier(output_profile, "output_profile")

  zero_names <- c("id", "exception_count", "coordinate_md5", "counts")
  if (!is.list(leontief_zero) || !identical(names(leontief_zero), zero_names)) {
    stop("Invalid Leontief zero-output scientific profile.", call. = FALSE)
  }
  leontief_zero$id <- scalar_identifier(
    leontief_zero$id,
    "leontief_zero$id"
  )
  if (!is.numeric(leontief_zero$exception_count) ||
      length(leontief_zero$exception_count) != 1L ||
      is.na(leontief_zero$exception_count) ||
      !is.finite(leontief_zero$exception_count) ||
      leontief_zero$exception_count < 0 ||
      leontief_zero$exception_count != floor(leontief_zero$exception_count)) {
    stop("Invalid Leontief zero-output exception count.", call. = FALSE)
  }
  leontief_zero$exception_count <- as.integer(leontief_zero$exception_count)
  if (!is.character(leontief_zero$coordinate_md5) ||
      length(leontief_zero$coordinate_md5) != 1L ||
      is.na(leontief_zero$coordinate_md5) ||
      !grepl("^[0-9a-f]{32}$", leontief_zero$coordinate_md5)) {
    stop("Invalid Leontief zero-output coordinate hash.", call. = FALSE)
  }
  zero_count_columns <- c("year", "output", "exception_count")
  counts <- leontief_zero$counts
  if (!is.data.frame(counts) || !identical(names(counts), zero_count_columns) ||
      anyNA(counts) || any(!vapply(counts[c("year", "output")], is.character,
        logical(1L))) ||
      !is.numeric(counts$exception_count) ||
      any(!nzchar(as.matrix(counts[c("year", "output")]))) ||
      any(!is.finite(counts$exception_count)) ||
      any(counts$exception_count <= 0) ||
      any(counts$exception_count != floor(counts$exception_count)) ||
      anyDuplicated(paste(counts$year, counts$output, sep = "\034")) ||
      sum(counts$exception_count) != leontief_zero$exception_count) {
    stop("Invalid Leontief zero-output grouped counts.", call. = FALSE)
  }
  counts$exception_count <- as.integer(counts$exception_count)
  leontief_zero$counts <- counts

  signed_names <- c("id", "rows")
  if (!is.list(leontief_signed) ||
      !identical(names(leontief_signed), signed_names)) {
    stop("Invalid signed Leontief scientific profile.", call. = FALSE)
  }
  leontief_signed$id <- scalar_identifier(
    leontief_signed$id,
    "leontief_signed$id"
  )
  signed_columns <- c(
    "year", "coefficient_negative_count", "certificate_type"
  )
  signed <- leontief_signed$rows
  valid_certificates <- c(
    "productivity_nonnegative", "absolute_convergence_signed"
  )
  if (!is.data.frame(signed) || !identical(names(signed), signed_columns) ||
      !nrow(signed) || anyNA(signed) ||
      !is.character(signed$year) ||
      !is.numeric(signed$coefficient_negative_count) ||
      !is.character(signed$certificate_type) ||
      any(!nzchar(signed$year)) || anyDuplicated(signed$year) ||
      any(!is.finite(signed$coefficient_negative_count)) ||
      any(signed$coefficient_negative_count < 0) ||
      any(signed$coefficient_negative_count !=
        floor(signed$coefficient_negative_count)) ||
      any(!signed$certificate_type %in% valid_certificates) ||
      any((signed$coefficient_negative_count == 0) !=
        (signed$certificate_type == "productivity_nonnegative"))) {
    stop("Invalid signed Leontief yearly declarations.", call. = FALSE)
  }
  signed$coefficient_negative_count <- as.integer(
    signed$coefficient_negative_count
  )
  leontief_signed$rows <- signed

  resolution_names <- c(
    "id", "action", "expected_count", "groups", "rules"
  )
  if (!is.list(nonfinite_resolution) ||
      !identical(names(nonfinite_resolution), resolution_names)) {
    stop("Invalid non-finite resolution scientific profile.", call. = FALSE)
  }
  nonfinite_resolution$id <- scalar_identifier(
    nonfinite_resolution$id,
    "nonfinite_resolution$id"
  )
  valid_resolution_actions <- c(
    "reject", "replace_nan_with_zero",
    "replace_zero_denominator_with_zero"
  )
  if (!is.character(nonfinite_resolution$action) ||
      length(nonfinite_resolution$action) != 1L ||
      is.na(nonfinite_resolution$action) ||
      !nonfinite_resolution$action %in% valid_resolution_actions ||
      !is.numeric(nonfinite_resolution$expected_count) ||
      length(nonfinite_resolution$expected_count) != 1L ||
      is.na(nonfinite_resolution$expected_count) ||
      !is.finite(nonfinite_resolution$expected_count) ||
      nonfinite_resolution$expected_count < 0 ||
      nonfinite_resolution$expected_count !=
        floor(nonfinite_resolution$expected_count)) {
    stop("Invalid non-finite resolution declaration.", call. = FALSE)
  }
  nonfinite_resolution$expected_count <- as.integer(
    nonfinite_resolution$expected_count
  )
  group_columns <- c(
    "binding", "indicator", "kind", "module", "expected_count",
    "coordinate_sha256"
  )
  groups <- nonfinite_resolution$groups
  if (!is.data.frame(groups) || !identical(names(groups), group_columns) ||
      anyNA(groups) ||
      !is.character(groups$binding) || !is.character(groups$indicator) ||
      !is.character(groups$kind) ||
      !is.character(groups$module) ||
      !is.numeric(groups$expected_count) ||
      !is.character(groups$coordinate_sha256) ||
      any(!grepl("^[a-z][a-z0-9_.]*$", groups$binding)) ||
      any(!grepl("^[a-z][a-z0-9_.]*$", groups$indicator)) ||
      any(!groups$kind %in% c("NaN", "Inf")) ||
      any(!grepl("^[a-z][a-z0-9_.]*$", groups$module)) ||
      any(!is.finite(groups$expected_count)) ||
      any(groups$expected_count <= 0) ||
      any(groups$expected_count != floor(groups$expected_count)) ||
      any(!grepl("^[0-9a-f]{64}$", groups$coordinate_sha256)) ||
      anyDuplicated(paste(groups$binding, groups$kind, sep = "\034")) ||
      sum(groups$expected_count) != nonfinite_resolution$expected_count) {
    stop("Invalid non-finite resolution groups.", call. = FALSE)
  }
  groups$expected_count <- as.integer(groups$expected_count)
  nonfinite_resolution$groups <- groups
  resolution_columns <- c(
    "artifact", "indicator", "year", "country", "sector", "from", "to"
  )
  rules <- nonfinite_resolution$rules
  if (!is.data.frame(rules) ||
      !identical(names(rules), resolution_columns) ||
      anyNA(rules) || any(!vapply(rules, is.character, logical(1L))) ||
      any(rules$artifact != "sea_sectors") ||
      any(!grepl("^[a-z][a-z0-9_.]*$", rules$indicator)) ||
      any(!(rules$year == "*" | grepl("^[0-9]{4}$", rules$year))) ||
      any(!grepl("^[A-Z0-9._-]+$", rules$country)) ||
      any(!nzchar(rules$sector)) || any(rules$sector == "*") ||
      any(rules$from != "NaN") || any(rules$to != "0") ||
      anyDuplicated(do.call(paste, c(rules, sep = "\034"))) ||
      (nonfinite_resolution$action == "reject" &&
        (nrow(groups) != 0L || nrow(rules) != 0L ||
          nonfinite_resolution$expected_count != 0L)) ||
      (nonfinite_resolution$action == "replace_nan_with_zero" &&
        (nrow(groups) == 0L || nrow(rules) == 0L ||
          any(groups$kind != "NaN") ||
          any(groups$indicator != groups$binding) ||
          length(unique(groups$module)) != 1L)) ||
      (nonfinite_resolution$action ==
          "replace_zero_denominator_with_zero" &&
        (nrow(groups) == 0L || nrow(rules) != 0L ||
          any(vapply(
            split(groups$module, groups$binding),
            function(modules) length(unique(modules)) != 1L,
            logical(1L)
          )) ||
          any(vapply(
            split(groups$indicator, groups$binding),
            function(indicators) length(unique(indicators)) != 1L,
            logical(1L)
          ))))) {
    stop("Invalid non-finite resolution coordinate rules.", call. = FALSE)
  }
  if (nonfinite_resolution$action == "replace_nan_with_zero") {
    explicit_years <- unique(rules$year[rules$year != "*"])
    if (any(!explicit_years %in% signed$year)) {
      stop(
        "Non-finite resolution rules reference years outside the scientific profile.",
        call. = FALSE
      )
    }
    if (!setequal(groups$binding, unique(rules$indicator))) {
      stop("Non-finite resolution groups do not match their rules.",
        call. = FALSE
      )
    }
    profile_years <- signed$year
    expanded_all <- character()
    for (index in seq_len(nrow(groups))) {
      selected_rules <- rules[rules$indicator == groups$binding[[index]], ,
        drop = FALSE
      ]
      keys <- unlist(lapply(seq_len(nrow(selected_rules)), function(rule) {
        selected_years <- if (selected_rules$year[[rule]] == "*") {
          profile_years
        } else {
          selected_rules$year[[rule]]
        }
        paste(
          selected_years,
          selected_rules$country[[rule]],
          selected_rules$sector[[rule]],
          sep = "|"
        )
      }), use.names = FALSE)
      keys <- sort(keys, method = "radix")
      coordinate_sha256 <- wlv_nonfinite_coordinate_sha256(keys)
      if (anyDuplicated(keys) ||
          length(keys) != groups$expected_count[[index]] ||
          !identical(
            coordinate_sha256,
            groups$coordinate_sha256[[index]]
          )) {
        stop("Non-finite resolution group rules are invalid.", call. = FALSE)
      }
      expanded_all <- c(
        expanded_all,
        paste(groups$binding[[index]], keys, sep = "|")
      )
    }
    if (anyDuplicated(expanded_all)) {
      stop("Non-finite resolution rules overlap after year expansion.",
        call. = FALSE
      )
    }
  }
  nonfinite_resolution$rules <- rules

  structure(
    list(
      id = id,
      method = method,
      source = source,
      output_profile = output_profile,
      leontief_zero = leontief_zero,
      leontief_signed = leontief_signed,
      nonfinite_resolution = nonfinite_resolution
    ),
    class = c("wlv_scientific_profile", "list")
  )
}

wlv_assert_scientific_profile <- function(
    profile,
    method = profile$method,
    source = profile$source) {
  if (!inherits(profile, "wlv_scientific_profile") ||
      !is.list(profile) ||
      !identical(names(profile), c(
        "id", "method", "source", "output_profile", "leontief_zero",
        "leontief_signed", "nonfinite_resolution"
      )) ||
      !identical(profile$method, method) ||
      !identical(profile$source, source)) {
    stop("Invalid or mismatched scientific profile.", call. = FALSE)
  }
  validated <- wlv_scientific_profile_contract(
    id = profile$id,
    method = profile$method,
    source = profile$source,
    output_profile = profile$output_profile,
    leontief_zero = profile$leontief_zero,
    leontief_signed = profile$leontief_signed,
    nonfinite_resolution = profile$nonfinite_resolution
  )
  if (!identical(profile, validated)) {
    stop("Invalid or non-canonical scientific profile.", call. = FALSE)
  }
  invisible(profile)
}

wlv_new_contract_runtime <- function(
    method,
    source,
    policy,
    scientific_profile) {
  if (!inherits(policy, "wlv_missingness_policy")) {
    stop("`policy` must be a missingness policy.", call. = FALSE)
  }
  if (missing(scientific_profile) || is.null(scientific_profile)) {
    stop("`scientific_profile` must be supplied explicitly.", call. = FALSE)
  }
  wlv_assert_scientific_profile(scientific_profile, method, source)
  runtime <- new.env(parent = emptyenv())
  runtime$method <- method
  runtime$source <- source
  runtime$policy <- policy
  runtime$scientific_profile <- scientific_profile
  runtime$anomalies <- wlv_empty_contract_table()
  runtime$states <- new.env(parent = emptyenv())
  runtime$semantic_states <- stats::setNames(vector("list", 0L), character())
  runtime
}

wlv_contract_state_key <- function(artifact, indicator) {
  paste(artifact, indicator, sep = "\034")
}

wlv_contract_record <- function(runtime, anomalies) {
  if (is.null(anomalies) || !nrow(anomalies)) {
    return(invisible(runtime))
  }
  runtime$anomalies <- wlv_bind_contract_tables(
    runtime$anomalies,
    anomalies
  )
  row.names(runtime$anomalies) <- NULL
  invisible(runtime)
}

wlv_contract_capture <- function(runtime, expression) {
  tryCatch(
    force(expression),
    wlv_contract_error = function(error) {
      wlv_contract_record(runtime, error$anomalies)
      stop(error)
    }
  )
}

wlv_contract_register_result <- function(runtime, artifact, indicator, value) {
  actions <- attr(value, "wlv_actions", exact = TRUE)
  states <- attr(value, "wlv_state", exact = TRUE)
  wlv_contract_record(runtime, actions)
  key <- wlv_contract_state_key(artifact, indicator)
  if (!is.null(states)) {
    assign(key, states, envir = runtime$states)
  } else if (exists(key, envir = runtime$states, inherits = FALSE)) {
    rm(list = key, envir = runtime$states)
  }
  invisible(value)
}

wlv_contract_clear_states <- function(runtime, artifact, indicators) {
  for (indicator in indicators) {
    key <- wlv_contract_state_key(artifact, indicator)
    if (exists(key, envir = runtime$states, inherits = FALSE)) {
      rm(list = key, envir = runtime$states)
    }
  }
  invisible(runtime)
}

wlv_contract_register_states <- function(runtime, artifact, indicator, states) {
  if (!is.character(states) || anyNA(states)) {
    stop("Registered missingness states must be a complete character array.", call. = FALSE)
  }
  valid <- c("finite", "uncomputed", "source_missing", "not_applicable")
  if (any(!states %in% valid)) {
    stop("Registered missingness states contain an unknown state.", call. = FALSE)
  }
  assign(
    wlv_contract_state_key(artifact, indicator),
    states,
    envir = runtime$states
  )
  invisible(states)
}

wlv_contract_is_compact_semantic_state <- function(resource) {
  inherits(resource, "wlv_runtime_semantic_state_codec")
}

wlv_contract_compact_semantic_state <- function(
    resource,
    target_key,
    axes) {
  codec <- wlv_runtime_snapshot_state_pack_validated(resource)
  wlv_runtime_snapshot_state_codec_validate(
    codec,
    target_key = target_key,
    axes = axes,
    state_key = wlv_semantic_state_key(target_key)
  )
  codec
}

wlv_contract_empty_compact_semantic_state <- function(target_key, axes) {
  columns <- stats::setNames(
    rep(list(character()), length(axes) + 1L),
    c(axes, "state")
  )
  resource <- wlv_semantic_new_state_resource(
    as.data.frame(columns, stringsAsFactors = FALSE),
    target_key,
    axes
  )
  wlv_contract_compact_semantic_state(resource, target_key, axes)
}

wlv_contract_compact_semantic_state_filter <- function(resource, labels) {
  if (!wlv_contract_is_compact_semantic_state(resource) ||
      !is.list(labels) || is.null(names(labels)) || anyNA(names(labels)) ||
      any(!nzchar(names(labels))) || anyDuplicated(names(labels)) ||
      any(!names(labels) %in% resource$axes) ||
      any(!vapply(labels, is.character, logical(1L))) ||
      any(vapply(labels, anyNA, logical(1L)))) {
    stop("Compact contract-state selection is invalid.", call. = FALSE)
  }
  wlv_runtime_snapshot_state_codec_validate(resource)
  if (identical(resource$encoding, "rows")) {
    rows <- resource$rows
    selected <- rep(TRUE, nrow(rows))
    for (axis in names(labels)) {
      selected <- selected & rows[[axis]] %in% labels[[axis]]
    }
    rows <- rows[selected, c(resource$axes, "state"), drop = FALSE]
    row.names(rows) <- NULL
    rows <- wlv_semantic_new_state_resource(
      rows,
      resource$target_key,
      resource$axes
    )
    return(wlv_contract_compact_semantic_state(
      rows,
      resource$target_key,
      resource$axes
    ))
  }
  selectors <- resource$selectors
  for (axis in names(labels)) {
    selectors[[axis]] <- selectors[[axis]][
      selectors[[axis]] %in% labels[[axis]]
    ]
  }
  if (any(!vapply(selectors, length, integer(1L)))) {
    return(wlv_contract_empty_compact_semantic_state(
      resource$target_key,
      resource$axes
    ))
  }
  result <- wlv_runtime_snapshot_new_state_codec(
    encoding = "cartesian",
    target_key = resource$target_key,
    axes = resource$axes,
    state_version = resource$state_version,
    row_count = prod(vapply(selectors, length, double(1L))),
    selectors = selectors,
    state = resource$state
  )
  wlv_runtime_snapshot_state_codec_validate(result)
  result
}

wlv_contract_compact_semantic_state_subset <- function(resource, value) {
  axes <- resource$axes
  labels <- dimnames(value)
  label_axes <- names(labels)
  if (is.null(labels) || length(labels) != length(axes) ||
      (!is.null(label_axes) && !identical(label_axes, axes)) ||
      any(vapply(labels, is.null, logical(1L)))) {
    stop(
      "Registered missingness state labels do not match the result array.",
      call. = FALSE
    )
  }
  names(labels) <- axes
  wlv_contract_compact_semantic_state_filter(resource, labels)
}

wlv_contract_semantic_state_position_states <- function(
    resource,
    value,
    positions) {
  if (!is.numeric(positions) || anyNA(positions) ||
      any(positions < 1) || any(positions > length(value)) ||
      any(positions != floor(positions))) {
    stop("Contract-state positions are invalid.", call. = FALSE)
  }
  if (!length(positions) || is.null(resource)) {
    return(rep(NA_character_, length(positions)))
  }
  rows <- if (wlv_contract_is_compact_semantic_state(resource) &&
      identical(resource$encoding, "rows")) {
    resource$rows
  } else if (!wlv_contract_is_compact_semantic_state(resource)) {
    resource
  } else {
    NULL
  }
  if (!is.null(rows)) {
    state_positions <- wlv_semantic_state_linear_indices(rows, value)
    matched <- match(positions, state_positions)
    result <- rep(NA_character_, length(positions))
    present <- !is.na(matched)
    result[present] <- rows$state[matched[present]]
    return(result)
  }
  wlv_runtime_snapshot_state_codec_validate(resource)
  labels <- dimnames(value)
  label_axes <- names(labels)
  if (is.null(labels) ||
      (!is.null(label_axes) && !identical(label_axes, resource$axes))) {
    stop(
      "Registered missingness state labels do not match the result array.",
      call. = FALSE
    )
  }
  names(labels) <- resource$axes
  dimensions <- dim(value)
  strides <- c(1, cumprod(as.double(dimensions)))[seq_along(dimensions)]
  selector_positions <- lapply(seq_along(resource$axes), function(index) {
    matched <- match(resource$selectors[[index]], labels[[index]])
    if (anyNA(matched)) {
      stop(
        "Registered missingness states reference unavailable labels.",
        call. = FALSE
      )
    }
    matched
  })
  offsets <- as.double(positions) - 1
  covered <- rep(TRUE, length(positions))
  for (index in seq_along(resource$axes)) {
    coordinates <- (offsets %/% strides[[index]]) %% dimensions[[index]] + 1
    covered <- covered & coordinates %in% selector_positions[[index]]
  }
  result <- rep(NA_character_, length(positions))
  result[covered] <- resource$state
  result
}

wlv_contract_semantic_state_has_invalid_structural <- function(
    resource,
    input_labels) {
  if (is.null(resource)) {
    return(FALSE)
  }
  rows <- if (wlv_contract_is_compact_semantic_state(resource) &&
      identical(resource$encoding, "rows")) {
    resource$rows
  } else if (!wlv_contract_is_compact_semantic_state(resource)) {
    resource
  } else {
    NULL
  }
  if (!is.null(rows)) {
    structural <- rows$variable %in% wlv_m_io_structural_missing_indicators() &
      !rows$output %in% input_labels
    return(any(structural & rows$state != "not_applicable"))
  }
  wlv_runtime_snapshot_state_codec_validate(resource)
  has_structural <- any(
    resource$selectors$variable %in% wlv_m_io_structural_missing_indicators()
  ) && any(!resource$selectors$output %in% input_labels)
  has_structural && !identical(resource$state, "not_applicable")
}

wlv_contract_register_semantic_states <- function(
    runtime,
    artifact,
    resource,
    value) {
  if (!is.character(artifact) || length(artifact) != 1L || is.na(artifact) ||
      !artifact %in% c("m_io")) {
    stop("Sparse contract states received an unsupported artifact.", call. = FALSE)
  }
  target_key <- paste0("artifact/", artifact)
  axes <- names(dimnames(value))
  compact <- if (wlv_runtime_snapshot_is_state_codec(resource)) {
    wlv_runtime_snapshot_state_codec_validate(
      resource,
      target_key = target_key,
      axes = axes,
      state_key = wlv_semantic_state_key(target_key),
      target_value = value
    )
    resource
  } else {
    wlv_runtime_snapshot_state_cartesian_pack(
      resource,
      target_key = target_key,
      axes = axes,
      state_key = wlv_semantic_state_key(target_key),
      target_value = value,
      return_commitment = FALSE
    )
  }
  if (is.null(compact)) {
    wlv_semantic_state_validate(
      resource,
      value = value,
      target_key = target_key,
      axes = axes,
      state_key = wlv_semantic_state_key(target_key)
    )
    compact <- wlv_contract_compact_semantic_state(
      resource,
      target_key,
      axes
    )
  }
  resource <- compact
  semantic_states <- runtime$semantic_states
  if (is.null(semantic_states)) {
    semantic_states <- stats::setNames(vector("list", 0L), character())
  }
  if (!is.list(semantic_states) || is.null(names(semantic_states)) ||
      anyNA(names(semantic_states)) || any(!nzchar(names(semantic_states))) ||
      anyDuplicated(names(semantic_states))) {
    stop("Contract runtime sparse states are not canonical.", call. = FALSE)
  }
  # The validation runtime only needs membership and state lookups. Keep the
  # canonical compact codec instead of retaining the assembler's potentially
  # enormous Cartesian coordinate table.
  semantic_states[[target_key]] <- resource
  runtime$semantic_states <- semantic_states
  invisible(resource)
}

wlv_contract_semantic_states <- function(runtime, artifact) {
  semantic_states <- runtime$semantic_states
  if (is.null(semantic_states)) {
    return(NULL)
  }
  if (!is.list(semantic_states) || is.null(names(semantic_states)) ||
      anyNA(names(semantic_states)) || any(!nzchar(names(semantic_states))) ||
      anyDuplicated(names(semantic_states))) {
    stop("Contract runtime sparse states are not canonical.", call. = FALSE)
  }
  target_key <- paste0("artifact/", artifact)
  resource <- semantic_states[[target_key]]
  if (is.null(resource)) {
    return(NULL)
  }
  valid <- if (wlv_contract_is_compact_semantic_state(resource)) {
    tryCatch({
      wlv_runtime_snapshot_state_codec_validate(
        resource,
        target_key = target_key,
        state_key = wlv_semantic_state_key(target_key)
      )
      TRUE
    }, error = function(error) FALSE)
  } else {
    is.data.frame(resource) && inherits(resource, "wlv_semantic_state") &&
      identical(attr(resource, "target_key", exact = TRUE), target_key)
  }
  if (!isTRUE(valid)) {
    stop("Contract runtime sparse state binding is invalid.", call. = FALSE)
  }
  resource
}

wlv_contract_semantic_state_filter <- function(resource, selected) {
  if (!is.logical(selected) || length(selected) != nrow(resource) || anyNA(selected)) {
    stop("Sparse contract-state selection is invalid.", call. = FALSE)
  }
  if (all(selected)) {
    return(resource)
  }
  axes <- attr(resource, "axes", exact = TRUE)
  target_key <- attr(resource, "target_key", exact = TRUE)
  result <- resource[selected, c(axes, "state"), drop = FALSE]
  row.names(result) <- NULL
  class(result) <- c("wlv_semantic_state", "data.frame")
  attr(result, "target_key") <- target_key
  attr(result, "axes") <- axes
  attr(result, "version") <- wlv_semantic_state_version()
  result
}

wlv_contract_semantic_state_subset <- function(runtime, artifact, value) {
  resource <- wlv_contract_semantic_states(runtime, artifact)
  if (is.null(resource)) {
    return(NULL)
  }
  if (wlv_contract_is_compact_semantic_state(resource)) {
    return(wlv_contract_compact_semantic_state_subset(resource, value))
  }
  axes <- attr(resource, "axes", exact = TRUE)
  labels <- dimnames(value)
  label_axes <- names(labels)
  if (is.null(labels) || length(labels) != length(axes) ||
      (!is.null(label_axes) && !identical(label_axes, axes))) {
    stop(
      "Registered missingness state labels do not match the result array.",
      call. = FALSE
    )
  }
  retains_all <- all(vapply(seq_along(axes), function(index) {
    all(unique(resource[[axes[[index]]]]) %in% labels[[index]])
  }, logical(1L)))
  if (retains_all) {
    return(resource)
  }
  selected <- rep(TRUE, nrow(resource))
  for (index in seq_along(axes)) {
    selected <- selected & resource[[axes[[index]]]] %in% labels[[index]]
  }
  wlv_contract_semantic_state_filter(resource, selected)
}

wlv_contract_semantic_state_slice <- function(
    runtime,
    artifact,
    indicator,
    value) {
  resource <- wlv_contract_semantic_state_subset(runtime, artifact, value)
  if (is.null(resource)) {
    return(NULL)
  }
  if (wlv_contract_is_compact_semantic_state(resource)) {
    axes <- resource$axes
    labels <- dimnames(value)
    if (length(axes) < 2L || !identical(labels[[2L]], indicator)) {
      stop(
        "Registered missingness state labels do not match the result slice.",
        call. = FALSE
      )
    }
    selected <- wlv_contract_compact_semantic_state_filter(
      resource,
      stats::setNames(list(indicator), axes[[2L]])
    )
    return(wlv_runtime_snapshot_state_unpack(selected))
  }
  axes <- attr(resource, "axes", exact = TRUE)
  labels <- dimnames(value)
  if (length(axes) < 2L || !identical(labels[[2L]], indicator)) {
    stop(
      "Registered missingness state labels do not match the result slice.",
      call. = FALSE
    )
  }
  selected <- resource[[axes[[2L]]]] == indicator
  wlv_contract_semantic_state_filter(resource, selected)
}

wlv_contract_copy_indicator_states <- function(
    runtime,
    artifact,
    source_indicator,
    target_indicator,
    value,
    checkpoint) {
  states <- wlv_contract_declared_states(
    runtime,
    artifact,
    source_indicator,
    value,
    checkpoint
  )
  states[is.na(states)] <- "finite"
  wlv_contract_register_states(runtime, artifact, target_indicator, states)
}

wlv_contract_merge_state_arrays <- function(base, overlay) {
  if (
    !is.character(base) || !is.character(overlay) ||
    !wlv_same_shape_and_labels(base, overlay)
  ) {
    stop("Missingness state arrays must have identical shape and labels.", call. = FALSE)
  }
  selected <- !is.na(overlay) & overlay != "finite"
  if (any(selected)) {
    base[selected] <- vapply(
      which(selected),
      function(position) {
        wlv_group_missing_state(c(base[[position]], overlay[[position]]))
      },
      character(1L)
    )
  }
  base
}

wlv_empty_leontief_zero_output_positions <- function() {
  data.frame(
    position = numeric(), year_index = integer(), input_index = integer(),
    output_index = integer(), numerator = numeric(),
    stringsAsFactors = FALSE
  )
}

wlv_leontief_zero_output_profile <- function(
    invalid,
    both_zero,
    years,
    inputs,
    outputs) {
  expected_columns <- names(wlv_empty_leontief_zero_output_positions())
  if (
    !is.data.frame(invalid) || !is.data.frame(both_zero) ||
    !identical(names(invalid), expected_columns) ||
    !identical(names(both_zero), expected_columns) ||
    !is.character(years) || !length(years) || anyNA(years) ||
    any(!nzchar(years)) || anyDuplicated(years) ||
    !is.character(inputs) || !length(inputs) || anyNA(inputs) ||
    any(!nzchar(inputs)) || anyDuplicated(inputs) ||
    !is.character(outputs) || !length(outputs) || anyNA(outputs) ||
    any(!nzchar(outputs)) || anyDuplicated(outputs)
  ) {
    stop("Invalid streaming Leontief zero-output profile.", call. = FALSE)
  }
  positions <- rbind(invalid, both_zero)
  if (nrow(positions)) {
    expected_position <-
      positions$year_index +
      (positions$input_index - 1) * length(years) +
      (positions$output_index - 1) * length(years) * length(inputs)
    invalid_coordinates <-
      positions$year_index < 1 | positions$year_index > length(years) |
      positions$input_index < 1 | positions$input_index > length(inputs) |
      positions$output_index < 1 | positions$output_index > length(outputs)
    if (
      anyNA(positions) || any(!is.finite(positions$numerator)) ||
      any(invalid_coordinates) ||
      any(positions$position != expected_position) ||
      anyDuplicated(positions$position) ||
      any(invalid$numerator == 0) || any(both_zero$numerator != 0)
    ) {
      stop("Invalid streaming Leontief zero-output coordinates.", call. = FALSE)
    }
  }
  invalid <- invalid[order(invalid$position, method = "radix"), , drop = FALSE]
  both_zero <- both_zero[
    order(both_zero$position, method = "radix"),
    ,
    drop = FALSE
  ]
  row.names(invalid) <- NULL
  row.names(both_zero) <- NULL
  structure(
    list(
      invalid = invalid,
      both_zero = both_zero,
      years = years,
      inputs = inputs,
      outputs = outputs,
      validated_method = NULL
    ),
    class = c("wlv_leontief_zero_output_profile", "list")
  )
}

wlv_scan_leontief_zero_output_year <- function(
    numerator_block,
    gross_output,
    productive,
    year_index,
    year_count,
    inputs,
    outputs = inputs) {
  total_dimension <- length(productive)
  productive_indices <- which(productive)
  if (
    !is.matrix(numerator_block) || !is.numeric(numerator_block) ||
    !identical(dim(numerator_block), rep(length(productive_indices), 2L)) ||
    anyNA(numerator_block) || any(!is.finite(numerator_block)) ||
    !is.numeric(gross_output) || length(gross_output) != total_dimension ||
    anyNA(gross_output) || any(!is.finite(gross_output)) ||
    !is.logical(productive) || anyNA(productive) || !any(productive) ||
    !is.numeric(year_index) || length(year_index) != 1L ||
    year_index != as.integer(year_index) || year_index < 1 ||
    !is.numeric(year_count) || length(year_count) != 1L ||
    year_count != as.integer(year_count) || year_count < year_index ||
    !is.character(inputs) || length(inputs) != total_dimension ||
    !is.character(outputs) || length(outputs) != total_dimension
  ) {
    stop("Invalid annual streaming Leontief zero-output scan.", call. = FALSE)
  }
  block_labels <- inputs[productive]
  if (
    (!is.null(rownames(numerator_block)) &&
      !identical(rownames(numerator_block), block_labels)) ||
    (!is.null(colnames(numerator_block)) &&
      !identical(colnames(numerator_block), outputs[productive]))
  ) {
    stop("Annual Leontief block labels do not match productive sectors.", call. = FALSE)
  }

  empty <- wlv_empty_leontief_zero_output_positions()
  zero_outputs <- which(gross_output == 0)
  if (!length(zero_outputs)) {
    return(structure(
      list(year_index = as.integer(year_index), invalid = empty, both_zero = empty),
      class = c("wlv_leontief_zero_output_scan", "list")
    ))
  }
  invalid_rows <- vector("list", length(zero_outputs))
  both_zero_rows <- vector("list", length(zero_outputs))
  for (zero_index in seq_along(zero_outputs)) {
    output_index <- zero_outputs[[zero_index]]
    block_output <- match(output_index, productive_indices, nomatch = 0L)
    nonzero_inputs <- integer()
    nonzero_values <- numeric()
    if (block_output) {
      numerator_column <- numerator_block[, block_output]
      selected <- numerator_column != 0
      nonzero_inputs <- productive_indices[selected]
      nonzero_values <- numerator_column[selected]
    }
    position_for <- function(input_index) {
      year_index +
        (input_index - 1) * year_count +
        (output_index - 1) * year_count * total_dimension
    }
    if (length(nonzero_inputs)) {
      invalid_rows[[zero_index]] <- data.frame(
        position = position_for(nonzero_inputs),
        year_index = rep(as.integer(year_index), length(nonzero_inputs)),
        input_index = as.integer(nonzero_inputs),
        output_index = rep(as.integer(output_index), length(nonzero_inputs)),
        numerator = as.numeric(nonzero_values),
        stringsAsFactors = FALSE
      )
    }
    zero_inputs <- setdiff(seq_len(total_dimension), nonzero_inputs)
    both_zero_rows[[zero_index]] <- data.frame(
      position = position_for(zero_inputs),
      year_index = rep(as.integer(year_index), length(zero_inputs)),
      input_index = as.integer(zero_inputs),
      output_index = rep(as.integer(output_index), length(zero_inputs)),
      numerator = rep(0, length(zero_inputs)),
      stringsAsFactors = FALSE
    )
  }
  bind_positions <- function(values) {
    values <- values[!vapply(values, is.null, logical(1L))]
    if (!length(values)) empty else do.call(rbind, values)
  }
  structure(
    list(
      year_index = as.integer(year_index),
      invalid = bind_positions(invalid_rows),
      both_zero = bind_positions(both_zero_rows)
    ),
    class = c("wlv_leontief_zero_output_scan", "list")
  )
}

wlv_combine_leontief_zero_output_scans <- function(
    scans,
    years,
    inputs,
    outputs = inputs) {
  if (
    !is.list(scans) || length(scans) != length(years) ||
    any(!vapply(scans, inherits, logical(1L), "wlv_leontief_zero_output_scan")) ||
    !identical(
      vapply(scans, `[[`, integer(1L), "year_index"),
      seq_along(years)
    )
  ) {
    stop("Incomplete annual streaming Leontief zero-output scans.", call. = FALSE)
  }
  bind <- function(name) {
    values <- lapply(scans, `[[`, name)
    if (!sum(vapply(values, nrow, integer(1L)))) {
      wlv_empty_leontief_zero_output_positions()
    } else {
      do.call(rbind, values)
    }
  }
  wlv_leontief_zero_output_profile(
    bind("invalid"),
    bind("both_zero"),
    years = as.character(years),
    inputs = as.character(inputs),
    outputs = as.character(outputs)
  )
}

wlv_validate_leontief_zero_output_profile <- function(runtime, profile) {
  if (!inherits(profile, "wlv_leontief_zero_output_profile")) {
    stop("Invalid streaming Leontief zero-output profile.", call. = FALSE)
  }
  if (!is.environment(runtime) || is.null(runtime$scientific_profile)) {
    stop(
      "Leontief validation requires an explicit scientific runtime.",
      call. = FALSE
    )
  }
  method <- runtime$method
  invalid <- profile$invalid
  scientific_profile <- runtime$scientific_profile
  wlv_assert_scientific_profile(
    scientific_profile,
    runtime$method,
    runtime$source
  )
  expected <- scientific_profile$leontief_zero
  observed_years <- profile$years[invalid$year_index]
  observed_inputs <- profile$inputs[invalid$input_index]
  observed_outputs <- profile$outputs[invalid$output_index]
  keys <- sort(
    paste(observed_years, observed_inputs, observed_outputs, sep = "|"),
    method = "radix"
  )
  observed_hash <- unclass(tolower(as.character(openssl::md5(
    charToRaw(enc2utf8(paste(keys, collapse = "\n")))
  ))))
  observed_counts <- table(paste(observed_years, observed_outputs, sep = "|"))
  expected_counts <- stats::setNames(
    expected$counts$exception_count,
    paste(expected$counts$year, expected$counts$output, sep = "|")
  )
  counts_match <- if (!length(expected_counts)) {
    !length(observed_counts)
  } else {
    identical(sort(names(observed_counts)), sort(names(expected_counts))) &&
      identical(
        as.integer(observed_counts[names(expected_counts)]),
        as.integer(expected_counts)
      )
  }
  if (length(keys) != expected$exception_count || !counts_match ||
      !identical(observed_hash, expected$coordinate_md5)) {
    stop(
      sprintf(
        paste0(
          "Leontief exceptions differ from explicit scientific profile `%s` ",
          "(observed_count=%s, expected_count=%s, observed_md5=%s)."
        ),
        expected$id,
        length(keys),
        expected$exception_count,
        observed_hash
      ),
      call. = FALSE
    )
  }
  profile$validated_method <- method
  profile$validated_scientific_profile <- scientific_profile$id
  profile
}

wlv_validate_leontief_zero_output_anomalies <- function(runtime, anomalies) {
  if (!is.environment(runtime) || is.null(runtime$scientific_profile)) {
    stop(
      "Leontief anomaly validation requires an explicit scientific runtime.",
      call. = FALSE
    )
  }
  wlv_assert_scientific_profile(
    runtime$scientific_profile,
    runtime$method,
    runtime$source
  )
  if (!is.data.frame(anomalies) ||
      !identical(names(anomalies), wlv_contract_anomaly_columns())) {
    stop("Leontief anomaly validation received an invalid audit trail.",
      call. = FALSE
    )
  }
  expected <- runtime$scientific_profile$leontief_zero
  observed <- anomalies[
    !is.na(anomalies$action) &
      anomalies$action == "allowlisted_nonzero_over_zero",
    ,
    drop = FALSE
  ]
  context_matches <-
    observed$artifact == "m_io" &
    observed$indicator == "leontief_input_ratio" &
    observed$checkpoint == "after_matrices" &
    observed$stage == "3" &
    observed$module == "transformation.R" &
    observed$policy_id == expected$id &
    observed$original_value %in% c("Inf", "-Inf") &
    !is.na(observed$year) & nzchar(observed$year) &
    !is.na(observed$sector) & nzchar(observed$sector) &
    !is.na(observed$output) & nzchar(observed$output) &
    (is.na(observed$country) | !nzchar(observed$country))
  keys <- sort(
    paste(observed$year, observed$sector, observed$output, sep = "|"),
    method = "radix"
  )
  coordinate_md5 <- unclass(tolower(as.character(openssl::md5(
    charToRaw(enc2utf8(paste(keys, collapse = "\n")))
  ))))
  observed_counts <- table(paste(observed$year, observed$output, sep = "|"))
  expected_counts <- stats::setNames(
    expected$counts$exception_count,
    paste(expected$counts$year, expected$counts$output, sep = "|")
  )
  counts_match <- if (!length(expected_counts)) {
    !length(observed_counts)
  } else {
    identical(sort(names(observed_counts)), sort(names(expected_counts))) &&
      identical(
        as.integer(observed_counts[names(expected_counts)]),
        as.integer(expected_counts)
      )
  }
  valid <-
    nrow(observed) == expected$exception_count &&
    all(context_matches) &&
    !anyDuplicated(keys) &&
    counts_match &&
    identical(coordinate_md5, expected$coordinate_md5)
  if (!valid) {
    stop(sprintf(
      paste0(
        "Published Leontief exceptions differ from explicit scientific ",
        "profile `%s` (observed_count=%s, expected_count=%s, ",
        "observed_md5=%s)."
      ),
      expected$id,
      nrow(observed),
      expected$exception_count,
      coordinate_md5
    ), call. = FALSE)
  }
  invisible(TRUE)
}

wlv_leontief_zero_output_contract_table <- function(
    runtime,
    profile,
    type = c("invalid", "both_zero")) {
  type <- match.arg(type)
  positions <- if (identical(type, "both_zero")) {
    replaced_invalid <- profile$invalid
    replaced_invalid$numerator <- rep(0, nrow(replaced_invalid))
    combined <- rbind(profile$both_zero, replaced_invalid)
    combined[order(combined$position, method = "radix"), , drop = FALSE]
  } else {
    profile[[type]]
  }
  if (!nrow(positions)) {
    return(wlv_empty_contract_table())
  }
  allowlisted <- identical(type, "invalid")
  context <- wlv_contract_context_for(
    runtime,
    artifact = "m_io",
    indicator = "leontief_input_ratio",
    checkpoint = "after_matrices",
    stage = 3L,
    module = "transformation.R",
    axes = c(year = 1L, sector = 2L, output = 3L),
    policy_id = if (allowlisted) {
      runtime$scientific_profile$leontief_zero$id
    } else {
      runtime$policy$policy_id
    }
  )
  original <- if (allowlisted) positions$numerator / 0 else rep(NaN, nrow(positions))
  data.frame(
    artifact = rep(context$artifact, nrow(positions)),
    indicator = rep(context$indicator, nrow(positions)),
    checkpoint = rep(context$checkpoint, nrow(positions)),
    stage = rep(context$stage, nrow(positions)),
    module = rep(context$module, nrow(positions)),
    year = profile$years[positions$year_index],
    country = rep(NA_character_, nrow(positions)),
    sector = profile$inputs[positions$input_index],
    output = profile$outputs[positions$output_index],
    original_value = vapply(original, wlv_format_original_value, character(1L)),
    policy_id = rep(context$policy_id, nrow(positions)),
    action = rep(
      if (allowlisted) {
        "allowlisted_nonzero_over_zero"
      } else {
        "replace_both_zero_with_zero"
      },
      nrow(positions)
    ),
    stringsAsFactors = FALSE
  )[wlv_contract_anomaly_columns()]
}

wlv_record_leontief_zero_output_profile <- function(
    runtime,
    profile,
    include_both_zero = TRUE) {
  if (
    !inherits(profile, "wlv_leontief_zero_output_profile") ||
    is.null(profile$validated_method) ||
    !identical(profile$validated_method, runtime$method) ||
    !identical(
      profile$validated_scientific_profile,
      runtime$scientific_profile$id
    )
  ) {
    stop("Leontief zero-output profile must be validated before recording.", call. = FALSE)
  }
  wlv_contract_record(
    runtime,
    wlv_leontief_zero_output_contract_table(runtime, profile, "invalid")
  )
  if (isTRUE(include_both_zero)) {
    wlv_contract_record(
      runtime,
      wlv_leontief_zero_output_contract_table(runtime, profile, "both_zero")
    )
  }
  invisible(profile)
}

wlv_allowlisted_leontief_zero_output <- function(
    runtime,
    numerator,
    denominator,
    years,
    inputs,
    outputs) {
  wlv_assert_conformable_numeric(numerator, denominator)
  if (
    length(dim(numerator)) != 3L ||
    !identical(dim(numerator), c(length(years), length(inputs), length(outputs)))
  ) {
    stop("Leontief exception coordinates do not match the matrix shape.", call. = FALSE)
  }
  invalid_mask <- denominator == 0 & numerator != 0
  both_zero_mask <- denominator == 0 & numerator == 0
  positions_for <- function(mask) {
    if (!any(mask)) {
      return(wlv_empty_leontief_zero_output_positions())
    }
    coordinates <- which(mask, arr.ind = TRUE)
    data.frame(
      position = as.numeric(which(mask)),
      year_index = as.integer(coordinates[, 1L]),
      input_index = as.integer(coordinates[, 2L]),
      output_index = as.integer(coordinates[, 3L]),
      numerator = as.numeric(numerator[mask]),
      stringsAsFactors = FALSE
    )
  }
  profile <- wlv_leontief_zero_output_profile(
    positions_for(invalid_mask),
    positions_for(both_zero_mask),
    years = as.character(years),
    inputs = as.character(inputs),
    outputs = as.character(outputs)
  )
  profile <- wlv_validate_leontief_zero_output_profile(runtime, profile)
  wlv_record_leontief_zero_output_profile(
    runtime,
    profile,
    include_both_zero = FALSE
  )
  numerator[invalid_mask] <- 0
  numerator
}

wlv_contract_context_for <- function(
    runtime,
    artifact,
    indicator,
    checkpoint,
    stage = NA_character_,
    module = NA_character_,
    axes = integer(),
    policy_id = runtime$policy$policy_id) {
  wlv_contract_context(
    artifact = artifact,
    indicator = indicator,
    checkpoint = checkpoint,
    stage = stage,
    module = module,
    policy_id = policy_id,
    axes = axes
  )
}

wlv_nonfinite_resolution_diagnostic_columns <- function() {
  c(
    "method", "scientific_profile", "nonfinite_resolution_profile",
    "action", "module", "binding", "indicator", "kind", "resolved_count",
    "coordinate_sha256"
  )
}

wlv_nonfinite_resolution_diagnostic_row <- function(
    runtime,
    module,
    binding,
    indicator,
    kind,
    resolved_count,
    coordinate_sha256) {
  profile <- runtime$scientific_profile
  data.frame(
    method = runtime$method,
    scientific_profile = profile$id,
    nonfinite_resolution_profile = profile$nonfinite_resolution$id,
    action = profile$nonfinite_resolution$action,
    module = module,
    binding = binding,
    indicator = indicator,
    kind = kind,
    resolved_count = as.integer(resolved_count),
    coordinate_sha256 = coordinate_sha256,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )[wlv_nonfinite_resolution_diagnostic_columns()]
}

wlv_normalize_nonfinite_resolution_diagnostics <- function(value) {
  columns <- wlv_nonfinite_resolution_diagnostic_columns()
  character_columns <- setdiff(columns, "resolved_count")
  if (!is.data.frame(value) || !identical(names(value), columns) ||
      !nrow(value) || anyNA(value) ||
      any(!vapply(value[character_columns], is.character, logical(1L)))) {
    stop("Non-finite resolution diagnostics have an invalid schema.",
      call. = FALSE
    )
  }
  resolved_count <- suppressWarnings(as.integer(value$resolved_count))
  canonical_count <- if (is.character(value$resolved_count)) {
    value$resolved_count == as.character(resolved_count)
  } else {
    is.numeric(value$resolved_count) &
      value$resolved_count == resolved_count
  }
  if (anyNA(resolved_count) || any(!canonical_count) ||
      any(resolved_count <= 0L) ||
      any(!nzchar(as.matrix(value[character_columns]))) ||
      any(!grepl("^[0-9a-f]{64}$", value$coordinate_sha256)) ||
      anyDuplicated(paste(
        value$binding,
        value$indicator,
        value$kind,
        sep = "\034"
      ))) {
    stop("Non-finite resolution diagnostics are invalid.", call. = FALSE)
  }
  value$resolved_count <- resolved_count
  value <- value[order(value$binding, value$kind, method = "radix"), , drop = FALSE]
  row.names(value) <- NULL
  value
}

wlv_read_nonfinite_resolution_diagnostics <- function(path) {
  if (!file.exists(path) || isTRUE(file.info(path)$isdir)) {
    stop(sprintf(
      "Non-finite resolution diagnostic does not exist: `%s`.",
      path
    ), call. = FALSE)
  }
  value <- utils::read.csv2(
    path,
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL,
    fileEncoding = "UTF-8"
  )
  wlv_normalize_nonfinite_resolution_diagnostics(value)
}

wlv_validate_nonfinite_resolution_anomalies <- function(runtime, anomalies) {
  if (!is.environment(runtime) || is.null(runtime$scientific_profile)) {
    stop("Non-finite anomaly validation requires a scientific runtime.",
      call. = FALSE
    )
  }
  wlv_assert_scientific_profile(
    runtime$scientific_profile,
    runtime$method,
    runtime$source
  )
  if (!is.data.frame(anomalies) ||
      !identical(names(anomalies), wlv_contract_anomaly_columns())) {
    stop("Non-finite anomaly validation received an invalid audit trail.",
      call. = FALSE
    )
  }
  resolution <- runtime$scientific_profile$nonfinite_resolution
  reserved_nan_action <- "replace_profiled_historical_nan_with_zero"
  if (identical(resolution$action, "reject")) {
    claimed <- (!is.na(anomalies$policy_id) &
      anomalies$policy_id == resolution$id) |
      (!is.na(anomalies$action) &
        anomalies$action == reserved_nan_action)
    if (any(claimed)) {
      stop(sprintf(
        "Audit trail claims non-finite transitions forbidden by profile `%s`.",
        resolution$id
      ), call. = FALSE)
    }
    return(invisible(TRUE))
  }

  groups <- resolution$groups
  expected_action <- if (identical(
      resolution$action,
      "replace_nan_with_zero"
    )) {
    reserved_nan_action
  } else {
    "replace_zero_denominator_with_zero"
  }
  expected_indicators <- unique(groups$indicator)
  expected_modules <- unique(groups$module)
  expected_scope <- !is.na(anomalies$artifact) &
    anomalies$artifact == "sea_sectors" &
    !is.na(anomalies$checkpoint) &
    anomalies$checkpoint == "after_stage_2" &
    !is.na(anomalies$stage) &
    anomalies$stage == "2"
  claimed <- (!is.na(anomalies$policy_id) &
    anomalies$policy_id == resolution$id) |
    (!is.na(anomalies$action) &
      anomalies$action == reserved_nan_action) |
    (!is.na(anomalies$action) &
      anomalies$action == expected_action &
      !is.na(anomalies$indicator) &
      anomalies$indicator %in% expected_indicators &
      expected_scope) |
    (!is.na(anomalies$module) &
      anomalies$module %in% expected_modules &
      !is.na(anomalies$indicator) &
      anomalies$indicator %in% expected_indicators &
      expected_scope)
  observed <- anomalies[claimed, , drop = FALSE]
  if (nrow(observed) != resolution$expected_count) {
    stop(sprintf(
      paste0(
        "Non-finite anomaly audit count differs from profile `%s` ",
        "(expected=%s; observed=%s)."
      ),
      resolution$id,
      resolution$expected_count,
      nrow(observed)
    ), call. = FALSE)
  }

  matched <- rep(FALSE, nrow(observed))
  for (index in seq_len(nrow(groups))) {
    group <- groups[index, , drop = FALSE]
    selected <- !is.na(observed$indicator) &
      !is.na(observed$module) &
      !is.na(observed$original_value) &
      observed$indicator == group$indicator[[1L]] &
      observed$module == group$module[[1L]] &
      observed$original_value == group$kind[[1L]]
    rows <- observed[selected, , drop = FALSE]
    context_matches <-
      rows$artifact == "sea_sectors" &
      rows$checkpoint == "after_stage_2" &
      rows$stage == "2" &
      rows$policy_id == resolution$id &
      rows$action == expected_action &
      !is.na(rows$year) & nzchar(rows$year) &
      !is.na(rows$country) & nzchar(rows$country) &
      !is.na(rows$sector) & nzchar(rows$sector) &
      (is.na(rows$output) | !nzchar(rows$output))
    keys <- sort(
      paste(rows$year, rows$country, rows$sector, sep = "|"),
      method = "radix"
    )
    coordinate_sha256 <- wlv_nonfinite_coordinate_sha256(keys)
    if (nrow(rows) != group$expected_count[[1L]] ||
        !isTRUE(all(context_matches)) || anyDuplicated(keys) ||
        !identical(
          coordinate_sha256,
          group$coordinate_sha256[[1L]]
        )) {
      stop(sprintf(
        "Non-finite anomaly group `%s/%s` differs from profile `%s`.",
        group$binding[[1L]],
        group$kind[[1L]],
        resolution$id
      ), call. = FALSE)
    }
    matched <- matched | selected
  }
  if (any(!matched)) {
    stop(sprintf(
      "Non-finite anomaly audit contains an undeclared group for profile `%s`.",
      resolution$id
    ), call. = FALSE)
  }
  invisible(TRUE)
}

wlv_nonfinite_coordinate_keys <- function(value, mask, context) {
  positions <- which(mask)
  if (!length(positions)) {
    return(character())
  }
  coordinates <- arrayInd(
    positions,
    .dim = dim(value),
    .dimnames = dimnames(value)
  )
  resolved_axes <- wlv_context_axes(context, value)
  labels <- dimnames(value)
  sort(paste(
    labels[[resolved_axes[["year"]]]][coordinates[, resolved_axes[["year"]]]],
    labels[[resolved_axes[["country"]]]][coordinates[, resolved_axes[["country"]]]],
    labels[[resolved_axes[["sector"]]]][coordinates[, resolved_axes[["sector"]]]],
    sep = "|"
  ), method = "radix")
}

wlv_nonfinite_coordinate_sha256 <- function(keys) {
  unclass(tolower(as.character(openssl::sha256(
    charToRaw(enc2utf8(paste(keys, collapse = "\n")))
  ))))
}

wlv_resolve_profiled_zero_denominator <- function(
    runtime,
    numerator,
    denominator,
    binding,
    indicator,
    artifact,
    checkpoint,
    stage,
    module,
    axes) {
  if (!is.environment(runtime) || is.null(runtime$scientific_profile)) {
    stop("Profiled zero-denominator resolution requires a scientific runtime.",
      call. = FALSE
    )
  }
  wlv_assert_scientific_profile(
    runtime$scientific_profile,
    runtime$method,
    runtime$source
  )
  resolution <- runtime$scientific_profile$nonfinite_resolution
  if (!identical(
      resolution$action,
      "replace_zero_denominator_with_zero"
    )) {
    stop(sprintf(
      "Scientific profile `%s` declares no profiled zero-denominator resolution.",
      runtime$scientific_profile$id
    ), call. = FALSE)
  }
  groups <- resolution$groups[
    resolution$groups$binding == binding,
    ,
    drop = FALSE
  ]
  if (!nrow(groups)) {
    stop(sprintf(
      "Non-finite resolution profile `%s` does not cover binding `%s`.",
      resolution$id,
      binding
    ), call. = FALSE)
  }
  if (any(groups$module != module)) {
    stop(sprintf(
      "Non-finite resolution profile `%s` does not authorize module `%s`.",
      resolution$id,
      module
    ), call. = FALSE)
  }
  if (any(groups$indicator != indicator)) {
    stop(sprintf(
      "Non-finite resolution profile `%s` does not authorize indicator `%s`.",
      resolution$id,
      indicator
    ), call. = FALSE)
  }
  wlv_assert_conformable_numeric(numerator, denominator)
  if (anyNA(numerator) || anyNA(denominator) ||
      any(is.infinite(numerator)) || any(is.infinite(denominator))) {
    stop("Profiled zero-denominator operands must be finite.", call. = FALSE)
  }
  context <- wlv_contract_context_for(
    runtime,
    artifact = artifact,
    indicator = indicator,
    checkpoint = checkpoint,
    stage = stage,
    module = module,
    axes = axes,
    policy_id = resolution$id
  )
  raw <- numerator / denominator
  negative_infinite <- is.infinite(raw) & raw < 0
  observed <- stats::setNames(
    list(is.nan(raw), is.infinite(raw) & raw > 0),
    c("NaN", "Inf")
  )
  ordinary_missing <- is.na(raw) & !is.nan(raw)
  special <- observed[["NaN"]] | observed[["Inf"]]
  expected_special <- denominator == 0
  mismatch <- ordinary_missing | negative_infinite |
    xor(special, expected_special)
  if (any(mismatch)) {
    anomalies <- wlv_contract_table(
      raw,
      mismatch,
      context,
      "abort_zero_denominator_profile_mismatch"
    )
    wlv_contract_record(runtime, anomalies)
    wlv_abort_contract(
      context,
      anomalies,
      sprintf(
        "zero-denominator transition differs from explicit profile `%s`",
        resolution$id
      )
    )
  }
  diagnostics <- list()
  expected_kinds <- groups$kind
  observed_kinds <- names(observed)[vapply(observed, any, logical(1L))]
  if (!setequal(observed_kinds, expected_kinds)) {
    stop(sprintf(
      "Zero-denominator kinds differ from explicit profile `%s`.",
      resolution$id
    ), call. = FALSE)
  }
  for (kind in sort(expected_kinds, method = "radix")) {
    expected <- groups[groups$kind == kind, , drop = FALSE]
    keys <- wlv_nonfinite_coordinate_keys(raw, observed[[kind]], context)
    coordinate_sha256 <- wlv_nonfinite_coordinate_sha256(keys)
    if (length(keys) != expected$expected_count[[1L]] ||
        !identical(coordinate_sha256, expected$coordinate_sha256[[1L]])) {
      stop(sprintf(
        paste0(
          "Zero-denominator group `%s/%s` differs from profile `%s` ",
          "(count=%s, sha256=%s)."
        ),
        binding,
        kind,
        resolution$id,
        length(keys),
        coordinate_sha256
      ), call. = FALSE)
    }
    diagnostics[[kind]] <- wlv_nonfinite_resolution_diagnostic_row(
      runtime,
      module,
      binding,
      indicator,
      kind,
      length(keys),
      coordinate_sha256
    )
  }
  result <- wlv_contract_capture(
    runtime,
    wlv_safe_divide(
      numerator,
      denominator,
      zero = "zero_if_denominator_zero",
      context = context
    )
  )
  wlv_contract_record(runtime, attr(result, "wlv_actions", exact = TRUE))
  attr(result, "wlv_state") <- NULL
  attr(result, "wlv_actions") <- NULL
  list(
    value = result,
    diagnostics = list(
      `_nonfinite_resolution_diagnostics.csv` = do.call(rbind, diagnostics)
    )
  )
}

wlv_profiled_nonfinite_mask <- function(
    runtime,
    value,
    artifact,
    indicator,
    axes) {
  profile <- runtime$scientific_profile
  if (is.null(profile)) {
    stop("A profiled non-finite transition requires a scientific profile.",
      call. = FALSE
    )
  }
  wlv_assert_scientific_profile(profile, runtime$method, runtime$source)
  resolution <- profile$nonfinite_resolution
  if (!identical(resolution$action, "replace_nan_with_zero")) {
    stop(sprintf(
      "Scientific profile `%s` declares no non-finite replacement.",
      profile$id
    ), call. = FALSE)
  }
  rules <- resolution$rules[
    resolution$rules$artifact == artifact &
      resolution$rules$indicator == indicator,
    ,
    drop = FALSE
  ]
  if (!nrow(rules)) {
    stop(sprintf(
      "Non-finite resolution profile `%s` does not cover `%s/%s`.",
      resolution$id,
      artifact,
      indicator
    ), call. = FALSE)
  }
  if (!is.numeric(value) || is.null(dim(value)) ||
      is.null(dimnames(value))) {
    stop("Profiled non-finite resolution requires a labelled numeric array.",
      call. = FALSE
    )
  }
  context <- wlv_contract_context(
    artifact = artifact,
    indicator = indicator,
    checkpoint = "profile_resolution",
    policy_id = resolution$id,
    axes = axes
  )
  resolved_axes <- wlv_context_axes(context, value)
  required_axes <- c("year", "country", "sector")
  if (!all(required_axes %in% names(resolved_axes))) {
    stop("Non-finite resolution requires year, country and sector axes.",
      call. = FALSE
    )
  }
  mask <- array(FALSE, dim = dim(value), dimnames = dimnames(value))
  for (index in seq_len(nrow(rules))) {
    selected <- rep(list(TRUE), length(dim(value)))
    for (role in required_axes) {
      axis <- resolved_axes[[role]]
      labels <- dimnames(value)[[axis]]
      declared <- rules[[role]][[index]]
      positions <- if (identical(declared, "*")) {
        seq_along(labels)
      } else {
        match(declared, labels)
      }
      if (!length(positions) || anyNA(positions)) {
        stop(sprintf(
          "Non-finite resolution profile `%s` references unavailable %s `%s`.",
          resolution$id,
          role,
          declared
        ), call. = FALSE)
      }
      selected[[axis]] <- positions
    }
    mask <- do.call(
      `[<-`,
      c(list(mask), selected, list(value = TRUE))
    )
  }
  mask
}

wlv_resolve_profiled_nonfinite <- function(
    runtime,
    values,
    numerators,
    denominator,
    artifact,
    checkpoint,
    stage,
    module,
    axes) {
  if (!is.environment(runtime) || is.null(runtime$scientific_profile)) {
    stop("Profiled non-finite resolution requires a scientific runtime.",
      call. = FALSE
    )
  }
  wlv_assert_scientific_profile(
    runtime$scientific_profile,
    runtime$method,
    runtime$source
  )
  resolution <- runtime$scientific_profile$nonfinite_resolution
  profile_id <- resolution$id
  expected_indicators <- unique(resolution$groups$binding)
  valid_lists <- is.list(values) && is.list(numerators) &&
    !is.null(names(values)) && !is.null(names(numerators)) &&
    !anyDuplicated(names(values)) && !anyDuplicated(names(numerators)) &&
    setequal(names(values), expected_indicators) &&
    setequal(names(numerators), expected_indicators)
  if (!valid_lists || !identical(resolution$action, "replace_nan_with_zero")) {
    stop(sprintf(
      "Non-finite resolution profile `%s` received incompatible outputs.",
      profile_id
    ), call. = FALSE)
  }
  reference <- values[[1L]]
  if (!is.numeric(denominator) ||
      !wlv_same_shape_and_labels(denominator, reference) ||
      anyNA(denominator) || any(is.infinite(denominator))) {
    stop("Profiled non-finite resolution requires one finite denominator.",
      call. = FALSE
    )
  }

  masks <- list()
  actions <- list()
  diagnostics <- list()
  keys <- character()
  for (indicator in sort(expected_indicators, method = "radix")) {
    value <- values[[indicator]]
    numerator <- numerators[[indicator]]
    if (!is.numeric(value) || !is.numeric(numerator) ||
        !wlv_same_shape_and_labels(value, reference) ||
        !wlv_same_shape_and_labels(numerator, reference) ||
        anyNA(numerator) || any(is.infinite(numerator))) {
      stop(sprintf(
        "Profiled non-finite inputs are invalid for `%s`.",
        indicator
      ), call. = FALSE)
    }
    expected <- wlv_profiled_nonfinite_mask(
      runtime,
      value,
      artifact,
      indicator,
      axes
    )
    context <- wlv_contract_context_for(
      runtime,
      artifact = artifact,
      indicator = indicator,
      checkpoint = checkpoint,
      stage = stage,
      module = module,
      axes = axes,
      policy_id = profile_id
    )
    observed_nan <- is.nan(value)
    observed_other_special <-
      (is.na(value) & !is.nan(value)) | is.infinite(value)
    mismatch <- xor(observed_nan, expected) | observed_other_special
    if (any(mismatch)) {
      anomalies <- wlv_contract_table(
        value,
        mismatch,
        context,
        "abort_nonfinite_resolution_profile_mismatch"
      )
      wlv_contract_record(runtime, anomalies)
      wlv_abort_contract(
        context,
        anomalies,
        sprintf(
          "non-finite transition differs from explicit profile `%s`",
          profile_id
        )
      )
    }
    invalid_origin <- expected & (numerator != 0 | denominator != 0)
    if (any(invalid_origin)) {
      anomalies <- wlv_contract_table(
        value,
        invalid_origin,
        context,
        "abort_nonfinite_resolution_origin_mismatch"
      )
      wlv_contract_record(runtime, anomalies)
      wlv_abort_contract(
        context,
        anomalies,
        "profiled NaN transition is not produced by the declared 0/0 origin"
      )
    }

    group_keys <- wlv_nonfinite_coordinate_keys(value, expected, context)
    group_sha256 <- wlv_nonfinite_coordinate_sha256(group_keys)
    group <- resolution$groups[
      resolution$groups$binding == indicator &
        resolution$groups$kind == "NaN",
      ,
      drop = FALSE
    ]
    if (nrow(group) != 1L ||
        !identical(group$indicator[[1L]], indicator) ||
        !identical(group$module[[1L]], module) ||
        length(group_keys) != group$expected_count[[1L]] ||
        !identical(group_sha256, group$coordinate_sha256[[1L]])) {
      stop(sprintf(
        "Non-finite resolution group `%s/NaN` differs from profile `%s`.",
        indicator,
        profile_id
      ), call. = FALSE)
    }
    keys <- c(keys, paste(indicator, group_keys, sep = "|"))
    masks[[indicator]] <- expected
    actions[[indicator]] <- wlv_contract_table(
      value,
      expected,
      context,
      "replace_profiled_historical_nan_with_zero"
    )
    diagnostics[[indicator]] <- wlv_nonfinite_resolution_diagnostic_row(
      runtime,
      module,
      indicator,
      indicator,
      "NaN",
      length(group_keys),
      group_sha256
    )
  }

  keys <- sort(keys, method = "radix")
  if (length(keys) != resolution$expected_count) {
    stop(sprintf(
      "Non-finite transition differs from profile `%s` (count=%s).",
      profile_id,
      length(keys)
    ), call. = FALSE)
  }

  result <- values
  for (indicator in expected_indicators) {
    result[[indicator]][masks[[indicator]]] <- 0
    if (anyNA(result[[indicator]]) || any(is.infinite(result[[indicator]]))) {
      stop("Profiled non-finite resolution did not produce finite outputs.",
        call. = FALSE
      )
    }
  }
  wlv_contract_record(runtime, do.call(wlv_bind_contract_tables, actions))
  wlv_contract_clear_states(runtime, artifact, expected_indicators)
  list(
    values = result,
    diagnostics = list(
      `_nonfinite_resolution_diagnostics.csv` = do.call(rbind, diagnostics)
    )
  )
}

wlv_source_missing_indicators <- function(policy) {
  policy$result_source_missing$row_indicators
}

wlv_contract_slice_registered_states <- function(registered, value) {
  if (length(dim(registered)) != length(dim(value))) {
    return(registered)
  }
  registered_labels <- dimnames(registered)
  value_labels <- dimnames(value)
  if (is.null(registered_labels) || is.null(value_labels) ||
      any(vapply(registered_labels, is.null, logical(1L))) ||
      any(vapply(value_labels, is.null, logical(1L))) ||
      any(vapply(registered_labels, anyDuplicated, integer(1L))) ||
      any(vapply(value_labels, anyDuplicated, integer(1L)))) {
    return(registered)
  }
  registered_roles <- names(registered_labels)
  value_roles <- names(value_labels)
  if (!is.null(registered_roles) && !is.null(value_roles) &&
      !identical(registered_roles, value_roles)) {
    return(registered)
  }
  selected <- lapply(seq_along(value_labels), function(axis) {
    match(value_labels[[axis]], registered_labels[[axis]])
  })
  if (any(vapply(selected, anyNA, logical(1L)))) {
    return(registered)
  }
  sliced <- do.call(`[`, c(list(registered), selected, list(drop = FALSE)))
  array(as.vector(sliced), dim = dim(value), dimnames = value_labels)
}

wlv_m_io_structural_missing_indicators <- function() {
  c("k_composition", "k_depreciation", "consumption_basket")
}

wlv_contract_declared_states <- function(
    runtime,
    artifact,
    indicator,
    value,
    checkpoint) {
  states <- wlv_character_like(value)
  dimensions <- dim(value)
  labels <- dimnames(value)

  if (artifact == "sea_sectors" && length(dimensions) %in% c(3L, 4L)) {
    country_axis <- length(dimensions)
    countries <- labels[[country_axis]]
    if (!is.null(countries) && "ROW" %in% countries) {
      allow_row <- indicator %in% wlv_source_missing_indicators(runtime$policy) ||
        checkpoint == "after_stage_1"
      if (allow_row) {
        if (length(dimensions) == 4L) {
          states[, , , countries == "ROW"] <- "source_missing"
        } else {
          states[, , countries == "ROW"] <- "source_missing"
        }
      }
    }
    if (
      checkpoint == "after_stage_1" &&
      indicator %in% runtime$policy$result_source_missing$stage1_china_indicators &&
      !is.null(countries) && "CHN" %in% countries
    ) {
      if (length(dimensions) == 4L) {
        states[, , , countries == "CHN"] <- "source_missing"
      } else {
        states[, , countries == "CHN"] <- "source_missing"
      }
    }
  }

  if (artifact == "sea_countries" && length(dimensions) %in% c(2L, 3L)) {
    country_axis <- length(dimensions)
    countries <- labels[[country_axis]]
    if (
    indicator %in% wlv_source_missing_indicators(runtime$policy) &&
      !is.null(countries) && "ROW" %in% countries
    ) {
      if (length(dimensions) == 3L) {
        states[, , countries == "ROW"] <- "source_missing"
      } else {
        states[, countries == "ROW"] <- "source_missing"
      }
    }
  }

  if (
    artifact == "m_io" && length(dimensions) == 4L &&
    indicator %in% wlv_m_io_structural_missing_indicators()
  ) {
    inputs <- labels[[3L]]
    outputs <- labels[[4L]]
    if (!is.null(inputs) && !is.null(outputs)) {
      states[, , , !outputs %in% inputs] <- "not_applicable"
    }
  }

  semantic <- wlv_contract_semantic_state_slice(
    runtime,
    artifact,
    indicator,
    value
  )
  if (!is.null(semantic) && nrow(semantic)) {
    positions <- wlv_semantic_state_linear_indices(semantic, value)
    registered <- semantic$state
    conflict <- !is.na(states[positions]) & states[positions] != registered
    if (any(conflict)) {
      conflicts <- unique(data.frame(
        declared = states[positions][conflict],
        registered = registered[conflict],
        stringsAsFactors = FALSE
      ))
      stop(
        sprintf(
          paste0(
            "Conflicting missingness states were registered for `%s/%s`: %s."
          ),
          artifact,
          indicator,
          paste(
            paste(conflicts$declared, conflicts$registered, sep = " -> "),
            collapse = ", "
          )
        ),
        call. = FALSE
      )
    }
    states[positions] <- registered
  }

  key <- wlv_contract_state_key(artifact, indicator)
  if (exists(key, envir = runtime$states, inherits = FALSE)) {
    registered <- get(key, envir = runtime$states, inherits = FALSE)
    if (length(dim(registered)) == length(dim(value)) + 1L &&
        dim(registered)[[2L]] == 1L) {
      if (!identical(dimnames(registered)[[2L]], indicator)) {
        stop(
          "Registered missingness state labels do not match the result slice.",
          call. = FALSE
        )
      }
      registered <- array(
        registered,
        dim = dim(registered)[-2L],
        dimnames = dimnames(registered)[-2L]
      )
    }
    expand_indicator <- length(dim(value)) == length(dim(registered)) + 1L &&
      dim(value)[[2L]] == 1L
    comparison_value <- value
    if (expand_indicator) {
      value_slice <- array(
        value,
        dim = dim(value)[-2L],
        dimnames = dimnames(value)[-2L]
      )
      if (!identical(dimnames(value)[[2L]], indicator)) {
        stop(
          "Registered missingness state labels do not match the result slice.",
          call. = FALSE
        )
      }
      comparison_value <- value_slice
    }
    registered <- wlv_contract_slice_registered_states(
      registered,
      comparison_value
    )
    if (expand_indicator &&
        wlv_same_shape_and_labels(registered, comparison_value)) {
      registered <- array(
        registered,
        dim = dim(value),
        dimnames = dimnames(value)
      )
    }
    same_dimensions <- identical(dim(registered), dim(value))
    if (!same_dimensions) {
      stop(
        sprintf(
          "Registered missingness state shape does not match `%s/%s`.",
          artifact,
          indicator
        ),
        call. = FALSE
      )
    }
    if (same_dimensions && !wlv_same_shape_and_labels(registered, value)) {
      stop(
        "Registered missingness state labels do not match the result array.",
        call. = FALSE
      )
    }
    if (same_dimensions && wlv_same_shape_and_labels(registered, value)) {
      selected <- !is.na(registered) & registered != "finite"
      conflict <- selected & !is.na(states) & states != registered
      if (any(conflict)) {
        conflicts <- unique(data.frame(
          declared = as.vector(states)[as.vector(conflict)],
          registered = as.vector(registered)[as.vector(conflict)],
          stringsAsFactors = FALSE
        ))
        stop(
          sprintf(
            paste0(
              "Conflicting missingness states were registered for `%s/%s`: %s."
            ),
            artifact,
            indicator,
            paste(
              paste(conflicts$declared, conflicts$registered, sep = " -> "),
              collapse = ", "
            )
          ),
          call. = FALSE
        )
      }
      states[selected] <- registered[selected]
    }
  }
  states
}

wlv_assert_no_special_values <- function(
    runtime,
    value,
    artifact,
    indicator,
    checkpoint,
    stage,
    module,
    axes) {
  failed <- is.nan(value) | is.infinite(value)
  if (!any(failed)) {
    return(invisible(value))
  }
  context <- wlv_contract_context_for(
    runtime,
    artifact,
    indicator,
    checkpoint,
    stage,
    module,
    axes
  )
  anomalies <- wlv_contract_table(value, failed, context, "abort_non_finite")
  wlv_contract_record(runtime, anomalies)
  wlv_abort_contract(context, anomalies, "unexpected NaN or infinite value")
}

wlv_validate_sea_indicator <- function(
    runtime,
    sea_sectors,
    indicator,
    checkpoint,
    stage,
    module = NA_character_,
    years = dimnames(sea_sectors)[[1L]]) {
  value <- sea_sectors[years, indicator, , , drop = FALSE]
  context <- wlv_contract_context_for(
    runtime,
    artifact = "sea_sectors",
    indicator = indicator,
    checkpoint = checkpoint,
    stage = stage,
    module = module,
    axes = c(year = 1L, sector = 3L, country = 4L)
  )
  states <- wlv_contract_declared_states(
    runtime,
    "sea_sectors",
    indicator,
    value,
    checkpoint
  )
  wlv_contract_capture(
    runtime,
    wlv_classify_missingness(value, allowed_missing = states, context = context)
  )
  invisible(value)
}

wlv_assert_sea_no_special_values <- function(
    runtime,
    sea_sectors,
    checkpoint,
    stage,
    module = NA_character_) {
  indicators <- dimnames(sea_sectors)[[2L]]
  for (indicator in indicators) {
    value <- sea_sectors[, indicator, , , drop = FALSE]
    wlv_assert_no_special_values(
      runtime,
      value,
      artifact = "sea_sectors",
      indicator = indicator,
      checkpoint = checkpoint,
      stage = stage,
      module = module,
      axes = c(year = 1L, sector = 3L, country = 4L)
    )
  }
  invisible(sea_sectors)
}

wlv_validate_sea_stage <- function(
    runtime,
    sea_sectors,
    sea_variables,
    stage,
    checkpoint,
    years = dimnames(sea_sectors)[[1L]]) {
  due <- sea_variables$names[sea_variables$stage <= stage]
  for (indicator in due) {
    wlv_validate_sea_indicator(
      runtime,
      sea_sectors,
      indicator,
      checkpoint,
      stage,
      years = years
    )
  }
  invisible(sea_sectors)
}

wlv_validate_m_io_contract_detailed <- function(
    runtime,
    value,
    checkpoint = "after_matrices") {
  indicators <- dimnames(value)[[2L]]
  for (indicator in indicators) {
    indicator_value <- value[, indicator, , , drop = FALSE]
    context <- wlv_contract_context_for(
      runtime,
      artifact = "m_io",
      indicator = indicator,
      checkpoint = checkpoint,
      stage = 4L,
      axes = c(year = 1L, sector = 3L, output = 4L)
    )
    states <- wlv_contract_declared_states(
      runtime,
      "m_io",
      indicator,
      indicator_value,
      checkpoint
    )
    wlv_contract_capture(
      runtime,
      wlv_classify_missingness(
        indicator_value,
        allowed_missing = states,
        context = context
      )
    )
  }
  invisible(value)
}

wlv_contract_has_registered_m_io_states <- function(runtime, indicators) {
  keys <- wlv_contract_state_key("m_io", indicators)
  any(vapply(
    keys,
    exists,
    logical(1L),
    envir = runtime$states,
    inherits = FALSE
  ))
}

wlv_can_validate_m_io_contract_sparse <- function(value) {
  dimensions <- dim(value)
  labels <- dimnames(value)
  is.double(value) &&
    !is.object(value) &&
    length(dimensions) == 4L &&
    length(labels) == 4L &&
    all(vapply(seq_len(4L), function(axis) {
      axis_labels <- labels[[axis]]
      !is.null(axis_labels) &&
        length(axis_labels) == dimensions[[axis]] &&
        !anyNA(axis_labels) &&
        !anyDuplicated(axis_labels) &&
        all(nzchar(axis_labels))
    }, logical(1L)))
}

wlv_m_io_nonfinite_positions <- function(value, chunk_values = 2^20) {
  if (!is.double(value) || !is.numeric(chunk_values) ||
      length(chunk_values) != 1L || is.na(chunk_values) ||
      !is.finite(chunk_values) || chunk_values < 1L) {
    stop("Sparse m_io scan received invalid inputs.", call. = FALSE)
  }
  chunk_values <- as.integer(chunk_values)
  total <- length(value)
  if (!total) {
    return(integer())
  }
  positions <- vector("list", ceiling(total / chunk_values))
  index <- 0L
  for (start in seq.int(1L, total, by = chunk_values)) {
    end <- min(total, start + chunk_values - 1L)
    current <- which(!is.finite(value[start:end]))
    if (length(current)) {
      index <- index + 1L
      positions[[index]] <- as.integer(current + start - 1L)
    }
  }
  if (!index) {
    return(integer())
  }
  as.integer(unlist(positions[seq_len(index)], use.names = FALSE))
}

wlv_validate_m_io_contract_compact_chunks <- function(
    value,
    semantic,
    chunk_values = 2^20) {
  if (!wlv_can_validate_m_io_contract_sparse(value) ||
      !(is.null(semantic) || (
        wlv_contract_is_compact_semantic_state(semantic) &&
          identical(semantic$encoding, "cartesian")
      )) || !is.numeric(chunk_values) || length(chunk_values) != 1L ||
      is.na(chunk_values) || !is.finite(chunk_values) || chunk_values < 1L ||
      chunk_values > .Machine$integer.max) {
    stop("Compact m_io validation received invalid inputs.", call. = FALSE)
  }
  chunk_values <- as.integer(chunk_values)
  dimensions <- dim(value)
  labels <- dimnames(value)
  indicators <- labels[[2L]]
  special_indicators <- wlv_m_io_structural_missing_indicators()
  year_count <- dimensions[[1L]]
  indicator_count <- dimensions[[2L]]
  input_count <- dimensions[[3L]]
  total <- length(value)
  if (!total) {
    return(TRUE)
  }
  for (start in seq.int(1L, total, by = chunk_values)) {
    end <- min(total, start + chunk_values - 1L)
    current <- value[start:end]
    local_positions <- which(!is.finite(current))
    if (!length(local_positions)) {
      next
    }
    observed <- current[local_positions]
    if (any(is.nan(observed) | is.infinite(observed))) {
      return(FALSE)
    }
    positions <- as.double(start) + local_positions - 1
    offsets <- positions - 1
    indicator_indices <- (offsets %/% year_count) %% indicator_count + 1
    output_indices <-
      offsets %/% (year_count * indicator_count * input_count) + 1
    allowed <- indicators[indicator_indices] %in% special_indicators &
      !labels[[4L]][output_indices] %in% labels[[3L]]
    unresolved <- !allowed
    if (!is.null(semantic) && any(unresolved)) {
      registered <- wlv_contract_semantic_state_position_states(
        semantic,
        value,
        positions[unresolved]
      )
      allowed[unresolved] <- !is.na(registered)
    }
    if (any(!allowed)) {
      return(FALSE)
    }
  }
  TRUE
}

wlv_validate_m_io_contract_sparse <- function(
    runtime,
    value,
    checkpoint = "after_matrices") {
  if (!wlv_can_validate_m_io_contract_sparse(value)) {
    return(wlv_validate_m_io_contract_detailed(runtime, value, checkpoint))
  }

  dimensions <- dim(value)
  labels <- dimnames(value)
  indicators <- labels[[2L]]
  if (wlv_contract_has_registered_m_io_states(runtime, indicators)) {
    return(wlv_validate_m_io_contract_detailed(runtime, value, checkpoint))
  }
  semantic <- wlv_contract_semantic_state_subset(runtime, "m_io", value)
  if (wlv_contract_semantic_state_has_invalid_structural(
        semantic,
        labels[[3L]]
      )) {
    return(wlv_validate_m_io_contract_detailed(runtime, value, checkpoint))
  }
  if (length(indicators)) {
    wlv_contract_context_for(
      runtime,
      artifact = "m_io",
      indicator = indicators[[1L]],
      checkpoint = checkpoint,
      stage = 4L,
      axes = c(year = 1L, sector = 3L, output = 4L)
    )
  }
  compact_scan <- is.null(semantic) || (
    wlv_contract_is_compact_semantic_state(semantic) &&
      identical(semantic$encoding, "cartesian")
  )
  if (compact_scan) {
    if (!wlv_validate_m_io_contract_compact_chunks(value, semantic)) {
      return(wlv_validate_m_io_contract_detailed(runtime, value, checkpoint))
    }
    return(invisible(value))
  }
  nonfinite_positions <- wlv_m_io_nonfinite_positions(value)
  if (!length(nonfinite_positions)) {
    return(invisible(value))
  }

  semantic_states <- wlv_contract_semantic_state_position_states(
    semantic,
    value,
    nonfinite_positions
  )

  offsets <- nonfinite_positions - 1
  year_count <- dimensions[[1L]]
  indicator_count <- dimensions[[2L]]
  input_count <- dimensions[[3L]]
  indicator_indices <- (offsets %/% year_count) %% indicator_count + 1
  output_indices <-
    offsets %/% (year_count * indicator_count * input_count) + 1
  nonfinite_values <- value[nonfinite_positions]
  special_indicators <- wlv_m_io_structural_missing_indicators()

  for (indicator_index in seq_along(indicators)) {
    selected <- indicator_indices == indicator_index
    if (!any(selected)) {
      next
    }
    indicator <- indicators[[indicator_index]]
    observed <- nonfinite_values[selected]
    selected_outputs <- output_indices[selected]
    invalid_numeric <- is.nan(observed) | is.infinite(observed)
    ordinary_missing <- is.na(observed) & !is.nan(observed)
    allowed_missing <- rep(FALSE, length(observed))
    if (
      indicator %in% special_indicators &&
        !is.null(labels[[3L]]) && !is.null(labels[[4L]])
    ) {
      allowed_missing <- !labels[[4L]][selected_outputs] %in% labels[[3L]]
    }
    registered <- semantic_states[selected]
    allowed_missing <- allowed_missing | !is.na(registered)
    unexpected_missing <- ordinary_missing & !allowed_missing
    if (any(invalid_numeric) || any(unexpected_missing)) {
      return(wlv_validate_m_io_contract_detailed(runtime, value, checkpoint))
    }
  }
  invisible(value)
}

wlv_validate_m_io_contract <- function(runtime, value, checkpoint = "after_matrices") {
  wlv_validate_m_io_contract_sparse(runtime, value, checkpoint)
}

wlv_validate_m_countries_contract <- function(
    runtime,
    value,
    checkpoint = "after_reduced_matrices") {
  indicators <- dimnames(value)[[2L]]
  for (indicator in indicators) {
    indicator_value <- value[, indicator, , , drop = FALSE]
    context <- wlv_contract_context_for(
      runtime,
      artifact = "m_countries",
      indicator = indicator,
      checkpoint = checkpoint,
      stage = 4L,
      axes = c(year = 1L, country = 3L, output = 4L)
    )
    wlv_contract_capture(
      runtime,
      wlv_classify_missingness(indicator_value, context = context)
    )
  }
  invisible(value)
}

wlv_validate_sea_countries_contract <- function(
    runtime,
    value,
    checkpoint = "after_country_aggregation") {
  indicators <- dimnames(value)[[2L]]
  for (indicator in indicators) {
    indicator_value <- value[, indicator, , drop = FALSE]
    context <- wlv_contract_context_for(
      runtime,
      artifact = "sea_countries",
      indicator = indicator,
      checkpoint = checkpoint,
      stage = 5L,
      axes = c(year = 1L, country = 3L)
    )
    states <- wlv_contract_declared_states(
      runtime,
      "sea_countries",
      indicator,
      indicator_value,
      checkpoint
    )
    wlv_contract_capture(
      runtime,
      wlv_classify_missingness(
        indicator_value,
        allowed_missing = states,
        context = context
      )
    )
  }
  invisible(value)
}

wlv_contract_aggregate_runtime <- function(
    runtime,
    value,
    margin,
    operation,
    missing,
    artifact,
    indicator,
    checkpoint,
    stage,
    module,
    axes,
    allowed_missing = NULL) {
  context <- wlv_contract_context_for(
    runtime,
    artifact,
    indicator,
    checkpoint,
    stage,
    module,
    axes
  )
  result <- wlv_contract_capture(
    runtime,
    wlv_contract_aggregate(
      value,
      margin = margin,
      operation = operation,
      missing = missing,
      allowed_missing = allowed_missing,
      context = context
    )
  )
  wlv_contract_register_result(runtime, artifact, indicator, result)
  result
}

wlv_aggregation_allowed_input <- function(allowed_missing, name, value) {
  if (is.null(allowed_missing)) {
    return(NULL)
  }
  if (is.character(allowed_missing)) {
    return(allowed_missing)
  }
  if (!is.list(allowed_missing) || is.null(names(allowed_missing)) ||
      anyDuplicated(names(allowed_missing))) {
    stop("Typed aggregation missingness inputs must be a uniquely named list.",
      call. = FALSE
    )
  }
  state <- allowed_missing[[name]]
  if (is.null(state)) {
    return(NULL)
  }
  if (!wlv_same_shape_and_labels(state, value)) {
    stop("Typed aggregation missingness states do not match their input.",
      call. = FALSE
    )
  }
  state
}

wlv_aggregation_runtime_shape <- function(value, template) {
  if (is.null(dim(template))) {
    result <- as.vector(value)
    names(result) <- names(template)
    return(result)
  }
  array(as.vector(value), dim = dim(template), dimnames = dimnames(template))
}

wlv_contract_aggregation_audit <- function(
    runtime,
    binding,
    values,
    margin,
    allowed_missing,
    context) {
  inputs <- wlv_aggregation_binding_inputs(binding)
  strategy <- binding$spec$strategy
  if (identical(strategy, "not_applicable")) {
    return(NULL)
  }
  if (strategy %in% c("sum", "legacy_mean", "invariant")) {
    input <- values[[inputs[[1L]]]]
    return(wlv_contract_capture(
      runtime,
      wlv_contract_aggregate(
        input,
        margin = margin,
        operation = if (identical(strategy, "sum")) "sum" else "mean",
        missing = binding$spec$missing,
        allowed_missing = wlv_aggregation_allowed_input(
          allowed_missing,
          inputs[[1L]],
          input
        ),
        context = context
      )
    ))
  }

  classifications <- lapply(inputs, function(name) {
    input <- values[[name]]
    wlv_contract_capture(
      runtime,
      wlv_classify_missingness(
        input,
        allowed_missing = wlv_aggregation_allowed_input(
          allowed_missing,
          name,
          input
        ),
        context = context
      )
    )
  })
  reference <- values[[inputs[[1L]]]]
  if (any(!vapply(values[inputs], wlv_same_shape_and_labels, logical(1L),
    right = reference))) {
    stop("Typed aggregation inputs must have identical shape and labels.",
      call. = FALSE
    )
  }
  missing <- Reduce(`|`, lapply(values[inputs], is.na))
  audit <- wlv_character_like(reference, 0)
  audit[missing] <- NA_real_
  states <- wlv_character_like(reference, "finite")
  for (position in which(missing)) {
    states[[position]] <- wlv_group_missing_state(vapply(
      classifications,
      `[[`,
      character(1L),
      position
    ))
  }
  wlv_contract_capture(
    runtime,
    wlv_contract_aggregate(
      audit,
      margin = margin,
      operation = "sum",
      missing = binding$spec$missing,
      allowed_missing = states,
      context = context
    )
  )
}

wlv_contract_aggregate_spec_runtime <- function(
    runtime,
    binding,
    values,
    margin,
    artifact,
    indicator,
    checkpoint,
    stage,
    module,
    axes,
    allowed_missing = NULL) {
  wlv_validate_aggregation_binding(binding)
  if (identical(binding$contract_strategy, "formula")) {
    stop("Formula aggregation bindings cannot use the typed dispatcher.",
      call. = FALSE
    )
  }
  inputs <- wlv_aggregation_binding_inputs(binding)
  if (!is.list(values) || any(!inputs %in% names(values))) {
    stop("Typed aggregation inputs are incomplete.", call. = FALSE)
  }
  reference <- values[[inputs[[1L]]]]
  dimensions <- dim(reference)
  if (is.null(dimensions)) {
    dimensions <- length(reference)
  }
  collapsed <- setdiff(seq_along(dimensions), margin)
  if (length(collapsed) != 1L) {
    stop("Typed aggregation must collapse exactly one input dimension.",
      call. = FALSE
    )
  }
  context <- wlv_contract_context_for(
    runtime,
    artifact,
    indicator,
    checkpoint,
    stage,
    module,
    axes
  )
  audit <- wlv_contract_aggregation_audit(
    runtime,
    binding,
    values,
    margin,
    allowed_missing,
    context
  )

  dispatch_binding <- binding
  zero_policy <- binding$spec$zero_denominator
  if (identical(zero_policy, "error")) {
    dispatch_binding$spec$zero_denominator <- "zero"
  }
  result <- wlv_aggregate_binding(
    dispatch_binding,
    values,
    axis = collapsed
  )
  aggregation_states <- attr(result, "wlv_state", exact = TRUE)
  runtime_states <- if (is.null(audit)) {
    wlv_character_like(result, "not_applicable")
  } else {
    wlv_aggregation_runtime_shape(
      attr(audit, "wlv_state", exact = TRUE),
      result
    )
  }
  actions <- if (is.null(audit)) {
    wlv_empty_contract_table()
  } else {
    attr(audit, "wlv_actions", exact = TRUE)
  }
  if (is.null(actions)) {
    actions <- wlv_empty_contract_table()
  }

  if (binding$spec$strategy %in% c("sum", "legacy_mean") &&
      !identical(as.numeric(result), as.numeric(audit))) {
    stop("Typed aggregation differs from the legacy-compatible reduction.",
      call. = FALSE
    )
  }
  output_context <- wlv_margin_context(context, margin)
  zero_denominator <- aggregation_states == "zero_denominator"
  if (any(zero_denominator)) {
    if (identical(zero_policy, "error")) {
      errors <- wlv_contract_table(
        result,
        zero_denominator,
        output_context,
        "abort_zero_denominator"
      )
      wlv_contract_capture(
        runtime,
        wlv_abort_contract(
          output_context,
          errors,
          sprintf(
            "typed aggregation rejected %s zero denominator(s)",
            sum(zero_denominator)
          )
        )
      )
    }
    runtime_states[zero_denominator] <- "finite"
    actions <- wlv_bind_contract_tables(
      actions,
      wlv_contract_table(
        result,
        zero_denominator,
        output_context,
        "replace_zero_denominator_with_zero"
      )
    )
  }
  zero_not_applicable <- aggregation_states == "not_applicable" &
    binding$spec$strategy %in% c("ratio_of_sums", "weighted_mean")
  if (any(zero_not_applicable)) {
    runtime_states[zero_not_applicable] <- "not_applicable"
    actions <- wlv_bind_contract_tables(
      actions,
      wlv_contract_table(
        result,
        zero_not_applicable,
        output_context,
        "mark_zero_denominator_not_applicable"
      )
    )
  }
  attr(result, "wlv_aggregation_state") <- aggregation_states
  attr(result, "wlv_state") <- runtime_states
  attr(result, "wlv_actions") <- actions
  wlv_contract_register_result(runtime, artifact, indicator, result)
  result
}

wlv_safe_divide_runtime <- function(
    runtime,
    numerator,
    denominator,
    zero,
    artifact,
    indicator,
    checkpoint,
    stage,
    module,
    axes) {
  context <- wlv_contract_context_for(
    runtime,
    artifact,
    indicator,
    checkpoint,
    stage,
    module,
    axes
  )
  result <- wlv_contract_capture(
    runtime,
    wlv_safe_divide(numerator, denominator, zero = zero, context = context)
  )
  wlv_contract_register_result(runtime, artifact, indicator, result)
  result
}

wlv_safe_divide_missing_runtime <- function(
    runtime,
    numerator,
    denominator,
    zero,
    artifact,
    indicator,
    checkpoint,
    stage,
    module,
    axes,
    allowed_missing = NULL,
    numerator_allowed_missing = allowed_missing,
    denominator_allowed_missing = allowed_missing,
    result_allowed_missing = allowed_missing,
    register_result = TRUE) {
  context <- wlv_contract_context_for(
    runtime,
    artifact,
    indicator,
    checkpoint,
    stage,
    module,
    axes
  )
  numerator_state <- wlv_contract_capture(
    runtime,
    wlv_classify_missingness(
      numerator,
      allowed_missing = numerator_allowed_missing,
      context = context
    )
  )
  denominator_state <- wlv_contract_capture(
    runtime,
    wlv_classify_missingness(
      denominator,
      allowed_missing = denominator_allowed_missing,
      context = context
    )
  )
  missing <- is.na(numerator) | is.na(denominator)
  safe_numerator <- numerator
  safe_denominator <- denominator
  safe_numerator[missing] <- 0
  safe_denominator[missing] <- 1
  result <- wlv_contract_capture(
    runtime,
    wlv_safe_divide(
      safe_numerator,
      safe_denominator,
      zero = zero,
      context = context
    )
  )
  states <- attr(result, "wlv_state", exact = TRUE)
  if (any(missing)) {
    states[missing] <- vapply(
      which(missing),
      function(position) {
        wlv_group_missing_state(c(
          numerator_state[[position]],
          denominator_state[[position]]
        ))
      },
      character(1L)
    )
    result[missing] <- NA_real_
  }
  declared_result <- wlv_normalize_allowed_missing(
    result_allowed_missing,
    result
  )
  restore_source_missing <-
    is.na(result) & !is.nan(result) &
    states == "not_applicable" &
    !is.na(declared_result) & declared_result == "source_missing"
  if (any(restore_source_missing)) {
    actions <- wlv_bind_contract_tables(
      attr(result, "wlv_actions", exact = TRUE),
      wlv_contract_table(
        result,
        restore_source_missing,
        context,
        "restore_declared_source_missing"
      )
    )
    states[restore_source_missing] <- "source_missing"
    attr(result, "wlv_actions") <- actions
  }
  attr(result, "wlv_state") <- states
  if (isTRUE(register_result)) {
    wlv_contract_register_result(runtime, artifact, indicator, result)
  } else {
    wlv_contract_record(runtime, attr(result, "wlv_actions", exact = TRUE))
  }
  result
}

wlv_ratio_runtime <- function(
    runtime,
    numerator,
    denominator,
    zero,
    artifact,
    indicator,
    checkpoint,
    stage,
    module,
    axes) {
  allowed <- wlv_contract_declared_states(
    runtime,
    artifact,
    indicator,
    numerator,
    checkpoint
  )
  wlv_safe_divide_missing_runtime(
    runtime,
    numerator,
    denominator,
    zero = zero,
    artifact = artifact,
    indicator = indicator,
    checkpoint = checkpoint,
    stage = stage,
    module = module,
    axes = axes,
    allowed_missing = allowed
  )
}

wlv_ratio_with_dependency_states_runtime <- function(
    runtime,
    numerator,
    denominator,
    dependencies,
    zero,
    artifact,
    indicator,
    checkpoint,
    stage,
    module,
    axes) {
  result_allowed <- wlv_contract_declared_states(
    runtime,
    artifact,
    indicator,
    numerator,
    checkpoint
  )
  if (!is.list(dependencies) || is.null(names(dependencies))) {
    stop("`dependencies` must be a named list of conformable arrays.", call. = FALSE)
  }
  numerator_allowed <- result_allowed
  denominator_allowed <- result_allowed
  for (dependency in names(dependencies)) {
    value <- dependencies[[dependency]]
    wlv_assert_conformable_numeric(numerator, value)
    dependency_allowed <- wlv_contract_declared_states(
      runtime,
      artifact,
      dependency,
      value,
      checkpoint
    )
    dependency_context <- wlv_contract_context_for(
      runtime,
      artifact,
      dependency,
      checkpoint,
      stage,
      module,
      axes
    )
    dependency_states <- wlv_contract_capture(
      runtime,
      wlv_classify_missingness(
        value,
        allowed_missing = dependency_allowed,
        context = dependency_context
      )
    )
    denominator_allowed <- wlv_contract_merge_state_arrays(
      denominator_allowed,
      dependency_states
    )
  }
  wlv_safe_divide_missing_runtime(
    runtime,
    numerator,
    denominator,
    zero = zero,
    artifact = artifact,
    indicator = indicator,
    checkpoint = checkpoint,
    stage = stage,
    module = module,
    axes = axes,
    numerator_allowed_missing = numerator_allowed,
    denominator_allowed_missing = denominator_allowed,
    result_allowed_missing = result_allowed
  )
}

wlv_sequential_ratio_runtime <- function(
    runtime,
    numerator,
    denominators,
    zero,
    artifact,
    indicator,
    checkpoint,
    stage,
    module,
    axes) {
  if (
    !is.list(denominators) || is.null(names(denominators)) ||
    any(!nzchar(names(denominators))) || anyDuplicated(names(denominators))
  ) {
    stop("`denominators` must be a uniquely named list of arrays.", call. = FALSE)
  }
  output_allowed <- wlv_contract_declared_states(
    runtime,
    artifact,
    indicator,
    numerator,
    checkpoint
  )
  current <- numerator
  current_allowed <- output_allowed
  for (dependency in names(denominators)) {
    denominator <- denominators[[dependency]]
    wlv_assert_conformable_numeric(current, denominator)
    denominator_allowed <- wlv_contract_declared_states(
      runtime,
      artifact,
      dependency,
      denominator,
      checkpoint
    )
    result_allowed <- wlv_contract_merge_state_arrays(
      current_allowed,
      denominator_allowed
    )
    current <- wlv_safe_divide_missing_runtime(
      runtime,
      current,
      denominator,
      zero = zero,
      artifact = artifact,
      indicator = indicator,
      checkpoint = checkpoint,
      stage = stage,
      module = module,
      axes = axes,
      numerator_allowed_missing = current_allowed,
      denominator_allowed_missing = denominator_allowed,
      result_allowed_missing = result_allowed
    )
    current_allowed <- wlv_contract_merge_state_arrays(
      output_allowed,
      attr(current, "wlv_state", exact = TRUE)
    )
  }
  current
}

wlv_ratio_of_aggregates_runtime <- function(
    runtime,
    numerator,
    denominator,
    margin,
    indicator,
    numerator_indicator,
    denominator_indicator,
    checkpoint,
    module,
    input_axes,
    output_axes,
    zero = "not_applicable") {
  numerator_allowed <- wlv_contract_declared_states(
    runtime, "sea_sectors", numerator_indicator, numerator, checkpoint
  )
  denominator_allowed <- wlv_contract_declared_states(
    runtime, "sea_sectors", denominator_indicator, denominator, checkpoint
  )
  numerator_context <- wlv_contract_context_for(
    runtime, "sea_sectors", numerator_indicator, checkpoint, 5L, module, input_axes
  )
  denominator_context <- wlv_contract_context_for(
    runtime, "sea_sectors", denominator_indicator, checkpoint, 5L, module, input_axes
  )
  numerator_state <- wlv_contract_capture(
    runtime,
    wlv_classify_missingness(
      numerator, allowed_missing = numerator_allowed, context = numerator_context
    )
  )
  denominator_state <- wlv_contract_capture(
    runtime,
    wlv_classify_missingness(
      denominator, allowed_missing = denominator_allowed, context = denominator_context
    )
  )
  pair_missing <- is.na(numerator) | is.na(denominator)
  paired_state <- wlv_character_like(numerator)
  if (any(pair_missing)) {
    paired_state[pair_missing] <- vapply(
      which(pair_missing),
      function(position) {
        wlv_group_missing_state(c(
          numerator_state[[position]], denominator_state[[position]]
        ))
      },
      character(1L)
    )
    numerator[pair_missing] <- NA_real_
    denominator[pair_missing] <- NA_real_
  }

  aggregate_one <- function(value, suffix) {
    context <- wlv_contract_context_for(
      runtime,
      "sea_countries",
      paste0(indicator, suffix),
      checkpoint,
      5L,
      module,
      input_axes
    )
    result <- wlv_contract_capture(
      runtime,
      wlv_contract_aggregate(
        value,
        margin = margin,
        operation = "sum",
        missing = "available",
        allowed_missing = paired_state,
        context = context
      )
    )
    wlv_contract_record(runtime, attr(result, "wlv_actions", exact = TRUE))
    result
  }
  aggregate_numerator <- aggregate_one(numerator, ".numerator")
  aggregate_denominator <- aggregate_one(denominator, ".denominator")
  numerator_aggregate_state <- attr(
    aggregate_numerator,
    "wlv_state",
    exact = TRUE
  )
  denominator_aggregate_state <- attr(
    aggregate_denominator,
    "wlv_state",
    exact = TRUE
  )
  result_allowed <- wlv_contract_declared_states(
    runtime,
    "sea_countries",
    indicator,
    aggregate_numerator,
    checkpoint
  )
  numerator_result_allowed <- wlv_contract_merge_state_arrays(
    result_allowed,
    numerator_aggregate_state
  )
  denominator_result_allowed <- wlv_contract_merge_state_arrays(
    result_allowed,
    denominator_aggregate_state
  )
  combined_result_allowed <- wlv_contract_merge_state_arrays(
    numerator_result_allowed,
    denominator_aggregate_state
  )
  wlv_safe_divide_missing_runtime(
    runtime,
    aggregate_numerator,
    aggregate_denominator,
    zero = zero,
    artifact = "sea_countries",
    indicator = indicator,
    checkpoint = checkpoint,
    stage = 5L,
    module = module,
    axes = output_axes,
    numerator_allowed_missing = numerator_result_allowed,
    denominator_allowed_missing = denominator_result_allowed,
    result_allowed_missing = combined_result_allowed,
    register_result = FALSE
  )
}

wlv_country_and_world_ratio_runtime <- function(
    runtime,
    numerator,
    denominator,
    indicator,
    numerator_indicator,
    denominator_indicator,
    checkpoint,
    module,
    zero = "not_applicable") {
  country <- wlv_ratio_of_aggregates_runtime(
    runtime,
    numerator,
    denominator,
    margin = c(1L, 3L),
    indicator = indicator,
    numerator_indicator = numerator_indicator,
    denominator_indicator = denominator_indicator,
    checkpoint = checkpoint,
    module = module,
    input_axes = c(year = 1L, sector = 2L, country = 3L),
    output_axes = c(year = 1L, country = 2L),
    zero = zero
  )
  world <- wlv_ratio_of_aggregates_runtime(
    runtime,
    numerator,
    denominator,
    margin = 1L,
    indicator = indicator,
    numerator_indicator = numerator_indicator,
    denominator_indicator = denominator_indicator,
    checkpoint = checkpoint,
    module = module,
    input_axes = c(year = 1L, sector = 2L, country = 3L),
    output_axes = c(year = 1L),
    zero = zero
  )
  list(country = country, world = world)
}

wlv_wiodr16_hours_worked_runtime <- function(
    runtime,
    employee_hours,
    employees,
    persons_engaged,
    indicator = "hours_worked.emp.s.hr",
    module = "indicator.hours_worked.emp.s.hr.wiodr16") {
  wlv_assert_conformable_numeric(employee_hours, employees)
  wlv_assert_conformable_numeric(employee_hours, persons_engaged)
  if (length(dim(employee_hours)) != 3L) {
    stop("WIOD16 labour inputs must be year-sector-country arrays.", call. = FALSE)
  }
  context <- wlv_contract_context_for(
    runtime,
    artifact = "sea_sectors",
    indicator = indicator,
    checkpoint = "after_stage_1",
    stage = 1L,
    module = module,
    axes = c(year = 1L, sector = 2L, country = 3L)
  )
  allowed <- wlv_contract_declared_states(
    runtime,
    "sea_sectors",
    indicator,
    employee_hours,
    "after_stage_1"
  )
  hours_state <- wlv_contract_capture(
    runtime,
    wlv_classify_missingness(
      employee_hours, allowed_missing = allowed, context = context
    )
  )
  employees_state <- wlv_contract_capture(
    runtime,
    wlv_classify_missingness(
      employees, allowed_missing = allowed, context = context
    )
  )
  persons_state <- wlv_contract_capture(
    runtime,
    wlv_classify_missingness(
      persons_engaged, allowed_missing = allowed, context = context
    )
  )

  missing <- is.na(employee_hours) | is.na(employees) | is.na(persons_engaged)
  result <- employee_hours
  result[] <- NA_real_
  states <- wlv_character_like(result, "finite")
  if (any(missing)) {
    states[missing] <- vapply(
      which(missing),
      function(position) {
        wlv_group_missing_state(c(
          hours_state[[position]],
          employees_state[[position]],
          persons_state[[position]]
        ))
      },
      character(1L)
    )
  }

  present <- !missing
  regular <- present & employees != 0
  result[regular] <-
    employee_hours[regular] / employees[regular] *
    persons_engaged[regular]
  persons_zero <- present & employees == 0 & persons_engaged == 0
  result[persons_zero] <- 0
  fallback <- present & employees == 0 & persons_engaged != 0
  raw_result <- employee_hours / employees * persons_engaged
  actions <- wlv_empty_contract_table()
  if (any(persons_zero)) {
    actions <- wlv_bind_contract_tables(
      actions,
      wlv_contract_table(
        raw_result,
        persons_zero,
        context,
        "zero_hours_when_persons_engaged_zero"
      )
    )
  }

  if (any(fallback)) {
    positions <- which(fallback)
    coordinates <- arrayInd(
      positions,
      .dim = dim(employee_hours),
      .dimnames = dimnames(employee_hours)
    )
    keys <- paste(
      dimnames(employee_hours)[[1L]][coordinates[, 1L]],
      dimnames(employee_hours)[[2L]][coordinates[, 2L]],
      dimnames(employee_hours)[[3L]][coordinates[, 3L]],
      sep = "|"
    )
    source_values_match <- length(positions) == 1L && identical(
      c(
        employee_hours[[positions]],
        employees[[positions]],
        persons_engaged[[positions]]
      ),
      c(9000, 0, 10)
    )
    if (!identical(keys, "2001|M72|MLT") || !source_values_match) {
      errors <- wlv_contract_table(
        raw_result,
        fallback,
        context,
        "abort_undeclared_employee_hours_fallback"
      )
      wlv_abort_contract(
        context,
        errors,
        "employee hours require an undeclared zero-employee fallback"
      )
    }
    year_index <- coordinates[[1L, 1L]]
    country_index <- coordinates[[1L, 3L]]
    country_hours <- employee_hours[year_index, , country_index]
    country_employees <- employees[year_index, , country_index]
    if (
      any(!is.finite(country_hours)) || any(!is.finite(country_employees)) ||
      sum(country_employees) <= 0
    ) {
      stop("WIOD16 employee-hours fallback has no complete country basis.", call. = FALSE)
    }
    result[[positions]] <-
      sum(country_hours) / sum(country_employees) *
      persons_engaged[[positions]]
    actions <- wlv_bind_contract_tables(
      actions,
      wlv_contract_table(
        raw_result,
        fallback,
        context,
        "fallback_to_country_employee_hours"
      )
    )
  }

  non_finite <- is.nan(result) | is.infinite(result)
  if (any(non_finite)) {
    errors <- wlv_contract_table(result, non_finite, context, "abort_non_finite_result")
    wlv_abort_contract(context, errors, "employee-hours calculation is non-finite")
  }
  attr(result, "wlv_state") <- states
  attr(result, "wlv_actions") <- actions
  wlv_contract_register_result(runtime, "sea_sectors", indicator, result)
  result
}

wlv_row_capital_stock_runtime <- function(
    runtime,
    row_hours,
    reference_capital,
    reference_hours,
    reference_country_intensity,
    year,
    reference_country,
    indicator = "capital_stock.s.us",
    module = "row/row.R",
    basis = c("hours", "workers")) {
  basis <- match.arg(basis)
  if (
    !is.numeric(row_hours) || !is.numeric(reference_capital) ||
    !is.numeric(reference_hours) ||
    length(row_hours) != length(reference_capital) ||
    length(row_hours) != length(reference_hours) ||
    is.null(names(row_hours)) ||
    !identical(names(row_hours), names(reference_capital)) ||
    !identical(names(row_hours), names(reference_hours)) ||
    length(reference_country_intensity) != 1L ||
    length(year) != 1L || length(reference_country) != 1L
  ) {
    stop("Invalid ROW capital-stock inputs.", call. = FALSE)
  }
  if (
    anyNA(row_hours) || any(!is.finite(row_hours)) ||
    anyNA(reference_capital) || any(!is.finite(reference_capital)) ||
    anyNA(reference_hours) || any(!is.finite(reference_hours)) ||
    !is.finite(reference_country_intensity) || reference_country_intensity <= 0
  ) {
    stop("ROW capital-stock inputs must be complete and finite.", call. = FALSE)
  }

  sectors <- names(row_hours)
  raw_result <- row_hours * reference_capital / reference_hours
  result <- raw_result
  zero_reference_hours <- reference_hours == 0
  invalid_reference <- zero_reference_hours & reference_capital != 0
  if (any(invalid_reference)) {
    stop(
      sprintf(
        "ROW capital-stock reference has capital but zero labour %s.",
        basis
      ),
      call. = FALSE
    )
  }

  country_zero <- zero_reference_hours & row_hours == 0
  country_fallback <- zero_reference_hours & row_hours != 0
  if (identical(runtime$policy$policy_id, "wiodr16_v1")) {
    expected_zero_reference <- sort(
      c(
        "C33", "E37-E39", "H53", "J58", "J59_J60", "K66", "M72",
        "M73", "M74_M75", "T", "U"
      ),
      method = "radix"
    )
    expected_fallback <- setdiff(expected_zero_reference, "M73")
    observed_zero_reference <- sort(
      sectors[zero_reference_hours & reference_capital == 0],
      method = "radix"
    )
    observed_zero <- sort(sectors[country_zero], method = "radix")
    observed_fallback <- sort(sectors[country_fallback], method = "radix")
    aggregate_intensity <- sum(reference_capital) / sum(reference_hours)
    violations <- character()

    if (!identical(runtime$source, "wiodr16")) {
      violations <- c(violations, sprintf("runtime source=%s", runtime$source))
    }
    if (
      identical(basis, "workers") &&
      !identical(runtime$method, "wiodr16v09")
    ) {
      violations <- c(
        violations,
        sprintf("runtime method=%s (expected wiodr16v09)", runtime$method)
      )
    }
    if (!identical(as.character(reference_country), "IND")) {
      violations <- c(
        violations,
        sprintf("reference country=%s (expected IND)", reference_country)
      )
    }
    if (!as.character(year) %in% as.character(2000:2014)) {
      violations <- c(
        violations,
        sprintf("year=%s (expected 2000:2014)", as.character(year))
      )
    }
    if (!is.finite(aggregate_intensity) || aggregate_intensity <= 0) {
      violations <- c(
        violations,
        sprintf("aggregate intensity=%s (expected finite and positive)", aggregate_intensity)
      )
    } else if (!identical(
      as.numeric(reference_country_intensity),
      as.numeric(aggregate_intensity)
    )) {
      violations <- c(
        violations,
        sprintf(
          "reference intensity=%s (expected aggregate intensity=%s)",
          reference_country_intensity,
          aggregate_intensity
        )
      )
    }
    if (!identical(observed_zero_reference, expected_zero_reference)) {
      violations <- c(
        violations,
        sprintf(
          "zero-zero sectors=%s (expected %s)",
          paste(observed_zero_reference, collapse = ","),
          paste(expected_zero_reference, collapse = ",")
        )
      )
    }
    if (!identical(observed_zero, "M73")) {
      violations <- c(
        violations,
        sprintf(
          "zero ROW-%s sectors=%s (expected M73)",
          basis,
          paste(observed_zero, collapse = ",")
        )
      )
    }
    if (!identical(observed_fallback, expected_fallback)) {
      violations <- c(
        violations,
        sprintf(
          "aggregate-fallback sectors=%s (expected %s)",
          paste(observed_fallback, collapse = ","),
          paste(expected_fallback, collapse = ",")
        )
      )
    }
    if (length(violations)) {
      stop(
        sprintf(
          "ROW capital-stock fallback differs from the pinned policy: %s.",
          paste(violations, collapse = "; ")
        ),
        call. = FALSE
      )
    }
  }

  result[country_zero] <- 0
  result[country_fallback] <-
    row_hours[country_fallback] * reference_country_intensity
  if (any(is.na(result)) || any(!is.finite(result))) {
    stop("ROW capital-stock result is non-finite.", call. = FALSE)
  }

  if (any(zero_reference_hours)) {
    report_value <- array(
      raw_result,
      dim = c(1L, length(sectors), 1L),
      dimnames = list(as.character(year), sectors, "ROW")
    )
    context <- wlv_contract_context_for(
      runtime,
      artifact = "sea_sectors",
      indicator = indicator,
      checkpoint = "after_assumptions",
      stage = 1L,
      module = module,
      axes = c(year = 1L, sector = 2L, country = 3L),
      policy_id = if (identical(basis, "hours")) {
        "wiodr16_row_capital_intensity_v1"
      } else {
        paste0(runtime$method, "_row_capital_per_worker_v1")
      }
    )
    if (any(country_zero)) {
      mask <- array(
        country_zero,
        dim = dim(report_value),
        dimnames = dimnames(report_value)
      )
      wlv_contract_record(
        runtime,
        wlv_contract_table(
          report_value,
          mask,
          context,
          if (identical(basis, "hours")) {
            "zero_row_capital_when_hours_zero"
          } else {
            "zero_row_capital_when_workers_zero"
          }
        )
      )
    }
    if (any(country_fallback)) {
      mask <- array(
        country_fallback,
        dim = dim(report_value),
        dimnames = dimnames(report_value)
      )
      wlv_contract_record(
        runtime,
        wlv_contract_table(
          report_value,
          mask,
          context,
          if (identical(basis, "hours")) {
            "fallback_to_reference_country_capital_intensity"
          } else {
            "fallback_to_reference_country_capital_per_worker"
          }
        )
      )
    }
  }
  result
}

wlv_exchange_rate_by_country <- function(
    numerator,
    denominator,
    usa_tolerance = 1e-7) {
  wlv_assert_conformable_numeric(numerator, denominator)
  labels <- dimnames(numerator)
  fully_labelled <-
    length(dim(numerator)) == 3L &&
    length(labels) == 3L &&
    all(vapply(labels, function(value) {
      !is.null(value) && length(value) > 0L && !anyNA(value) &&
        all(nzchar(value)) && !anyDuplicated(value)
    }, logical(1L)))
  if (!fully_labelled) {
    stop(
      "Exchange-rate inputs must be fully labelled year-sector-country arrays.",
      call. = FALSE
    )
  }
  if (
    !is.numeric(usa_tolerance) || length(usa_tolerance) != 1L ||
    is.na(usa_tolerance) || !is.finite(usa_tolerance) || usa_tolerance <= 0
  ) {
    stop("`usa_tolerance` must be one positive finite number.", call. = FALSE)
  }
  if (
    any(is.nan(numerator)) || any(is.infinite(numerator)) ||
    any(is.nan(denominator)) || any(is.infinite(denominator))
  ) {
    stop("Exchange-rate inputs contain NaN or infinite values.", call. = FALSE)
  }
  years <- labels[[1L]]
  countries <- labels[[3L]]
  if (!"USA" %in% countries) {
    stop("Exchange-rate inputs must contain USA for unit validation.", call. = FALSE)
  }
  input_missing <- is.na(numerator) | is.na(denominator)
  non_row_missing <- input_missing
  if ("ROW" %in% countries) {
    non_row_missing[, , countries == "ROW"] <- FALSE
  }
  if (any(non_row_missing)) {
    stop("Exchange-rate inputs are unexpectedly missing outside ROW.", call. = FALSE)
  }

  value <- array(
    NA_real_,
    dim = dim(numerator),
    dimnames = dimnames(numerator)
  )
  rates <- matrix(
    NA_real_,
    nrow = length(years),
    ncol = length(countries),
    dimnames = list(year = years, country = countries)
  )
  for (year_index in seq_along(years)) {
    for (country_index in seq_along(countries)) {
      if (countries[[country_index]] == "ROW") {
        next
      }
      numerator_total <- sum(numerator[year_index, , country_index])
      denominator_total <- sum(denominator[year_index, , country_index])
      if (!is.finite(numerator_total) || numerator_total <= 0) {
        stop(
          sprintf(
            "Exchange-rate numerator total is not positive and finite for %s in %s.",
            countries[[country_index]],
            years[[year_index]]
          ),
          call. = FALSE
        )
      }
      if (!is.finite(denominator_total) || denominator_total <= 0) {
        stop(
          sprintf(
            "Exchange-rate denominator total is not positive and finite for %s in %s.",
            countries[[country_index]],
            years[[year_index]]
          ),
          call. = FALSE
        )
      }
      rate <- numerator_total / denominator_total
      if (!is.finite(rate) || rate <= 0) {
        stop(
          sprintf(
            "Exchange rate is not positive and finite for %s in %s.",
            countries[[country_index]],
            years[[year_index]]
          ),
          call. = FALSE
        )
      }
      rates[year_index, country_index] <- rate
      value[year_index, , country_index] <- rate
    }
  }

  usa_rates <- rates[, "USA"]
  invalid_usa <- abs(usa_rates - 1) > usa_tolerance
  if (any(invalid_usa)) {
    failed_year <- years[[which(invalid_usa)[[1L]]]]
    stop(
      sprintf(
        paste0(
          "USA aggregate exchange rate differs from 1 USD/USD in %s ",
          "(observed %.17g; tolerance %.17g)."
        ),
        failed_year,
        rates[failed_year, "USA"],
        usa_tolerance
      ),
      call. = FALSE
    )
  }
  value[, , "USA"] <- 1
  value
}

wlv_exchange_rate_by_sector_v09 <- function(
    numerator,
    denominator,
    runtime = NULL,
    module = "indicator.exchange.r.us.v09") {
  wlv_assert_conformable_numeric(numerator, denominator)
  if (length(dim(numerator)) != 3L || is.null(dimnames(numerator))) {
    stop("Exchange-rate inputs must be year-sector-country arrays.", call. = FALSE)
  }
  if (
    any(is.nan(numerator)) || any(is.infinite(numerator)) ||
    any(is.nan(denominator)) || any(is.infinite(denominator))
  ) {
    stop("Exchange-rate inputs contain NaN or infinite values.", call. = FALSE)
  }
  countries <- dimnames(numerator)[[3L]]
  input_missing <- is.na(numerator) | is.na(denominator)
  non_row_missing <- input_missing
  if ("ROW" %in% countries) {
    non_row_missing[, , countries == "ROW"] <- FALSE
  }
  if (any(non_row_missing)) {
    stop("Exchange-rate inputs are unexpectedly missing outside ROW.", call. = FALSE)
  }

  value <- array(
    NA_real_,
    dim = dim(numerator),
    dimnames = dimnames(numerator)
  )
  available <- !input_missing
  value[available] <- numerator[available] / denominator[available]
  for (year_index in seq_len(dim(value)[[1L]])) {
    for (country_index in seq_len(dim(value)[[3L]])) {
      if (countries[[country_index]] == "ROW") {
        next
      }
      current <- value[year_index, , country_index]
      invalid <- !is.finite(current) | current <= 0
      if (!any(invalid)) {
        next
      }
      replacement_pool <- current[is.finite(current) & current > 0]
      if (!length(replacement_pool)) {
        stop(
          sprintf(
            "No positive finite exchange rate exists for %s in %s.",
            countries[[country_index]],
            dimnames(value)[[1L]][[year_index]]
          ),
          call. = FALSE
        )
      }
      failed <- array(FALSE, dim = dim(value), dimnames = dimnames(value))
      failed[year_index, invalid, country_index] <- TRUE
      if (!is.null(runtime)) {
        context <- wlv_contract_context_for(
          runtime,
          artifact = "sea_sectors",
          indicator = "exchange.r.us",
          checkpoint = "after_stage_1",
          stage = 1L,
          module = module,
          axes = c(year = 1L, sector = 2L, country = 3L),
          policy_id = "exchange_country_mean_v1"
        )
        wlv_contract_record(
          runtime,
          wlv_contract_table(
            value,
            failed,
            context,
            "replace_invalid_sector_rate_with_country_mean"
          )
        )
      }
      value[year_index, invalid, country_index] <- mean(replacement_pool)
    }
  }
  value
}

wlv_write_contract_report <- function(runtime, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.table(
    runtime$anomalies,
    file = path,
    sep = ";",
    dec = ",",
    row.names = FALSE,
    col.names = TRUE,
    quote = TRUE,
    na = "",
    fileEncoding = "UTF-8"
  )
  invisible(path)
}

wlv_validate_contract_report_records <- function(records) {
  if (!is.data.frame(records) ||
      !all(vapply(records, is.character, logical(1L)))) {
    stop("Contract report records must be a character data frame.", call. = FALSE)
  }
  if (!identical(names(records), wlv_contract_anomaly_columns())) {
    stop("Contract report has an invalid schema.", call. = FALSE)
  }
  records <- records[wlv_contract_anomaly_columns()]
  row.names(records) <- NULL
  records
}

wlv_read_contract_report <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("Contract report does not exist: %s.", path), call. = FALSE)
  }
  encoded <- readLines(path, warn = FALSE, encoding = "UTF-8")
  if (any(grepl("\ufffd", encoded, fixed = TRUE))) {
    stop("Contract report contains invalid UTF-8 text.", call. = FALSE)
  }
  rm(encoded)
  invisible(gc(full = FALSE))
  records <- utils::read.csv2(
    path,
    colClasses = "character",
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = "",
    fileEncoding = "UTF-8"
  )
  wlv_validate_contract_report_records(records)
}

wlv_load_contract_records <- function(runtime, records) {
  records <- wlv_validate_contract_report_records(records)
  if (!nrow(runtime$anomalies)) {
    runtime$anomalies <- records
  } else {
    runtime$anomalies <- wlv_bind_contract_tables(runtime$anomalies, records)
  }
  invisible(TRUE)
}

wlv_load_contract_report <- function(runtime, path) {
  if (!file.exists(path)) {
    return(invisible(FALSE))
  }
  wlv_load_contract_records(runtime, wlv_read_contract_report(path))
}

wlv_contract_state_columns <- function() {
  c(
  "artifact", "indicator", "year", "country", "sector", "output", "state"
)
}

wlv_empty_contract_states <- function() {
  as.data.frame(
    stats::setNames(
      rep(list(character()), length(wlv_contract_state_columns())),
      wlv_contract_state_columns()
    ),
    stringsAsFactors = FALSE
  )
}

wlv_contract_state_axes <- function(artifact) {
  switch(
    artifact,
    sea_sectors = c(year = 1L, sector = 3L, country = 4L),
    sea_countries = c(year = 1L, country = 3L),
    stop(sprintf("Unsupported persisted-state artifact `%s`.", artifact), call. = FALSE)
  )
}

wlv_collect_contract_states <- function(runtime, artifact, value) {
  indicators <- dimnames(value)[[2L]]
  rows <- vector("list", length(indicators))
  for (index in seq_along(indicators)) {
    indicator <- indicators[[index]]
    indicator_value <- if (artifact == "sea_sectors") {
      value[, indicator, , , drop = FALSE]
    } else {
      value[, indicator, , drop = FALSE]
    }
    states <- wlv_contract_declared_states(
      runtime,
      artifact,
      indicator,
      indicator_value,
      checkpoint = "pre_publish"
    )
    selected <- is.na(indicator_value) & !is.na(states) & states != "finite"
    if (!any(selected)) {
      rows[[index]] <- wlv_empty_contract_states()
      next
    }
    if (any(!states[selected] %in% c("source_missing", "not_applicable"))) {
      stop(
        sprintf(
          "Final artifact `%s` indicator `%s` contains an uncomputed state.",
          artifact,
          indicator
        ),
        call. = FALSE
      )
    }
    context <- wlv_contract_context_for(
      runtime,
      artifact = artifact,
      indicator = indicator,
      checkpoint = "pre_publish",
      stage = 5L,
      axes = wlv_contract_state_axes(artifact)
    )
    coordinates <- wlv_contract_table(
      indicator_value,
      selected,
      context,
      action = "persist_state"
    )
    rows[[index]] <- data.frame(
      artifact = coordinates$artifact,
      indicator = coordinates$indicator,
      year = coordinates$year,
      country = coordinates$country,
      sector = coordinates$sector,
      output = coordinates$output,
      state = as.vector(states)[as.vector(selected)],
      stringsAsFactors = FALSE
    )[wlv_contract_state_columns()]
  }
  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result
}

wlv_collect_all_contract_states <- function(runtime, values) {
  states <- do.call(rbind, Map(
    function(artifact, value) {
      wlv_collect_contract_states(runtime, artifact, value)
    },
    names(values),
    values
  ))
  wlv_normalize_contract_states(states)
}

wlv_assert_contract_states_roundtrip <- function(runtime, records, values) {
  expected <- wlv_collect_all_contract_states(runtime, values)
  actual <- wlv_normalize_contract_states(records)
  if (!identical(actual, expected)) {
    stop("Persisted missingness states differ from the in-memory contract.", call. = FALSE)
  }
  invisible(TRUE)
}

wlv_write_contract_states <- function(runtime, staging, reader = read_fst_array) {
  values <- list(
    sea_sectors = reader(file.path(staging, "sea_sectors.fst")),
    sea_countries = reader(file.path(staging, "sea_countries.fst"))
  )
  states <- wlv_collect_all_contract_states(runtime, values)
  path <- file.path(staging, "_states.csv")
  utils::write.table(
    states,
    file = path,
    sep = ";",
    dec = ",",
    row.names = FALSE,
    col.names = TRUE,
    quote = TRUE,
    na = "",
    fileEncoding = "UTF-8"
  )
  invisible(path)
}

wlv_read_contract_states <- function(path) {
  records <- utils::read.csv2(
    path,
    colClasses = "character",
    stringsAsFactors = FALSE,
    check.names = FALSE,
    fileEncoding = "UTF-8"
  )
  if (!identical(names(records), wlv_contract_state_columns())) {
    stop("Persisted missingness states have an invalid schema.", call. = FALSE)
  }
  records[is.na(records)] <- ""
  records <- records[wlv_contract_state_columns()]
  row.names(records) <- NULL
  records
}

wlv_normalize_contract_states <- function(records) {
  records[] <- lapply(records, as.character)
  records[is.na(records)] <- ""
  records <- records[wlv_contract_state_columns()]
  row.names(records) <- NULL
  records
}

wlv_load_contract_states <- function(runtime, path, values) {
  if (!file.exists(path)) {
    has_missing <- any(vapply(
      values,
      function(value) any(is.na(value) & !is.nan(value)),
      logical(1L)
    ))
    if (has_missing) {
      stop(
        "A missing `_states.csv` cannot authorize persisted missing values.",
        call. = FALSE
      )
    }
    return(invisible(FALSE))
  }
  records <- wlv_read_contract_states(path)
  if (!nrow(records)) {
    has_missing <- any(vapply(
      values,
      function(value) any(is.na(value) & !is.nan(value)),
      logical(1L)
    ))
    if (has_missing) {
      stop(
        "An empty `_states.csv` cannot authorize persisted missing values.",
        call. = FALSE
      )
    }
    return(invisible(TRUE))
  }
  if (
    any(!records$artifact %in% names(values)) ||
    any(!records$state %in% c("source_missing", "not_applicable"))
  ) {
    stop("Persisted missingness states contain an invalid artifact or state.", call. = FALSE)
  }
  key <- do.call(paste, c(records[wlv_contract_state_columns()[-7L]], sep = "\034"))
  if (anyDuplicated(key)) {
    stop("Persisted missingness states contain duplicate coordinates.", call. = FALSE)
  }

  for (artifact in unique(records$artifact)) {
    artifact_value <- values[[artifact]]
    artifact_records <- records[records$artifact == artifact, , drop = FALSE]
    artifact_axes <- wlv_contract_state_axes(artifact)
    for (indicator in unique(artifact_records$indicator)) {
      if (!indicator %in% dimnames(artifact_value)[[2L]]) {
        stop(sprintf("Persisted state references unknown indicator `%s`.", indicator), call. = FALSE)
      }
      indicator_value <- if (artifact == "sea_sectors") {
        artifact_value[, indicator, , , drop = FALSE]
      } else {
        artifact_value[, indicator, , drop = FALSE]
      }
      current <- artifact_records[
        artifact_records$indicator == indicator,
        ,
        drop = FALSE
      ]
      coordinates <- matrix(1L, nrow = nrow(current), ncol = length(dim(indicator_value)))
      for (role in names(artifact_axes)) {
        dimension_index <- artifact_axes[[role]]
        labels <- dimnames(indicator_value)[[dimension_index]]
        matched <- match(current[[role]], labels)
        if (anyNA(matched)) {
          stop(
            sprintf("Persisted state has an unknown %s coordinate.", role),
            call. = FALSE
          )
        }
        coordinates[, dimension_index] <- matched
      }
      unused_roles <- setdiff(c("year", "country", "sector", "output"), names(artifact_axes))
      if (any(vapply(current[unused_roles], function(x) any(nzchar(x)), logical(1L)))) {
        stop("Persisted state has coordinates outside its artifact dimensions.", call. = FALSE)
      }
      multipliers <- c(1, cumprod(dim(indicator_value))[-length(dim(indicator_value))])
      positions <- 1L + rowSums(sweep(coordinates - 1L, 2L, multipliers, "*"))
      if (any(!is.na(indicator_value[positions]) | is.nan(indicator_value[positions]))) {
        stop("Persisted state does not point to an ordinary missing value.", call. = FALSE)
      }
      states <- wlv_character_like(indicator_value, "finite")
      states[positions] <- current$state
      wlv_contract_register_states(runtime, artifact, indicator, states)
    }
  }
  invisible(TRUE)
}

wlv_write_failed_contract_report <- function(runtime, results_root, error) {
  if (inherits(error, "wlv_contract_error")) {
    count <- nrow(error$anomalies)
    recorded_tail <- utils::tail(runtime$anomalies, count)
    row.names(recorded_tail) <- NULL
    error_anomalies <- error$anomalies
    row.names(error_anomalies) <- NULL
    already_recorded <- nrow(runtime$anomalies) >= count &&
      identical(recorded_tail, error_anomalies)
    if (!already_recorded) {
      wlv_contract_record(runtime, error$anomalies)
    }
  }
  diagnostics <- file.path(results_root, "diagnostics")
  timestamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  if (inherits(error, "wlv_scientific_validation_error")) {
    dir.create(diagnostics, recursive = TRUE, showWarnings = FALSE)
    scientific_path <- tempfile(
      pattern = sprintf(
        "%s-%s-%s-scientific-",
        runtime$method,
        timestamp,
        Sys.getpid()
      ),
      tmpdir = diagnostics,
      fileext = "-failed.csv"
    )
    scientific_failure <- data.frame(
      method = as.character(error$method),
      check_id = as.character(error$check_id),
      artifact = as.character(error$artifact),
      indicator = as.character(error$indicator),
      scope = as.character(error$scope),
      message = conditionMessage(error),
      stringsAsFactors = FALSE
    )
    quote_csv_field <- function(value) {
      paste0('"', gsub('"', '""', enc2utf8(value), fixed = TRUE), '"')
    }
    header <- paste(vapply(
      names(scientific_failure), quote_csv_field, character(1L)
    ), collapse = ";")
    record <- paste(vapply(
      scientific_failure[1L, ],
      function(value) quote_csv_field(as.character(value)),
      character(1L)
    ), collapse = ";")
    payload <- enc2utf8(paste(header, record, sep = "\r\n"))
    payload_raw <- charToRaw(payload)
    roundtrip_payload <- rawToChar(payload_raw)
    Encoding(roundtrip_payload) <- "UTF-8"
    if (
      !identical(utf8ToInt(roundtrip_payload), utf8ToInt(payload)) ||
        grepl("\ufffd", payload, fixed = TRUE)
    ) {
      stop("Scientific failure payload failed UTF-8 round-trip verification.", call. = FALSE)
    }
    connection <- file(scientific_path, open = "wb")
    writeBin(payload_raw, connection)
    close(connection)
    persisted_raw <- wlv_read_file_raw(scientific_path)
    if (!identical(persisted_raw, payload_raw)) {
      stop("Scientific failure report failed UTF-8 verification.", call. = FALSE)
    }
  }
  if (!nrow(runtime$anomalies)) {
    return(invisible(NULL))
  }
  dir.create(diagnostics, recursive = TRUE, showWarnings = FALSE)
  path <- tempfile(
    pattern = sprintf("%s-%s-%s-", runtime$method, timestamp, Sys.getpid()),
    tmpdir = diagnostics,
    fileext = "-failed.csv"
  )
  wlv_write_contract_report(runtime, path)
}

wlv_method_result_metadata <- function(
    parameters,
    assumptions,
    matrices,
    solutions,
    sectors,
    meta_indicators,
    extra_csv = list()) {
  if (
    !is.list(extra_csv) ||
    (length(extra_csv) &&
      (is.null(names(extra_csv)) ||
        anyNA(names(extra_csv)) ||
        any(!nzchar(names(extra_csv))) ||
        anyDuplicated(names(extra_csv)) ||
        any(basename(names(extra_csv)) != names(extra_csv)) ||
        any(!endsWith(names(extra_csv), ".csv"))))
  ) {
    stop(
      "Additional method result CSVs must be a uniquely named list of CSV files.",
      call. = FALSE
    )
  }
  standard_csv <- list(
    `_parameters.csv` = parameters,
    `_method_assumptions.csv` = assumptions,
    `_method_matrices.csv` = matrices,
    `_method_solutions.csv` = solutions,
    `_sectors.csv` = sectors
  )
  if (length(intersect(names(standard_csv), names(extra_csv)))) {
    stop(
      "Additional method result CSVs cannot replace standard metadata.",
      call. = FALSE
    )
  }
  values <- list(
    csv = c(standard_csv, extra_csv),
    meta_indicators = meta_indicators
  )
  if (any(!vapply(values$csv, is.data.frame, logical(1L))) ||
      !is.data.frame(meta_indicators)) {
    stop("Method result metadata must contain data frames.", call. = FALSE)
  }
  values
}

wlv_write_result_csv <- function(value, path) {
  utils::write.csv2(
    value,
    path,
    row.names = FALSE,
    na = "",
    fileEncoding = "UTF-8"
  )
  size <- file.info(path)$size
  connection <- file(path, open = "rb")
  on.exit(close(connection), add = TRUE)
  bytes <- readBin(connection, what = "raw", n = size)
  decoded <- tryCatch(
    iconv(rawToChar(bytes), from = "UTF-8", to = "UTF-8", sub = NA),
    error = function(error) NA_character_
  )
  if (
    length(decoded) != 1L || is.na(decoded) ||
    !identical(charToRaw(decoded), bytes) ||
    grepl("\ufffd", decoded, fixed = TRUE)
  ) {
    stop(sprintf("Method metadata `%s` failed UTF-8 verification.", path), call. = FALSE)
  }
  invisible(path)
}

wlv_write_method_result_metadata <- function(result_dir, metadata) {
  if (!dir.exists(result_dir) || !is.list(metadata) ||
      !is.list(metadata$csv) || !is.data.frame(metadata$meta_indicators)) {
    stop("Invalid method result metadata destination or payload.", call. = FALSE)
  }
  for (name in names(metadata$csv)) {
    wlv_write_result_csv(metadata$csv[[name]], file.path(result_dir, name))
  }
  saveRDS(metadata$meta_indicators, file.path(result_dir, "meta_indicators.RDS"))
  invisible(result_dir)
}

wlv_read_file_raw <- function(path) {
  size <- file.info(path)$size
  if (is.na(size)) {
    stop(sprintf("Cannot inspect method metadata `%s`.", path), call. = FALSE)
  }
  connection <- file(path, open = "rb")
  on.exit(close(connection), add = TRUE)
  readBin(connection, what = "raw", n = size)
}

wlv_validate_method_result_metadata <- function(staging, expected) {
  if (!is.list(expected) || !is.list(expected$csv) ||
      !is.data.frame(expected$meta_indicators)) {
    stop("Invalid expected method result metadata.", call. = FALSE)
  }
  staged_method_sidecars <- list.files(
    staging,
    pattern = "[.]csv$",
    all.files = TRUE,
    ignore.case = TRUE,
    full.names = FALSE
  )
  unexpected_method_sidecars <- setdiff(
    staged_method_sidecars,
    c(names(expected$csv), "_states.csv", "_anomalies.csv")
  )
  if (length(unexpected_method_sidecars)) {
    stop(
      sprintf(
        paste0(
          "Staged method metadata contains unexpected scientific sidecar ",
          "or metadata sidecar(s): %s."
        ),
        paste(unexpected_method_sidecars, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  for (name in names(expected$csv)) {
    path <- file.path(staging, name)
    if (!file.exists(path)) {
      stop(sprintf("Staged method metadata is missing `%s`.", name), call. = FALSE)
    }
    reference <- tempfile("wlv-result-metadata-", fileext = ".csv")
    on.exit(unlink(reference), add = TRUE)
    wlv_write_result_csv(expected$csv[[name]], reference)
    if (!identical(wlv_read_file_raw(path), wlv_read_file_raw(reference))) {
      stop(
        sprintf("Staged method metadata `%s` differs from the current configuration.", name),
        call. = FALSE
      )
    }
    unlink(reference)
  }
  meta_path <- file.path(staging, "meta_indicators.RDS")
  if (!file.exists(meta_path)) {
    stop("Staged method metadata is missing `meta_indicators.RDS`.", call. = FALSE)
  }
  observed_meta <- tryCatch(
    readRDS(meta_path),
    error = function(error) {
      stop(
        sprintf("Cannot read staged `meta_indicators.RDS`: %s", conditionMessage(error)),
        call. = FALSE
      )
    }
  )
  if (!identical(observed_meta, expected$meta_indicators)) {
    stop(
      "Staged `meta_indicators.RDS` differs from the current calculation metadata.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

wlv_expected_staged_result_artifacts <- function(
    expected_metadata,
    expected_io_artifacts) {
  if (!is.list(expected_metadata) || !is.list(expected_metadata$csv) ||
      !is.data.frame(expected_metadata$meta_indicators)) {
    stop("Invalid expected method result metadata.", call. = FALSE)
  }
  expected_io_artifacts <- chartr("\\", "/", expected_io_artifacts)
  valid_io <- is.character(expected_io_artifacts) &&
    length(expected_io_artifacts) && !anyNA(expected_io_artifacts) &&
    all(nzchar(expected_io_artifacts)) &&
    all(basename(expected_io_artifacts) == expected_io_artifacts) &&
    all(grepl("^m_io.*[.]fst$", expected_io_artifacts)) &&
    !anyDuplicated(expected_io_artifacts)
  if (!valid_io) {
    stop(
      "Expected m_io artifacts must be unique FST basenames.",
      call. = FALSE
    )
  }
  sort(unique(c(
    "m_countries.fst", "m_countries.fst.meta",
    "sea_sectors.fst", "sea_sectors.fst.meta",
    "sea_countries.fst", "sea_countries.fst.meta",
    expected_io_artifacts,
    paste0(expected_io_artifacts, ".meta"),
    names(expected_metadata$csv),
    "meta_indicators.RDS", "_states.csv", "_anomalies.csv",
    wlv_runtime_snapshot_filename(),
    "_scientific_checks.csv"
  )), method = "radix")
}

wlv_assert_staged_result_artifact_allowlist <- function(
    staging,
    expected_artifacts,
    require_scientific_checks) {
  expected_artifacts <- wlv_publication_normalize_relative_paths(
    expected_artifacts,
    "expected staged artifacts"
  )
  observed <- wlv_publication_list_files(
    staging,
    exclude = wlv_run_manifest_filename()
  )
  required <- if (isTRUE(require_scientific_checks)) {
    expected_artifacts
  } else {
    setdiff(expected_artifacts, "_scientific_checks.csv")
  }
  missing <- setdiff(required, observed)
  unexpected <- setdiff(observed, expected_artifacts)
  if (length(missing) || length(unexpected)) {
    details <- c(
      if (length(missing)) {
        paste0("missing: ", paste(missing, collapse = ", "))
      },
      if (length(unexpected)) {
        paste0("unexpected: ", paste(unexpected, collapse = ", "))
      }
    )
    stop(sprintf(
      "Staged result artifact allowlist mismatch (%s).",
      paste(details, collapse = "; ")
    ), call. = FALSE)
  }
  invisible(observed)
}

wlv_validate_staged_results <- function(
    staging,
    method,
    mode,
    runtime,
    expected_metadata,
    aggregation_registry,
    expected_io_artifacts,
    at_stage = NULL,
    reader = read_fst_array,
    runtime_snapshot_receipt = NULL) {
  if (!is.function(reader)) {
    stop("`reader` must be an array reader.", call. = FALSE)
  }
  if (is.null(runtime$scientific_profile)) {
    stop("Staged result validation requires an explicit scientific profile.",
      call. = FALSE
    )
  }
  wlv_assert_scientific_profile(
    runtime$scientific_profile,
    runtime$method,
    runtime$source
  )
  required <- c(
    "m_countries.fst", "m_countries.fst.meta",
    "sea_sectors.fst", "sea_sectors.fst.meta",
    "sea_countries.fst", "sea_countries.fst.meta",
    "meta_indicators.RDS", "_parameters.csv", "_method_assumptions.csv",
    "_method_matrices.csv", "_method_solutions.csv", "_sectors.csv",
    "_states.csv", "_anomalies.csv", wlv_runtime_snapshot_filename()
  )
  missing <- required[!file.exists(file.path(staging, required))]
  if (length(missing)) {
    stop(
      sprintf("Staged results for `%s` are incomplete: %s.", method, paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
  runtime_partitions <- vapply(
    file.path(staging, expected_io_artifacts),
    wlv_native_io_partition,
    character(1L)
  )
  expected_artifacts <- wlv_expected_staged_result_artifacts(
    expected_metadata,
    expected_io_artifacts
  )
  wlv_assert_staged_result_artifact_allowlist(
    staging,
    expected_artifacts,
    require_scientific_checks = FALSE
  )
  pre_validation_artifacts <- wlv_capture_validated_run_artifacts(staging)
  snapshot_bindings <- NULL
  if (is.null(runtime_snapshot_receipt)) {
    wlv_runtime_snapshot_read(
      staging,
      method = method,
      source = runtime$source,
      partitions = runtime_partitions
    )
  } else {
    snapshot_bindings <- wlv_runtime_snapshot_receipt_assert(
      runtime_snapshot_receipt,
      method = method,
      source = runtime$source,
      partitions = runtime_partitions,
      artifacts = pre_validation_artifacts,
      staging = staging
    )
  }
  rm(runtime_snapshot_receipt)
  invisible(gc(full = FALSE))

  solutions <- expected_metadata$csv[["_method_solutions.csv"]]
  sea_sectors <- reader(file.path(staging, "sea_sectors.fst"))
  wlv_validate_sea_stage(
    runtime,
    sea_sectors,
    solutions,
    stage = 5L,
    checkpoint = "post_roundtrip"
  )
  sea_countries <- reader(file.path(staging, "sea_countries.fst"))
  wlv_validate_sea_countries_contract(runtime, sea_countries, "post_roundtrip")
  if (!is.null(snapshot_bindings)) {
    wlv_runtime_snapshot_validate_materialized_panel(
      snapshot_bindings,
      "sea_sectors",
      sea_sectors
    )
    wlv_runtime_snapshot_validate_materialized_panel(
      snapshot_bindings,
      "sea_countries",
      sea_countries
    )
  }
  snapshot_io_bindings <- if (is.null(snapshot_bindings)) {
    NULL
  } else {
    wlv_runtime_snapshot_io_binding_expectations(snapshot_bindings)
  }
  rm(snapshot_bindings)
  invisible(gc(full = TRUE))
  m_countries <- reader(file.path(staging, "m_countries.fst"))
  wlv_validate_m_countries_contract(runtime, m_countries, "post_roundtrip")
  unit_contract_path <- file.path(staging, "_unit_contract.csv")
  persisted_unit_contract <- if (file.exists(unit_contract_path)) {
    tryCatch(
      utils::read.csv2(
        unit_contract_path,
        stringsAsFactors = FALSE,
        colClasses = "character",
        check.names = FALSE,
        na.strings = NULL
      ),
      error = function(error) {
        stop(
          sprintf(
            "Cannot read staged `_unit_contract.csv`: %s",
            conditionMessage(error)
          ),
          call. = FALSE
        )
      }
    )
  } else {
    NULL
  }
  aggregation_rows <- wlv_reconcile_aggregation_registry_sidecar(
    aggregation_registry,
    persisted_unit_contract
  )
  scientific_check_parts <- list(wlv_scientific_validate_result_arrays(
    method = method,
    sea_sectors = sea_sectors,
    sea_countries = sea_countries,
    m_countries = m_countries,
    solutions = solutions,
    aggregations = aggregation_rows
  ))
  scientific_io_years <- character()

  persisted_report <- wlv_read_contract_report(
    file.path(staging, "_anomalies.csv")
  )
  expected_report <- runtime$anomalies
  row.names(expected_report) <- NULL
  if (!identical(persisted_report, expected_report)) {
    stop("Persisted anomaly report differs from the in-memory audit trail.", call. = FALSE)
  }
  wlv_validate_leontief_zero_output_anomalies(runtime, persisted_report)
  wlv_validate_nonfinite_resolution_anomalies(runtime, persisted_report)

  io_files <- sort(list.files(staging, pattern = "^m_io.*\\.fst$", full.names = TRUE))
  if (!length(io_files)) {
    stop(sprintf("Staged results for `%s` contain no m_io array.", method), call. = FALSE)
  }
  for (path in io_files) {
    io_value <- reader(path)
    wlv_validate_m_io_contract(
      runtime,
      io_value,
      checkpoint = "post_roundtrip"
    )
    if (!is.null(snapshot_io_bindings)) {
      wlv_runtime_snapshot_validate_materialized_io(
        snapshot_io_bindings,
        wlv_native_io_partition(path),
        io_value
      )
    }
    scientific_check_parts[[length(scientific_check_parts) + 1L]] <-
      wlv_scientific_validate_io_array(
        method = method,
        m_io = io_value,
        sea_sectors = sea_sectors
      )
    scientific_io_years <- c(
      scientific_io_years,
      dimnames(io_value)[[1L]]
    )
    rm(io_value)
    gc()
  }
  rm(snapshot_io_bindings)
  persisted_runtime <- wlv_new_contract_runtime(
    method = runtime$method,
    source = runtime$source,
    policy = runtime$policy,
    scientific_profile = runtime$scientific_profile
  )
  persisted_states <- wlv_read_contract_states(
    file.path(staging, "_states.csv")
  )
  wlv_assert_contract_states_roundtrip(
    runtime,
    persisted_states,
    values = list(
      sea_sectors = sea_sectors,
      sea_countries = sea_countries
    )
  )
  wlv_load_contract_states(
    persisted_runtime,
    file.path(staging, "_states.csv"),
    values = list(
      sea_sectors = sea_sectors,
      sea_countries = sea_countries
    )
  )
  wlv_validate_sea_stage(
    persisted_runtime,
    sea_sectors,
    solutions,
    stage = 5L,
    checkpoint = "post_roundtrip_persisted"
  )
  wlv_validate_sea_countries_contract(
    persisted_runtime,
    sea_countries,
    checkpoint = "post_roundtrip_persisted"
  )
  scientific_names <- grep(
    wlv_scientific_sidecar_pattern(),
    names(expected_metadata$csv),
    value = TRUE
  )
  scientific_names <- setdiff(scientific_names, "_scientific_checks.csv")
  scientific_diagnostics <- expected_metadata$csv[scientific_names]
  scientific_checks <- wlv_finalize_scientific_checks(
    checks = scientific_check_parts,
    method = method,
    source = runtime$source,
    years = dimnames(sea_sectors)[[1L]],
    io_years = scientific_io_years,
    diagnostics = scientific_diagnostics,
    sea_sectors = sea_sectors,
    scientific_profile = runtime$scientific_profile
  )
  wlv_write_result_csv(
    scientific_checks,
    file.path(staging, "_scientific_checks.csv")
  )
  written_scientific_checks <- wlv_publication_file_record(
    file.path(staging, "_scientific_checks.csv")
  )
  expected_metadata$csv[["_scientific_checks.csv"]] <- scientific_checks
  wlv_validate_method_result_metadata(staging, expected_metadata)
  wlv_assert_staged_result_artifact_allowlist(
    staging,
    expected_artifacts,
    require_scientific_checks = TRUE
  )
  validated_artifacts <- wlv_capture_validated_run_artifacts(staging)
  validated_paths <- vapply(
    validated_artifacts,
    `[[`,
    character(1L),
    "path"
  )
  scientific_index <- match("_scientific_checks.csv", validated_paths)
  validated_scientific_checks <- if (!is.na(scientific_index)) {
    validated_artifacts[[scientific_index]][c("size_bytes", "sha256")]
  } else {
    NULL
  }
  if (!identical(validated_scientific_checks, written_scientific_checks)) {
    stop(
      paste0(
        "Staged scientific checks changed while their semantic contract ",
        "was being validated."
      ),
      call. = FALSE
    )
  }
  wlv_assert_staged_validation_snapshot(
    pre_validation_artifacts,
    validated_artifacts
  )
  attr(scientific_checks, "wlv_validated_run_artifacts") <-
    validated_artifacts
  invisible(scientific_checks)
}
