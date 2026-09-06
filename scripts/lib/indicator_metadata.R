# Canonical storage and display metadata for published indicators.

wlv_indicator_metadata_columns <- function() {
  c(
    "canonical_unit", "display_unit", "display_multiplier",
    "index_base_year", "index_storage_base"
  )
}

wlv_validate_unit_display_contract <- function(units, indicators = NULL) {
  required <- c(
    "indicator", "quantity_kind", "canonical_unit", "display_unit",
    "display_multiplier", "base_year", "index_base"
  )
  if (!is.data.frame(units) || any(!required %in% names(units)) || !nrow(units)) {
    stop("Unit display metadata requires a complete unit-contract table.",
      call. = FALSE
    )
  }
  if (
    anyNA(units[c("indicator", "quantity_kind", "canonical_unit", "display_unit")]) ||
      any(!nzchar(units$indicator)) || anyDuplicated(units$indicator) ||
      any(!nzchar(units$canonical_unit)) || any(!nzchar(units$display_unit))
  ) {
    stop("Unit display metadata contains invalid identifiers.", call. = FALSE)
  }
  multiplier <- suppressWarnings(as.numeric(units$display_multiplier))
  if (
    length(multiplier) != nrow(units) || anyNA(multiplier) ||
      any(!is.finite(multiplier)) || any(multiplier <= 0)
  ) {
    stop("Unit display multipliers must be finite and strictly positive.",
      call. = FALSE
    )
  }
  index <- units$quantity_kind == "index"
  base_year <- as.character(units$base_year)
  storage_base <- suppressWarnings(as.numeric(units$index_base))
  if (
    any(index & (is.na(base_year) | !grepl("^[0-9]{4}$", base_year))) ||
      any(index & (is.na(storage_base) | !is.finite(storage_base) |
        storage_base <= 0)) ||
      any(!index & !is.na(storage_base))
  ) {
    stop("Index display metadata disagrees with canonical storage metadata.",
      call. = FALSE
    )
  }
  if (!is.null(indicators)) {
    if (
      !is.character(indicators) || !length(indicators) || anyNA(indicators) ||
        any(!nzchar(indicators)) || anyDuplicated(indicators)
    ) {
      stop("`indicators` must contain unique non-empty identifiers.",
        call. = FALSE
      )
    }
    missing <- setdiff(indicators, units$indicator)
    if (length(missing)) {
      stop(
        sprintf(
          "Unit display metadata is missing indicator(s): %s.",
          paste(missing, collapse = ", ")
        ),
        call. = FALSE
      )
    }
  }
  invisible(units)
}

wlv_contract_indicator_metadata <- function(units, indicators = units$indicator) {
  wlv_validate_unit_display_contract(units, indicators)
  selected <- units[match(indicators, units$indicator), , drop = FALSE]
  index <- selected$quantity_kind == "index"
  data.frame(
    code = selected$indicator,
    canonical_unit = selected$canonical_unit,
    display_unit = selected$display_unit,
    display_multiplier = as.numeric(selected$display_multiplier),
    index_base_year = ifelse(index, as.character(selected$base_year), NA_character_),
    index_storage_base = ifelse(index, as.numeric(selected$index_base), NA_real_),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    row.names = selected$indicator
  )
}

wlv_complete_indicator_metadata <- function(
    metadata,
    units) {
  if (
    !is.data.frame(metadata) || !"code" %in% names(metadata) ||
      anyNA(metadata$code) || any(!nzchar(metadata$code)) ||
      anyDuplicated(metadata$code)
  ) {
    stop("Indicator metadata must contain unique non-empty `code` values.",
      call. = FALSE
    )
  }
  columns <- wlv_indicator_metadata_columns()
  projection <- wlv_contract_indicator_metadata(units, metadata$code)
  defaults <- list(
    canonical_unit = NA_character_,
    display_unit = NA_character_,
    display_multiplier = NA_real_,
    index_base_year = NA_character_,
    index_storage_base = NA_real_
  )
  for (column in columns) {
    if (!column %in% names(metadata)) {
      metadata[[column]] <- rep(defaults[[column]], nrow(metadata))
    }
    observed <- metadata[[column]]
    expected <- projection[[column]]
    differs <- !is.na(observed) & (
      is.na(expected) | (!is.na(expected) & observed != expected)
    )
    if (any(differs)) {
      stop(
        sprintf(
          "Indicator metadata column `%s` differs from the unit contract.",
          column
        ),
        call. = FALSE
      )
    }
    fill <- is.na(observed) & !is.na(expected)
    observed[fill] <- expected[fill]
    metadata[[column]] <- observed
  }

  if (anyNA(metadata$display_multiplier) ||
      any(!is.finite(metadata$display_multiplier)) ||
      any(metadata$display_multiplier <= 0)) {
    stop("Indicator display multipliers must be finite and strictly positive.",
      call. = FALSE
    )
  }
  row.names(metadata) <- metadata$code
  metadata
}
