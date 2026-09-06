wlv_contract_anomaly_columns <- function() {
  c(
  "artifact",
  "indicator",
  "checkpoint",
  "stage",
  "module",
  "year",
  "country",
  "sector",
  "output",
  "original_value",
  "policy_id",
  "action"
)
}

wlv_wiodr13_result_source_missing <- function() {
  c(
  "empe.s.un", "hours_worked.empe.s.hr",
  "compensation.empe_hs.r.pc", "compensation.empe_ms.r.pc",
  "compensation.empe_ls.r.pc", "hours_worked.empe_hs.r.pc",
  "hours_worked.empe_ms.r.pc", "hours_worked.empe_ls.r.pc",
  "exchange.r.us", "compensation.empe.s.us", "compensation.emp.s.us",
  "profit.s.us", "appropriated_profit.r.pc", "abstract_labour.empe.s.mv",
  "labour_force_value.s.mv", "labour_force_value.emp.s.mv",
  "surplus_value.empe_hs.r.pc", "surplus_value.empe_ms.r.pc",
  "surplus_value.empe_ls.r.pc", "compensation.emp.s.cu",
  "compensation.empe.s.cu", "surplus_value.empe.r.pc",
  "labour_force_value.m.mv", "abstract_labour.empe.m.mv",
  "labour_force_value.emp.m.mv", "surplus_value.emp.r.pc",
  "surplus_value.emp_p.r.pc", "surplus_value.empe_p.r.pc"
)
}

wlv_wiodr16_result_source_missing <- function() {
  c(
  "empe.s.un", "hours_worked.empe.s.hr", "exchange.r.us",
  "compensation.empe.s.us", "compensation.emp.s.us", "profit.s.us",
  "appropriated_profit.r.pc", "capital_stock.s.cu",
  "abstract_labour.empe.s.mv", "labour_force_value.s.mv",
  "labour_force_value.emp.s.mv", "compensation.emp.s.cu",
  "compensation.empe.s.cu", "surplus_value.empe.r.pc",
  "labour_force_value.m.mv", "abstract_labour.empe.m.mv",
  "labour_force_value.emp.m.mv", "surplus_value.emp.r.pc",
  "surplus_value.emp_p.r.pc", "surplus_value.empe_p.r.pc"
)
}

wlv_new_missingness_policy <- function(
    policy_id,
    source,
    source_rules,
    result_source_missing = list(
      row_indicators = character(),
      stage1_china_indicators = character()
    )) {
  policy_id <- wlv_contract_scalar_character(policy_id, "policy_id")
  source <- wlv_contract_scalar_character(source, "source")
  required_rule_columns <- c(
    "artifact",
    "indicator_selector",
    "checkpoint_selector",
    "year_selector",
    "country_selector",
    "sector_selector",
    "state"
  )
  if (
    !is.data.frame(source_rules) ||
      !identical(names(source_rules), required_rule_columns) ||
      anyNA(source_rules) ||
      any(!vapply(source_rules, is.character, logical(1L))) ||
      any(!nzchar(as.matrix(source_rules))) ||
      any(!source_rules$state %in% c("source_missing", "not_applicable"))
  ) {
    stop("Invalid source missingness rules.", call. = FALSE)
  }
  required_result_rules <- c("row_indicators", "stage1_china_indicators")
  if (
    !is.list(result_source_missing) ||
      !identical(names(result_source_missing), required_result_rules) ||
      any(!vapply(result_source_missing, is.character, logical(1L))) ||
      any(vapply(result_source_missing, anyNA, logical(1L))) ||
      any(vapply(result_source_missing, anyDuplicated, integer(1L)) > 0L)
  ) {
    stop("Invalid result missingness rules.", call. = FALSE)
  }

  structure(
    list(
      policy_id = policy_id,
      source = source,
      allowed_states = c(
        "uncomputed",
        "source_missing",
        "not_applicable",
        "finite"
      ),
      non_finite_action = "error",
      aggregation_policies = c("error", "propagate", "available"),
      division_policies = c(
        "error",
        "zero_if_both_zero",
        "zero_if_denominator_zero",
        "not_applicable",
        "not_applicable_if_both_zero"
      ),
      source_rules = source_rules,
      result_source_missing = result_source_missing
    ),
    class = "wlv_missingness_policy"
  )
}

