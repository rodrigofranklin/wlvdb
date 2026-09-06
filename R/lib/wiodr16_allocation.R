wlv_wiodr16_source_unit_multiplier <- function(input_unit) {
  input_unit <- as.character(input_unit)
  if (
    length(input_unit) != 1L || is.na(input_unit) ||
      !input_unit %in% c("million_usd", "usd")
  ) {
    stop(
      "`input_unit` must be either `million_usd` or `usd`.",
      call. = FALSE
    )
  }
  if (identical(input_unit, "usd")) 1000000 else 1
}

wlv_wiodr16_expected_negative_source_k <- function() {
  data.frame(
    year = c("2012", "2013", "2014"),
    sector = "C33",
    country = "PRT",
    value = c(-313.147, -554.413, -873.203),
    stringsAsFactors = FALSE
  )
}

wlv_wiodr16_expected_negative_euklems_weights <- function() {
  data.frame(
    year = c(
      "2010", "2011", rep("2012", 15L), rep("2014", 2L), rep("2015", 2L)
    ),
    country = c(
      "EL", "EL", rep("EE", 5L), "EL", "EL", rep("EE", 8L),
      "EL", "EL", "EL", "EL"
    ),
    sector = c(
      "K", "K", rep("H51", 5L), "C31-C33", "K", rep("H51", 8L),
      "C31-C33", "K", "C31-C33", "K"
    ),
    variable = c(
      "K_TraEq", "K_TraEq", "K_GFCF", "K_IT", "K_CT", "K_Soft_DB",
      "K_TraEq", "K_TraEq", "K_TraEq", "K_OMach", "K_OCon",
      "K_RStruc", "K_RD", "K_ITCT", "K_RSOC", "K_SoftIPP", "K_RDetc",
      "K_TraEq", "K_TraEq", "K_TraEq", "K_TraEq"
    ),
    value = c(
      -0.00011356869678385729,
      -0.00012885058988428588,
      -0.00013121578648407891,
      -9.6869706421059477e-05,
      -0.00013440129409246027,
      -7.8609437482220066e-05,
      -0.0008324331665834566,
      -2.6826507943161338e-05,
      -0.00013580919646225426,
      -8.2429174713967258e-05,
      -0.0001613822351065852,
      -1.1662473802869488e-06,
      -2.0569807628102506e-05,
      -0.00012810059672339216,
      -9.0550786187394244e-05,
      -6.3325336048517282e-05,
      -3.6384872042820539e-05,
      -7.2182361518139434e-05,
      -5.5941330176558063e-05,
      -6.8492136362290079e-05,
      -3.3320498770843819e-05
    ),
    stringsAsFactors = FALSE
  )
}

wlv_wiodr16_expected_negative_va_ratios <- function() {
  data.frame(
    year = "2007",
    input = "ROU.J58",
    value = -0.027559192993556868,
    stringsAsFactors = FALSE
  )
}

wlv_wiodr16_expected_source_va_exception <- function() {
  data.frame(
    year = c(
      "2000", "2000", "2001", "2002", "2004", "2004", "2005", "2005",
      "2005", "2006", "2007", "2007", "2008", "2011", "2011", "2011",
      "2012", "2012", "2012", "2013", "2013", "2013", "2014", "2014",
      "2014", "2014"
    ),
    variable = rep("VA_USD", 26L),
    sector = c(
      "C19", "B", "C19", "C19", "C19", "T", "C19", "T", "B", "C19",
      "C19", "J58", "C19", "C19", "H51", "B", "C19", "B", "D35",
      "C19", "H50", "H53", "C19", "C19", "H50", "B"
    ),
    country = c(
      "BRA", "MLT", "BRA", "BRA", "BRA", "JPN", "BRA", "JPN", "MLT",
      "BRA", "BRA", "ROU", "BRA", "BRA", "LVA", "MLT", "BRA", "MLT",
      "MLT", "BRA", "LUX", "LUX", "BGR", "BRA", "LUX", "MLT"
    ),
    value = c(
      -1751.6965443734994, -1.2567961085037498, -2336.753754971835,
      -2012.337601105467, -1528.9750243169362, -1.2919767759740355e-11,
      -2600.4489938552415, -8.46649520099163e-12, -0.56913483029886713,
      -7569.6282062174187, -3351.4276018643263, -17.404439964866128,
      -11940.50491142658, -6098.6535800000347, -34.246179518853182,
      -11.638690810474539,
      -13902.23128,
      -42.360757700503441, -0.36994411521583848, -13089.912069000002,
      -55.753616993808798, -125.65482444003439, -203.94872075799785,
      -12221.259959420464, -54.051464909195879, -2.3004445006018308
    ),
    stringsAsFactors = FALSE
  )
}

