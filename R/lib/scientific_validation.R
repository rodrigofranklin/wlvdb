wlv_scientific_check_columns <- function() {
  c(
  "method", "check_id", "artifact", "indicator", "scope", "status",
  "observations", "maximum_absolute_error", "maximum_scaled_error",
  "tolerance", "detail"
)
}

wlv_empty_scientific_checks <- function() {
  data.frame(
    method = character(),
    check_id = character(),
    artifact = character(),
    indicator = character(),
    scope = character(),
    status = character(),
    observations = integer(),
    maximum_absolute_error = numeric(),
    maximum_scaled_error = numeric(),
    tolerance = character(),
    detail = character(),
    stringsAsFactors = FALSE
  )[wlv_scientific_check_columns()]
}

wlv_new_scientific_validation_error <- function(
    message,
    method,
    check_id,
    artifact,
    indicator,
    scope,
    call = NULL) {
  structure(
    list(
      message = as.character(message),
      call = call,
      method = as.character(method),
      check_id = as.character(check_id),
      artifact = as.character(artifact),
      indicator = as.character(indicator),
      scope = as.character(scope)
    ),
    class = c("wlv_scientific_validation_error", "error", "condition")
  )
}

wlv_abort_scientific_validation <- function(
    method,
    check_id,
    artifact,
    indicator = "",
    scope = "global",
    reason) {
  message <- sprintf(
    paste0(
      "Scientific validation failed for method `%s`, check `%s` ",
      "(artifact `%s`%s, scope `%s`): %s."
    ),
    method,
    check_id,
    artifact,
    if (nzchar(indicator)) sprintf(", indicator `%s`", indicator) else "",
    scope,
    reason
  )
  stop(wlv_new_scientific_validation_error(
    message = message,
    method = method,
    check_id = check_id,
    artifact = artifact,
    indicator = indicator,
    scope = scope
  ))
}

wlv_scientific_check_row <- function(
    method,
    check_id,
    artifact,
    indicator = "",
    scope = "global",
    status = "pass",
    observations = 0L,
    maximum_absolute_error = NA_real_,
    maximum_scaled_error = NA_real_,
    tolerance = "exact",
    detail = "") {
  data.frame(
    method = as.character(method),
    check_id = as.character(check_id),
    artifact = as.character(artifact),
    indicator = as.character(indicator),
    scope = as.character(scope),
    status = as.character(status),
    observations = as.integer(observations),
    maximum_absolute_error = as.numeric(maximum_absolute_error),
    maximum_scaled_error = as.numeric(maximum_scaled_error),
    tolerance = as.character(tolerance),
    detail = as.character(detail),
    stringsAsFactors = FALSE
  )[wlv_scientific_check_columns()]
}

wlv_scientific_not_applicable <- function(
    method,
    check_id,
    artifact,
    indicator = "",
    scope = "global",
    detail) {
  wlv_scientific_check_row(
    method = method,
    check_id = check_id,
    artifact = artifact,
    indicator = indicator,
    scope = scope,
    status = "not_applicable",
    detail = detail
  )
}

wlv_scientific_validate_named_array <- function(
    value,
    rank,
    method,
    artifact) {
  dimensions <- dim(value)
  labels <- dimnames(value)
  valid_labels <-
    is.list(labels) && length(labels) == rank &&
    all(vapply(seq_len(rank), function(axis) {
      current <- labels[[axis]]
      is.character(current) &&
        length(current) == dimensions[[axis]] &&
        !anyNA(current) &&
        all(nzchar(current)) &&
        !anyDuplicated(current)
    }, logical(1L)))
  if (
    !is.array(value) || !is.numeric(value) ||
      length(dimensions) != rank || any(dimensions < 1L) || !valid_labels
  ) {
    wlv_abort_scientific_validation(
      method = method,
      check_id = "dimensions_labels",
      artifact = artifact,
      reason = sprintf(
        "expected a numeric rank-%s array with complete, unique labels on every axis",
        rank
      )
    )
  }
  invisible(value)
}

wlv_scientific_structure_check <- function(value, rank, method, artifact) {
  wlv_scientific_validate_named_array(value, rank, method, artifact)
  wlv_scientific_check_row(
    method = method,
    check_id = "dimensions_labels",
    artifact = artifact,
    observations = length(value),
    detail = sprintf(
      "rank=%s; dimensions=%s",
      rank,
      paste(dim(value), collapse = "x")
    )
  )
}

wlv_scientific_format_position <- function(value, position) {
  dimensions <- dim(value)
  if (is.null(dimensions)) {
    return(as.character(position))
  }
  coordinates <- arrayInd(position, .dim = dimensions)
  labels <- dimnames(value)
  paste(vapply(seq_along(dimensions), function(axis) {
    coordinate <- coordinates[[axis]]
    if (!is.null(labels) && !is.null(labels[[axis]])) {
      labels[[axis]][[coordinate]]
    } else {
      as.character(coordinate)
    }
  }, character(1L)), collapse = "/")
}

