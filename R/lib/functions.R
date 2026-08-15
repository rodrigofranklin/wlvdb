newDim <- function(x, dimensions) {
  # return a variable with changed dimensions
  dim(x) <- dimensions
  return(x)
}

wlv_euklems_country_codes <- function(countries) {
  if (
    !is.character(countries) ||
    !length(countries) ||
    anyNA(countries) ||
    any(!nzchar(countries))
  ) {
    stop("`countries` must contain non-empty ISO3 country codes.", call. = FALSE)
  }

  countrycode::countrycode(
    countries,
    origin = "iso3c",
    destination = "iso2c",
    custom_match = c(
      GBR = "UK",
      GRC = "EL",
      ROW = NA_character_
    )
  )
}

wlv_wiodr13_euklems_country_codes <- function(countries) {
  wlv_euklems_country_codes(countries)
}

wlv_wiodr16_euklems_country_codes <- function(countries) {
  wlv_euklems_country_codes(countries)
}

wlv_wiodr16_gfcf_columns <- function(column_labels, countries) {
  if (
    !is.character(column_labels) ||
    anyNA(column_labels) ||
    any(!nzchar(column_labels))
  ) {
    stop("`column_labels` must contain non-empty labels.", call. = FALSE)
  }
  if (
    !is.character(countries) ||
    !length(countries) ||
    anyNA(countries) ||
    any(!nzchar(countries)) ||
    anyDuplicated(countries)
  ) {
    stop("`countries` must contain unique, non-empty codes.", call. = FALSE)
  }

  expected <- paste0(countries, ".c60")
  counts <- vapply(expected, function(label) sum(column_labels == label), integer(1))
  if (any(counts != 1L)) {
    invalid <- sprintf("%s (%s found)", expected[counts != 1L], counts[counts != 1L])
    stop(
      sprintf(
        paste0(
          "WIOD16 requires exactly one GFCF column `<country>.c60` per country; ",
          "invalid: %s."
        ),
        paste(invalid, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  match(expected, column_labels)
}

wlv_read_wiodr16_china_hours_per_worker <- function(
    path,
    expected_codes,
    expected_names,
    expected_years = as.character(2000:2014)) {
  canonical_years <- as.character(2000:2014)
  if (!identical(as.character(expected_years), canonical_years)) {
    stop(
      "WIOD16 China hours require the complete ordered period 2000-2014.",
      call. = FALSE
    )
  }
  if (
    !is.character(expected_codes) ||
    length(expected_codes) != 56L ||
    anyNA(expected_codes) ||
    any(!nzchar(expected_codes)) ||
    anyDuplicated(expected_codes)
  ) {
    stop(
      "WIOD16 China hours require 56 unique, non-empty sector codes.",
      call. = FALSE
    )
  }
  if (
    !is.character(expected_names) ||
    length(expected_names) != length(expected_codes) ||
    anyNA(expected_names) ||
    any(!nzchar(trimws(expected_names)))
  ) {
    stop(
      "WIOD16 China hours require one non-empty name per sector code.",
      call. = FALSE
    )
  }
  if (!file.exists(path)) {
    stop(sprintf("Missing WIOD16 China hours file: %s", path), call. = FALSE)
  }

  value <- tryCatch(
    utils::read.csv2(
      path,
      stringsAsFactors = FALSE,
      check.names = FALSE
    ),
    error = function(error) {
      stop(
        sprintf(
          "Cannot read WIOD16 China hours file `%s`: %s",
          path,
          conditionMessage(error)
        ),
        call. = FALSE
      )
    }
  )
  expected_columns <- c("setor", "code", canonical_years)
  if (!identical(names(value), expected_columns)) {
    stop(
      sprintf(
        "WIOD16 China hours columns must be exactly: %s.",
        paste(expected_columns, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (!identical(as.character(value$code), expected_codes)) {
    stop(
      "WIOD16 China hours sector codes or their order do not match the method.",
      call. = FALSE
    )
  }
  if (!identical(trimws(as.character(value$setor)), trimws(expected_names))) {
    stop(
      "WIOD16 China hours sector names or their order do not match the method.",
      call. = FALSE
    )
  }
  if (!all(vapply(value[canonical_years], is.numeric, logical(1)))) {
    stop("WIOD16 China hours contain a non-numeric year column.", call. = FALSE)
  }

  hours <- as.matrix(value[canonical_years])
  if (anyNA(hours) || any(!is.finite(hours))) {
    stop("WIOD16 China hours must all be finite.", call. = FALSE)
  }
  # Coefficients are thousands of annual hours per person. The upper bound is
  # the number of hours in a leap year, expressed in the same unit.
  if (any(hours < 0 | hours > 8.784)) {
    stop(
      "WIOD16 China hours must be between 0 and 8.784 thousand hours per person.",
      call. = FALSE
    )
  }

  dimnames(hours) <- list(expected_codes, canonical_years)
  t(hours)
}

wlv_distribute_capital_stock <- function(
    weights,
    capital_stock,
    fallback_weights = NULL,
    tolerance = 1e-10) {
  if (
    !is.matrix(weights) || !is.numeric(weights) || anyNA(weights) ||
    any(!is.finite(weights))
  ) {
    stop("`weights` must be a finite numeric matrix.", call. = FALSE)
  }
  if (
    !is.numeric(capital_stock) ||
    length(capital_stock) != ncol(weights) ||
    anyNA(capital_stock) ||
    any(!is.finite(capital_stock))
  ) {
    stop(
      "`capital_stock` must contain one finite number per weight column.",
      call. = FALSE
    )
  }
  if (
    length(tolerance) != 1L || !is.numeric(tolerance) || is.na(tolerance) ||
    !is.finite(tolerance) || tolerance < 0
  ) {
    stop("`tolerance` must be one finite non-negative number.", call. = FALSE)
  }

  totals <- colSums(weights)
  invalid_columns <- totals == 0
  fallback_columns <- which(invalid_columns & capital_stock != 0)
  if (length(fallback_columns)) {
    if (
      is.null(fallback_weights) || !is.matrix(fallback_weights) ||
      !is.numeric(fallback_weights) ||
      !identical(dim(fallback_weights), dim(weights)) ||
      anyNA(fallback_weights) || any(!is.finite(fallback_weights)) ||
      any(fallback_weights < 0)
    ) {
      stop(
        paste0(
          "Positive or negative capital stock without primary weights requires ",
          "a conformable finite non-negative fallback matrix."
        ),
        call. = FALSE
      )
    }
    fallback_totals <- colSums(fallback_weights)
    unresolved <- fallback_columns[fallback_totals[fallback_columns] <= 0]
    if (length(unresolved)) {
      stop(
        sprintf(
          "Capital stock has no primary or fallback weights in column(s): %s.",
          paste(unresolved, collapse = ", ")
        ),
        call. = FALSE
      )
    }
    weights[, fallback_columns] <- fallback_weights[, fallback_columns, drop = FALSE]
    totals[fallback_columns] <- fallback_totals[fallback_columns]
  }
  distribution <- sweep(weights, 2L, totals, "/")
  zero_stock_columns <- totals == 0 & capital_stock == 0
  distribution[, zero_stock_columns] <- 0
  if (any(!is.finite(distribution))) {
    stop("Capital-stock weights produced a non-finite distribution.", call. = FALSE)
  }
  result <- sweep(distribution, 2L, capital_stock, "*")
  residual <- abs(colSums(result) - capital_stock)
  if (any(residual > tolerance * pmax(1, abs(capital_stock)))) {
    stop("Capital-stock allocation does not conserve column totals.", call. = FALSE)
  }
  attr(result, "wlv.fallback_columns") <- fallback_columns
  result
}

wlv_add_synthetic_depreciation_component <- function(
    aggregate_rate,
    component_rate,
    component_stock,
    aggregate_stock,
    direct_rate_provided) {
  numeric_values <- list(
    aggregate_rate = aggregate_rate,
    component_rate = component_rate,
    component_stock = component_stock,
    aggregate_stock = aggregate_stock
  )
  dimensions <- lapply(numeric_values, dim)
  if (
    any(!vapply(numeric_values, is.numeric, logical(1))) ||
    any(vapply(dimensions, is.null, logical(1))) ||
    !all(vapply(dimensions[-1L], identical, logical(1), dimensions[[1L]])) ||
    !is.logical(direct_rate_provided) ||
    !identical(dim(direct_rate_provided), dimensions[[1L]]) ||
    anyNA(direct_rate_provided)
  ) {
    stop(
      paste0(
        "Depreciation rates, stocks and the direct-rate mask must be ",
        "conformable numeric/logical matrices."
      ),
      call. = FALSE
    )
  }

  invalid_input <- vapply(
    numeric_values,
    function(value) anyNA(value) || any(!is.finite(value)),
    logical(1L)
  )
  if (any(invalid_input)) {
    stop("Depreciation rates and stocks must be finite.", call. = FALSE)
  }
  zero_stock <- aggregate_stock == 0
  invalid_zero <- zero_stock & component_stock != 0
  if (any(invalid_zero)) {
    stop(
      "A positive depreciation component cannot have zero aggregate stock.",
      call. = FALSE
    )
  }
  weighted_component <- component_rate * component_stock
  weighted_component[!zero_stock] <-
    weighted_component[!zero_stock] / aggregate_stock[!zero_stock]
  weighted_component[zero_stock] <- 0
  synthesize <- !direct_rate_provided
  aggregate_rate[synthesize] <-
    aggregate_rate[synthesize] + weighted_component[synthesize]
  aggregate_rate
}

wlv_sum_input_flows <- function(
    intermediate_consumption,
    depreciation,
    structural_missing = NULL) {
  if (
    !is.numeric(intermediate_consumption) || !is.numeric(depreciation) ||
    !identical(dim(intermediate_consumption), dim(depreciation))
  ) {
    stop("Input-flow arrays must be conformable numeric values.", call. = FALSE)
  }
  if (anyNA(intermediate_consumption) || any(!is.finite(intermediate_consumption))) {
    stop("Intermediate consumption must be fully finite.", call. = FALSE)
  }
  if (any(is.nan(depreciation)) || any(is.infinite(depreciation))) {
    stop("Depreciation contains NaN or infinite values.", call. = FALSE)
  }
  if (is.null(structural_missing)) {
    structural_missing <- rep(FALSE, length(depreciation))
    dim(structural_missing) <- dim(depreciation)
  }
  if (
    !is.logical(structural_missing) || anyNA(structural_missing) ||
    !identical(dim(structural_missing), dim(depreciation))
  ) {
    stop("`structural_missing` must be a conformable logical mask.", call. = FALSE)
  }
  unexpected <- is.na(depreciation) & !structural_missing
  if (any(unexpected)) {
    stop("Depreciation contains an undeclared missing value.", call. = FALSE)
  }
  if (any(structural_missing & !is.na(depreciation))) {
    stop("The depreciation structural-missing mask is not exact.", call. = FALSE)
  }
  depreciation[structural_missing] <- 0
  intermediate_consumption + depreciation
}

cnames <- function(a,b) {
  #match column named "names"  from a and b
  match(a$names,b$names)
}

read_fst_array <- function(file_name) {
  
  ft <- fst::read_fst(file_name)  # single column data.frame
  metaf <- paste0(file_name, ".meta")
  if(file.exists(metaf)) {
  meta_data <- readRDS(metaf)  # retrieve dim
  
  m <- ft[[1]]  
  attr(m, "dim") <- meta_data$dim
  dimensiones <- length(meta_data$dim)
  meta_data <- meta_data[2:(dimensiones+1)]
  # lapply(1:dimensiones,function(d,f) {
  #   dimnames(f)[[d]] <- meta_data[[d]]
  # })
  dimnames(m) <- meta_data
  
  m} else {
    ft
  }
}

write_fst_array <- function(m, file_name) {
  
  # store and remove dims attribute
  dim <- attr(m, "dim")
  
  meta_data <- list(
    dim = dim
  )
  for (i in 1:length(dim)){
    meta_data[[i+1]] <- dimnames(m)[[i]]
  }
  
  # serialize tale and meta data
  attr(m, "dim") <- NULL
  fst::write_fst(data.frame(Data = m), file_name)
  saveRDS(meta_data, paste0(file_name, ".meta"))
}

convert_array_RDS <- function(nomebase) {
  nrds <- paste0(nomebase,".rds")
  print(paste("Converting",nrds))
  t <- readRDS(nrds)
  if(class(t) == "array"){
    print("This is an array object")
  write_fst_array(t,paste0(nomebase,".fst"))
  } else {
    write_fst(t,paste0(nomebase,".fst"))
  }
  rm(t)
  gc()
}