wlv_wiodr16_expected_gfcf_fallbacks <- function() {
  common <- c(
    "MEX.T", "MEX.U", "TUR.T", "TWN.T", "USA.T", "ROW.T", "ROW.U"
  )
  data.frame(
    year = c(
      rep(as.character(2000:2014), each = length(common)),
      as.character(2001:2014),
      "2012"
    ),
    input = c(rep(common, times = 15L), rep("LUX.T", 14L), "EST.H51"),
    stringsAsFactors = FALSE
  )
}

# Exceções de fonte são listas autenticadas de ano/país/setor/valor, não limites
# genéricos. Conferir coordenadas e magnitudes distingue uma observação conhecida
# de um defeito novo antes de qualquer truncamento. Guias: docs/guide-pt.md e
# docs/guide-en.md, contratos de alocação/ausência WIOD16.
wlv_wiodr16_assert_exact_anomalies <- function(
    observed,
    expected,
    keys,
    label,
    tolerance = 1e-10,
    compare_values = TRUE) {
  if (
    length(tolerance) != 1L ||
    !is.numeric(tolerance) ||
    is.na(tolerance) ||
    !is.finite(tolerance) ||
    tolerance < 0
  ) {
    stop("`tolerance` must be one finite non-negative number.", call. = FALSE)
  }
  required <- c(keys, if (compare_values) "value")
  if (
    !is.data.frame(observed) ||
    !is.data.frame(expected) ||
    any(!required %in% names(observed)) ||
    any(!required %in% names(expected))
  ) {
    stop(sprintf("Invalid %s anomaly tables.", label), call. = FALSE)
  }
  observed_key <- if (nrow(observed)) {
    do.call(paste, c(observed[keys], sep = "\034"))
  } else {
    character()
  }
  expected_key <- if (nrow(expected)) {
    do.call(paste, c(expected[keys], sep = "\034"))
  } else {
    character()
  }
  if (anyDuplicated(observed_key) || anyDuplicated(expected_key)) {
    stop(sprintf("Duplicated %s anomaly keys.", label), call. = FALSE)
  }
  unexpected <- setdiff(observed_key, expected_key)
  missing <- setdiff(expected_key, observed_key)
  if (length(unexpected) || length(missing)) {
    stop(
      sprintf(
        paste0(
          "WIOD16 %s anomalies differ from the exact allowlist; ",
          "unexpected: %s; missing: %s."
        ),
        label,
        if (length(unexpected)) paste(unexpected, collapse = ", ") else "none",
        if (length(missing)) paste(missing, collapse = ", ") else "none"
      ),
      call. = FALSE
    )
  }
  if (compare_values && nrow(observed)) {
    expected_order <- match(observed_key, expected_key)
    difference <- abs(observed$value - expected$value[expected_order])
    scale <- pmax(1, abs(expected$value[expected_order]))
    if (any(!is.finite(difference)) || any(difference > tolerance * scale)) {
      stop(
        sprintf("WIOD16 %s anomaly values differ from the allowlist.", label),
        call. = FALSE
      )
    }
  }
  invisible(observed)
}