wlv_scientific_compare <- function(
    observed,
    expected,
    method,
    check_id,
    artifact,
    indicator = "",
    scope = "global",
    absolute_tolerance = 64 * .Machine$double.eps,
    relative_tolerance = 64 * .Machine$double.eps,
    error_limit = NULL,
    tolerance_label = NULL,
    detail = "") {
  if (
    !is.numeric(observed) || !is.numeric(expected) ||
      length(observed) != length(expected) ||
      !identical(dim(observed), dim(expected))
  ) {
    wlv_abort_scientific_validation(
      method, check_id, artifact, indicator, scope,
      "observed and expected values are not conformable numeric arrays"
    )
  }
  missing_mismatch <- xor(is.na(observed), is.na(expected))
  if (any(missing_mismatch)) {
    position <- which(missing_mismatch)[[1L]]
    wlv_abort_scientific_validation(
      method, check_id, artifact, indicator, scope,
      sprintf(
        "missingness differs at `%s` (observed=%s, expected=%s)",
        wlv_scientific_format_position(observed, position),
        if (is.na(observed[[position]])) "NA" else sprintf("%.17g", observed[[position]]),
        if (is.na(expected[[position]])) "NA" else sprintf("%.17g", expected[[position]])
      )
    )
  }
  selected <- !is.na(observed) & !is.na(expected)
  if (any(!is.finite(observed[selected])) || any(!is.finite(expected[selected]))) {
    wlv_abort_scientific_validation(
      method, check_id, artifact, indicator, scope,
      "comparison contains NaN or infinite values"
    )
  }
  differences <- abs(observed[selected] - expected[selected])
  scales <- pmax(abs(observed[selected]), abs(expected[selected]), 1)
  limits <- if (is.null(error_limit)) {
    absolute_tolerance + relative_tolerance * scales
  } else {
    if (
      !is.numeric(error_limit) || length(error_limit) != length(observed) ||
        any(!is.na(error_limit) & (!is.finite(error_limit) | error_limit < 0))
    ) {
      stop("`error_limit` must be a conformable nonnegative numeric value.", call. = FALSE)
    }
    as.vector(error_limit)[selected]
  }
  scaled <- if (!length(differences)) {
    numeric()
  } else if (all(limits == 0)) {
    ifelse(differences == 0, 0, Inf)
  } else {
    differences / limits
  }
  maximum_absolute_error <- if (length(differences)) max(differences) else 0
  maximum_scaled_error <- if (length(scaled)) max(scaled) else 0
  if (length(scaled) && any(scaled > 1)) {
    selected_positions <- which(selected)
    local_position <- which.max(scaled)
    position <- selected_positions[[local_position]]
    wlv_abort_scientific_validation(
      method, check_id, artifact, indicator, scope,
      sprintf(
        paste0(
          "maximum error exceeds abs=%s + rel=%s*scale at `%s` ",
          "(observed=%.17g, expected=%.17g, abs_error=%.17g, scaled_error=%.17g)"
        ),
          if (is.null(error_limit)) {
            format(absolute_tolerance, scientific = TRUE)
          } else {
            "reduction-bound"
          },
          if (is.null(error_limit)) {
            format(relative_tolerance, scientific = TRUE)
          } else {
            "0"
          },
        wlv_scientific_format_position(observed, position),
        observed[[position]], expected[[position]],
        differences[[local_position]], scaled[[local_position]]
      )
    )
  }
  wlv_scientific_check_row(
    method = method,
    check_id = check_id,
    artifact = artifact,
    indicator = indicator,
    scope = scope,
    observations = sum(selected),
    maximum_absolute_error = maximum_absolute_error,
    maximum_scaled_error = maximum_scaled_error,
    tolerance = if (!is.null(tolerance_label)) {
      tolerance_label
    } else if (!is.null(error_limit)) {
      "64*eps*max(1,abs(expected))+8*gamma_k*sum(abs(terms))"
    } else {
      sprintf(
        "abs=%s;rel=%s",
        format(absolute_tolerance, scientific = TRUE),
        format(relative_tolerance, scientific = TRUE)
      )
    },
    detail = detail
  )
}

wlv_scientific_reduction_error_limit <- function(terms, expected) {
  terms <- terms[!is.na(terms)]
  if (!length(terms) || is.na(expected)) {
    return(NA_real_)
  }
  if (any(!is.finite(terms)) || !is.finite(expected)) {
    return(NA_real_)
  }
  operations <- length(terms)
  gamma_k <- operations * .Machine$double.eps /
    (1 - operations * .Machine$double.eps)
  64 * .Machine$double.eps * max(1, abs(expected)) +
    8 * gamma_k * sum(abs(terms))
}

wlv_scientific_available_aggregate <- function(value, operation) {
  finite <- !is.na(value)
  if (!any(finite)) {
    return(NA_real_)
  }
  if (identical(operation, "sum")) {
    sum(value[finite])
  } else {
    mean(value[finite])
  }
}

wlv_scientific_aggregation_row <- function(
    aggregations,
    indicator,
    level,
    method) {
  row <- aggregations[
    aggregations$indicator == indicator & aggregations$level == level,
    ,
    drop = FALSE
  ]
  if (nrow(row) != 1L) {
    wlv_abort_scientific_validation(
      method,
      "aggregation_contract",
      "_unit_contract.csv",
      indicator,
      level,
      "expected exactly one typed aggregation row"
    )
  }
  row
}

wlv_scientific_reference_aggregate <- function(
    strategy,
    value = NULL,
    numerator = NULL,
    denominator = NULL,
    weight = NULL,
    zero_denominator = "",
    tolerance = sqrt(.Machine$double.eps)) {
  if (identical(strategy, "not_applicable")) {
    return(NA_real_)
  }
  paired <- strategy %in% c("ratio_of_sums", "weighted_mean")
  if (paired) {
    left <- if (identical(strategy, "ratio_of_sums")) numerator else value
    right <- if (identical(strategy, "ratio_of_sums")) denominator else weight
    if (!is.numeric(left) || !is.numeric(right) ||
        length(left) != length(right)) {
      stop("Scientific aggregation dependencies are not conformable.",
        call. = FALSE
      )
    }
    selected <- !is.na(left) & !is.na(right)
    if (!any(selected)) {
      return(NA_real_)
    }
    left <- left[selected]
    right <- right[selected]
    if (identical(strategy, "weighted_mean") && any(right < 0)) {
      stop("Scientific weighted aggregation received negative weights.",
        call. = FALSE
      )
    }
    aggregate_numerator <- if (identical(strategy, "ratio_of_sums")) {
      sum(left)
    } else {
      sum(left * right)
    }
    aggregate_denominator <- sum(right)
    if (aggregate_denominator == 0) {
      return(switch(
        zero_denominator,
        error = stop("Scientific aggregation has a zero denominator.",
          call. = FALSE
        ),
        not_applicable = NA_real_,
        zero = 0,
        stop("Scientific aggregation has an invalid zero policy.",
          call. = FALSE
        )
      ))
    }
    return(aggregate_numerator / aggregate_denominator)
  }

  if (!is.numeric(value)) {
    stop("Scientific aggregation input must be numeric.", call. = FALSE)
  }
  value <- value[!is.na(value)]
  if (!length(value)) {
    return(NA_real_)
  }
  switch(
    strategy,
    sum = sum(value),
    mean = mean(value),
    invariant = {
      reference <- value[[1L]]
      scale <- pmax(1, abs(value), abs(reference))
      if (any(abs(value - reference) > tolerance * scale)) {
        stop("Scientific invariant aggregation differs within a group.",
          call. = FALSE
        )
      }
      reference
    },
    stop("Scientific aggregation strategy is unsupported.", call. = FALSE)
  )
}

wlv_scientific_reference_arguments <- function(row, lookup) {
  strategy <- as.character(row$strategy[[1L]])
  indicator <- as.character(row$indicator[[1L]])
  if (identical(strategy, "ratio_of_sums")) {
    return(list(
      strategy = strategy,
      numerator = lookup(as.character(row$numerator[[1L]])),
      denominator = lookup(as.character(row$denominator[[1L]])),
      zero_denominator = as.character(row$zero_denominator[[1L]])
    ))
  }
  if (identical(strategy, "weighted_mean")) {
    return(list(
      strategy = strategy,
      value = lookup(indicator),
      weight = lookup(as.character(row$weight[[1L]])),
      zero_denominator = as.character(row$zero_denominator[[1L]])
    ))
  }
  list(strategy = strategy, value = lookup(indicator))
}