wlv_strict_missingness_policy <- function(source, policy_id) {
  source_rules <- as.data.frame(
    stats::setNames(
      rep(list(character()), 7L),
      c(
        "artifact",
        "indicator_selector",
        "checkpoint_selector",
        "year_selector",
        "country_selector",
        "sector_selector",
        "state"
      )
    ),
    stringsAsFactors = FALSE
  )
  wlv_new_missingness_policy(
    policy_id = policy_id,
    source = source,
    source_rules = source_rules
  )
}

wlv_wiodr13_missingness_policy <- function() {
  wlv_new_missingness_policy(
    policy_id = "wiodr13_v1",
    source = "wiodr13",
    source_rules = data.frame(
      artifact = "sea_source",
      indicator_selector = "except:VA_USD,GO_USD",
      checkpoint_selector = "source_preflight",
      year_selector = "*",
      country_selector = "ROW",
      sector_selector = "*",
      state = "source_missing",
      stringsAsFactors = FALSE
    ),
    result_source_missing = list(
      row_indicators = wlv_wiodr13_result_source_missing(),
      stage1_china_indicators = character()
    )
  )
}

wlv_wiodr16_missingness_policy <- function() {
  wlv_new_missingness_policy(
    policy_id = "wiodr16_v1",
    source = "wiodr16",
    source_rules = data.frame(
      artifact = rep("sea_source", 2L),
      indicator_selector = c("raw_variables", "EMPE,H_EMPE"),
      checkpoint_selector = rep("source_preflight", 2L),
      year_selector = rep("*", 2L),
      country_selector = c("ROW", "CHN"),
      sector_selector = rep("*", 2L),
      state = rep("source_missing", 2L),
      stringsAsFactors = FALSE
    ),
    result_source_missing = list(
      row_indicators = wlv_wiodr16_result_source_missing(),
      stage1_china_indicators = c(
        "empe.s.un", "hours_worked.empe.s.hr", "hours_worked.emp.s.hr"
      )
    )
  )
}

wlv_contract_scalar_character <- function(value, name, allow_na = FALSE) {
  if (
    length(value) != 1L ||
      !is.character(value) ||
      (!allow_na && (is.na(value) || !nzchar(value))) ||
      (allow_na && !is.na(value) && !nzchar(value))
  ) {
    qualifier <- if (allow_na) "one non-empty string or NA" else "one non-empty string"
    stop(sprintf("`%s` must be %s.", name, qualifier), call. = FALSE)
  }
  value
}

wlv_contract_context <- function(
    artifact,
    indicator,
    checkpoint,
    stage = NA_character_,
    module = NA_character_,
    policy_id = "strict",
    axes = integer()) {
  artifact <- wlv_contract_scalar_character(artifact, "artifact")
  indicator <- wlv_contract_scalar_character(indicator, "indicator")
  checkpoint <- wlv_contract_scalar_character(checkpoint, "checkpoint")
  module <- wlv_contract_scalar_character(module, "module", allow_na = TRUE)
  policy_id <- wlv_contract_scalar_character(policy_id, "policy_id")

  if (length(stage) != 1L || is.list(stage)) {
    stop("`stage` must be one value or NA.", call. = FALSE)
  }
  stage <- if (is.na(stage)) NA_character_ else as.character(stage)
  if (!is.na(stage) && !nzchar(stage)) {
    stop("`stage` must not be empty.", call. = FALSE)
  }

  if (is.null(axes)) {
    axes <- integer()
  }
  if (
    !is.numeric(axes) ||
      anyNA(axes) ||
      any(axes < 1 | axes != floor(axes)) ||
      anyDuplicated(axes) ||
      (length(axes) && (
        is.null(names(axes)) ||
          anyNA(names(axes)) ||
          any(!nzchar(names(axes))) ||
          anyDuplicated(names(axes)) ||
          any(!names(axes) %in% c("year", "country", "sector", "output"))
      ))
  ) {
    stop(
      paste0(
        "`axes` must be a uniquely named integer vector using year, country, ",
        "sector or output."
      ),
      call. = FALSE
    )
  }

  structure(
    list(
      artifact = artifact,
      indicator = indicator,
      checkpoint = checkpoint,
      stage = stage,
      module = module,
      policy_id = policy_id,
      axes = as.integer(axes) |> stats::setNames(names(axes))
    ),
    class = "wlv_contract_context"
  )
}

