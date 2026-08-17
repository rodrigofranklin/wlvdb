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

wlv_aggregation_contract_strategies <- function() {
  c(
    "sum", "mean", "ratio_of_sums", "weighted_mean", "invariant",
    "not_applicable", "formula"
  )
}

wlv_aggregation_contract_columns <- function() {
  c(
    "indicator", "level", "strategy", "module", "numerator",
    "denominator", "weight", "zero_denominator", "notes"
  )
}

wlv_aggregation_binding_key <- function(indicator, level) {
  paste(indicator, level, sep = "\034")
}

wlv_aggregation_contract_field <- function(row, name) {
  value <- as.character(row[[name]][[1L]])
  if (is.na(value)) "" else value
}

wlv_aggregation_binding_from_row <- function(
    row,
    missing = "available",
    legacy = FALSE) {
  required <- c(
    "indicator", "level", "strategy", "module", "numerator",
    "denominator", "weight", "zero_denominator"
  )
  if (!is.data.frame(row) || nrow(row) != 1L ||
      any(!required %in% names(row))) {
    stop("An aggregation contract binding must be exactly one complete row.",
      call. = FALSE
    )
  }
  fields <- stats::setNames(
    lapply(required, function(name) wlv_aggregation_contract_field(row, name)),
    required
  )
  wlv_aggregation_scalar_character(
    fields$level,
    "level",
    wlv_aggregation_levels()
  )
  wlv_aggregation_scalar_character(
    fields$strategy,
    "strategy",
    wlv_aggregation_contract_strategies()
  )
  if (!nzchar(fields$indicator)) {
    stop("An aggregation contract binding requires an indicator.", call. = FALSE)
  }

  formula <- identical(fields$strategy, "formula")
  if (formula != nzchar(fields$module)) {
    stop("Only formula aggregation bindings may declare a module.", call. = FALSE)
  }
  ratio <- identical(fields$strategy, "ratio_of_sums")
  weighted <- identical(fields$strategy, "weighted_mean")
  dependencies <- c(fields$numerator, fields$denominator, fields$weight)
  valid_dependencies <-
    if (ratio) {
      nzchar(fields$numerator) && nzchar(fields$denominator) &&
        !nzchar(fields$weight)
    } else if (weighted) {
      nzchar(fields$weight) &&
        !nzchar(fields$numerator) && !nzchar(fields$denominator)
    } else {
      !any(nzchar(dependencies))
    }
  if (!valid_dependencies) {
    stop("Aggregation binding dependencies do not match its strategy.",
      call. = FALSE
    )
  }

  strategy <- if (identical(fields$strategy, "mean")) {
    "legacy_mean"
  } else {
    fields$strategy
  }
  spec <- if (formula) {
    NULL
  } else {
    wlv_aggregation_spec(
      strategy = strategy,
      level = fields$level,
      missing = missing,
      zero_denominator = if (ratio || weighted) {
        fields$zero_denominator
      } else {
        NULL
      }
    )
  }
  structure(
    list(
      indicator = fields$indicator,
      level = fields$level,
      contract_strategy = fields$strategy,
      spec = spec,
      module = fields$module,
      numerator = fields$numerator,
      denominator = fields$denominator,
      weight = fields$weight,
      legacy = isTRUE(legacy)
    ),
    class = "wlv_aggregation_binding"
  )
}

wlv_validate_aggregation_binding <- function(binding) {
  if (!inherits(binding, "wlv_aggregation_binding") || !is.list(binding)) {
    stop("`binding` must be a `wlv_aggregation_binding` object.", call. = FALSE)
  }
  expected <- c(
    "indicator", "level", "contract_strategy", "spec", "module",
    "numerator", "denominator", "weight", "legacy"
  )
  if (!identical(names(binding), expected)) {
    stop("Invalid `wlv_aggregation_binding` fields.", call. = FALSE)
  }
  formula <- identical(binding$contract_strategy, "formula")
  if (formula) {
    if (!is.null(binding$spec) || !nzchar(binding$module)) {
      stop("Invalid formula aggregation binding.", call. = FALSE)
    }
  } else {
    wlv_validate_aggregation_spec(binding$spec)
    if (!identical(binding$spec$level, binding$level) || nzchar(binding$module)) {
      stop("Aggregation binding and specification disagree.", call. = FALSE)
    }
  }
  invisible(binding)
}