wlv_scientific_reference_from_row <- function(row, lookup) {
  do.call(
    wlv_scientific_reference_aggregate,
    wlv_scientific_reference_arguments(row, lookup)
  )
}

wlv_scientific_reference_checked <- function(
    row,
    lookup,
    method,
    indicator,
    level) {
  tryCatch(
    wlv_scientific_reference_from_row(row, lookup),
    error = function(error) {
      if (inherits(error, "wlv_scientific_validation_error")) {
        stop(error)
      }
      wlv_abort_scientific_validation(
        method,
        level,
        "sea_countries",
        indicator,
        as.character(row$strategy[[1L]]),
        conditionMessage(error)
      )
    }
  )
}

wlv_scientific_range_profiles <- function() {
  nonnegative <- data.frame(
    artifact = c(
      rep("sea_sectors", 5L),
      "m_io", "m_io"
    ),
    indicator = c(
      "capital_stock.s.us", "capital_depreciation.s.us",
      "gross_output.s.us", "gross_output.s.mv", "value.m.mv",
      "k_composition", "k_depreciation"
    ),
    minimum = rep(0, 7L),
    maximum = rep(Inf, 7L),
    exact_zero = rep(FALSE, 7L),
    stringsAsFactors = FALSE
  )
  zero_depreciation <- rbind(
    nonnegative[nonnegative$indicator != "capital_depreciation.s.us" &
      nonnegative$indicator != "k_depreciation", , drop = FALSE],
    data.frame(
      artifact = c("sea_sectors", "m_io"),
      indicator = c("capital_depreciation.s.us", "k_depreciation"),
      minimum = c(0, 0), maximum = c(0, 0), exact_zero = c(TRUE, TRUE),
      stringsAsFactors = FALSE
    )
  )
  profiles <- list(
    wiodr13 = nonnegative,
    wiodr16 = nonnegative,
    wiodr16v09 = nonnegative,
    zerodep_2 = zero_depreciation
  )
  profiles
}

wlv_scientific_range_rules <- function(method) {
  profiles <- wlv_scientific_range_profiles()
  if (!method %in% names(profiles)) {
    return(profiles[[1L]][FALSE, , drop = FALSE])
  }
  profiles[[method]]
}

wlv_scientific_md5_lines <- function(value) {
  if (!is.character(value) || anyNA(value)) {
    stop("Scientific pin payload must be complete character data.", call. = FALSE)
  }
  path <- tempfile("wlv-scientific-pin-", fileext = ".txt")
  on.exit(unlink(path), add = TRUE)
  connection <- file(path, open = "wb")
  writeBin(
    charToRaw(enc2utf8(paste(sort(value, method = "radix"), collapse = "\n"))),
    connection
  )
  close(connection)
  unname(tools::md5sum(path))
}

wlv_scientific_wiodr13_signed_sea_pin <- function(value, indicator, method) {
  positions <- which(value < 0, arr.ind = TRUE)
  expected_value <- switch(
    indicator,
    capital_stock.s.us = -75458950528.278488,
    capital_depreciation.s.us = -6684967062.9865351,
    NULL
  )
  labels <- dimnames(value)
  valid <-
    !is.null(expected_value) && nrow(positions) == 1L &&
    identical(labels[[1L]][positions[1L, 1L]], "2006") &&
    identical(labels[[3L]][positions[1L, 3L]], "23") &&
    identical(labels[[4L]][positions[1L, 4L]], "GBR") &&
    identical(
      sprintf("%.17g", value[positions]),
      sprintf("%.17g", expected_value)
    )
  if (!valid) {
    wlv_abort_scientific_validation(
      method, "wiodr13_signed_exception", "sea_sectors", indicator,
      scope = "2006/GBR.23",
      reason = "negative cells differ from the single pinned signed-domain exception"
    )
  }
  invisible(TRUE)
}

wlv_scientific_wiodr13_signed_io_pin <- function(value, indicator, method) {
  positions <- which(value < 0, arr.ind = TRUE)
  expected <- switch(
    indicator,
    k_composition = c(
      count = 824,
      coordinate_md5 = "31181c10e48b8defdec83affb2a5a261",
      value_md5 = "4989e51b2a6295660d6fbb0ceffe0686"
    ),
    k_depreciation = c(
      count = 824,
      coordinate_md5 = "31181c10e48b8defdec83affb2a5a261",
      value_md5 = "8d61eeb9b0692f6e896eaef24d85024f"
    ),
    NULL
  )
  if (is.null(expected) || nrow(positions) != as.integer(expected[["count"]])) {
    wlv_abort_scientific_validation(
      method, "wiodr13_signed_exception", "m_io", indicator,
      scope = paste(dimnames(value)[[1L]], collapse = ","),
      reason = sprintf(
        "negative-cell count differs from the pinned profile (observed=%s, expected=%s)",
        nrow(positions), if (is.null(expected)) "0" else expected[["count"]]
      )
    )
  }
  labels <- dimnames(value)
  keys <- paste(
    labels[[1L]][positions[, 1L]],
    labels[[3L]][positions[, 3L]],
    labels[[4L]][positions[, 4L]],
    sep = "|"
  )
  coordinate_md5 <- wlv_scientific_md5_lines(keys)
  value_md5 <- wlv_scientific_md5_lines(
    paste(keys, sprintf("%.17g", value[positions]), sep = "|")
  )
  if (
    !identical(coordinate_md5, unname(expected[["coordinate_md5"]])) ||
      !identical(value_md5, unname(expected[["value_md5"]]))
  ) {
    wlv_abort_scientific_validation(
      method, "wiodr13_signed_exception", "m_io", indicator,
      scope = paste(dimnames(value)[[1L]], collapse = ","),
      reason = sprintf(
        "negative-cell pin differs (coordinate_md5=%s; value_md5=%s)",
        coordinate_md5, value_md5
      )
    )
  }
  invisible(TRUE)
}