wlv_as_contract_context <- function(context) {
  if (inherits(context, "wlv_contract_context")) {
    return(context)
  }
  if (!is.list(context) || is.null(names(context))) {
    stop("`context` must be produced by wlv_contract_context().", call. = FALSE)
  }
  do.call(wlv_contract_context, context)
}

wlv_empty_contract_table <- function() {
  value <- as.data.frame(
    stats::setNames(
      rep(list(character()), length(wlv_contract_anomaly_columns())),
      wlv_contract_anomaly_columns()
    ),
    stringsAsFactors = FALSE
  )
  value[wlv_contract_anomaly_columns()]
}

wlv_bind_contract_tables <- function(...) {
  values <- list(...)
  values <- values[vapply(values, nrow, integer(1L)) > 0L]
  if (!length(values)) {
    return(wlv_empty_contract_table())
  }
  value <- do.call(rbind, values)
  row.names(value) <- NULL
  value[wlv_contract_anomaly_columns()]
}

wlv_new_contract_error <- function(message, anomalies, call = NULL) {
  if (
    !is.data.frame(anomalies) ||
      !identical(names(anomalies), wlv_contract_anomaly_columns()) ||
      !nrow(anomalies)
  ) {
    stop("A contract error requires a non-empty canonical anomaly table.", call. = FALSE)
  }
  structure(
    list(
      message = as.character(message),
      call = call,
      anomalies = anomalies
    ),
    class = c("wlv_contract_error", "error", "condition")
  )
}

wlv_contract_examples <- function(anomalies, maximum = 3L) {
  examples <- anomalies[seq_len(min(nrow(anomalies), maximum)), , drop = FALSE]
  apply(examples, 1L, function(value) {
    coordinates <- c(
      year = value[["year"]],
      country = value[["country"]],
      sector = value[["sector"]],
      output = value[["output"]]
    )
    coordinates <- coordinates[!is.na(coordinates) & nzchar(coordinates)]
    location <- if (length(coordinates)) {
      paste(paste(names(coordinates), coordinates, sep = "="), collapse = "/")
    } else {
      "coordinates unavailable"
    }
    sprintf("%s (%s)", location, value[["original_value"]])
  })
}

wlv_abort_contract <- function(context, anomalies, reason) {
  context <- wlv_as_contract_context(context)
  message <- sprintf(
    paste0(
      "Missingness contract failed for artifact `%s`, indicator `%s`, ",
      "checkpoint `%s`: %s; example(s): %s."
    ),
    context$artifact,
    context$indicator,
    context$checkpoint,
    reason,
    paste(wlv_contract_examples(anomalies), collapse = ", ")
  )
  stop(wlv_new_contract_error(message, anomalies))
}

wlv_format_original_value <- function(value) {
  if (is.nan(value)) {
    return("NaN")
  }
  if (is.na(value)) {
    return("NA")
  }
  if (is.infinite(value)) {
    return(if (value > 0) "Inf" else "-Inf")
  }
  sprintf("%.17g", value)
}

wlv_value_shape <- function(value) {
  dimensions <- dim(value)
  if (is.null(dimensions)) {
    dimensions <- length(value)
    dimension_names <- list(names(value))
  } else {
    dimension_names <- dimnames(value)
  }
  if (is.null(dimension_names)) {
    dimension_names <- rep(list(NULL), length(dimensions))
  }
  list(dim = as.integer(dimensions), dimnames = dimension_names)
}

wlv_context_axes <- function(context, value) {
  context <- wlv_as_contract_context(context)
  shape <- wlv_value_shape(value)
  axes <- context$axes
  if (!length(axes)) {
    dimension_roles <- names(shape$dimnames)
    if (!is.null(dimension_roles)) {
      matched <- match(c("year", "country", "sector", "output"), dimension_roles)
      axes <- matched[!is.na(matched)]
      names(axes) <- c("year", "country", "sector", "output")[!is.na(matched)]
    }
  }
  if (length(axes) && any(axes > length(shape$dim))) {
    stop("A context axis is outside the value dimensions.", call. = FALSE)
  }
  axes
}