wlv_wiodr16_validate_input_labels <- function(input_labels, expected_length) {
  if (
    !is.character(input_labels) ||
    length(input_labels) != expected_length ||
    anyNA(input_labels) ||
    any(!nzchar(input_labels)) ||
    anyDuplicated(input_labels)
  ) {
    stop(
      "`input_labels` must be unique, non-empty character labels of the expected length.",
      call. = FALSE
    )
  }
  invisible(input_labels)
}

wlv_wiodr16_validate_year <- function(year) {
  year <- as.character(year)
  if (
    length(year) != 1L ||
    is.na(year) ||
    !grepl("^[0-9]{4}$", year)
  ) {
    stop("`year` must be one four-digit calendar year.", call. = FALSE)
  }
  year
}

wlv_wiodr16_validate_source_negative_k <- function(
    sea,
    tolerance = 1e-10,
    input_unit = "million_usd") {
  if (!is.array(sea) || length(dim(sea)) != 4L || is.null(dimnames(sea))) {
    stop("`sea` must be a four-dimensional named array.", call. = FALSE)
  }
  if (!"K" %in% dimnames(sea)[[2L]]) {
    return(invisible(data.frame()))
  }
  value <- sea[, "K", , , drop = FALSE]
  positions <- which(value < 0, arr.ind = TRUE)
  observed <- data.frame(
    year = dimnames(value)[[1L]][positions[, 1L]],
    sector = dimnames(value)[[3L]][positions[, 3L]],
    country = dimnames(value)[[4L]][positions[, 4L]],
    value = if (nrow(positions)) value[positions] else numeric(),
    stringsAsFactors = FALSE
  )
  expected <- wlv_wiodr16_expected_negative_source_k()
  expected <- expected[
    expected$year %in% dimnames(value)[[1L]] &
      expected$sector %in% dimnames(value)[[3L]] &
      expected$country %in% dimnames(value)[[4L]],
    ,
    drop = FALSE
  ]
  unit_multiplier <- wlv_wiodr16_source_unit_multiplier(input_unit)
  expected$value <- expected$value * unit_multiplier
  wlv_wiodr16_assert_exact_anomalies(
    observed,
    expected,
    keys = c("year", "sector", "country"),
    label = "negative source K",
    tolerance = tolerance
  )
}

wlv_wiodr16_validate_source_va_exception <- function(
    sea,
    tolerance = 1e-10,
    input_unit = "million_usd") {
  if (!is.array(sea) || length(dim(sea)) != 4L || is.null(dimnames(sea))) {
    stop("`sea` must be a four-dimensional named array.", call. = FALSE)
  }
  if (!"VA_USD" %in% dimnames(sea)[[2L]]) {
    return(invisible(data.frame()))
  }

  value <- sea[, "VA_USD", , , drop = FALSE]
  positions <- which(value < 0, arr.ind = TRUE)
  observed <- data.frame(
    year = dimnames(value)[[1L]][positions[, 1L]],
    variable = rep("VA_USD", nrow(positions)),
    sector = dimnames(value)[[3L]][positions[, 3L]],
    country = dimnames(value)[[4L]][positions[, 4L]],
    value = if (nrow(positions)) value[positions] else numeric(),
    stringsAsFactors = FALSE
  )
  expected <- wlv_wiodr16_expected_source_va_exception()
  expected <- expected[
    expected$year %in% dimnames(sea)[[1L]] &
    expected$variable %in% dimnames(sea)[[2L]] &
    expected$sector %in% dimnames(sea)[[3L]] &
    expected$country %in% dimnames(sea)[[4L]],
    ,
    drop = FALSE
  ]
  unit_multiplier <- wlv_wiodr16_source_unit_multiplier(input_unit)
  expected$value <- expected$value * unit_multiplier
  wlv_wiodr16_assert_exact_anomalies(
    observed,
    expected,
    keys = c("year", "variable", "sector", "country"),
    label = "source value-added exception",
    tolerance = tolerance
  )
}