wlv_scientific_check_range <- function(
    value,
    method,
    artifact,
    indicator,
    minimum,
    maximum,
    exact_zero = FALSE,
    scope = "all published cells") {
  selected <- !is.na(value)
  finite_values <- value[selected]
  if (any(!is.finite(finite_values))) {
    wlv_abort_scientific_validation(
      method, "method_range", artifact, indicator, scope,
      "range contains NaN or infinite values"
    )
  }
  if (exact_zero) {
    invalid <- finite_values != 0
    tolerance <- "exact zero"
  } else {
    lower_scale <- pmax(
      abs(finite_values),
      if (is.finite(minimum)) abs(minimum) else 0,
      1
    )
    upper_scale <- pmax(
      abs(finite_values),
      if (is.finite(maximum)) abs(maximum) else 0,
      1
    )
    lower_slack <- 64 * .Machine$double.eps * lower_scale
    upper_slack <- 64 * .Machine$double.eps * upper_scale
    invalid <- finite_values < minimum - lower_slack |
      finite_values > maximum + upper_slack
    tolerance <- sprintf(
      "[%s,%s];componentwise_roundoff=64*eps*max(1,abs(value),abs(bound))",
      format(minimum, scientific = TRUE),
      format(maximum, scientific = TRUE)
    )
  }
  signed_wiodr13 <- identical(method, "wiodr13") &&
    (
      identical(artifact, "sea_sectors") &&
        indicator %in% c("capital_stock.s.us", "capital_depreciation.s.us") ||
      identical(artifact, "m_io") &&
        indicator %in% c("k_composition", "k_depreciation")
    )
  if (signed_wiodr13) {
    if (identical(artifact, "sea_sectors")) {
      wlv_scientific_wiodr13_signed_sea_pin(value, indicator, method)
    } else {
      wlv_scientific_wiodr13_signed_io_pin(value, indicator, method)
    }
    invalid[] <- FALSE
  }
  if (any(invalid)) {
    positions <- which(selected)[invalid]
    position <- positions[[1L]]
    wlv_abort_scientific_validation(
      method, "method_range", artifact, indicator, scope,
      sprintf(
        "value %.17g at `%s` is outside the method-specific range [%s, %s]",
        value[[position]],
        wlv_scientific_format_position(value, position),
        format(minimum, scientific = TRUE),
        format(maximum, scientific = TRUE)
      )
    )
  }
  maximum_error <- if (!length(finite_values)) {
    0
  } else if (exact_zero) {
    max(abs(finite_values))
  } else {
    max(c(minimum - finite_values, finite_values - maximum, 0))
  }
  wlv_scientific_check_row(
    method = method,
    check_id = "method_range",
    artifact = artifact,
    indicator = indicator,
    scope = scope,
    status = if (signed_wiodr13) "warning" else "pass",
    observations = length(finite_values),
    maximum_absolute_error = maximum_error,
    maximum_scaled_error = 0,
    tolerance = tolerance,
    detail = if (signed_wiodr13) {
      paste0(
        "Pinned WIOD13/2006/GBR.23 signed-domain exception; all other cells ",
        "remain nonnegative."
      )
    } else {
      "Method-versioned physical or methodological range."
    }
  )
}