wlv_contract_table <- function(value, failed, context, action) {
  context <- wlv_as_contract_context(context)
  if (
    !is.logical(failed) ||
      length(failed) != length(value) ||
      anyNA(failed) ||
      !any(failed)
  ) {
    stop("`failed` must select at least one value position.", call. = FALSE)
  }
  if (length(action) != 1L || !is.character(action) || is.na(action) || !nzchar(action)) {
    stop("`action` must be one non-empty string.", call. = FALSE)
  }

  shape <- wlv_value_shape(value)
  positions <- which(failed)
  coordinates <- arrayInd(positions, .dim = shape$dim, .dimnames = shape$dimnames)
  axes <- wlv_context_axes(context, value)
  coordinate_values <- stats::setNames(
    rep(list(rep(NA_character_, length(positions))), 4L),
    c("year", "country", "sector", "output")
  )
  for (role in intersect(names(axes), names(coordinate_values))) {
    dimension_index <- axes[[role]]
    coordinate_index <- coordinates[, dimension_index]
    labels <- shape$dimnames[[dimension_index]]
    coordinate_values[[role]] <- if (is.null(labels)) {
      as.character(coordinate_index)
    } else {
      as.character(labels[coordinate_index])
    }
  }

  data.frame(
    artifact = rep(context$artifact, length(positions)),
    indicator = rep(context$indicator, length(positions)),
    checkpoint = rep(context$checkpoint, length(positions)),
    stage = rep(context$stage, length(positions)),
    module = rep(context$module, length(positions)),
    year = coordinate_values$year,
    country = coordinate_values$country,
    sector = coordinate_values$sector,
    output = coordinate_values$output,
    original_value = vapply(value[positions], wlv_format_original_value, character(1L)),
    policy_id = rep(context$policy_id, length(positions)),
    action = rep(action, length(positions)),
    stringsAsFactors = FALSE
  )[wlv_contract_anomaly_columns()]
}

wlv_character_like <- function(value, fill = NA_character_) {
  result <- rep(fill, length(value))
  if (is.null(dim(value))) {
    names(result) <- names(value)
  } else {
    dim(result) <- dim(value)
    dimnames(result) <- dimnames(value)
  }
  result
}

wlv_same_shape_and_labels <- function(left, right) {
  if (length(left) != length(right) || !identical(dim(left), dim(right))) {
    return(FALSE)
  }
  if (is.null(dim(left))) {
    return(identical(names(left), names(right)))
  }
  all(vapply(
    seq_along(dim(left)),
    function(axis) identical(dimnames(left)[[axis]], dimnames(right)[[axis]]),
    logical(1L)
  ))
}

wlv_conformable_mask <- function(mask, value, name) {
  if (!is.logical(mask) || length(mask) != length(value) || anyNA(mask)) {
    stop(sprintf("Missingness mask `%s` must be logical and conformable.", name), call. = FALSE)
  }
  if (!identical(dim(mask), dim(value))) {
    stop(sprintf("Missingness mask `%s` has different dimensions.", name), call. = FALSE)
  }
  if (!wlv_same_shape_and_labels(mask, value)) {
    stop(sprintf("Missingness mask `%s` has different labels.", name), call. = FALSE)
  }
  as.vector(mask)
}

wlv_normalize_allowed_missing <- function(allowed_missing, value) {
  states <- c("uncomputed", "source_missing", "not_applicable")
  result <- wlv_character_like(value)
  if (is.null(allowed_missing) || !length(allowed_missing)) {
    return(result)
  }

  if (is.character(allowed_missing)) {
    if (
      !wlv_same_shape_and_labels(allowed_missing, value)
    ) {
      stop(
        "The allowed-missing state array must match the shape and labels of `value`.",
        call. = FALSE
      )
    }
    invalid <- !is.na(allowed_missing) & !allowed_missing %in% c(states, "finite")
    if (any(invalid)) {
      stop(
        sprintf(
          "Unknown allowed-missing state(s): %s.",
          paste(unique(allowed_missing[invalid]), collapse = ", ")
        ),
        call. = FALSE
      )
    }
    result[] <- allowed_missing
    return(result)
  }

  if (
    !is.list(allowed_missing) ||
      is.null(names(allowed_missing)) ||
      anyNA(names(allowed_missing)) ||
      any(!nzchar(names(allowed_missing))) ||
      anyDuplicated(names(allowed_missing)) ||
      any(!names(allowed_missing) %in% states)
  ) {
    stop(
      paste0(
        "`allowed_missing` must be a conformable state array or a uniquely named ",
        "list of uncomputed, source_missing and not_applicable masks."
      ),
      call. = FALSE
    )
  }

  occupied <- rep(FALSE, length(value))
  for (state in names(allowed_missing)) {
    mask <- wlv_conformable_mask(allowed_missing[[state]], value, state)
    if (any(occupied & mask)) {
      stop("Allowed-missing masks must not overlap.", call. = FALSE)
    }
    result[mask] <- state
    occupied <- occupied | mask
  }
  result
}

