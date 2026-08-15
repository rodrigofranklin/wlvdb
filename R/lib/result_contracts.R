wlv_new_contract_runtime <- function(method, source, policy) {
  if (!inherits(policy, "wlv_missingness_policy")) {
    stop("`policy` must be a missingness policy.", call. = FALSE)
  }
  runtime <- new.env(parent = emptyenv())
  runtime$method <- method
  runtime$source <- source
  runtime$policy <- policy
  runtime$anomalies <- wlv_empty_contract_table()
  runtime$states <- new.env(parent = emptyenv())
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
  invalid <- denominator == 0 & numerator != 0
  if (!any(invalid)) {
    if (identical(runtime$method, "wiodr13")) {
      stop("The pinned WIOD13 Leontief exception set is unexpectedly empty.", call. = FALSE)
    }
    return(numerator)
  }
  if (!identical(runtime$method, "wiodr13")) {
    stop("Leontief inputs contain an undeclared nonzero flow over zero output.", call. = FALSE)
  }
  coordinates <- which(invalid, arr.ind = TRUE)
  observed_years <- years[coordinates[, 1L]]
  observed_inputs <- inputs[coordinates[, 2L]]
  observed_outputs <- outputs[coordinates[, 3L]]
  keys <- sort(
    paste(observed_years, observed_inputs, observed_outputs, sep = "|"),
    method = "radix"
  )
  hash_file <- tempfile("wlv-leontief-", fileext = ".txt")
  on.exit(unlink(hash_file), add = TRUE)
  connection <- file(hash_file, open = "wb")
  writeBin(charToRaw(enc2utf8(paste(keys, collapse = "\n"))), connection)
  close(connection)
  observed_hash <- unname(tools::md5sum(hash_file))
  observed_counts <- table(paste(observed_years, observed_outputs, sep = "|"))
  expected_counts <- c(
    "2005|CYP.23" = 781L,
    "2006|CYP.23" = 776L,
    "2007|CYP.23" = 786L,
    "2005|MLT.23" = 807L
  )
  expected_hash <- "f66341eea44e71728bbda6f8e25765ba"
  counts_match <-
    identical(sort(names(observed_counts)), sort(names(expected_counts))) &&
    identical(
      as.integer(observed_counts[names(expected_counts)]),
      as.integer(expected_counts)
    )
  if (length(keys) != 3150L || !counts_match || !identical(observed_hash, expected_hash)) {
    stop(
      sprintf(
        paste0(
          "WIOD13 Leontief exceptions differ from the pinned set ",
          "(count=%s, md5=%s)."
        ),
        length(keys),
        observed_hash
      ),
      call. = FALSE
    )
  }

  original_ratio <- numerator / denominator
  dimnames(original_ratio) <- list(years, inputs, outputs)
  context <- wlv_contract_context_for(
    runtime,
    artifact = "m_io",
    indicator = "leontief_input_ratio",
    checkpoint = "after_matrices",
    stage = 3L,
    module = "transformation.R",
    axes = c(year = 1L, sector = 2L, output = 3L),
    policy_id = "wiodr13_leontief_zero_output_v1"
  )
  wlv_contract_record(
    runtime,
    wlv_contract_table(
      original_ratio,
      invalid,
      context,
      "allowlisted_nonzero_over_zero"
    )
  )
  numerator[invalid] <- 0
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

wlv_source_missing_indicators <- function(policy) {
  policy$result_source_missing$row_indicators
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
    indicator %in% c("k_composition", "k_depreciation", "consumption_basket")
  ) {
    inputs <- labels[[3L]]
    outputs <- labels[[4L]]
    if (!is.null(inputs) && !is.null(outputs)) {
      states[, , , !outputs %in% inputs] <- "not_applicable"
    }
  }

  key <- wlv_contract_state_key(artifact, indicator)
  if (exists(key, envir = runtime$states, inherits = FALSE)) {
    registered <- get(key, envir = runtime$states, inherits = FALSE)
    if (
      length(dim(registered)) == length(dim(value)) + 1L &&
      dim(registered)[[2L]] == 1L &&
      identical(dim(registered)[-2L], dim(value))
    ) {
      registered_slice <- array(
        registered,
        dim = dim(registered)[-2L],
        dimnames = dimnames(registered)[-2L]
      )
      if (
        !identical(dimnames(registered)[[2L]], indicator) ||
        !wlv_same_shape_and_labels(registered_slice, value)
      ) {
        stop(
          "Registered missingness state labels do not match the result slice.",
          call. = FALSE
        )
      }
      registered <- array(
        registered,
        dim = dim(value),
        dimnames = dimnames(value)
      )
    }
    if (
      length(dim(value)) == length(dim(registered)) + 1L &&
      dim(value)[[2L]] == 1L &&
      identical(dim(value)[-2L], dim(registered))
    ) {
      value_slice <- array(
        value,
        dim = dim(value)[-2L],
        dimnames = dimnames(value)[-2L]
      )
      if (
        !identical(dimnames(value)[[2L]], indicator) ||
        !wlv_same_shape_and_labels(value_slice, registered)
      ) {
        stop(
          "Registered missingness state labels do not match the result slice.",
          call. = FALSE
        )
      }
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

wlv_validate_m_io_contract <- function(runtime, value, checkpoint = "after_matrices") {
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
    module = "wiodr16/hours_worked.emp.s.hr.R") {
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
    persons_engaged[regular] * 1000000
  persons_zero <- present & employees == 0 & persons_engaged == 0
  result[persons_zero] <- 0
  fallback <- present & employees == 0 & persons_engaged != 0
  raw_result <- employee_hours / employees * persons_engaged * 1000000
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
      c(0.009, 0, 0.01)
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
      persons_engaged[[positions]] * 1000000
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
    module = "row/row.R") {
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
      "ROW capital-stock reference has capital but zero labour hours.",
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
          "zero ROW-hours sectors=%s (expected M73)",
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
      policy_id = "wiodr16_row_capital_intensity_v1"
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
          "zero_row_capital_when_hours_zero"
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
          "fallback_to_reference_country_capital_intensity"
        )
      )
    }
  }
  result
}