wlv_scientific_validate_result_arrays <- function(
    method,
    sea_sectors,
    sea_countries,
    m_countries,
    solutions,
    aggregations) {
  rows <- list(
    wlv_scientific_structure_check(sea_sectors, 4L, method, "sea_sectors"),
    wlv_scientific_structure_check(sea_countries, 3L, method, "sea_countries"),
    wlv_scientific_structure_check(m_countries, 4L, method, "m_countries")
  )
  sector_years <- dimnames(sea_sectors)[[1L]]
  sector_indicators <- dimnames(sea_sectors)[[2L]]
  sectors <- dimnames(sea_sectors)[[3L]]
  countries <- dimnames(sea_sectors)[[4L]]
  structural_alignment <-
    identical(dimnames(sea_countries)[[1L]], sector_years) &&
    identical(dimnames(sea_countries)[[2L]], sector_indicators) &&
    identical(dimnames(sea_countries)[[3L]], c(countries, "WWW")) &&
    identical(dimnames(m_countries)[[1L]], sector_years) &&
    identical(dimnames(m_countries)[[3L]], countries) &&
    identical(dimnames(m_countries)[[4L]], countries)
  if (!structural_alignment) {
    wlv_abort_scientific_validation(
      method, "cross_artifact_labels", "published_results",
      reason = paste0(
        "years, indicators, sector countries, country matrices and the WWW ",
        "aggregate do not use the same ordered labels"
      )
    )
  }
  rows[[length(rows) + 1L]] <- wlv_scientific_check_row(
    method, "cross_artifact_labels", "published_results",
    observations = length(sector_years) + length(sector_indicators) +
      length(sectors) + length(countries),
    detail = "Ordered year, indicator, sector and country labels agree."
  )

  if (
    !is.data.frame(solutions) ||
      !all(c("names", "country_solution") %in% names(solutions)) ||
      anyNA(solutions[c("names", "country_solution")]) ||
      anyDuplicated(solutions$names) ||
      !identical(as.character(solutions$names), sector_indicators)
  ) {
    wlv_abort_scientific_validation(
      method, "solution_metadata", "_method_solutions.csv",
      reason = "solution metadata does not exactly describe the published indicator axis"
    )
  }
  rows[[length(rows) + 1L]] <- wlv_scientific_check_row(
    method, "solution_metadata", "_method_solutions.csv",
    observations = nrow(solutions),
    detail = "Solution metadata and the published indicator axis agree."
  )

  aggregation_columns <- c(
    "indicator", "level", "strategy", "module", "numerator",
    "denominator", "weight", "zero_denominator"
  )
  valid_row_set <- function(value) {
    is.data.frame(value) &&
      all(aggregation_columns %in% names(value)) &&
      !anyNA(value[aggregation_columns])
  }
  if (!valid_row_set(aggregations)) {
    wlv_abort_scientific_validation(
      method,
      "aggregation_contract",
      "published_metadata",
      reason = paste0(
        "aggregation routes do not contain complete operational columns"
      )
    )
  }
  aggregations <- aggregations[aggregation_columns]
  aggregation_keys <- paste(
    aggregations$indicator,
    aggregations$level,
    sep = "/"
  )
  valid_coverage <-
    !anyDuplicated(aggregation_keys) &&
    setequal(unique(aggregations$indicator), sector_indicators) &&
    all(table(factor(
      aggregations$indicator,
      levels = sector_indicators
    )) == 2L) &&
    all(vapply(
      split(
        aggregations$level,
        aggregations$indicator
      ),
      setequal,
      logical(1L),
      c("sector_to_country", "country_to_world")
    ))
  supported <- c(
    "sum", "mean", "ratio_of_sums", "weighted_mean", "invariant",
    "not_applicable", "formula"
  )
  valid_strategies <- all(aggregations$strategy %in% supported)
  if (!valid_coverage || !valid_strategies) {
    wlv_abort_scientific_validation(
      method,
      "aggregation_contract",
      "published_metadata",
      reason = paste0(
        "typed routes must be supported and cover both levels of every ",
        "published indicator"
      )
    )
  }
  references <- unlist(
    aggregations[c("numerator", "denominator", "weight")],
    use.names = FALSE
  )
  references <- as.character(references)
  references <- references[!is.na(references) & nzchar(references)]
  if (any(!references %in% sector_indicators)) {
    wlv_abort_scientific_validation(
      method,
      "aggregation_contract",
      "_unit_contract.csv",
      reason = "typed aggregation rows contain an unavailable dependency"
    )
  }
  rows[[length(rows) + 1L]] <- wlv_scientific_check_row(
    method,
    "aggregation_contract",
    "_unit_contract.csv",
    observations = nrow(aggregations),
    detail = "Persisted typed aggregation rows exactly cover the result."
  )

  for (indicator in sector_indicators) {
    country_row <- wlv_scientific_aggregation_row(
      aggregations,
      indicator,
      "sector_to_country",
      method
    )
    world_row <- wlv_scientific_aggregation_row(
      aggregations,
      indicator,
      "country_to_world",
      method
    )
    country_formula <- identical(
      as.character(country_row$strategy[[1L]]),
      "formula"
    )
    world_formula <- identical(
      as.character(world_row$strategy[[1L]]),
      "formula"
    )
    if (country_formula != world_formula) {
      wlv_abort_scientific_validation(
        method,
        "aggregation_contract",
        "_unit_contract.csv",
        indicator,
        reason = "formula routing must agree at both aggregation levels"
      )
    }
    if (country_formula) {
      next
    }
    country_strategy <- as.character(country_row$strategy[[1L]])
    world_strategy <- as.character(world_row$strategy[[1L]])
    expected_country <- array(
      NA_real_,
      dim = c(length(sector_years), length(countries)),
      dimnames = list(sector_years, countries)
    )
    country_error_limit <- expected_country
    for (year_index in seq_along(sector_years)) {
      for (country_index in seq_along(countries)) {
        lookup <- function(name) {
          sea_sectors[year_index, name, , country_index]
        }
        expected_country[year_index, country_index] <-
          wlv_scientific_reference_checked(
            country_row,
            lookup,
            method,
            indicator,
            "sector_to_country"
          )
        if (country_strategy %in% c("sum", "mean")) {
          country_error_limit[year_index, country_index] <-
            wlv_scientific_reduction_error_limit(
              lookup(indicator),
              expected_country[year_index, country_index]
            )
        }
      }
    }
    observed_country <- sea_countries[, indicator, countries, drop = FALSE]
    observed_country <- array(
      observed_country,
      dim = dim(expected_country),
      dimnames = dimnames(expected_country)
    )
    country_comparison <- list(
      observed_country,
      expected_country,
      method = method,
      check_id = "sector_to_country",
      artifact = "sea_countries",
      indicator = indicator,
      scope = country_strategy,
      detail = sprintf(
        "Independent `%s` typed reference aggregation over sectors.",
        country_strategy
      )
    )
    if (country_strategy %in% c("sum", "mean")) {
      country_comparison$error_limit <- country_error_limit
    }
    rows[[length(rows) + 1L]] <- do.call(
      wlv_scientific_compare,
      country_comparison
    )

    expected_world <- vapply(seq_along(sector_years), function(year_index) {
      lookup <- function(name) {
        sea_countries[year_index, name, countries]
      }
      wlv_scientific_reference_checked(
        world_row,
        lookup,
        method,
        indicator,
        "country_to_world"
      )
    }, numeric(1L))
    names(expected_world) <- sector_years
    observed_world <- sea_countries[, indicator, "WWW"]
    names(observed_world) <- sector_years
    world_comparison <- list(
      observed_world,
      expected_world,
      method = method,
      check_id = "country_to_world",
      artifact = "sea_countries",
      indicator = indicator,
      scope = world_strategy,
      detail = sprintf(
        "Independent `%s` typed reference aggregation over countries.",
        world_strategy
      )
    )
    if (world_strategy %in% c("sum", "mean")) {
      world_error_limit <- vapply(
        seq_along(sector_years),
        function(year_index) {
          wlv_scientific_reduction_error_limit(
            sea_countries[year_index, indicator, countries],
            expected_world[[year_index]]
          )
        },
        numeric(1L)
      )
      names(world_error_limit) <- sector_years
      world_comparison$error_limit <- world_error_limit
    }
    rows[[length(rows) + 1L]] <- do.call(
      wlv_scientific_compare,
      world_comparison
    )
  }

  bilateral_indicators <- dimnames(m_countries)[[2L]]
  for (indicator in bilateral_indicators) {
    diagonals <- unlist(lapply(seq_along(sector_years), function(year_index) {
      diag(m_countries[year_index, indicator, , ])
    }), use.names = FALSE)
    expected <- rep(0, length(diagonals))
    rows[[length(rows) + 1L]] <- wlv_scientific_compare(
      diagonals,
      expected,
      method = method,
      check_id = "bilateral_diagonal_zero",
      artifact = "m_countries",
      indicator = indicator,
      scope = "all years",
      absolute_tolerance = 0,
      relative_tolerance = 0,
      detail = "Domestic bilateral cells must be exactly zero."
    )
  }

  if ("transfers_productive_values" %in% bilateral_indicators) {
    for (year in sector_years) {
      current <- m_countries[year, "transfers_productive_values", , ]
      observed <- sum(current)
      absolute_tolerance <- 64 * .Machine$double.eps * max(sum(abs(current)), 1)
      rows[[length(rows) + 1L]] <- wlv_scientific_compare(
        observed,
        0,
        method = method,
        check_id = "productive_transfer_conservation",
        artifact = "m_countries",
        indicator = "transfers_productive_values",
        scope = year,
        absolute_tolerance = absolute_tolerance,
        relative_tolerance = 0,
        detail = paste0(
          "Productive value transfers sum to zero; total transfers are not ",
          "subject to this invariant."
        )
      )
    }
  } else {
    rows[[length(rows) + 1L]] <- wlv_scientific_not_applicable(
      method,
      "productive_transfer_conservation",
      "m_countries",
      "transfers_productive_values",
      detail = "The method publishes no productive-transfer matrix."
    )
  }

  rules <- wlv_scientific_range_rules(method)
  sector_rules <- rules[rules$artifact == "sea_sectors", , drop = FALSE]
  for (index in seq_len(nrow(sector_rules))) {
    indicator <- sector_rules$indicator[[index]]
    if (!indicator %in% sector_indicators) {
      rows[[length(rows) + 1L]] <- wlv_scientific_not_applicable(
        method, "method_range", "sea_sectors", indicator,
        detail = "The method does not publish this profiled indicator."
      )
      next
    }
    rows[[length(rows) + 1L]] <- wlv_scientific_check_range(
      sea_sectors[, indicator, , , drop = FALSE],
      method = method,
      artifact = "sea_sectors",
      indicator = indicator,
      minimum = sector_rules$minimum[[index]],
      maximum = sector_rules$maximum[[index]],
      exact_zero = sector_rules$exact_zero[[index]]
    )
  }

  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result[wlv_scientific_check_columns()]
}