wlv_aggregation_legacy_row <- function(indicator, level, solution) {
  formula <- grepl("[.][Rr]$", solution)
  strategy <- if (formula) {
    "formula"
  } else if (solution %in% c("sum", "mean")) {
    solution
  } else {
    stop(
      sprintf("Legacy aggregation string `%s` cannot be adapted.", solution),
      call. = FALSE
    )
  }
  data.frame(
    indicator = indicator,
    level = level,
    strategy = strategy,
    module = if (formula) solution else "",
    numerator = "",
    denominator = "",
    weight = "",
    zero_denominator = "",
    notes = "Experimental legacy aggregation adapter.",
    stringsAsFactors = FALSE
  )
}

wlv_aggregation_contract_row_is_compatible <- function(
    row,
    solution,
    indicators) {
  if (!nrow(row)) {
    return(FALSE)
  }
  strategy <- wlv_aggregation_contract_field(row, "strategy")
  module <- wlv_aggregation_contract_field(row, "module")
  formula <- grepl("[.][Rr]$", solution)
  solution_matches <- if (formula) {
    identical(strategy, "formula") && identical(module, solution)
  } else {
    !identical(strategy, "formula")
  }
  references <- unlist(
    row[c("numerator", "denominator", "weight")],
    use.names = FALSE
  )
  references <- as.character(references)
  references <- references[!is.na(references) & nzchar(references)]
  solution_matches && all(references %in% indicators)
}