wlv_classify_missingness <- function(value, allowed_missing = NULL, context) {
  if (!is.numeric(value)) {
    stop("`value` must be numeric.", call. = FALSE)
  }
  context <- wlv_as_contract_context(context)
  declared_state <- wlv_normalize_allowed_missing(allowed_missing, value)

  invalid_numeric <- is.nan(value) | is.infinite(value)
  ordinary_missing <- is.na(value) & !is.nan(value)
  unexpected_missing <- ordinary_missing &
    (is.na(declared_state) | declared_state == "finite")

  anomalies <- wlv_empty_contract_table()
  if (any(invalid_numeric)) {
    anomalies <- wlv_bind_contract_tables(
      anomalies,
      wlv_contract_table(value, invalid_numeric, context, "abort_non_finite")
    )
  }
  if (any(unexpected_missing)) {
    anomalies <- wlv_bind_contract_tables(
      anomalies,
      wlv_contract_table(value, unexpected_missing, context, "abort_unexpected_missing")
    )
  }
  if (nrow(anomalies)) {
    wlv_abort_contract(
      context,
      anomalies,
      sprintf("%s unexpected missing or non-finite value(s)", nrow(anomalies))
    )
  }

  classification <- wlv_character_like(value, "finite")
  classification[ordinary_missing] <- declared_state[ordinary_missing]
  classification
}

wlv_group_missing_state <- function(states) {
  states <- unique(states[!is.na(states) & states != "finite"])
  if (!length(states)) {
    return("not_applicable")
  }
  if ("uncomputed" %in% states) {
    return("uncomputed")
  }
  if ("source_missing" %in% states) {
    return("source_missing")
  }
  "not_applicable"
}

wlv_shape_aggregate_output <- function(value, input, margin) {
  if (!length(margin)) {
    return(as.vector(value))
  }
  shape <- wlv_value_shape(input)
  dimensions <- shape$dim[margin]
  dimension_names <- shape$dimnames[margin]
  if (length(dimensions) == 1L) {
    value <- as.vector(value)
    names(value) <- dimension_names[[1L]]
    return(value)
  }
  array(value, dim = dimensions, dimnames = dimension_names)
}

wlv_margin_context <- function(context, margin) {
  context <- wlv_as_contract_context(context)
  axes <- context$axes
  if (length(axes)) {
    retained <- axes %in% margin
    axes <- match(axes[retained], margin)
    names(axes) <- names(context$axes)[retained]
  }
  wlv_contract_context(
    artifact = context$artifact,
    indicator = context$indicator,
    checkpoint = context$checkpoint,
    stage = context$stage,
    module = context$module,
    policy_id = context$policy_id,
    axes = axes
  )
}

