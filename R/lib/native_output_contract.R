# Public panel ordering contract -------------------------------------------
#
# DAG order is computational, not presentational.  These data-only profiles
# preserve the indicator dimension of wlvpanel-output/1.0.0 without letting
# CSV row order influence dependency resolution.

wlv_native_output_read_csv <- function(path, columns, label) {
  if (!file.exists(path) || isTRUE(file.info(path)$isdir)) {
    stop(sprintf("%s does not exist: `%s`.", label, path), call. = FALSE)
  }
  value <- utils::read.csv2(
    path,
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL,
    fileEncoding = "UTF-8"
  )
  if (!identical(names(value), columns) || anyNA(value)) {
    stop(sprintf("%s has an invalid schema.", label), call. = FALSE)
  }
  value
}

wlv_native_output_identifier <- function(value, name) {
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !grepl("^[a-z][a-z0-9_]*$", value)) {
    stop(sprintf("`%s` must be one valid identifier.", name), call. = FALSE)
  }
  value
}

wlv_native_output_profile_map <- function(root) {
  value <- wlv_native_output_read_csv(
    file.path(root, "config", "outputs", "method_profiles.csv"),
    c("method", "profile"),
    "Output profile map"
  )
  if (!nrow(value) || any(!nzchar(as.matrix(value))) ||
      anyDuplicated(value$method) ||
      any(!vapply(value$method, function(item) {
        grepl("^[a-z][a-z0-9_]*$", item)
      }, logical(1L))) ||
      any(!vapply(value$profile, function(item) {
        grepl("^[a-z][a-z0-9_]*$", item)
      }, logical(1L)))) {
    stop("Output profile map contains invalid declarations.", call. = FALSE)
  }
  value
}

wlv_native_output_profiles <- function(root) {
  value <- wlv_native_output_read_csv(
    file.path(root, "config", "outputs", "profiles.csv"),
    c("profile", "source"),
    "Output profiles"
  )
  if (!nrow(value) || any(!nzchar(value$profile)) ||
      any(!nzchar(value$source)) || anyDuplicated(value$profile)) {
    stop("Output profiles contain invalid declarations.", call. = FALSE)
  }
  value
}

wlv_native_output_overrides <- function(root, profiles) {
  value <- wlv_native_output_read_csv(
    file.path(root, "config", "outputs", "overrides.csv"),
    c("profile", "position", "indicator"),
    "Output profile overrides"
  )
  positions <- suppressWarnings(as.integer(value$position))
  valid <- nzchar(value$profile) & nzchar(value$indicator) &
    !is.na(positions) & positions > 0L &
    value$position == as.character(positions) &
    value$profile %in% profiles$profile &
    grepl("^[a-z][a-z0-9_.]*$", value$indicator)
  keys <- paste(value$profile, value$position, sep = "\034")
  indicators <- paste(value$profile, value$indicator, sep = "\034")
  if (any(!valid) || anyDuplicated(keys) || anyDuplicated(indicators)) {
    stop("Output profile overrides contain invalid declarations.", call. = FALSE)
  }
  value$position <- positions
  value
}

wlv_native_output_source_indicators <- function(root, source) {
  source <- wlv_native_output_identifier(source, "source")
  value <- wlv_native_output_read_csv(
    file.path(root, "config", "outputs", "sources", paste0(source, ".csv")),
    "indicator",
    sprintf("Output source profile `%s`", source)
  )
  indicators <- value$indicator
  if (!length(indicators) || any(!nzchar(indicators)) ||
      anyDuplicated(indicators) || any(!grepl("^[a-z][a-z0-9_.]*$", indicators))) {
    stop(sprintf("Output source profile `%s` is invalid.", source), call. = FALSE)
  }
  indicators
}

wlv_native_output_indicators <- function(
    root,
    catalog,
    method,
    aggregation_registry = NULL) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  wlv_catalog_assert(catalog)
  method <- wlv_native_output_identifier(method, "method")
  record <- wlv_catalog_method(catalog, method)
  source <- as.character(record$source[[1L]])
  mapping <- wlv_native_output_profile_map(root)
  selected <- mapping[mapping$method == method, , drop = FALSE]
  if (nrow(selected) != 1L) {
    stop(sprintf("Method `%s` requires exactly one output profile.", method), call. = FALSE)
  }
  profiles <- wlv_native_output_profiles(root)
  profile <- profiles[
    profiles$profile == selected$profile[[1L]],
    ,
    drop = FALSE
  ]
  if (nrow(profile) != 1L || !identical(profile$source[[1L]], source)) {
    stop(sprintf("Output profile source mismatch for method `%s`.", method), call. = FALSE)
  }
  base <- wlv_native_output_source_indicators(root, source)
  overrides <- wlv_native_output_overrides(root, profiles)
  overrides <- overrides[
    overrides$profile == profile$profile[[1L]],
    ,
    drop = FALSE
  ]
  if (any(!overrides$indicator %in% base) ||
      any(overrides$position > length(base))) {
    stop(
      sprintf("Output profile `%s` has an invalid ordered override.", profile$profile[[1L]]),
      call. = FALSE
    )
  }
  indicators <- rep(NA_character_, length(base))
  if (nrow(overrides)) {
    indicators[overrides$position] <- overrides$indicator
  }
  retained <- base[!base %in% overrides$indicator]
  indicators[is.na(indicators)] <- retained

  source_record <- wlv_catalog_source(catalog, source)
  unit_contract <- wlv_catalog_unit_contract(
    catalog,
    as.character(source_record$unit_contract[[1L]])
  )
  if (!setequal(indicators, as.character(unit_contract$units$indicator))) {
    stop(
      sprintf("Output profile for `%s` differs from its unit contract.", method),
      call. = FALSE
    )
  }
  if (!is.null(aggregation_registry)) {
    wlv_validate_aggregation_registry(aggregation_registry)
    aggregation_indicators <- unique(aggregation_registry$rows$indicator)
    if (!setequal(indicators, aggregation_indicators)) {
      stop(
        sprintf("Output and aggregation profiles disagree for `%s`.", method),
        call. = FALSE
      )
    }
  }
  as.character(indicators)
}

wlv_validate_native_output_profiles <- function(root, catalog) {
  methods <- wlv_catalog_method_table(catalog)
  executable <- methods$can_calculate | methods$can_recalculate
  methods <- methods[executable, , drop = FALSE]
  mapping <- wlv_native_output_profile_map(root)
  missing <- setdiff(methods$method, mapping$method)
  extra <- setdiff(mapping$method, methods$method)
  if (length(missing) || length(extra)) {
    stop(
      sprintf(
        "Output profile coverage is invalid (missing=%s; extra=%s).",
        paste(missing, collapse = ","),
        paste(extra, collapse = ",")
      ),
      call. = FALSE
    )
  }
  result <- lapply(methods$method, function(method) {
    registry <- wlv_native_aggregation_registry(root, catalog, method)
    wlv_native_output_indicators(root, catalog, method, registry)
  })
  names(result) <- methods$method
  result
}