wlv_scientific_validate_io_array <- function(method, m_io, sea_sectors) {
  rows <- list(wlv_scientific_structure_check(m_io, 4L, method, "m_io"))
  years <- dimnames(m_io)[[1L]]
  indicators <- dimnames(m_io)[[2L]]
  inputs <- dimnames(m_io)[[3L]]
  outputs <- dimnames(m_io)[[4L]]
  sea_years <- dimnames(sea_sectors)[[1L]]
  sectors <- dimnames(sea_sectors)[[3L]]
  countries <- dimnames(sea_sectors)[[4L]]
  expected_inputs <- paste(
    rep(countries, each = length(sectors)),
    rep(sectors, times = length(countries)),
    sep = "."
  )
  if (
    any(!years %in% sea_years) ||
      !identical(inputs, expected_inputs) ||
      length(outputs) < length(inputs) ||
      !identical(outputs[seq_along(inputs)], inputs)
  ) {
    wlv_abort_scientific_validation(
      method, "io_labels", "m_io",
      scope = paste(years, collapse = ","),
      reason = paste0(
        "I/O years, ordered input labels or the productive-output prefix do ",
        "not agree with the published sector results"
      )
    )
  }
  rows[[length(rows) + 1L]] <- wlv_scientific_check_row(
    method, "io_labels", "m_io",
    scope = paste(years, collapse = ","),
    observations = length(years) + length(inputs) + length(outputs),
    detail = "I/O labels agree with the ordered country-sector product."
  )

  checks <- list(
    list(
      matrix = "k_composition",
      sector = "capital_stock.s.us",
      check_id = "capital_stock_conservation"
    ),
    list(
      matrix = "k_depreciation",
      sector = "capital_depreciation.s.us",
      check_id = "depreciation_identity"
    )
  )
  for (specification in checks) {
    if (
      !specification$matrix %in% indicators ||
        !specification$sector %in% dimnames(sea_sectors)[[2L]]
    ) {
      rows[[length(rows) + 1L]] <- wlv_scientific_not_applicable(
        method,
        specification$check_id,
        "m_io",
        specification$matrix,
        scope = paste(years, collapse = ","),
        detail = sprintf(
          "Matrix `%s` or sector indicator `%s` is not published by this method.",
          specification$matrix,
          specification$sector
        )
      )
      next
    }
    for (year in years) {
      matrix_value <- m_io[year, specification$matrix, inputs, inputs, drop = TRUE]
      observed <- colSums(matrix_value, na.rm = TRUE)
      expected <- as.vector(sea_sectors[year, specification$sector, , ])
      error_limit <- vapply(seq_along(expected), function(column_index) {
        wlv_scientific_reduction_error_limit(
          matrix_value[, column_index],
          expected[[column_index]]
        )
      }, numeric(1L))
      names(observed) <- inputs
      names(expected) <- inputs
      names(error_limit) <- inputs
      rows[[length(rows) + 1L]] <- wlv_scientific_compare(
        observed,
        expected,
        method = method,
        check_id = specification$check_id,
        artifact = "m_io",
        indicator = specification$matrix,
        scope = year,
        error_limit = error_limit,
        detail = sprintf(
          "Column sums equal `sea_sectors/%s`.",
          specification$sector
        )
      )
    }
  }

  if (
    "values" %in% indicators &&
      "gross_output.s.mv" %in% dimnames(sea_sectors)[[2L]]
  ) {
    for (year in years) {
      observed <- rowSums(m_io[year, "values", , , drop = TRUE], na.rm = TRUE)
      expected <- as.vector(sea_sectors[year, "gross_output.s.mv", , ])
      matrix_value <- m_io[year, "values", , , drop = TRUE]
      error_limit <- vapply(seq_along(expected), function(row_index) {
        wlv_scientific_reduction_error_limit(
          matrix_value[row_index, ],
          expected[[row_index]]
        )
      }, numeric(1L))
      names(observed) <- inputs
      names(expected) <- inputs
      names(error_limit) <- inputs
      rows[[length(rows) + 1L]] <- wlv_scientific_compare(
        observed,
        expected,
        method = method,
        check_id = "gross_output_value_identity",
        artifact = "m_io",
        indicator = "values",
        scope = year,
        error_limit = error_limit,
        detail = "Row sums equal `sea_sectors/gross_output.s.mv`."
      )
    }
  } else {
    rows[[length(rows) + 1L]] <- wlv_scientific_not_applicable(
      method,
      "gross_output_value_identity",
      "m_io",
      "values",
      scope = paste(years, collapse = ","),
      detail = "The values matrix or gross-output-in-value indicator is absent."
    )
  }

  rules <- wlv_scientific_range_rules(method)
  io_rules <- rules[rules$artifact == "m_io", , drop = FALSE]
  for (index in seq_len(nrow(io_rules))) {
    indicator <- io_rules$indicator[[index]]
    if (!indicator %in% indicators) {
      rows[[length(rows) + 1L]] <- wlv_scientific_not_applicable(
        method, "method_range", "m_io", indicator,
        scope = paste(years, collapse = ","),
        detail = "The method does not publish this profiled matrix."
      )
      next
    }
    rows[[length(rows) + 1L]] <- wlv_scientific_check_range(
      m_io[, indicator, , inputs, drop = FALSE],
      method = method,
      artifact = "m_io",
      indicator = indicator,
      minimum = io_rules$minimum[[index]],
      maximum = io_rules$maximum[[index]],
      exact_zero = io_rules$exact_zero[[index]],
      scope = paste(years, collapse = ",")
    )
  }

  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result[wlv_scientific_check_columns()]
}

wlv_validate_scientific_check_artifact <- function(value, method) {
  if (
    !is.data.frame(value) ||
      !identical(names(value), wlv_scientific_check_columns()) ||
      !nrow(value) || anyNA(value[c(
        "method", "check_id", "artifact", "indicator", "scope", "status",
        "observations", "tolerance", "detail"
      )]) ||
      any(value$method != method) ||
      any(!value$status %in% c("pass", "warning", "not_applicable")) ||
      any(value$observations < 0L) ||
      any(!is.na(value$maximum_absolute_error) &
        !is.finite(value$maximum_absolute_error)) ||
      any(!is.na(value$maximum_scaled_error) &
        !is.finite(value$maximum_scaled_error))
  ) {
    wlv_abort_scientific_validation(
      method, "scientific_check_sidecar", "_scientific_checks.csv",
      reason = "the scientific-check sidecar has an invalid schema or value"
    )
  }
  invisible(value)
}

