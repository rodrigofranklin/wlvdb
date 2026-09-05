# Deterministic symbolic dimensions used to validate unit algebra before a
# calculation module is evaluated. Values are immutable by convention: every
# operation returns a new canonical object.

wlv_unit_dimension_bases <- function() {
  c(
  "USD", "LCU", "person", "hour", "labour_value"
)
}
wlv_unit_price_bases <- function() {
  c("not_applicable", "current", "constant")
}
wlv_unit_kinds <- function() {
  c("quantity", "ratio", "index")
}

wlv_unit_canonical_exponents <- function(exponents = NULL) {
  result <- stats::setNames(
    integer(length(wlv_unit_dimension_bases())),
    wlv_unit_dimension_bases()
  )
  if (is.null(exponents) || !length(exponents)) {
    return(result)
  }
  invalid_message <- paste0(
    "`exponents` must be a uniquely named integer vector using only: ",
    paste(wlv_unit_dimension_bases(), collapse = ", "), "."
  )
  if (
    !is.numeric(exponents) || is.null(names(exponents)) ||
      anyNA(exponents) || any(!is.finite(exponents)) ||
      anyNA(names(exponents)) || any(!nzchar(names(exponents))) ||
      anyDuplicated(names(exponents)) ||
      any(!names(exponents) %in% wlv_unit_dimension_bases())
  ) {
    stop(invalid_message, call. = FALSE)
  }
  integer_exponents <- suppressWarnings(as.integer(exponents))
  if (anyNA(integer_exponents) || any(exponents != integer_exponents)) {
    stop(invalid_message, call. = FALSE)
  }
  result[names(exponents)] <- integer_exponents
  result
}

wlv_unit_base_year <- function(base_year, required = FALSE) {
  missing <-
    is.null(base_year) || length(base_year) == 0L ||
    (length(base_year) == 1L && is.na(base_year))
  if (missing) {
    if (required) {
      stop("A four-digit `base_year` is required.", call. = FALSE)
    }
    return(NA_integer_)
  }
  text <- as.character(base_year)
  if (
    length(text) != 1L || is.na(text) ||
      !grepl("^[0-9]{4}$", text)
  ) {
    stop("`base_year` must be one four-digit year or NA.", call. = FALSE)
  }
  as.integer(text)
}