wlv_exchange_rate_by_country <- function(
    numerator,
    denominator,
    runtime = NULL,
    module = "wiodr13/exchange.r.us.R") {
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

wlv_read_contract_report <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("Contract report does not exist: %s.", path), call. = FALSE)
  }
  encoded <- readLines(path, warn = FALSE, encoding = "UTF-8")
  if (any(grepl("\ufffd", encoded, fixed = TRUE))) {
    stop("Contract report contains invalid UTF-8 text.", call. = FALSE)
  }
  records <- utils::read.csv2(
    path,
    colClasses = "character",
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = "",
    fileEncoding = "UTF-8"
  )
  if (!identical(names(records), wlv_contract_anomaly_columns)) {
    stop("Contract report has an invalid schema.", call. = FALSE)
  }
  records <- records[wlv_contract_anomaly_columns]
  row.names(records) <- NULL
  records
}

wlv_load_contract_report <- function(runtime, path) {
  if (!file.exists(path)) {
    return(invisible(FALSE))
  }
  previous <- wlv_read_contract_report(path)
  runtime$anomalies <- wlv_bind_contract_tables(runtime$anomalies, previous)
  invisible(TRUE)
}

wlv_contract_state_columns <- c(
  "artifact", "indicator", "year", "country", "sector", "output", "state"
)