wlv_scientific_validate_lambda_fingerprints <- function(
    leontief,
    sea_sectors,
    method) {
  if (
    !is.array(sea_sectors) || length(dim(sea_sectors)) != 4L ||
    is.null(dimnames(sea_sectors)) ||
    !"value.m.mv" %in% dimnames(sea_sectors)[[2L]]
  ) {
    wlv_abort_scientific_validation(
      method,
      "leontief_generation_fingerprint",
      "sea_sectors/value.m.mv",
      reason = "the published labour-value array is unavailable for fingerprint validation"
    )
  }
  sectors <- dimnames(sea_sectors)[[3L]]
  countries <- dimnames(sea_sectors)[[4L]]
  labels <- paste(
    rep(countries, each = length(sectors)),
    rep(sectors, times = length(countries)),
    sep = "."
  )
  observed <- vapply(
    leontief$year,
    function(year) {
      if (!year %in% dimnames(sea_sectors)[[1L]]) {
        wlv_abort_scientific_validation(
          method,
          "leontief_generation_fingerprint",
          "sea_sectors/value.m.mv",
          scope = year,
          reason = "the diagnostic year is absent from the published labour-value array"
        )
      }
      lambda <- as.numeric(sea_sectors[year, "value.m.mv", , ])
      wlv_lambda_fingerprint(lambda, labels)
    },
    character(1L),
    USE.NAMES = FALSE
  )
  mismatch <- observed != leontief$lambda_fingerprint
  if (any(mismatch)) {
    wlv_abort_scientific_validation(
      method,
      "leontief_generation_fingerprint",
      "_leontief_diagnostics.csv",
      scope = paste(leontief$year[mismatch], collapse = ","),
      reason = paste0(
        "the diagnostic fingerprint does not match the published ",
        "`sea_sectors/value.m.mv` values"
      )
    )
  }
  wlv_scientific_check_row(
    method,
    "leontief_generation_fingerprint",
    "_leontief_diagnostics.csv",
    indicator = "value.m.mv",
    observations = length(observed),
    detail = paste0(
      "Every annual diagnostic fingerprint matches the published ",
      "labour-value vector and its canonical input labels."
    )
  )
}

wlv_scientific_validate_leontief_signed_profile <- function(
    leontief,
    scientific_profile,
    method) {
  expected <- scientific_profile$leontief_signed$rows
  valid <-
    is.data.frame(leontief) &&
    all(c(
      "year", "coefficient_negative_count", "certificate_type"
    ) %in% names(leontief)) &&
    identical(as.character(leontief$year), as.character(expected$year)) &&
    identical(
      as.integer(leontief$coefficient_negative_count),
      as.integer(expected$coefficient_negative_count)
    ) &&
    identical(
      as.character(leontief$certificate_type),
      as.character(expected$certificate_type)
    )
  if (!valid) {
    observed <- if (is.data.frame(leontief) && all(c(
      "year", "coefficient_negative_count", "certificate_type"
    ) %in% names(leontief))) {
      paste(
        leontief$year,
        leontief$coefficient_negative_count,
        leontief$certificate_type,
        sep = ":"
      )
    } else {
      "invalid-schema"
    }
    wlv_abort_scientific_validation(
      method,
      "leontief_signed_profile",
      "_leontief_diagnostics.csv",
      reason = sprintf(
        paste0(
          "signed coefficient profile differs from explicit profile `%s` ",
          "(observed %s)"
        ),
        scientific_profile$leontief_signed$id,
        paste(observed, collapse = ",")
      )
    )
  }
  as.character(expected$year[expected$coefficient_negative_count > 0L])
}

wlv_scientific_validate_nonfinite_resolution <- function(
    diagnostics,
    scientific_profile,
    method) {
  name <- "_nonfinite_resolution_diagnostics.csv"
  resolution <- scientific_profile$nonfinite_resolution
  if (identical(resolution$action, "reject")) {
    if (name %in% names(diagnostics)) {
      wlv_abort_scientific_validation(
        method,
        "nonfinite_resolution",
        name,
        reason = "a strict profile published an undeclared resolution sidecar"
      )
    }
    return(NULL)
  }
  if (!name %in% names(diagnostics)) {
    wlv_abort_scientific_validation(
      method,
      "nonfinite_resolution",
      name,
      reason = sprintf(
        "profile `%s` requires the non-finite resolution sidecar",
        resolution$id
      )
    )
  }
  observed <- tryCatch(
    wlv_normalize_nonfinite_resolution_diagnostics(diagnostics[[name]]),
    error = function(error) {
      wlv_abort_scientific_validation(
        method,
        "nonfinite_resolution",
        name,
        reason = conditionMessage(error)
      )
    }
  )
  expected <- resolution$groups[
    order(resolution$groups$binding, resolution$groups$kind, method = "radix"),
    ,
    drop = FALSE
  ]
  keys_match <- identical(observed$binding, expected$binding) &&
    identical(observed$indicator, expected$indicator) &&
    identical(observed$kind, expected$kind)
  values_match <- keys_match &&
    identical(observed$module, expected$module) &&
    identical(observed$resolved_count, expected$expected_count) &&
    identical(observed$coordinate_sha256, expected$coordinate_sha256)
  identity_match <-
    all(observed$method == method) &&
    all(observed$scientific_profile == scientific_profile$id) &&
    all(observed$nonfinite_resolution_profile == resolution$id) &&
    all(observed$action == resolution$action)
  if (!values_match || !identity_match ||
      sum(observed$resolved_count) != resolution$expected_count) {
    wlv_abort_scientific_validation(
      method,
      "nonfinite_resolution",
      name,
      reason = sprintf(
        "published transitions differ from explicit profile `%s`",
        resolution$id
      )
    )
  }
  wlv_scientific_check_row(
    method,
    "nonfinite_resolution",
    name,
    observations = sum(observed$resolved_count),
    detail = sprintf(
      "Profile `%s` closed %s declared historical transition(s).",
      resolution$id,
      sum(observed$resolved_count)
    )
  )
}

