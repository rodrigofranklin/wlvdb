wlv_row_constant_capital_stock <- function(
    current_stock,
    exchange_index,
    output_price_index,
    base_year = "2000",
    expected_zero_sectors = NULL,
    tolerance = 1e-10) {
  values <- list(
    current_stock = current_stock,
    exchange_index = exchange_index,
    output_price_index = output_price_index
  )
  valid_matrix <- vapply(
    values,
    function(value) is.matrix(value) && is.numeric(value),
    logical(1L)
  )
  if (!all(valid_matrix)) {
    stop(
      "ROW constant-capital inputs must be numeric year-by-sector matrices.",
      call. = FALSE
    )
  }

  reference_dimensions <- dim(current_stock)
  reference_dimnames <- dimnames(current_stock)
  conformable <- vapply(
    values[-1L],
    function(value) {
      identical(dim(value), reference_dimensions) &&
        identical(dimnames(value), reference_dimnames)
    },
    logical(1L)
  )
  valid_labels <-
    length(reference_dimnames) == 2L &&
    all(vapply(reference_dimnames, is.character, logical(1L))) &&
    all(vapply(reference_dimnames, function(value) {
      length(value) > 0L && !anyNA(value) && all(nzchar(value)) &&
        !anyDuplicated(value)
    }, logical(1L)))
  if (!all(conformable) || !valid_labels) {
    stop(
      paste0(
        "ROW constant-capital inputs must have identical dimensions and ",
        "unique year/sector labels."
      ),
      call. = FALSE
    )
  }

  if (
    length(base_year) != 1L || !is.character(base_year) ||
    is.na(base_year) || !nzchar(base_year) ||
    !base_year %in% rownames(current_stock)
  ) {
    stop("ROW constant capital requires its labelled base year.", call. = FALSE)
  }
  if (
    length(tolerance) != 1L || !is.numeric(tolerance) ||
    is.na(tolerance) || !is.finite(tolerance) || tolerance < 0
  ) {
    stop("`tolerance` must be one finite non-negative number.", call. = FALSE)
  }
  if (
    !is.null(expected_zero_sectors) &&
    (!is.character(expected_zero_sectors) || anyNA(expected_zero_sectors) ||
      any(!nzchar(expected_zero_sectors)) ||
      anyDuplicated(expected_zero_sectors) ||
      any(!expected_zero_sectors %in% colnames(current_stock)))
  ) {
    stop(
      "Expected ROW zero sectors must be unique labels present in the inputs.",
      call. = FALSE
    )
  }

  if (anyNA(current_stock) || any(!is.finite(current_stock))) {
    stop("ROW current capital stock must be finite.", call. = FALSE)
  }
  if (any(current_stock < 0)) {
    stop("ROW current capital stock must be non-negative.", call. = FALSE)
  }
  if (
    anyNA(exchange_index) || any(!is.finite(exchange_index)) ||
    anyNA(output_price_index) || any(!is.finite(output_price_index))
  ) {
    stop("ROW capital conversion indices must be finite.", call. = FALSE)
  }
  if (any(exchange_index <= 0) || any(output_price_index <= 0)) {
    stop("ROW capital conversion indices must be strictly positive.", call. = FALSE)
  }

  base_exchange <- exchange_index[base_year, , drop = TRUE]
  if (any(abs(base_exchange - 1) > tolerance)) {
    stop(
      sprintf(
        "ROW exchange-rate index must equal 1 in base year %s.",
        base_year
      ),
      call. = FALSE
    )
  }
  base_output_price <- output_price_index[base_year, , drop = TRUE]
  if (any(abs(base_output_price - 1) > tolerance)) {
    stop(
      sprintf(
        "ROW output-price index must equal 1 in base year %s.",
        base_year
      ),
      call. = FALSE
    )
  }

  zero_stock <- current_stock == 0
  if (!is.null(expected_zero_sectors)) {
    expected_zero <- matrix(
      FALSE,
      nrow = nrow(current_stock),
      ncol = ncol(current_stock),
      dimnames = dimnames(current_stock)
    )
    expected_zero[, expected_zero_sectors] <- TRUE
    if (!identical(zero_stock, expected_zero)) {
      observed <- apply(zero_stock, 1L, function(value) {
        paste(colnames(current_stock)[value], collapse = ",")
      })
      stop(
        sprintf(
          paste0(
            "ROW current-capital zero pattern differs from the pinned sectors ",
            "(%s); observed by year: %s."
          ),
          paste(expected_zero_sectors, collapse = ","),
          paste(paste(rownames(current_stock), observed, sep = "="), collapse = "; ")
        ),
        call. = FALSE
      )
    }
  }

  result <- current_stock * exchange_index / output_price_index
  if (anyNA(result) || any(!is.finite(result))) {
    stop("ROW constant capital stock is non-finite.", call. = FALSE)
  }
  if (any(result < 0)) {
    stop("ROW constant capital stock must be non-negative.", call. = FALSE)
  }
  if (any(result[zero_stock] != 0)) {
    stop("ROW constant capital stock did not preserve structural zeroes.", call. = FALSE)
  }

  base_current <- current_stock[base_year, , drop = TRUE]
  base_constant <- result[base_year, , drop = TRUE]
  base_difference <- abs(base_constant - base_current)
  base_scale <- pmax(1, abs(base_current))
  if (any(base_difference > tolerance * base_scale)) {
    stop(
      sprintf(
        "ROW constant capital stock differs from current capital in base year %s.",
        base_year
      ),
      call. = FALSE
    )
  }

  zero_positions <- which(zero_stock, arr.ind = TRUE)
  zeroes <- data.frame(
    year = rownames(current_stock)[zero_positions[, 1L]],
    country = rep("ROW", nrow(zero_positions)),
    sector = colnames(current_stock)[zero_positions[, 2L]],
    value = if (nrow(zero_positions)) current_stock[zero_positions] else numeric(),
    policy_id = rep("wiodr16_row_constant_capital_v1", nrow(zero_positions)),
    action = rep("preserve_zero_row_constant_capital", nrow(zero_positions)),
    stringsAsFactors = FALSE
  )
  attr(result, "wlv.row_constant_capital_zeroes") <- zeroes
  result
}