wlv_empty_contract_states <- function() {
  as.data.frame(
    stats::setNames(
      rep(list(character()), length(wlv_contract_state_columns)),
      wlv_contract_state_columns
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
    )[wlv_contract_state_columns]
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
  if (!identical(names(records), wlv_contract_state_columns)) {
    stop("Persisted missingness states have an invalid schema.", call. = FALSE)
  }
  records[is.na(records)] <- ""
  records <- records[wlv_contract_state_columns]
  row.names(records) <- NULL
  records
}

wlv_normalize_contract_states <- function(records) {
  records[] <- lapply(records, as.character)
  records[is.na(records)] <- ""
  records <- records[wlv_contract_state_columns]
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
  key <- do.call(paste, c(records[wlv_contract_state_columns[-7L]], sep = "\034"))
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
  if (!nrow(runtime$anomalies)) {
    return(invisible(NULL))
  }
  diagnostics <- file.path(results_root, "diagnostics")
  dir.create(diagnostics, recursive = TRUE, showWarnings = FALSE)
  timestamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
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
    meta_indicators) {
  values <- list(
    csv = list(
      `_parameters.csv` = parameters,
      `_method_assumptions.csv` = assumptions,
      `_method_matrices.csv` = matrices,
      `_method_solutions.csv` = solutions,
      `_sectors.csv` = sectors
    ),
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
  encoded <- readLines(path, warn = FALSE, encoding = "UTF-8")
  if (any(grepl("\ufffd", encoded, fixed = TRUE))) {
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

wlv_validate_staged_results <- function(
    staging,
    method,
    mode,
    runtime,
    expected_metadata,
    at_stage = NULL,
    reader = read_fst_array) {
  if (!is.function(reader)) {
    stop("`reader` must be an array reader.", call. = FALSE)
  }
  required <- c(
    "m_countries.fst", "m_countries.fst.meta",
    "sea_sectors.fst", "sea_sectors.fst.meta",
    "sea_countries.fst", "sea_countries.fst.meta",
    "meta_indicators.RDS", "_parameters.csv", "_method_assumptions.csv",
    "_method_matrices.csv", "_method_solutions.csv", "_sectors.csv",
    "_states.csv", "_anomalies.csv"
  )
  missing <- required[!file.exists(file.path(staging, required))]
  if (length(missing)) {
    stop(
      sprintf("Staged results for `%s` are incomplete: %s.", method, paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }

  wlv_validate_method_result_metadata(staging, expected_metadata)

  solutions <- utils::read.csv2(
    file.path(staging, "_method_solutions.csv"),
    stringsAsFactors = FALSE
  )
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
  m_countries <- reader(file.path(staging, "m_countries.fst"))
  wlv_validate_m_countries_contract(runtime, m_countries, "post_roundtrip")

  persisted_report <- wlv_read_contract_report(
    file.path(staging, "_anomalies.csv")
  )
  expected_report <- runtime$anomalies
  row.names(expected_report) <- NULL
  if (!identical(persisted_report, expected_report)) {
    stop("Persisted anomaly report differs from the in-memory audit trail.", call. = FALSE)
  }

  io_files <- sort(list.files(staging, pattern = "^m_io.*\\.fst$", full.names = TRUE))
  io_required <- !identical(mode, "recalculate") ||
    is.null(at_stage) || at_stage <= 4L
  if (!length(io_files) && io_required) {
    stop(sprintf("Staged results for `%s` contain no m_io array.", method), call. = FALSE)
  }
  for (path in io_files) {
    io_value <- reader(path)
    wlv_validate_m_io_contract(
      runtime,
      io_value,
      checkpoint = "post_roundtrip"
    )
    rm(io_value)
    gc()
  }
  persisted_runtime <- wlv_new_contract_runtime(
    method = runtime$method,
    source = runtime$source,
    policy = runtime$policy
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
  invisible(staging)
}

wlv_prepare_global_metadata <- function(run_environment, results_root) {
  indicators <- get0(
    "wlv_pending_indicators_en",
    envir = run_environment,
    inherits = FALSE
  )
  metadata <- get0(
    "wlv_pending_meta_indicators",
    envir = run_environment,
    inherits = FALSE
  )
  values <- list(
    indicators_en.csv = indicators,
    meta_indicators.csv = metadata
  )
  values <- values[!vapply(values, is.null, logical(1L))]
  if (!length(values)) {
    return(data.frame(
      target = character(), temporary = character(), backup = character(),
      had_target = logical(), installed = logical(), stringsAsFactors = FALSE
    ))
  }

  transaction <- data.frame(
    target = file.path(results_root, names(values)),
    temporary = character(length(values)),
    backup = character(length(values)),
    had_target = file.exists(file.path(results_root, names(values))),
    installed = rep(FALSE, length(values)),
    stringsAsFactors = FALSE
  )
  prepared <- FALSE
  on.exit({
    if (!prepared) {
      unlink(transaction$temporary[nzchar(transaction$temporary)], force = TRUE)
    }
  }, add = TRUE)
  for (index in seq_along(values)) {
    target <- transaction$target[[index]]
    temporary <- tempfile(
      pattern = paste0(".metadata-", basename(target), "-"),
      tmpdir = results_root
    )
    utils::write.csv2(
      values[[index]],
      temporary,
      row.names = FALSE,
      fileEncoding = "UTF-8"
    )
    encoded <- readLines(temporary, warn = FALSE, encoding = "UTF-8")
    if (any(grepl("\ufffd", encoded, fixed = TRUE))) {
      stop(sprintf("Global metadata `%s` failed UTF-8 verification.", target), call. = FALSE)
    }
    transaction$temporary[[index]] <- temporary
  }
  prepared <- TRUE
  transaction
}

wlv_rollback_global_metadata <- function(transaction) {
  if (is.null(transaction) || !nrow(transaction)) {
    return(invisible(transaction))
  }
  new_backups <- rep("", nrow(transaction))
  moved_new <- rep(FALSE, nrow(transaction))
  restored_old <- rep(FALSE, nrow(transaction))

  restore_new_generation <- function() {
    for (index in rev(which(restored_old & moved_new))) {
      target <- transaction$target[[index]]
      backup <- transaction$backup[[index]]
      if (file.exists(target) && !file.exists(backup)) {
        file.rename(target, backup)
      }
    }
    for (index in which(moved_new)) {
      target <- transaction$target[[index]]
      recovery <- new_backups[[index]]
      if (file.exists(recovery) && !file.exists(target)) {
        file.rename(recovery, target)
      }
    }
    invisible(NULL)
  }

  for (index in seq_len(nrow(transaction))) {
    target <- transaction$target[[index]]
    if (transaction$installed[[index]] && file.exists(target)) {
      recovery <- tempfile(
        pattern = paste0(".rollback-new-metadata-", basename(target), "-"),
        tmpdir = dirname(target)
      )
      if (!file.rename(target, recovery)) {
        restore_new_generation()
        stop(
          sprintf("Could not retain new global metadata `%s` for rollback.", target),
          call. = FALSE
        )
      }
      new_backups[[index]] <- recovery
      moved_new[[index]] <- TRUE
    }
  }

  for (index in seq_len(nrow(transaction))) {
    target <- transaction$target[[index]]
    backup <- transaction$backup[[index]]
    if (nzchar(backup)) {
      if (!file.exists(backup) || file.exists(target) ||
          !file.rename(backup, target)) {
        restore_new_generation()
        stop(
          sprintf(
            paste0(
              "Could not restore prior global metadata `%s`; the new ",
              "metadata generation was retained where recovery succeeded."
            ),
            target
          ),
          call. = FALSE
        )
      }
      restored_old[[index]] <- TRUE
    } else if (transaction$had_target[[index]] && !file.exists(target)) {
      restore_new_generation()
      stop(
        sprintf(
          "Prior global metadata `%s` is missing and has no rollback backup.",
          target
        ),
        call. = FALSE
      )
    }
  }

  unlink(new_backups[nzchar(new_backups)], force = TRUE)
  if (any(file.exists(new_backups[nzchar(new_backups)]))) {
    message("Global metadata rollback succeeded, but a new-generation backup remains.")
  }
  temporary <- transaction$temporary[nzchar(transaction$temporary)]
  unlink(temporary, force = TRUE)
  if (any(file.exists(temporary))) {
    message("Global metadata rollback succeeded, but a temporary metadata file remains.")
  }
  invisible(transaction)
}

wlv_begin_global_metadata_transaction <- function(run_environment, results_root) {
  transaction <- wlv_prepare_global_metadata(run_environment, results_root)
  if (!nrow(transaction)) {
    return(transaction)
  }
  installed <- FALSE
  on.exit({
    if (!installed) {
      wlv_rollback_global_metadata(transaction)
    }
  }, add = TRUE)
  for (index in seq_len(nrow(transaction))) {
    target <- transaction$target[[index]]
    if (transaction$had_target[[index]]) {
      backup <- tempfile(
        pattern = paste0(".backup-metadata-", basename(target), "-"),
        tmpdir = results_root
      )
      if (!file.rename(target, backup)) {
        stop(sprintf("Could not back up global metadata `%s`.", target), call. = FALSE)
      }
      transaction$backup[[index]] <- backup
    }
    if (!file.rename(transaction$temporary[[index]], target)) {
      stop(sprintf("Could not publish global metadata `%s`.", target), call. = FALSE)
    }
    transaction$temporary[[index]] <- ""
    transaction$installed[[index]] <- TRUE
  }
  installed <- TRUE
  transaction
}

wlv_finalize_global_metadata <- function(transaction) {
  backups <- transaction$backup[nzchar(transaction$backup)]
  if (length(backups)) {
    unlink(backups, force = TRUE)
    remaining <- backups[file.exists(backups)]
    if (length(remaining)) {
      warning(
        sprintf("Could not remove global metadata backup(s): %s.", paste(remaining, collapse = ", ")),
        call. = FALSE
      )
    }
  }
  invisible(transaction)
}