wlv_unit_dimension <- function(
    exponents = NULL,
    currency_scope = NULL,
    price_basis = NULL,
    base_year = NA_integer_,
    index_base = NA_real_,
    kind = NULL) {
  exponents <- wlv_unit_canonical_exponents(exponents)
  dimensionless <- all(exponents == 0L)
  has_usd <- exponents[["USD"]] != 0L
  has_lcu <- exponents[["LCU"]] != 0L
  has_currency <- has_usd || has_lcu

  if (is.null(kind)) {
    kind <- if (dimensionless) "ratio" else "quantity"
  }
  if (
    !is.character(kind) || length(kind) != 1L || is.na(kind) ||
      !kind %in% wlv_unit_kinds()
  ) {
    stop(
      sprintf("`kind` must be one of: %s.", paste(wlv_unit_kinds(), collapse = ", ")),
      call. = FALSE
    )
  }
  if (dimensionless && identical(kind, "quantity")) {
    stop("A zero-exponent unit must be a ratio or an index.", call. = FALSE)
  }
  if (!dimensionless && !identical(kind, "quantity")) {
    stop("Ratios and indices must have zero base-dimension exponents.", call. = FALSE)
  }

  if (is.null(currency_scope)) {
    currency_scope <- if (has_lcu) {
      stop("LCU dimensions require an explicit `currency_scope`.", call. = FALSE)
    } else if (has_usd) {
      "global"
    } else {
      "none"
    }
  }
  if (
    !is.character(currency_scope) || length(currency_scope) != 1L ||
      is.na(currency_scope) || !nzchar(currency_scope) ||
      !grepl("^[A-Za-z][A-Za-z0-9_-]*$", currency_scope)
  ) {
    stop("`currency_scope` must be one non-empty identifier.", call. = FALSE)
  }
  if (has_lcu && currency_scope %in% c("none", "global")) {
    stop(
      "LCU dimensions require a country-specific currency scope.",
      call. = FALSE
    )
  }
  if (!has_lcu && has_usd && !identical(currency_scope, "global")) {
    stop("USD-only dimensions require `currency_scope = \"global\"`.", call. = FALSE)
  }
  if (!has_currency && !identical(currency_scope, "none")) {
    stop("Non-currency dimensions require `currency_scope = \"none\"`.", call. = FALSE)
  }

  if (is.null(price_basis)) {
    price_basis <- if (has_currency) "current" else "not_applicable"
  }
  if (
    !is.character(price_basis) || length(price_basis) != 1L ||
      is.na(price_basis) || !price_basis %in% wlv_unit_price_bases()
  ) {
    stop(
      sprintf(
        "`price_basis` must be one of: %s.",
        paste(wlv_unit_price_bases(), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (has_currency && identical(price_basis, "not_applicable")) {
    stop("Currency dimensions require a current or constant price basis.", call. = FALSE)
  }
  if (!has_currency && !identical(price_basis, "not_applicable")) {
    stop("Only currency dimensions can declare a current or constant price basis.", call. = FALSE)
  }

  requires_base_year <-
    identical(price_basis, "constant") || identical(kind, "index")
  base_year <- wlv_unit_base_year(base_year, required = requires_base_year)
  if (identical(price_basis, "current") && !is.na(base_year)) {
    stop("Current-price units cannot declare a `base_year`.", call. = FALSE)
  }
  if (
    identical(price_basis, "not_applicable") &&
      !identical(kind, "index") && !is.na(base_year)
  ) {
    stop("Only constant-price units and indices can declare a `base_year`.", call. = FALSE)
  }

  if (identical(kind, "index")) {
    if (
      !is.numeric(index_base) || length(index_base) != 1L ||
        is.na(index_base) || !is.finite(index_base) || index_base <= 0
    ) {
      stop("Index units require one positive finite `index_base`.", call. = FALSE)
    }
    index_base <- as.numeric(index_base)
  } else {
    if (!(length(index_base) == 1L && is.na(index_base))) {
      stop("Only index units can declare an `index_base`.", call. = FALSE)
    }
    index_base <- NA_real_
  }

  structure(
    list(
      exponents = exponents,
      currency_scope = currency_scope,
      price_basis = price_basis,
      base_year = base_year,
      index_base = index_base,
      kind = kind
    ),
    class = "wlv_unit_dimension"
  )
}

wlv_unit_assert <- function(unit) {
  if (
    !inherits(unit, "wlv_unit_dimension") || !is.list(unit) ||
      !identical(
        names(unit),
        c(
          "exponents", "currency_scope", "price_basis", "base_year",
          "index_base", "kind"
        )
      )
  ) {
    stop("Expected a canonical `wlv_unit_dimension` object.", call. = FALSE)
  }
  canonical <- wlv_unit_dimension(
    exponents = unit$exponents,
    currency_scope = unit$currency_scope,
    price_basis = unit$price_basis,
    base_year = unit$base_year,
    index_base = unit$index_base,
    kind = unit$kind
  )
  if (!identical(unclass(unit), unclass(canonical))) {
    stop("Unit dimension is not in canonical form.", call. = FALSE)
  }
  invisible(unit)
}

wlv_unit_base <- function(
    base,
    currency_scope = NULL,
    price_basis = NULL,
    base_year = NA_integer_) {
  if (
    !is.character(base) || length(base) != 1L || is.na(base) ||
      !base %in% wlv_unit_dimension_bases()
  ) {
    stop(
      sprintf(
        "`base` must be one of: %s.",
        paste(wlv_unit_dimension_bases(), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  wlv_unit_dimension(
    exponents = stats::setNames(1L, base),
    currency_scope = currency_scope,
    price_basis = price_basis,
    base_year = base_year
  )
}

wlv_unit_dimensionless <- function() {
  wlv_unit_dimension(kind = "ratio")
}

wlv_unit_index <- function(base_year, index_base = 1) {
  wlv_unit_dimension(
    kind = "index",
    base_year = base_year,
    index_base = index_base
  )
}

wlv_unit_is_dimensionless <- function(unit) {
  wlv_unit_assert(unit)
  all(unit$exponents == 0L)
}

wlv_unit_signature <- function(unit) {
  wlv_unit_assert(unit)
  positions <- which(unit$exponents != 0L)
  dimension <- if (!length(positions)) {
    unit$kind
  } else {
    paste(
      vapply(
        positions,
        function(position) {
          exponent <- unit$exponents[[position]]
          if (exponent == 1L) {
            names(unit$exponents)[[position]]
          } else {
            paste0(names(unit$exponents)[[position]], "^", exponent)
          }
        },
        character(1L)
      ),
      collapse = "*"
    )
  }
  qualifiers <- character()
  if (unit$currency_scope != "none") {
    qualifiers <- c(qualifiers, paste0("currency_scope=", unit$currency_scope))
  }
  if (unit$price_basis != "not_applicable") {
    qualifiers <- c(qualifiers, paste0("price_basis=", unit$price_basis))
  }
  if (!is.na(unit$base_year)) {
    qualifiers <- c(qualifiers, paste0("base_year=", unit$base_year))
  }
  if (!is.na(unit$index_base)) {
    qualifiers <- c(
      qualifiers,
      paste0(
        "index_base=",
        format(unit$index_base, scientific = FALSE, trim = TRUE, digits = 17L)
      )
    )
  }
  if (length(qualifiers)) {
    paste0(dimension, " [", paste(qualifiers, collapse = "; "), "]")
  } else {
    dimension
  }
}

format.wlv_unit_dimension <- function(x, ...) {
  wlv_unit_signature(x)
}

print.wlv_unit_dimension <- function(x, ...) {
  cat("<wlv_unit_dimension> ", format(x), "\n", sep = "")
  invisible(x)
}

wlv_unit_equal <- function(left, right) {
  wlv_unit_assert(left)
  wlv_unit_assert(right)
  identical(unclass(left), unclass(right))
}

wlv_unit_assert_addable <- function(left, right, operation = "sum") {
  wlv_unit_assert(left)
  wlv_unit_assert(right)
  if (
    !is.character(operation) || length(operation) != 1L ||
      is.na(operation) || !nzchar(operation)
  ) {
    stop("`operation` must be one non-empty string.", call. = FALSE)
  }
  if (!wlv_unit_equal(left, right)) {
    stop(
      sprintf(
        "Cannot %s non-identical units: `%s` and `%s`.",
        operation,
        wlv_unit_signature(left),
        wlv_unit_signature(right)
      ),
      call. = FALSE
    )
  }
  invisible(left)
}

wlv_unit_common_price <- function(left, right, operator) {
  left_currency <- any(left$exponents[c("USD", "LCU")] != 0L)
  right_currency <- any(right$exponents[c("USD", "LCU")] != 0L)
  if (left_currency && right_currency) {
    same_price <-
      identical(left$price_basis, right$price_basis) &&
      identical(left$base_year, right$base_year)
    if (!same_price) {
      stop(
        sprintf(
          "Cannot %s units with incompatible price qualifiers: `%s` and `%s`.",
          operator,
          wlv_unit_signature(left),
          wlv_unit_signature(right)
        ),
        call. = FALSE
      )
    }
    return(list(price_basis = left$price_basis, base_year = left$base_year))
  }
  source <- if (left_currency) left else if (right_currency) right else NULL
  if (is.null(source)) {
    list(price_basis = "not_applicable", base_year = NA_integer_)
  } else {
    list(price_basis = source$price_basis, base_year = source$base_year)
  }
}

wlv_unit_common_lcu_scope <- function(left, right, operator) {
  left_lcu <- left$exponents[["LCU"]] != 0L
  right_lcu <- right$exponents[["LCU"]] != 0L
  if (
    left_lcu && right_lcu &&
      !identical(left$currency_scope, right$currency_scope)
  ) {
    stop(
      sprintf(
        "Cannot %s LCU units with different currency scopes: `%s` and `%s`.",
        operator,
        left$currency_scope,
        right$currency_scope
      ),
      call. = FALSE
    )
  }
  if (left_lcu) left$currency_scope else if (right_lcu) right$currency_scope else NULL
}

wlv_unit_arithmetic <- function(left, right, sign, operator) {
  wlv_unit_assert(left)
  wlv_unit_assert(right)
  if (!sign %in% c(-1L, 1L)) {
    stop("Internal unit arithmetic sign is invalid.", call. = FALSE)
  }
  price <- wlv_unit_common_price(left, right, operator)
  lcu_scope <- wlv_unit_common_lcu_scope(left, right, operator)

  both_indices <- identical(left$kind, "index") && identical(right$kind, "index")
  if (both_indices) {
    same_index <-
      identical(left$base_year, right$base_year) &&
      identical(left$index_base, right$index_base)
    if (!same_index) {
      stop(
        sprintf(
          "Cannot %s indices with different base qualifiers: `%s` and `%s`.",
          operator,
          wlv_unit_signature(left),
          wlv_unit_signature(right)
        ),
        call. = FALSE
      )
    }
    if (sign == 1L) {
      stop("Multiplying two index units requires an explicit output contract.", call. = FALSE)
    }
  }

  exponents <- left$exponents + sign * right$exponents
  has_usd <- exponents[["USD"]] != 0L
  has_lcu <- exponents[["LCU"]] != 0L
  has_currency <- has_usd || has_lcu
  currency_scope <- if (has_lcu) {
    lcu_scope
  } else if (has_usd) {
    "global"
  } else {
    "none"
  }

  if (!has_currency) {
    price <- list(price_basis = "not_applicable", base_year = NA_integer_)
  }

  dimensionless <- all(exponents == 0L)
  one_index <- xor(identical(left$kind, "index"), identical(right$kind, "index"))
  retain_index <- dimensionless && one_index && (
    sign == 1L || identical(left$kind, "index")
  )
  kind <- if (!dimensionless) {
    "quantity"
  } else if (retain_index) {
    "index"
  } else {
    "ratio"
  }
  index_source <- if (identical(left$kind, "index")) left else right

  wlv_unit_dimension(
    exponents = exponents,
    currency_scope = currency_scope,
    price_basis = price$price_basis,
    base_year = if (identical(kind, "index")) {
      index_source$base_year
    } else {
      price$base_year
    },
    index_base = if (identical(kind, "index")) {
      index_source$index_base
    } else {
      NA_real_
    },
    kind = kind
  )
}

wlv_unit_multiply <- function(left, right) {
  wlv_unit_arithmetic(left, right, sign = 1L, operator = "multiply")
}

wlv_unit_divide <- function(numerator, denominator) {
  wlv_unit_arithmetic(
    numerator,
    denominator,
    sign = -1L,
    operator = "divide"
  )
}

wlv_unit_ratio <- function(numerator, denominator) {
  wlv_unit_divide(numerator, denominator)
}

wlv_unit_rebase <- function(unit, base_year, index_base = unit$index_base) {
  wlv_unit_assert(unit)
  if (!identical(unit$kind, "index")) {
    stop("Only index units can be rebased.", call. = FALSE)
  }
  wlv_unit_index(base_year = base_year, index_base = index_base)
}

wlv_unit_rebase_index <- function(unit, base_year, index_base = unit$index_base) {
  wlv_unit_rebase(unit, base_year, index_base = index_base)
}

wlv_unit_assert_country_aggregation <- function(unit, countries) {
  wlv_unit_assert(unit)
  if (
    !is.character(countries) || !length(countries) || anyNA(countries) ||
      any(!nzchar(countries))
  ) {
    stop("`countries` must contain non-empty country identifiers.", call. = FALSE)
  }
  countries <- unique(countries)
  if (unit$exponents[["LCU"]] != 0L) {
    if (length(countries) > 1L) {
      stop(
        paste0(
          "Cannot aggregate LCU units across countries; convert them to a ",
          "common currency first."
        ),
        call. = FALSE
      )
    }
    if (
      !identical(unit$currency_scope, "country") &&
        !identical(unit$currency_scope, countries[[1L]])
    ) {
      stop(
        sprintf(
          "LCU currency scope `%s` does not match aggregation country `%s`.",
          unit$currency_scope,
          countries[[1L]]
        ),
        call. = FALSE
      )
    }
  }
  invisible(unit)
}

wlv_unit_assert_aggregable <- function(unit, countries) {
  wlv_unit_assert_country_aggregation(unit, countries)
}

wlv_unit_contract_field <- function(row, name) {
  value <- row[[name]][[1L]]
  if (length(value) != 1L || is.na(value)) "" else as.character(value)
}

wlv_unit_contract_number <- function(row, name) {
  value <- row[[name]][[1L]]
  if (length(value) != 1L || is.na(value) || !nzchar(as.character(value))) {
    return(NA_real_)
  }
  number <- suppressWarnings(as.numeric(value))
  if (is.na(number) || !is.finite(number)) {
    stop(sprintf("Unit contract `%s` must be numeric or empty.", name),
      call. = FALSE
    )
  }
  number
}

wlv_unit_dimension_from_contract <- function(row) {
  required <- c(
    "indicator", "quantity_kind", "canonical_unit", "currency", "price_basis",
    "base_year", "index_base"
  )
  if (!is.data.frame(row) || nrow(row) != 1L ||
      any(!required %in% names(row))) {
    stop("A unit dimension requires exactly one complete contract row.",
      call. = FALSE
    )
  }
  indicator <- wlv_unit_contract_field(row, "indicator")
  quantity_kind <- wlv_unit_contract_field(row, "quantity_kind")
  canonical_unit <- wlv_unit_contract_field(row, "canonical_unit")
  currency <- wlv_unit_contract_field(row, "currency")
  price_basis <- wlv_unit_contract_field(row, "price_basis")
  base_year <- wlv_unit_contract_field(row, "base_year")
  if (!nzchar(base_year)) {
    base_year <- NA_integer_
  }
  index_base <- wlv_unit_contract_number(row, "index_base")
  expected_currency <- switch(
    canonical_unit,
    usd = "usd",
    local_currency = "local_currency",
    local_currency_per_usd = "local_currency",
    abstract_labour_hour_per_usd = "mixed",
    person = "none",
    hour = "none",
    abstract_labour_hour = "none",
    abstract_labour_hour_per_person = "none",
    ratio = "none",
    multiplier = "none",
    index = "none",
    stop(
      sprintf(
        "Indicator `%s` has unsupported canonical unit `%s`.",
        indicator,
        canonical_unit
      ),
      call. = FALSE
    )
  )
  expected_kind <- switch(
    canonical_unit,
    usd = "monetary",
    local_currency = "monetary",
    local_currency_per_usd = "ratio",
    person = "count",
    hour = "duration",
    abstract_labour_hour = "labour_value",
    abstract_labour_hour_per_person = "ratio",
    abstract_labour_hour_per_usd = "ratio",
    ratio = "ratio",
    multiplier = "multiplier",
    index = "index"
  )
  if (!identical(quantity_kind, expected_kind)) {
    stop(
      sprintf(
        paste0(
          "Indicator `%s` canonical unit `%s` requires quantity_kind `%s`, ",
          "not `%s`."
        ),
        indicator,
        canonical_unit,
        expected_kind,
        quantity_kind
      ),
      call. = FALSE
    )
  }
  if (!identical(currency, expected_currency)) {
    stop(
      sprintf(
        paste0(
          "Indicator `%s` canonical unit `%s` requires currency `%s`, ",
          "not `%s`."
        ),
        indicator,
        canonical_unit,
        expected_currency,
        currency
      ),
      call. = FALSE
    )
  }

  unit <- switch(
    canonical_unit,
    usd = wlv_unit_base(
      "USD",
      price_basis = price_basis,
      base_year = base_year
    ),
    local_currency = wlv_unit_base(
      "LCU",
      currency_scope = "country",
      price_basis = price_basis,
      base_year = base_year
    ),
    local_currency_per_usd = wlv_unit_dimension(
      exponents = c(LCU = 1L, USD = -1L),
      currency_scope = "country",
      price_basis = price_basis,
      base_year = base_year
    ),
    person = wlv_unit_base("person"),
    hour = wlv_unit_base("hour"),
    abstract_labour_hour = wlv_unit_base("labour_value"),
    abstract_labour_hour_per_person = wlv_unit_divide(
      wlv_unit_base("labour_value"),
      wlv_unit_base("person")
    ),
    abstract_labour_hour_per_usd = wlv_unit_divide(
      wlv_unit_base("labour_value"),
      wlv_unit_base(
        "USD",
        price_basis = price_basis,
        base_year = base_year
      )
    ),
    ratio = wlv_unit_dimensionless(),
    multiplier = wlv_unit_dimensionless(),
    index = wlv_unit_index(base_year = base_year, index_base = index_base)
  )
  if (!identical(canonical_unit, "index") && !is.na(index_base)) {
    stop(
      sprintf("Indicator `%s` declares an index base for a non-index unit.", indicator),
      call. = FALSE
    )
  }
  unit
}

wlv_unit_dimension_registry <- function(units) {
  if (!is.data.frame(units) || !nrow(units) ||
      !"indicator" %in% names(units) || anyNA(units$indicator) ||
      any(!nzchar(units$indicator)) || anyDuplicated(units$indicator)) {
    stop("Unit contract indicators must be non-empty and unique.",
      call. = FALSE
    )
  }
  dimensions <- lapply(seq_len(nrow(units)), function(index) {
    wlv_unit_dimension_from_contract(units[index, , drop = FALSE])
  })
  names(dimensions) <- as.character(units$indicator)
  structure(dimensions, class = c("wlv_unit_dimension_registry", "list"))
}

wlv_unit_dimension_lookup <- function(registry, indicator) {
  if (!inherits(registry, "wlv_unit_dimension_registry") ||
      !is.list(registry) || is.null(names(registry)) ||
      anyDuplicated(names(registry))) {
    stop("Expected a canonical unit dimension registry.", call. = FALSE)
  }
  unit <- registry[[indicator]]
  if (is.null(unit)) {
    stop(
      sprintf("Aggregation dependency `%s` has no unit dimension.", indicator),
      call. = FALSE
    )
  }
  wlv_unit_assert(unit)
  unit
}

wlv_unit_assert_world_input <- function(unit, strategy, role) {
  tryCatch(
    wlv_unit_assert_country_aggregation(unit, c("country_a", "country_b")),
    error = function(error) {
      stop(
        sprintf(
          "%s `%s` is not dimensionally aggregable across countries: %s",
          strategy,
          role,
          conditionMessage(error)
        ),
        call. = FALSE
      )
    }
  )
}

wlv_validate_aggregation_dimensions <- function(
    units,
    aggregations,
    strict_cross_country = FALSE) {
  required <- c(
    "indicator", "level", "strategy", "numerator", "denominator", "weight"
  )
  if (!is.data.frame(aggregations) ||
      any(!required %in% names(aggregations))) {
    stop("Aggregation dimension validation requires complete typed rows.",
      call. = FALSE
    )
  }
  if (!is.logical(strict_cross_country) ||
      length(strict_cross_country) != 1L || is.na(strict_cross_country)) {
    stop("`strict_cross_country` must be one explicit flag.", call. = FALSE)
  }
  registry <- wlv_unit_dimension_registry(units)
  supported <- c(
    "sum", "mean", "ratio_of_sums", "weighted_mean", "invariant",
    "not_applicable", "formula"
  )
  for (index in seq_len(nrow(aggregations))) {
    row <- aggregations[index, , drop = FALSE]
    indicator <- wlv_unit_contract_field(row, "indicator")
    level <- wlv_unit_contract_field(row, "level")
    strategy <- wlv_unit_contract_field(row, "strategy")
    if (!strategy %in% supported) {
      stop(
        sprintf(
          "Aggregation `%s/%s` has unsupported dimensional strategy `%s`.",
          indicator,
          level,
          strategy
        ),
        call. = FALSE
      )
    }
    output <- wlv_unit_dimension_lookup(registry, indicator)
    tryCatch(
      {
        if (strict_cross_country && identical(level, "country_to_world") &&
            !identical(strategy, "not_applicable")) {
          wlv_unit_assert_world_input(output, strategy, "output")
        }
        if (identical(strategy, "ratio_of_sums")) {
          numerator_name <- wlv_unit_contract_field(row, "numerator")
          denominator_name <- wlv_unit_contract_field(row, "denominator")
          numerator <- wlv_unit_dimension_lookup(registry, numerator_name)
          denominator <- wlv_unit_dimension_lookup(registry, denominator_name)
          expected <- wlv_unit_divide(numerator, denominator)
          if (!wlv_unit_equal(output, expected)) {
            stop(
              sprintf(
                "declares `%s`, but numerator/denominator imply `%s`",
                wlv_unit_signature(output),
                wlv_unit_signature(expected)
              ),
              call. = FALSE
            )
          }
          if (identical(level, "country_to_world")) {
            wlv_unit_assert_world_input(numerator, strategy, "numerator")
            wlv_unit_assert_world_input(denominator, strategy, "denominator")
          }
        } else if (identical(strategy, "weighted_mean")) {
          weight_name <- wlv_unit_contract_field(row, "weight")
          weight <- wlv_unit_dimension_lookup(registry, weight_name)
          if (identical(level, "country_to_world")) {
            wlv_unit_assert_world_input(output, strategy, "value")
            wlv_unit_assert_world_input(weight, strategy, "weight")
          }
        } else if (identical(strategy, "invariant") &&
            identical(level, "country_to_world")) {
          wlv_unit_assert_world_input(output, strategy, "value")
        }
        # Schema-v1 sum/mean rows are numerical-compatibility declarations in
        # this PR. Their output units are validated, but historical cross-country
        # LCU reductions are intentionally left for the versioned migrations.
      },
      error = function(error) {
        stop(
          sprintf(
            "Aggregation unit contract `%s/%s` is invalid: %s",
            indicator,
            level,
            conditionMessage(error)
          ),
          call. = FALSE
        )
      }
    )
  }
  invisible(registry)
}