wlv_contract_aggregate <- function(
    value,
    margin = NULL,
    operation = c("sum", "mean"),
    missing = c("error", "propagate", "available"),
    allowed_missing = NULL,
    context) {
  operation <- match.arg(operation)
  missing <- match.arg(missing)
  context <- wlv_as_contract_context(context)
  if (!length(value)) {
    stop("`value` must not be empty.", call. = FALSE)
  }
  if (!length(context$axes)) {
    inferred_axes <- wlv_context_axes(context, value)
    if (length(inferred_axes)) {
      context <- wlv_contract_context(
        artifact = context$artifact,
        indicator = context$indicator,
        checkpoint = context$checkpoint,
        stage = context$stage,
        module = context$module,
        policy_id = context$policy_id,
        axes = inferred_axes
      )
    }
  }
  classification <- wlv_classify_missingness(value, allowed_missing, context)

  dimensions <- dim(value)
  if (is.null(dimensions)) {
    dimensions <- length(value)
  }
  dimension_count <- length(dimensions)
  if (is.null(margin)) {
    margin <- integer()
  }
  if (
    !is.numeric(margin) ||
      anyNA(margin) ||
      any(margin < 1 | margin > dimension_count | margin != floor(margin)) ||
      anyDuplicated(margin)
  ) {
    stop("`margin` must select unique value dimensions.", call. = FALSE)
  }
  margin <- as.integer(margin)

  input_positions <- arrayInd(seq_along(value), .dim = dimensions)
  if (!length(margin)) {
    group <- rep(1L, length(value))
    group_count <- 1L
  } else {
    kept_dimensions <- dimensions[margin]
    multipliers <- c(1L, cumprod(kept_dimensions)[-length(kept_dimensions)])
    group <- 1L + rowSums(
      sweep(input_positions[, margin, drop = FALSE] - 1L, 2L, multipliers, "*")
    )
    group_count <- prod(kept_dimensions)
  }

  result <- rep(NA_real_, group_count)
  result_state <- rep(NA_character_, group_count)
  actions <- wlv_empty_contract_table()
  errors <- wlv_empty_contract_table()

  aggregate_function <- if (operation == "sum") base::sum else base::mean
  for (group_index in seq_len(group_count)) {
    positions <- which(group == group_index)
    missing_positions <- positions[is.na(value[positions])]
    finite_positions <- setdiff(positions, missing_positions)
    if (!length(missing_positions)) {
      result[[group_index]] <- aggregate_function(value[positions])
      result_state[[group_index]] <- "finite"
      next
    }

    failed <- rep(FALSE, length(value))
    failed[missing_positions] <- TRUE
    group_state <- wlv_group_missing_state(classification[missing_positions])
    if (missing == "error") {
      errors <- wlv_bind_contract_tables(
        errors,
        wlv_contract_table(value, failed, context, "abort_missing_aggregation")
      )
      next
    }

    if (missing == "propagate") {
      result[[group_index]] <- NA_real_
      result_state[[group_index]] <- group_state
      actions <- wlv_bind_contract_tables(
        actions,
        wlv_contract_table(value, failed, context, "propagate_missing")
      )
      next
    }

    if (!length(finite_positions)) {
      result[[group_index]] <- NA_real_
      result_state[[group_index]] <- group_state
      action <- "preserve_all_missing"
    } else {
      result[[group_index]] <- aggregate_function(value[finite_positions])
      result_state[[group_index]] <- "finite"
      action <- "aggregate_available"
    }
    actions <- wlv_bind_contract_tables(
      actions,
      wlv_contract_table(value, failed, context, action)
    )
  }

  if (nrow(errors)) {
    wlv_abort_contract(
      context,
      errors,
      sprintf("aggregation policy `error` rejected %s missing component(s)", nrow(errors))
    )
  }

  result <- wlv_shape_aggregate_output(result, value, margin)
  result_state <- wlv_shape_aggregate_output(result_state, value, margin)
  non_finite <- is.nan(result) | is.infinite(result)
  if (any(non_finite)) {
    output_context <- wlv_margin_context(context, margin)
    errors <- wlv_contract_table(
      result,
      non_finite,
      output_context,
      "abort_non_finite_result"
    )
    wlv_abort_contract(
      output_context,
      errors,
      sprintf("aggregation produced %s non-finite result(s)", sum(non_finite))
    )
  }

  attr(result, "wlv_state") <- result_state
  attr(result, "wlv_actions") <- actions
  result
}

