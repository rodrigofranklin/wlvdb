# Read-only analysis example; not a native scientific module.
# Guides: docs/use-results-pt.md and docs/use-results-en.md.
# The function does not authenticate files: load a run through the public
# manifest-aware reader before supplying its arrays and sidecars here.
wlv_example_review_series <- function(countries, units, states, anomalies,
                                     method = "wiodr13", country = "BRA",
                                     indicator = "surplus_value.empe_p.r.pc",
                                     years = 1995:2007) {
  scalar_text <- function(x) is.character(x) && length(x) == 1L &&
    !is.na(x) && nzchar(x)
  if (!scalar_text(method) || !method %in% c("wiodr13", "wiodr16") ||
      !scalar_text(country) || !scalar_text(indicator)) {
    stop("Specify a supported method and one country and indicator.", call. = FALSE)
  }
  axes <- dimnames(countries)
  if (!is.numeric(countries) || length(dim(countries)) != 3L ||
      length(axes) != 3L || any(vapply(axes, is.null, logical(1L))) ||
      any(vapply(axes, anyDuplicated, integer(1L)) != 0L) ||
      any(vapply(axes, anyNA, logical(1L))) ||
      !indicator %in% axes[[2L]] || !country %in% axes[[3L]]) {
    stop("Expected a labelled year x indicator x country numeric array.", call. = FALSE)
  }
  year_text <- axes[[1L]]
  if (any(!grepl("^[0-9]{4}$", year_text))) {
    stop("Array years must be four-digit labels.", call. = FALSE)
  }
  available_years <- as.integer(year_text)
  if (!is.numeric(years) || !length(years) || anyNA(years) ||
      any(!is.finite(years)) || any(years != floor(years)) ||
      anyDuplicated(years) || !all(years %in% available_years)) {
    stop("Requested years must be distinct years present in the result.", call. = FALSE)
  }
  required_units <- c("indicator", "canonical_unit", "display_unit", "display_multiplier")
  required_states <- c("artifact", "indicator", "year", "country", "state")
  required_anomalies <- c("artifact", "indicator", "year", "country", "action")
  require_columns <- function(x, required, label) {
    if (!is.data.frame(x) || !all(required %in% names(x))) {
      stop(paste("Missing columns in", label), call. = FALSE)
    }
  }
  require_columns(units, required_units, "unit contract")
  require_columns(states, required_states, "states sidecar")
  require_columns(anomalies, required_anomalies, "anomalies sidecar")
  unit_rows <- !is.na(units$indicator) & as.character(units$indicator) == indicator
  unit <- unique(units[unit_rows, required_units[-1L], drop = FALSE])
  if (nrow(unit) != 1L || anyNA(unit) ||
      any(!nzchar(as.character(unit$canonical_unit))) ||
      any(!nzchar(as.character(unit$display_unit)))) {
    stop("Expected one consistent stored/display unit definition.", call. = FALSE)
  }
  multiplier <- suppressWarnings(as.numeric(as.character(unit$display_multiplier)))
  if (length(multiplier) != 1L || !is.finite(multiplier) || multiplier <= 0) {
    stop("Display multiplier must be finite and positive.", call. = FALSE)
  }
  value <- as.vector(countries[, indicator, country, drop = FALSE])
  if (any(is.nan(value) | is.infinite(value))) {
    stop("NaN and infinity are not published missingness states.", call. = FALSE)
  }
  exact <- function(x, target) !is.na(x) & as.character(x) %in% target
  state_rows <- exact(states$artifact, "sea_countries") &
    exact(states$indicator, indicator) & exact(states$country, country) &
    exact(states$year, year_text)
  selected_states <- states[state_rows, , drop = FALSE]
  if (anyDuplicated(as.character(selected_states$year)) ||
      anyNA(selected_states$state) ||
      any(!as.character(selected_states$state) %in% c("source_missing", "not_applicable"))) {
    stop("Ambiguous or invalid state for the selected series.", call. = FALSE)
  }
  state_index <- match(year_text, as.character(selected_states$year))
  has_state <- !is.na(state_index)
  if (any(is.na(value) != has_state)) {
    stop("Every selected NA must have one state; finite cells must not have states.",
         call. = FALSE)
  }
  state <- rep("finite", length(value))
  state[has_state] <- as.character(selected_states$state[state_index[has_state]])

  # Keep global upstream events: another country's imputation can affect the
  # world production system. Empty/unknown year coordinates are retained for
  # every year, rather than being silently discarded.
  anomaly_year <- as.character(anomalies$year)
  unspecified_year <- is.na(anomaly_year) | !grepl("^[0-9]{4}$", anomaly_year)
  relevant <- unspecified_year | anomaly_year %in% year_text
  audit <- anomalies[relevant, , drop = FALSE]
  ay <- as.character(audit$year)
  unknown <- is.na(ay) | !grepl("^[0-9]{4}$", ay)
  global_event_count <- vapply(year_text, function(y) {
    sum(unknown | (!is.na(ay) & ay == y))
  }, integer(1L))
  ac <- as.character(audit$country)
  selected_country <- !is.na(ac) & ac == country
  country_event_count <- vapply(year_text, function(y) {
    sum((unknown | (!is.na(ay) & ay == y)) & selected_country)
  }, integer(1L))

  in_period <- available_years %in% years
  coverage_alert <- method == "wiodr13" & available_years %in% 2008:2009
  candidate <- in_period & is.finite(value) & !coverage_alert
  reason <- ifelse(!in_period, "outside_requested_period",
    ifelse(coverage_alert, "wiodr13_2008_2009_coverage",
      ifelse(is.na(value), paste0("missing:", state), "pending_scientific_review")))
  series <- data.frame(
    method = method, country = country, indicator = indicator,
    year = available_years, stored_value = value,
    canonical_unit = as.character(unit$canonical_unit[[1L]]),
    display_value = value * multiplier,
    display_unit = as.character(unit$display_unit[[1L]]),
    state = state, in_requested_period = in_period,
    wiodr13_coverage_alert = coverage_alert,
    candidate_by_scope = candidate,
    global_year_events = global_event_count,
    selected_country_events = country_event_count,
    decision = ifelse(candidate, "pending", "exclude"),
    reason = reason, stringsAsFactors = FALSE
  )
  list(series = series, states = selected_states, anomalies = audit,
       unit = unit, requested_years = as.integer(years))
}

# This is a sensitivity calculation on explicitly matched observations,
# not a replacement for a published aggregate or an imputation of missing data.
wlv_example_common_coverage <- function(numerator, denominator) {
  if (!is.numeric(numerator) || !is.numeric(denominator) ||
      !length(numerator) || length(numerator) != length(denominator) ||
      any(is.nan(numerator) | is.infinite(numerator)) ||
      any(is.nan(denominator) | is.infinite(denominator))) {
    stop("Supply equally sized numeric operands with finite values or ordinary NA.",
         call. = FALSE)
  }
  complete <- !is.na(numerator) & !is.na(denominator)
  total_numerator <- if (any(complete)) sum(numerator[complete]) else NA_real_
  total_denominator <- if (any(complete)) sum(denominator[complete]) else NA_real_
  rate <- if (any(complete) && total_denominator != 0) {
    total_numerator / total_denominator - 1
  } else NA_real_
  list(rate = rate, included = which(complete), excluded = which(!complete),
       numerator = total_numerator, denominator = total_denominator,
       n_complete = sum(complete), n_total = length(complete))
}