wlv_wiodr16_clean_structural_nonfinite_stock <- function(
    capital_stock,
    input_labels) {
  if (!is.numeric(capital_stock) || length(capital_stock) != length(input_labels)) {
    stop("Invalid WIOD16 capital-stock vector.", call. = FALSE)
  }
  wlv_wiodr16_validate_input_labels(input_labels, length(capital_stock))

  invalid_numeric <- is.nan(capital_stock) | is.infinite(capital_stock)
  if (any(invalid_numeric)) {
    stop("WIOD16 capital stock contains NaN or infinite values.", call. = FALSE)
  }
  missing <- is.na(capital_stock)
  structural_row <- startsWith(input_labels, "ROW.")
  unexpected <- which(missing & !structural_row)
  if (length(unexpected)) {
    stop(
      sprintf(
        "WIOD16 capital stock is missing outside structural ROW: %s.",
        paste(input_labels[unexpected], collapse = ", ")
      ),
      call. = FALSE
    )
  }
  capital_stock
}

wlv_wiodr16_validate_negative_euklems_weights <- function(
    value,
    year,
    tolerance = 1e-10) {
  if (
    !is.data.frame(value) ||
    !all(c("country", "sector") %in% names(value)) ||
    length(year) != 1L ||
    is.na(year)
  ) {
    stop("Invalid WIOD16 EU KLEMS table or year.", call. = FALSE)
  }
  year <- wlv_wiodr16_validate_year(year)
  variables <- names(value)[vapply(value, is.numeric, logical(1))]
  numeric_value <- as.matrix(value[variables])
  positions <- which(numeric_value < 0, arr.ind = TRUE)
  observed <- data.frame(
    year = rep(year, nrow(positions)),
    country = value$country[positions[, 1L]],
    sector = value$sector[positions[, 1L]],
    variable = variables[positions[, 2L]],
    value = if (nrow(positions)) numeric_value[positions] else numeric(),
    stringsAsFactors = FALSE
  )
  expected <- wlv_wiodr16_expected_negative_euklems_weights()
  present_keys <- paste(value$country, value$sector, sep = "\034")
  expected_keys <- paste(expected$country, expected$sector, sep = "\034")
  expected <- expected[
    expected$year == year &
      expected_keys %in% present_keys &
      expected$variable %in% variables,
    ,
    drop = FALSE
  ]
  wlv_wiodr16_assert_exact_anomalies(
    observed,
    expected,
    keys = c("year", "country", "sector", "variable"),
    label = "negative EU KLEMS weights",
    tolerance = tolerance
  )
}

wlv_wiodr16_sanitize_euklems_weights <- function(value, year) {
  observed <- wlv_wiodr16_validate_negative_euklems_weights(value, year)
  observed$policy_id <- rep(
    "wiodr16_negative_euklems_weights_v1",
    nrow(observed)
  )
  observed$action <- rep(
    "truncate_allowlisted_negative_euklems_weight",
    nrow(observed)
  )
  variables <- names(value)[vapply(value, is.numeric, logical(1))]
  for (variable in variables) {
    value[[variable]][value[[variable]] < 0] <- 0
  }
  attr(value, "wlv.truncated_negative_weights") <- observed
  value
}