wlv_assert_conformable_numeric <- function(numerator, denominator) {
  if (!is.numeric(numerator) || !is.numeric(denominator)) {
    stop("Numerator and denominator must be numeric.", call. = FALSE)
  }
  dimensions_identical <- identical(dim(numerator), dim(denominator))
  labels_identical <- wlv_same_shape_and_labels(numerator, denominator)
  if (
    length(numerator) != length(denominator) ||
      !dimensions_identical ||
      !labels_identical
  ) {
    format_shape <- function(value) {
      dimensions <- dim(value)
      if (is.null(dimensions)) {
        return(sprintf("vector[%s]", length(value)))
      }
      paste(dimensions, collapse = "x")
    }
    label_mismatches <- if (is.null(dim(numerator)) || is.null(dim(denominator))) {
      "names"
    } else if (length(dim(numerator)) != length(dim(denominator))) {
      "rank"
    } else {
      which(!vapply(
        seq_along(dim(numerator)),
        function(axis) identical(
          dimnames(numerator)[[axis]], dimnames(denominator)[[axis]]
        ),
        logical(1L)
      ))
    }
    stop(
      sprintf(
        paste0(
          "Numerator and denominator must have identical shape and labels ",
          "(numerator=%s, denominator=%s, differing axes=%s)."
        ),
        format_shape(numerator),
        format_shape(denominator),
        paste(label_mismatches, collapse = ",")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

# Uma razão econômica precisa de uma política explícita para denominador zero.
# zero_if_both_zero admite 0/0 como zero estrutural, mas rejeita x/0 com x != 0;
# not_applicable registra inaplicabilidade (NA + estado), como uma taxa sem base.
# Nenhuma dessas opções permite NA/Inf inesperados ou eixos incompatíveis.
# A saída preserva a forma dos operandos e registra a ação por coordenada.
# Guias: docs/guide-pt.md e docs/guide-en.md.
wlv_safe_divide <- function(
    numerator,
    denominator,
    zero = c(
      "error", "zero_if_both_zero", "not_applicable",
      "not_applicable_if_both_zero", "zero_if_denominator_zero"
    ),
    context) {
  zero <- match.arg(zero)
  context <- wlv_as_contract_context(context)
  wlv_assert_conformable_numeric(numerator, denominator)
  wlv_classify_missingness(numerator, context = context)
  wlv_classify_missingness(denominator, context = context)

  result <- numerator / denominator
  zero_denominator <- denominator == 0
  both_zero <- zero_denominator & numerator == 0
  actions <- wlv_empty_contract_table()

  if (zero == "error" && any(zero_denominator)) {
    errors <- wlv_contract_table(
      result,
      zero_denominator,
      context,
      "abort_zero_denominator"
    )
    wlv_abort_contract(
      context,
      errors,
      sprintf("division policy `error` rejected %s zero denominator(s)", sum(zero_denominator))
    )
  }

  if (zero == "zero_if_both_zero") {
    invalid <- zero_denominator & !both_zero
    if (any(invalid)) {
      errors <- wlv_contract_table(
        result,
        invalid,
        context,
        "abort_nonzero_over_zero"
      )
      wlv_abort_contract(
        context,
        errors,
        sprintf(
          "division policy `zero_if_both_zero` rejected %s nonzero numerator(s)",
          sum(invalid)
        )
      )
    }
    if (any(both_zero)) {
      actions <- wlv_contract_table(
        result,
        both_zero,
        context,
        "replace_both_zero_with_zero"
      )
      result[both_zero] <- 0
    }
  }

  if (zero == "zero_if_denominator_zero" && any(zero_denominator)) {
    actions <- wlv_contract_table(
      result,
      zero_denominator,
      context,
      "replace_zero_denominator_with_zero"
    )
    result[zero_denominator] <- 0
  }

  if (zero == "not_applicable_if_both_zero") {
    invalid <- zero_denominator & !both_zero
    if (any(invalid)) {
      errors <- wlv_contract_table(
        result,
        invalid,
        context,
        "abort_nonzero_over_zero"
      )
      wlv_abort_contract(
        context,
        errors,
        sprintf(
          paste0(
            "division policy `not_applicable_if_both_zero` rejected %s ",
            "nonzero numerator(s)"
          ),
          sum(invalid)
        )
      )
    }
  }

  result_state <- wlv_character_like(result, "finite")
  if (zero == "not_applicable" && any(zero_denominator)) {
    actions <- wlv_contract_table(
      result,
      zero_denominator,
      context,
      "mark_not_applicable"
    )
    result[zero_denominator] <- NA_real_
    result_state[zero_denominator] <- "not_applicable"
  }
  if (zero == "not_applicable_if_both_zero" && any(both_zero)) {
    actions <- wlv_contract_table(
      result,
      both_zero,
      context,
      "mark_not_applicable"
    )
    result[both_zero] <- NA_real_
    result_state[both_zero] <- "not_applicable"
  }

  non_finite <- is.nan(result) | is.infinite(result)
  if (any(non_finite)) {
    errors <- wlv_contract_table(
      result,
      non_finite,
      context,
      "abort_non_finite_result"
    )
    wlv_abort_contract(
      context,
      errors,
      sprintf("division produced %s non-finite result(s)", sum(non_finite))
    )
  }

  attr(result, "wlv_state") <- result_state
  attr(result, "wlv_actions") <- actions
  result
}