wlv_scientific_validate_diagnostics <- function(
    diagnostics,
    method,
    source,
    years,
    sea_sectors,
    scientific_profile) {
  if (is.null(scientific_profile)) {
    wlv_abort_scientific_validation(
      method,
      "scientific_profile",
      "config/contracts/scientific_profiles.csv",
      reason = "an explicit scientific profile is required"
    )
  }
  wlv_assert_scientific_profile(scientific_profile, method, source)
  if (!is.list(diagnostics) || is.null(names(diagnostics))) {
    wlv_abort_scientific_validation(
      method, "diagnostic_inventory", "scientific_sidecars",
      reason = "scientific diagnostics must be a named list"
    )
  }
  leontief_name <- "_leontief_diagnostics.csv"
  if (!leontief_name %in% names(diagnostics)) {
    wlv_abort_scientific_validation(
      method, "leontief_diagnostics", leontief_name,
      reason = "the required Leontief diagnostic is missing"
    )
  }
  if (!exists("wlv_validate_leontief_diagnostic_artifact", mode = "function")) {
    wlv_abort_scientific_validation(
      method, "leontief_diagnostics", leontief_name,
      reason = "the Leontief diagnostic validator is not loaded"
    )
  }
  wlv_validate_leontief_diagnostic_artifact(
    diagnostics[[leontief_name]],
    method = method,
    expected_years = years
  )
  leontief <- diagnostics[[leontief_name]]
  fingerprint_check <- wlv_scientific_validate_lambda_fingerprints(
    leontief = leontief,
    sea_sectors = sea_sectors,
    method = method
  )
  signed_years <- wlv_scientific_validate_leontief_signed_profile(
    leontief,
    scientific_profile,
    method
  )
  rows <- list(fingerprint_check, wlv_scientific_check_row(
    method,
    "leontief_diagnostics",
    leontief_name,
    status = if (length(signed_years)) "warning" else "pass",
    observations = nrow(leontief),
    detail = if (length(signed_years)) {
      sprintf(
        paste0(
          "Numerical diagnostics passed; signed coefficient domains in year(s) ",
          "%s use the declared absolute-stability certificate."
        ),
        paste(signed_years, collapse = ",")
      )
    } else {
      "Per-year numerical diagnostics passed their declared thresholds."
    }
  ))
  rows[[length(rows) + 1L]] <- if (length(signed_years)) {
    wlv_scientific_not_applicable(
      method,
      "leontief_productivity",
      leontief_name,
      scope = paste(signed_years, collapse = ","),
      detail = paste0(
        "Hawkins-Simon productivity is not claimed for a signed coefficient ",
        "domain; absolute stability is certified instead."
      )
    )
  } else {
    wlv_scientific_check_row(
      method,
      "leontief_productivity",
      leontief_name,
      observations = nrow(leontief),
      detail = "All nonnegative coefficient systems passed the productivity certificate."
    )
  }
  nonfinite_check <- wlv_scientific_validate_nonfinite_resolution(
    diagnostics,
    scientific_profile,
    method
  )
  if (!is.null(nonfinite_check)) {
    rows[[length(rows) + 1L]] <- nonfinite_check
  }

  gfcf_names <- c(
    "_gfcf_negative_cells.csv",
    "_gfcf_negative_summary.csv"
  )
  present_gfcf <- intersect(gfcf_names, names(diagnostics))
  if (length(present_gfcf)) {
    if (!setequal(present_gfcf, gfcf_names)) {
      wlv_abort_scientific_validation(
        method, "gfcf_diagnostics", "gfcf_sidecars",
        reason = "the negative-GFCF diagnostic pair is incomplete"
      )
    }
    if (!exists("wlv_validate_gfcf_diagnostic_artifacts", mode = "function")) {
      wlv_abort_scientific_validation(
        method, "gfcf_diagnostics", "gfcf_sidecars",
        reason = "the negative-GFCF diagnostic validator is not loaded"
      )
    }
    wlv_validate_gfcf_diagnostic_artifacts(
      diagnostics[gfcf_names],
      method = source
    )
    rows[[length(rows) + 1L]] <- wlv_scientific_check_row(
      method,
      "gfcf_diagnostics",
      "gfcf_sidecars",
      observations = nrow(diagnostics[[gfcf_names[[1L]]]]),
      detail = sprintf("Pinned negative-GFCF profile for source `%s` passed.", source)
    )
  } else if (source %in% c("wiodr13", "wiodr16")) {
    wlv_abort_scientific_validation(
      method, "gfcf_diagnostics", "gfcf_sidecars",
      reason = sprintf("source `%s` requires the negative-GFCF diagnostic pair", source)
    )
  } else {
    rows[[length(rows) + 1L]] <- wlv_scientific_not_applicable(
      method,
      "gfcf_diagnostics",
      "gfcf_sidecars",
      detail = "The source has no pinned negative-GFCF profile."
    )
  }
  do.call(rbind, rows)
}

wlv_finalize_scientific_checks <- function(
    checks,
    method,
    source,
    years,
    io_years,
    diagnostics,
    sea_sectors,
    scientific_profile) {
  rows <- checks
  if (length(io_years)) {
    duplicated_years <- unique(io_years[duplicated(io_years)])
    missing_years <- setdiff(years, io_years)
    unexpected_years <- setdiff(io_years, years)
    if (length(duplicated_years) || length(missing_years) || length(unexpected_years)) {
      wlv_abort_scientific_validation(
        method, "io_year_coverage", "m_io",
        reason = sprintf(
          "I/O year coverage differs (missing=%s; duplicated=%s; unexpected=%s)",
          paste(missing_years, collapse = ","),
          paste(duplicated_years, collapse = ","),
          paste(unexpected_years, collapse = ",")
        )
      )
    }
    rows[[length(rows) + 1L]] <- wlv_scientific_check_row(
      method,
      "io_year_coverage",
      "m_io",
      observations = length(io_years),
      detail = "Every result year appears in exactly one I/O artifact."
    )
  } else {
    wlv_abort_scientific_validation(
      method, "io_year_coverage", "m_io",
      reason = "no I/O result array is available"
    )
  }

  rows[[length(rows) + 1L]] <- wlv_scientific_validate_diagnostics(
    diagnostics = diagnostics,
    method = method,
    source = source,
    years = years,
    sea_sectors = sea_sectors,
    scientific_profile = scientific_profile
  )
  result <- do.call(rbind, rows)
  result <- result[order(
    result$check_id,
    result$artifact,
    result$indicator,
    result$scope,
    method = "radix"
  ), , drop = FALSE]
  row.names(result) <- NULL
  wlv_validate_scientific_check_artifact(result, method)
  result
}

wlv_scientific_sidecar_pattern <- function() {
  "^_(gfcf_|leontief_|nonfinite_resolution_|scientific_).*[.]csv$"
}
