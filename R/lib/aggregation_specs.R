# Pure, typed aggregation specifications and deterministic reducers.
#
# This file deliberately has no dependency on the calculation runtime. It
# operates on labelled numeric arrays and returns another numeric array with a
# shape-aligned `wlv_state` attribute.

wlv_aggregation_strategies <- function() {
  c(
    "sum", "legacy_mean", "ratio_of_sums", "weighted_mean",
    "invariant", "not_applicable"
  )
}

wlv_aggregation_levels <- function() {
  c("sector_to_country", "country_to_world")
}

wlv_aggregation_missing_policies <- function() {
  c("error", "propagate", "available")
}

wlv_aggregation_zero_policies <- function() {
  c("error", "not_applicable", "zero")
}

wlv_aggregation_scalar_character <- function(value, name, choices) {
  if (
    !is.character(value) || length(value) != 1L || is.na(value) ||
      !nzchar(value) || !value %in% choices
  ) {
    stop(
      sprintf(
        "`%s` must be exactly one of: %s.",
        name,
        paste(choices, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  value
}

wlv_validate_aggregation_spec <- function(spec) {
  if (!inherits(spec, "wlv_aggregation_spec") || !is.list(spec)) {
    stop("`spec` must be a `wlv_aggregation_spec` object.", call. = FALSE)
  }
  expected_names <- c(
    "strategy", "level", "missing", "zero_denominator", "tolerance"
  )
  if (!identical(names(spec), expected_names)) {
    stop("Invalid `wlv_aggregation_spec` fields.", call. = FALSE)
  }

  wlv_aggregation_scalar_character(
    spec$strategy,
    "strategy",
    wlv_aggregation_strategies()
  )
  wlv_aggregation_scalar_character(
    spec$level,
    "level",
    wlv_aggregation_levels()
  )
  wlv_aggregation_scalar_character(
    spec$missing,
    "missing",
    wlv_aggregation_missing_policies()
  )

  needs_zero_policy <- spec$strategy %in% c(
    "ratio_of_sums", "weighted_mean"
  )
  if (needs_zero_policy) {
    wlv_aggregation_scalar_character(
      spec$zero_denominator,
      "zero_denominator",
      wlv_aggregation_zero_policies()
    )
  } else if (!is.null(spec$zero_denominator)) {
    stop(
      "`zero_denominator` is valid only for ratio or weighted aggregations.",
      call. = FALSE
    )
  }

  if (
    !is.numeric(spec$tolerance) || length(spec$tolerance) != 1L ||
      is.na(spec$tolerance) || !is.finite(spec$tolerance) ||
      spec$tolerance < 0
  ) {
    stop("`tolerance` must be one finite non-negative number.", call. = FALSE)
  }
  invisible(spec)
}

wlv_aggregation_spec <- function(
    strategy,
    level,
    missing,
    zero_denominator = NULL,
    tolerance = sqrt(.Machine$double.eps)) {
  if (base::missing(missing)) {
    stop("`missing` must be declared explicitly.", call. = FALSE)
  }
  spec <- structure(
    list(
      strategy = strategy,
      level = level,
      missing = missing,
      zero_denominator = zero_denominator,
      tolerance = tolerance
    ),
    class = "wlv_aggregation_spec"
  )
  wlv_validate_aggregation_spec(spec)
  spec
}

is.wlv_aggregation_spec <- function(value) {
  inherits(value, "wlv_aggregation_spec")
}

print.wlv_aggregation_spec <- function(x, ...) {
  wlv_validate_aggregation_spec(x)
  cat(
    "<wlv_aggregation_spec>\n",
    "  strategy: ", x$strategy, "\n",
    "  level: ", x$level, "\n",
    "  missing: ", x$missing, "\n",
    sep = ""
  )
  if (!is.null(x$zero_denominator)) {
    cat("  zero denominator: ", x$zero_denominator, "\n", sep = "")
  }
  invisible(x)
}

wlv_aggregation_assert_array <- function(value, name) {
  if (!is.numeric(value) || is.null(dim(value)) || !length(value)) {
    stop(sprintf("`%s` must be a non-empty numeric array.", name), call. = FALSE)
  }
  if (any(is.nan(value)) || any(is.infinite(value))) {
    stop(
      sprintf("`%s` must not contain NaN or infinite values.", name),
      call. = FALSE
    )
  }
  invisible(value)
}

wlv_aggregation_assert_conformable <- function(reference, value, name) {
  wlv_aggregation_assert_array(value, name)
  if (
    !identical(dim(reference), dim(value)) ||
      !identical(dimnames(reference), dimnames(value))
  ) {
    stop(
      sprintf("`%s` must have the same dimensions and dimnames as its peer.", name),
      call. = FALSE
    )
  }
  invisible(value)
}

wlv_aggregation_axis_role <- function(level) {
  if (identical(level, "sector_to_country")) "sector" else "country"
}

wlv_aggregation_resolve_axis <- function(value, level, axis = NULL) {
  role <- wlv_aggregation_axis_role(level)
  dimension_count <- length(dim(value))
  dimension_names <- names(dimnames(value))

  if (is.null(axis)) {
    if (is.null(dimension_names)) {
      stop(
        sprintf(
          "The `%s` dimension must be named, or `axis` must be supplied.",
          role
        ),
        call. = FALSE
      )
    }
    selected <- which(!is.na(dimension_names) & dimension_names == role)
    if (length(selected) != 1L) {
      stop(
        sprintf("Expected exactly one dimension named `%s`.", role),
        call. = FALSE
      )
    }
    return(selected)
  }

  if (is.character(axis)) {
    if (length(axis) != 1L || is.na(axis) || !identical(axis, role)) {
      stop(sprintf("Character `axis` must be `%s`.", role), call. = FALSE)
    }
    if (is.null(dimension_names)) {
      stop("A character `axis` requires named dimensions.", call. = FALSE)
    }
    selected <- which(!is.na(dimension_names) & dimension_names == axis)
    if (length(selected) != 1L) {
      stop(sprintf("Expected exactly one dimension named `%s`.", axis), call. = FALSE)
    }
    return(selected)
  }

  if (
    !is.numeric(axis) || length(axis) != 1L || is.na(axis) ||
      !is.finite(axis) || axis != floor(axis) || axis < 1L ||
      axis > dimension_count
  ) {
    stop("Numeric `axis` must select exactly one array dimension.", call. = FALSE)
  }
  selected <- as.integer(axis)
  if (
    !is.null(dimension_names) && !is.na(dimension_names[[selected]]) &&
      nzchar(dimension_names[[selected]]) &&
      !identical(dimension_names[[selected]], role)
  ) {
    stop(
      sprintf(
        "Aggregation level `%s` cannot collapse dimension `%s`.",
        level,
        dimension_names[[selected]]
      ),
      call. = FALSE
    )
  }
  selected
}

wlv_aggregation_layout <- function(value, axis) {
  dimensions <- dim(value)
  labels <- dimnames(value)
  retained <- setdiff(seq_along(dimensions), axis)
  permutation <- c(retained, axis)
  permuted <- if (length(permutation) > 1L) {
    aperm(value, permutation)
  } else {
    value
  }
  retained_size <- if (length(retained)) prod(dimensions[retained]) else 1L
  list(
    values = matrix(
      as.numeric(permuted),
      nrow = retained_size,
      ncol = dimensions[[axis]]
    ),
    retained_dim = dimensions[retained],
    retained_dimnames = if (is.null(labels)) NULL else labels[retained]
  )
}

wlv_aggregation_restore <- function(values, states, layout) {
  if (!length(layout$retained_dim)) {
    result <- as.numeric(values[[1L]])
    attr(result, "wlv_state") <- as.character(states[[1L]])
    return(result)
  }
  result <- array(
    as.numeric(values),
    dim = layout$retained_dim,
    dimnames = layout$retained_dimnames
  )
  state <- array(
    as.character(states),
    dim = layout$retained_dim,
    dimnames = layout$retained_dimnames
  )
  attr(result, "wlv_state") <- state
  result
}

wlv_aggregation_state <- function(value) {
  attr(value, "wlv_state", exact = TRUE)
}

wlv_aggregation_missing_selection <- function(missing, policy, group) {
  if (!any(missing)) {
    return(list(selected = rep(TRUE, length(missing)), state = "finite"))
  }
  if (identical(policy, "error")) {
    stop(
      sprintf("Missing aggregation input in group %s.", group),
      call. = FALSE
    )
  }
  if (identical(policy, "propagate")) {
    return(list(selected = rep(FALSE, length(missing)), state = "missing"))
  }
  selected <- !missing
  list(
    selected = selected,
    state = if (any(selected)) "partial" else "missing"
  )
}

wlv_aggregation_assert_finite_result <- function(value, group) {
  if (length(value) != 1L || is.na(value) || !is.finite(value)) {
    stop(
      sprintf("Aggregation produced a non-finite result in group %s.", group),
      call. = FALSE
    )
  }
  value
}

wlv_aggregation_reduce_unary <- function(matrix, spec) {
  result <- rep(NA_real_, nrow(matrix))
  states <- rep(NA_character_, nrow(matrix))
  for (group in seq_len(nrow(matrix))) {
    current <- matrix[group, ]
    selection <- wlv_aggregation_missing_selection(
      is.na(current),
      spec$missing,
      group
    )
    states[[group]] <- selection$state
    if (!any(selection$selected)) {
      next
    }
    selected <- current[selection$selected]
    aggregate <- switch(
      spec$strategy,
      sum = sum(selected),
      legacy_mean = mean(selected),
      invariant = {
        reference <- selected[[1L]]
        scale <- max(1, abs(selected), abs(reference))
        if (any(abs(selected - reference) > spec$tolerance * scale)) {
          stop(
            sprintf("Invariant aggregation differs within group %s.", group),
            call. = FALSE
          )
        }
        reference
      },
      stop("Unsupported unary aggregation strategy.", call. = FALSE)
    )
    result[[group]] <- wlv_aggregation_assert_finite_result(aggregate, group)
  }
  list(value = result, state = states)
}

wlv_aggregation_zero_result <- function(policy, group) {
  switch(
    policy,
    error = stop(
      sprintf("Zero aggregation denominator in group %s.", group),
      call. = FALSE
    ),
    not_applicable = list(value = NA_real_, state = "not_applicable"),
    zero = list(value = 0, state = "zero_denominator"),
    stop("Unsupported zero-denominator policy.", call. = FALSE)
  )
}

wlv_aggregation_reduce_pair <- function(left, right, spec) {
  result <- rep(NA_real_, nrow(left))
  states <- rep(NA_character_, nrow(left))
  for (group in seq_len(nrow(left))) {
    current_left <- left[group, ]
    current_right <- right[group, ]
    selection <- wlv_aggregation_missing_selection(
      is.na(current_left) | is.na(current_right),
      spec$missing,
      group
    )
    states[[group]] <- selection$state
    if (!any(selection$selected)) {
      next
    }
    selected_left <- current_left[selection$selected]
    selected_right <- current_right[selection$selected]

    if (identical(spec$strategy, "ratio_of_sums")) {
      numerator <- sum(selected_left)
      denominator <- sum(selected_right)
    } else {
      numerator <- sum(selected_left * selected_right)
      denominator <- sum(selected_right)
    }
    wlv_aggregation_assert_finite_result(numerator, group)
    wlv_aggregation_assert_finite_result(denominator, group)

    if (denominator == 0) {
      zero <- wlv_aggregation_zero_result(spec$zero_denominator, group)
      result[[group]] <- zero$value
      states[[group]] <- zero$state
      next
    }
    result[[group]] <- wlv_aggregation_assert_finite_result(
      numerator / denominator,
      group
    )
  }
  list(value = result, state = states)
}

wlv_aggregate <- function(spec, ...) {
  if (inherits(spec, "wlv_aggregation_spec")) {
    return(wlv_aggregate.wlv_aggregation_spec(spec, ...))
  }
  wlv_aggregate.default(spec, ...)
}

wlv_aggregate.default <- function(spec, ...) {
  stop("`spec` must be a `wlv_aggregation_spec` object.", call. = FALSE)
}

wlv_aggregate.wlv_aggregation_spec <- function(
    spec,
    value = NULL,
    numerator = NULL,
    denominator = NULL,
    weight = NULL,
    axis = NULL,
    ...) {
  wlv_validate_aggregation_spec(spec)
  if (length(list(...))) {
    stop("Unsupported aggregation arguments were supplied.", call. = FALSE)
  }

  strategy <- spec$strategy
  if (strategy %in% c("sum", "legacy_mean", "invariant", "not_applicable")) {
    if (is.null(value) || !is.null(numerator) || !is.null(denominator) || !is.null(weight)) {
      stop(
        sprintf("Strategy `%s` requires only `value`.", strategy),
        call. = FALSE
      )
    }
    wlv_aggregation_assert_array(value, "value")
    selected_axis <- wlv_aggregation_resolve_axis(value, spec$level, axis)
    layout <- wlv_aggregation_layout(value, selected_axis)
    if (identical(strategy, "not_applicable")) {
      count <- nrow(layout$values)
      return(wlv_aggregation_restore(
        rep(NA_real_, count),
        rep("not_applicable", count),
        layout
      ))
    }
    reduced <- wlv_aggregation_reduce_unary(layout$values, spec)
    return(wlv_aggregation_restore(reduced$value, reduced$state, layout))
  }

  if (identical(strategy, "ratio_of_sums")) {
    if (
      !is.null(value) || is.null(numerator) || is.null(denominator) ||
        !is.null(weight)
    ) {
      stop("Strategy `ratio_of_sums` requires numerator and denominator.", call. = FALSE)
    }
    wlv_aggregation_assert_array(numerator, "numerator")
    wlv_aggregation_assert_conformable(numerator, denominator, "denominator")
    selected_axis <- wlv_aggregation_resolve_axis(numerator, spec$level, axis)
    numerator_layout <- wlv_aggregation_layout(numerator, selected_axis)
    denominator_layout <- wlv_aggregation_layout(denominator, selected_axis)
    reduced <- wlv_aggregation_reduce_pair(
      numerator_layout$values,
      denominator_layout$values,
      spec
    )
    return(wlv_aggregation_restore(
      reduced$value,
      reduced$state,
      numerator_layout
    ))
  }

  if (
    is.null(value) || is.null(weight) || !is.null(numerator) ||
      !is.null(denominator)
  ) {
    stop("Strategy `weighted_mean` requires value and weight.", call. = FALSE)
  }
  wlv_aggregation_assert_array(value, "value")
  wlv_aggregation_assert_conformable(value, weight, "weight")
  if (any(weight < 0, na.rm = TRUE)) {
    stop("`weight` must be non-negative.", call. = FALSE)
  }
  selected_axis <- wlv_aggregation_resolve_axis(value, spec$level, axis)
  value_layout <- wlv_aggregation_layout(value, selected_axis)
  weight_layout <- wlv_aggregation_layout(weight, selected_axis)
  reduced <- wlv_aggregation_reduce_pair(
    value_layout$values,
    weight_layout$values,
    spec
  )
  wlv_aggregation_restore(reduced$value, reduced$state, value_layout)
}