wlv_wiodr16_sanitize_va_ratios <- function(
    ratios,
    year,
    input_labels,
    numerator = NULL,
    denominator = NULL) {
  if (
    !is.numeric(ratios) ||
    !is.character(input_labels) ||
    length(ratios) != length(input_labels) ||
    anyNA(input_labels)
  ) {
    stop("Invalid WIOD16 value-added disaggregation ratios.", call. = FALSE)
  }
  wlv_wiodr16_validate_input_labels(input_labels, length(ratios))
  year <- wlv_wiodr16_validate_year(year)
  invalid_numeric <- is.na(ratios) | is.infinite(ratios)
  zero_over_zero <- is.nan(ratios)
  if (any(invalid_numeric)) {
    conformable_inputs <-
      is.numeric(numerator) && is.numeric(denominator) &&
      length(numerator) == length(ratios) &&
      length(denominator) == length(ratios)
    if (!conformable_inputs) {
      stop("WIOD16 value-added ratios contain missing or non-finite values.", call. = FALSE)
    }
    allowed_zero <-
      zero_over_zero & numerator == 0 & denominator == 0 &
      is.finite(numerator) & is.finite(denominator)
    if (any(invalid_numeric & !allowed_zero)) {
      stop(
        "WIOD16 value-added ratios contain an unexpected missing or non-finite value.",
        call. = FALSE
      )
    }
    ratios[allowed_zero] <- 0
  }
  positions <- which(is.finite(ratios) & ratios < 0)
  observed <- data.frame(
    year = rep(year, length(positions)),
    input = input_labels[positions],
    value = ratios[positions],
    stringsAsFactors = FALSE
  )
  expected <- wlv_wiodr16_expected_negative_va_ratios()
  expected <- expected[
    expected$year == year & expected$input %in% input_labels,
    ,
    drop = FALSE
  ]
  wlv_wiodr16_assert_exact_anomalies(
    observed,
    expected,
    keys = c("year", "input"),
    label = "negative value-added allocation ratios"
  )
  observed$country <- sub("[.].*$", "", observed$input)
  observed$sector <- sub("^[^.]+[.]", "", observed$input)
  observed$policy_id <- rep("wiodr16_negative_va_ratio_v1", nrow(observed))
  observed$action <- rep(
    "absolute_allowlisted_negative_va_ratio",
    nrow(observed)
  )
  ratios[positions] <- abs(ratios[positions])
  attr(ratios, "wlv.absolute_va_ratios") <- observed
  attr(ratios, "wlv.zero_va_ratios") <- which(zero_over_zero)
  ratios
}

wlv_wiodr16_sanitize_capital_stock <- function(capital_stock, year, input_labels) {
  if (
    !is.numeric(capital_stock) ||
    !is.character(input_labels) ||
    length(capital_stock) != length(input_labels)
  ) {
    stop("Invalid WIOD16 capital-stock vector.", call. = FALSE)
  }
  wlv_wiodr16_validate_input_labels(input_labels, length(capital_stock))
  invalid_numeric <- is.nan(capital_stock) | is.infinite(capital_stock)
  structural_row <- startsWith(input_labels, "ROW.")
  if (
    any(invalid_numeric) ||
    any(is.na(capital_stock) & !structural_row)
  ) {
    stop("Invalid WIOD16 capital-stock vector.", call. = FALSE)
  }
  year <- wlv_wiodr16_validate_year(year)
  positions <- which(!is.na(capital_stock) & capital_stock < 0)
  observed <- data.frame(
    year = rep(year, length(positions)),
    input = input_labels[positions],
    value = capital_stock[positions],
    stringsAsFactors = FALSE
  )
  expected <- wlv_wiodr16_expected_negative_source_k()
  expected <- data.frame(
    year = expected$year,
    input = paste(expected$country, expected$sector, sep = "."),
    stringsAsFactors = FALSE
  )
  expected <- expected[
    expected$year == year & expected$input %in% input_labels,
    ,
    drop = FALSE
  ]
  wlv_wiodr16_assert_exact_anomalies(
    observed,
    expected,
    keys = c("year", "input"),
    label = "negative derived capital stock",
    compare_values = FALSE
  )
  observed$country <- sub("[.].*$", "", observed$input)
  observed$sector <- sub("^[^.]+[.]", "", observed$input)
  observed$policy_id <- rep(
    "wiodr16_negative_capital_stock_v1",
    nrow(observed)
  )
  observed$action <- rep(
    "truncate_allowlisted_negative_capital_stock",
    nrow(observed)
  )
  capital_stock[positions] <- 0
  attr(capital_stock, "wlv.truncated_negative_stock") <- observed
  capital_stock
}