wlv_resolve_aggregation_registry <- function(
    aggregations,
    solutions,
    method,
    stable,
    allow_legacy = FALSE,
    missing = "available") {
  required_aggregations <- c(
    "indicator", "level", "strategy", "module", "numerator",
    "denominator", "weight", "zero_denominator"
  )
  if (!is.data.frame(aggregations) ||
      any(!required_aggregations %in% names(aggregations))) {
    stop("`aggregations` must contain typed unit-contract rows.", call. = FALSE)
  }
  if (!is.data.frame(solutions) ||
      any(!c("names", "country_solution") %in% names(solutions)) ||
      anyNA(solutions[c("names", "country_solution")]) ||
      any(!nzchar(solutions$names)) || anyDuplicated(solutions$names)) {
    stop("`solutions` must contain unique aggregation metadata.", call. = FALSE)
  }
  if (!is.character(method) || length(method) != 1L || is.na(method) ||
      !nzchar(method)) {
    stop("`method` must be one non-empty string.", call. = FALSE)
  }
  if (!is.logical(stable) || length(stable) != 1L || is.na(stable) ||
      !is.logical(allow_legacy) || length(allow_legacy) != 1L ||
      is.na(allow_legacy)) {
    stop("`stable` and `allow_legacy` must be explicit flags.", call. = FALSE)
  }
  wlv_aggregation_scalar_character(
    missing,
    "missing",
    wlv_aggregation_missing_policies()
  )

  # Experimental methods deliberately remain on their historical execution
  # path. Unit definitions still describe their inputs and outputs, but typed
  # aggregation rows become authoritative only when a method is stable.
  if (!stable) {
    aggregations <- aggregations[FALSE, , drop = FALSE]
  }

  indicators <- as.character(solutions$names)
  levels <- wlv_aggregation_levels()
  rows <- vector("list", length(indicators) * length(levels))
  legacy <- logical(length(rows))
  position <- 0L
  for (indicator_index in seq_along(indicators)) {
    indicator <- indicators[[indicator_index]]
    solution <- as.character(solutions$country_solution[[indicator_index]])
    for (level in levels) {
      position <- position + 1L
      selected <- aggregations$indicator == indicator &
        aggregations$level == level
      row <- aggregations[selected, , drop = FALSE]
      compatible <- nrow(row) == 1L &&
        wlv_aggregation_contract_row_is_compatible(
          row,
          solution,
          indicators
        )
      if (!compatible) {
        if (stable) {
          stop(
            sprintf(
              paste0(
                "Stable method `%s` lacks a valid typed aggregation for ",
                "`%s/%s` (legacy string: `%s`)."
              ),
              method,
              indicator,
              level,
              solution
            ),
            call. = FALSE
          )
        }
        if (!allow_legacy) {
          stop(
            sprintf(
              paste0(
                "Experimental method `%s` requires explicit opt-in to adapt ",
                "legacy aggregation `%s` for `%s/%s`."
              ),
              method,
              solution,
              indicator,
              level
            ),
            call. = FALSE
          )
        }
        row <- wlv_aggregation_legacy_row(indicator, level, solution)
        legacy[[position]] <- TRUE
      }
      rows[[position]] <- row
    }
  }
  rows <- do.call(rbind, rows)
  row.names(rows) <- NULL
  bindings <- lapply(seq_len(nrow(rows)), function(index) {
    wlv_aggregation_binding_from_row(
      rows[index, , drop = FALSE],
      missing = missing,
      legacy = legacy[[index]]
    )
  })
  names(bindings) <- vapply(
    bindings,
    function(binding) {
      wlv_aggregation_binding_key(binding$indicator, binding$level)
    },
    character(1L)
  )
  if (anyDuplicated(names(bindings))) {
    stop("Aggregation registry bindings are not unique.", call. = FALSE)
  }
  for (indicator in indicators) {
    country_binding <- bindings[[wlv_aggregation_binding_key(
      indicator,
      "sector_to_country"
    )]]
    world_binding <- bindings[[wlv_aggregation_binding_key(
      indicator,
      "country_to_world"
    )]]
    country_formula <- identical(
      country_binding$contract_strategy,
      "formula"
    )
    world_formula <- identical(world_binding$contract_strategy, "formula")
    if (country_formula != world_formula ||
        (country_formula && !identical(
          country_binding$module,
          world_binding$module
        ))) {
      stop(
        sprintf(
          "Aggregation formula bindings disagree for `%s` across levels.",
          indicator
        ),
        call. = FALSE
      )
    }
    if (!world_formula) {
      dependencies <- wlv_aggregation_binding_inputs(world_binding)
      formula_dependencies <- dependencies[vapply(
        dependencies,
        function(dependency) {
          dependency_binding <- bindings[[wlv_aggregation_binding_key(
            dependency,
            "sector_to_country"
          )]]
          !is.null(dependency_binding) && identical(
            dependency_binding$contract_strategy,
            "formula"
          )
        },
        logical(1L)
      )]
      if (length(formula_dependencies)) {
        stop(
          sprintf(
            paste0(
              "Direct country-to-world aggregation `%s` depends on ",
              "formula-produced country indicator(s): %s."
            ),
            indicator,
            paste(formula_dependencies, collapse = ", ")
          ),
          call. = FALSE
        )
      }
    }
  }
  if (any(legacy)) {
    adapted <- paste(
      rows$indicator[legacy],
      rows$level[legacy],
      sep = "/"
    )
    warning(
      sprintf(
        paste0(
          "Experimental method `%s` adapted legacy aggregations: %s. ",
          "Rows without unit definitions are omitted from _unit_contract.csv."
        ),
        method,
        paste(adapted, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  structure(
    list(
      method = method,
      bindings = bindings,
      rows = rows,
      legacy = any(legacy)
    ),
    class = "wlv_aggregation_registry"
  )
}

wlv_validate_aggregation_registry <- function(registry) {
  if (!inherits(registry, "wlv_aggregation_registry") || !is.list(registry) ||
      !identical(names(registry), c("method", "bindings", "rows", "legacy")) ||
      !is.list(registry$bindings) || !length(registry$bindings) ||
      is.null(names(registry$bindings)) || anyDuplicated(names(registry$bindings))) {
    stop("Invalid `wlv_aggregation_registry` object.", call. = FALSE)
  }
  invisible(lapply(registry$bindings, wlv_validate_aggregation_binding))
  invisible(registry)
}

wlv_aggregation_registry_legacy_flags <- function(registry) {
  wlv_validate_aggregation_registry(registry)
  row_keys <- wlv_aggregation_binding_key(
    as.character(registry$rows$indicator),
    as.character(registry$rows$level)
  )
  if (!identical(row_keys, names(registry$bindings))) {
    stop("Aggregation registry rows and bindings are not aligned.", call. = FALSE)
  }
  vapply(
    registry$bindings,
    function(binding) isTRUE(binding$legacy),
    logical(1L)
  )
}

wlv_aggregation_sidecar_rows <- function(sidecar) {
  columns <- wlv_aggregation_contract_columns()
  if (is.null(sidecar)) {
    empty <- stats::setNames(
      rep(list(character()), length(columns)),
      columns
    )
    return(as.data.frame(
      empty,
      stringsAsFactors = FALSE,
      check.names = FALSE
    ))
  }
  sidecar_columns <- c(setdiff(columns, "notes"), "aggregation_notes")
  if (!is.data.frame(sidecar) || any(!sidecar_columns %in% names(sidecar))) {
    stop(
      "`_unit_contract.csv` does not contain complete aggregation rows.",
      call. = FALSE
    )
  }
  rows <- sidecar[, sidecar_columns, drop = FALSE]
  names(rows)[names(rows) == "aggregation_notes"] <- "notes"
  rows <- as.data.frame(
    lapply(rows[, columns, drop = FALSE], as.character),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  row.names(rows) <- NULL
  if (anyNA(rows)) {
    stop("`_unit_contract.csv` aggregation rows must not contain NA.", call. = FALSE)
  }
  rows
}

wlv_reconcile_aggregation_registry_sidecar <- function(
    registry,
    sidecar,
    stable) {
  wlv_validate_aggregation_registry(registry)
  if (!is.logical(stable) || length(stable) != 1L || is.na(stable)) {
    stop("`stable` must be TRUE or FALSE.", call. = FALSE)
  }
  columns <- wlv_aggregation_contract_columns()
  resolved <- registry$rows
  if (!is.data.frame(resolved) || any(!columns %in% names(resolved))) {
    stop("Aggregation registry does not contain complete contract rows.",
      call. = FALSE
    )
  }
  resolved <- as.data.frame(
    lapply(resolved[, columns, drop = FALSE], as.character),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  row.names(resolved) <- NULL
  if (anyNA(resolved)) {
    stop("Aggregation registry rows must not contain NA.", call. = FALSE)
  }
  legacy <- wlv_aggregation_registry_legacy_flags(registry)
  published <- wlv_aggregation_sidecar_rows(sidecar)
  resolved_keys <- wlv_aggregation_binding_key(
    resolved$indicator,
    resolved$level
  )
  published_keys <- wlv_aggregation_binding_key(
    published$indicator,
    published$level
  )
  if (anyDuplicated(resolved_keys)) {
    stop("Resolved aggregation rows contain duplicate keys.", call. = FALSE)
  }
  if (anyDuplicated(published_keys) || any(!published_keys %in% resolved_keys)) {
    stop("Published aggregation rows are duplicated or absent from the registry.",
      call. = FALSE
    )
  }
  published_match <- match(published_keys, resolved_keys)
  resolved_published <- resolved[published_match, , drop = FALSE]
  row.names(resolved_published) <- NULL

  if (stable) {
    same_keys <- length(published_keys) == length(resolved_keys) &&
      setequal(published_keys, resolved_keys)
    if (any(legacy) || !same_keys) {
      stop(
        paste0(
          "Stable aggregation registry and _unit_contract.csv must contain ",
          "the same unique aggregation keys."
        ),
        call. = FALSE
      )
    }
    if (!identical(published, resolved_published)) {
      stop(
        paste0(
          "Stable aggregation registry fields must exactly equal the ",
          "_unit_contract.csv rows with the same keys."
        ),
        call. = FALSE
      )
    }
  } else {
    published_indicators <- unique(published$indicator)
    expected_published_keys <- resolved_keys[
      resolved$indicator %in% published_indicators
    ]
    same_keys <- length(published_keys) == length(expected_published_keys) &&
      setequal(published_keys, expected_published_keys)
    if (!same_keys || !identical(published, resolved_published)) {
      stop(
        paste0(
          "Experimental _unit_contract.csv aggregation rows must exactly ",
          "equal the resolved rows for indicators with unit definitions."
        ),
        call. = FALSE
      )
    }
    omitted <- !resolved_keys %in% published_keys
    if (any(omitted & !legacy)) {
      stop(
        paste0(
          "Experimental sidecars may omit only complete indicators routed ",
          "through the legacy adapter."
        ),
        call. = FALSE
      )
    }
  }

  published_legacy <- legacy[published_match]
  omitted <- !resolved_keys %in% published_keys
  typed <- published[!published_legacy, , drop = FALSE]
  legacy_rows <- rbind(
    published[published_legacy, , drop = FALSE],
    resolved[omitted & legacy, , drop = FALSE]
  )
  row.names(typed) <- NULL
  row.names(legacy_rows) <- NULL
  list(
    published = published,
    typed = typed,
    legacy = legacy_rows
  )
}

wlv_aggregation_registry_binding <- function(registry, indicator, level) {
  wlv_validate_aggregation_registry(registry)
  wlv_aggregation_scalar_character(level, "level", wlv_aggregation_levels())
  key <- wlv_aggregation_binding_key(indicator, level)
  binding <- registry$bindings[[key]]
  if (is.null(binding)) {
    stop(
      sprintf("No typed aggregation binding exists for `%s/%s`.", indicator, level),
      call. = FALSE
    )
  }
  binding
}

wlv_aggregation_binding_inputs <- function(binding) {
  wlv_validate_aggregation_binding(binding)
  if (identical(binding$contract_strategy, "ratio_of_sums")) {
    unique(c(binding$numerator, binding$denominator))
  } else if (identical(binding$contract_strategy, "weighted_mean")) {
    unique(c(binding$indicator, binding$weight))
  } else if (identical(binding$contract_strategy, "formula")) {
    character()
  } else {
    binding$indicator
  }
}

wlv_aggregation_binding_arguments <- function(binding, values, axis = NULL) {
  wlv_validate_aggregation_binding(binding)
  if (identical(binding$contract_strategy, "formula")) {
    stop("Formula aggregation bindings are executed by their module.", call. = FALSE)
  }
  required <- wlv_aggregation_binding_inputs(binding)
  if (!is.list(values) || is.null(names(values)) || anyDuplicated(names(values)) ||
      any(!required %in% names(values))) {
    stop("Aggregation binding inputs are incomplete or unnamed.", call. = FALSE)
  }
  arguments <- if (identical(binding$contract_strategy, "ratio_of_sums")) {
    list(
      spec = binding$spec,
      numerator = values[[binding$numerator]],
      denominator = values[[binding$denominator]]
    )
  } else if (identical(binding$contract_strategy, "weighted_mean")) {
    list(
      spec = binding$spec,
      value = values[[binding$indicator]],
      weight = values[[binding$weight]]
    )
  } else {
    list(spec = binding$spec, value = values[[binding$indicator]])
  }
  if (!is.null(axis)) {
    arguments$axis <- axis
  }
  arguments
}

wlv_aggregate_binding <- function(binding, values, axis = NULL) {
  do.call(
    wlv_aggregate,
    wlv_aggregation_binding_arguments(binding, values, axis = axis)
  )
}