# Aloca o estoque monetário de cada usuário entre fornecedores. O caminho WIOD16
# exige pesos não negativos e conserva cada total de coluna; sem pesos EU KLEMS
# usa a FBCF nacional autorizada e documenta a escolha. Não inventa capital para
# compensar pesos ausentes nem transforma estoque negativo em ativo físico.
wlv_wiodr16_allocate_capital <- function(
    weights,
    capital_stock,
    fallback_weights,
    year,
    input_labels,
    tolerance = 1e-10) {
  if (
    !is.matrix(weights) ||
    !is.numeric(weights) ||
    !is.matrix(fallback_weights) ||
    !is.numeric(fallback_weights) ||
    !identical(dim(weights), dim(fallback_weights)) ||
    nrow(weights) != length(input_labels) ||
    ncol(weights) != length(input_labels) ||
    !is.numeric(capital_stock) ||
    length(capital_stock) != ncol(weights) ||
    anyNA(capital_stock) ||
    any(!is.finite(capital_stock)) ||
    any(capital_stock < 0) ||
    anyNA(weights) ||
    any(!is.finite(weights)) ||
    any(weights < 0) ||
    anyNA(fallback_weights) ||
    any(!is.finite(fallback_weights)) ||
    any(fallback_weights < 0)
  ) {
    stop("WIOD16 capital allocation requires conformable non-negative finite data.", call. = FALSE)
  }

  wlv_wiodr16_validate_input_labels(input_labels, nrow(weights))
  if (
    length(tolerance) != 1L ||
    !is.numeric(tolerance) ||
    is.na(tolerance) ||
    !is.finite(tolerance) ||
    tolerance < 0
  ) {
    stop("`tolerance` must be one finite non-negative number.", call. = FALSE)
  }

  year <- wlv_wiodr16_validate_year(year)
  totals <- colSums(weights)
  missing_positions <- which(capital_stock > 0 & totals <= 0)
  observed <- data.frame(
    year = rep(year, length(missing_positions)),
    input = input_labels[missing_positions],
    stringsAsFactors = FALSE
  )
  expected <- wlv_wiodr16_expected_gfcf_fallbacks()
  expected <- expected[
    expected$year == year & expected$input %in% input_labels,
    ,
    drop = FALSE
  ]
  wlv_wiodr16_assert_exact_anomalies(
    observed,
    expected,
    keys = c("year", "input"),
    label = "positive-stock columns without allocation weights",
    compare_values = FALSE
  )

  if (length(missing_positions)) {
    fallback_totals <- colSums(fallback_weights[, missing_positions, drop = FALSE])
    if (any(!is.finite(fallback_totals)) || any(fallback_totals <= 0)) {
      stop(
        "WIOD16 national-GFCF fallback lacks positive allocation weights.",
        call. = FALSE
      )
    }
    weights[, missing_positions] <- fallback_weights[, missing_positions, drop = FALSE]
    totals <- colSums(weights)
  }

  still_missing <- which(capital_stock > 0 & totals <= 0)
  if (length(still_missing)) {
    stop(
      sprintf(
        "WIOD16 positive capital stock remains unallocated: %s.",
        paste(input_labels[still_missing], collapse = ", ")
      ),
      call. = FALSE
    )
  }

  distribution <- sweep(weights, 2L, totals, "/")
  distribution[, totals <= 0] <- 0
  result <- sweep(distribution, 2L, capital_stock, "*")
  if (any(!is.finite(result)) || any(result < 0)) {
    stop("WIOD16 capital allocation produced invalid composition.", call. = FALSE)
  }
  residual <- abs(colSums(result) - capital_stock)
  if (any(residual > tolerance * pmax(1, abs(capital_stock)))) {
    stop("WIOD16 capital allocation does not conserve capital stock.", call. = FALSE)
  }
  attr(result, "wlv.gfcf_fallbacks") <- observed
  result
}
