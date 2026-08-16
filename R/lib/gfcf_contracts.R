wlv_wiodr_negative_gfcf_pin <- function(method) {
  switch(
    method,
    wiodr13 = list(
      years = as.character(1995:2009),
      demand = "c41",
      input_count = 1435L,
      output_count = 41L,
      count = 24L,
      coordinate_md5 = "61cfd5d08a9934a703335e14968e5b43",
      value_md5 = "0287db08451f74a23fe7657cc07e9165",
      canonical_unit = "million_usd",
      md5 = "61cfd5d08a9934a703335e14968e5b43"
    ),
    wiodr16 = list(
      years = as.character(2000:2014),
      demand = "c60",
      input_count = 2464L,
      output_count = 44L,
      count = 649L,
      coordinate_md5 = "5b638a35212f2b91cab933f19a037caa",
      value_md5 = "a3699faded649bb4d62c2f785e930d93",
      canonical_unit = "million_usd",
      md5 = "5b638a35212f2b91cab933f19a037caa"
    ),
    stop("Unknown WIOD GFCF contract method.", call. = FALSE)
  )
}

wlv_wiodr_radix_key_md5 <- function(keys) {
  if (!is.character(keys) || anyNA(keys) || any(!nzchar(keys))) {
    stop("GFCF anomaly keys must be non-empty strings.", call. = FALSE)
  }
  keys <- sort(keys, method = "radix")
  path <- tempfile("wlv-gfcf-", fileext = ".txt")
  on.exit(unlink(path), add = TRUE)
  connection <- file(path, open = "wb")
  writeBin(charToRaw(enc2utf8(paste(keys, collapse = "\n"))), connection)
  close(connection)
  unname(tools::md5sum(path))
}

wlv_wiodr_assert_gfcf_array <- function(value) {
  if (
    !is.array(value) ||
    !is.numeric(value) ||
    length(dim(value)) != 3L ||
    is.null(dimnames(value)) ||
    any(vapply(
      seq_along(dim(value)),
      function(index) {
        is.null(dimnames(value)[[index]]) && dim(value)[[index]] > 0L
      },
      logical(1L)
    )) ||
    any(vapply(dimnames(value), anyNA, logical(1L))) ||
    any(vapply(dimnames(value), anyDuplicated, integer(1L)) > 0L) ||
    anyNA(value) ||
    any(!is.finite(value))
  ) {
    stop(
      "WIOD GFCF values must be a finite, named three-dimensional array.",
      call. = FALSE
    )
  }
  invisible(value)
}

wlv_wiodr_gfcf_unit_divisor <- function(input_unit) {
  input_unit <- as.character(input_unit)
  if (
    length(input_unit) != 1L ||
    is.na(input_unit) ||
    !input_unit %in% c("million_usd", "usd")
  ) {
    stop(
      "`input_unit` must be either `million_usd` or `usd`.",
      call. = FALSE
    )
  }
  if (identical(input_unit, "usd")) 1000000 else 1
}

wlv_wiodr_observe_negative_gfcf <- function(
    value,
    input_unit = "million_usd") {
  wlv_wiodr_assert_gfcf_array(value)
  divisor <- wlv_wiodr_gfcf_unit_divisor(input_unit)
  positions <- which(value < 0, arr.ind = TRUE)
  data.frame(
    year = if (nrow(positions)) {
      dimnames(value)[[1L]][positions[, 1L]]
    } else {
      character()
    },
    input = if (nrow(positions)) {
      dimnames(value)[[2L]][positions[, 2L]]
    } else {
      character()
    },
    output = if (nrow(positions)) {
      dimnames(value)[[3L]][positions[, 3L]]
    } else {
      character()
    },
    value = if (nrow(positions)) value[positions] else numeric(),
    value_million_usd = if (nrow(positions)) {
      value[positions] / divisor
    } else {
      numeric()
    },
    stringsAsFactors = FALSE
  )
}

wlv_wiodr_negative_gfcf_signature <- function(observed) {
  required <- c("year", "input", "output", "value_million_usd")
  if (
    !is.data.frame(observed) ||
    length(setdiff(required, names(observed))) ||
    anyNA(observed[required]) ||
    any(!is.finite(observed$value_million_usd)) ||
    any(observed$value_million_usd >= 0)
  ) {
    stop("Invalid negative-GFCF observations.", call. = FALSE)
  }
  keys <- paste(
    observed$year,
    observed$input,
    observed$output,
    sep = "|"
  )
  canonical_values <- sprintf("%.17g", observed$value_million_usd)
  list(
    count = nrow(observed),
    coordinate_md5 = wlv_wiodr_radix_key_md5(keys),
    value_md5 = wlv_wiodr_radix_key_md5(
      paste(keys, canonical_values, sep = "|")
    ),
    canonical_unit = "million_usd"
  )
}

wlv_wiodr_assert_negative_gfcf_coordinates <- function(
    observed,
    method,
    pin = wlv_wiodr_negative_gfcf_pin(method)) {
  signature <- wlv_wiodr_negative_gfcf_signature(observed)
  if (
    !identical(signature$count, pin$count) ||
    !identical(signature$coordinate_md5, pin$coordinate_md5)
  ) {
    stop(
      sprintf(
        paste0(
          "WIOD %s negative GFCF coordinates differ from the pinned profile ",
          "(count=%s, coordinate_md5=%s)."
        ),
        sub("^wiodr", "", method),
        signature$count,
        signature$coordinate_md5
      ),
      call. = FALSE
    )
  }
  invisible(signature)
}

wlv_wiodr_assert_negative_gfcf_profile <- function(
    observed,
    method,
    pin = wlv_wiodr_negative_gfcf_pin(method)) {
  signature <- wlv_wiodr_assert_negative_gfcf_coordinates(
    observed,
    method,
    pin
  )
  if (!identical(signature$value_md5, pin$value_md5)) {
    stop(
      sprintf(
        paste0(
          "WIOD %s negative GFCF magnitudes differ from the pinned ",
          "canonical million-USD profile (value_md5=%s)."
        ),
        sub("^wiodr", "", method),
        signature$value_md5
      ),
      call. = FALSE
    )
  }
  invisible(signature)
}

wlv_wiodr_is_canonical_gfcf_scope <- function(value, pin) {
  identical(dimnames(value)[[1L]], pin$years) &&
    identical(dim(value)[[2L]], pin$input_count) &&
    identical(dim(value)[[3L]], pin$output_count)
}

wlv_wiodr_analyze_negative_gfcf <- function(
    value,
    method,
    input_unit = "million_usd") {
  wlv_wiodr_assert_gfcf_array(value)
  method <- as.character(method)
  if (length(method) != 1L || is.na(method) || !nzchar(method)) {
    stop("`method` must be one non-empty string.", call. = FALSE)
  }
  pin <- wlv_wiodr_negative_gfcf_pin(method)
  observed <- wlv_wiodr_observe_negative_gfcf(value, input_unit)

  canonical_scope <- wlv_wiodr_is_canonical_gfcf_scope(value, pin)
  if (!canonical_scope && nrow(observed)) {
    stop(
      sprintf(
        "WIOD %s negative GFCF cannot be accepted outside the pinned full source scope.",
        sub("^wiodr", "", method)
      ),
      call. = FALSE
    )
  }
  if (canonical_scope) {
    signature <- wlv_wiodr_assert_negative_gfcf_profile(
      observed,
      method,
      pin
    )
  } else {
    signature <- wlv_wiodr_negative_gfcf_signature(observed)
  }

  structure(
    list(
      observations = observed,
      signature = signature,
      canonical_scope = canonical_scope,
      input_unit = as.character(input_unit),
      canonical_unit = pin$canonical_unit
    ),
    class = c("wlv_negative_gfcf_analysis", "list")
  )
}

wlv_wiodr_analyze_m_io_negative_gfcf <- function(
    value,
    method,
    input_unit = "million_usd") {
  wlv_wiodr_assert_gfcf_array(value)
  pin <- wlv_wiodr_negative_gfcf_pin(method)
  suffix <- paste0(".", pin$demand)
  output_positions <- which(endsWith(dimnames(value)[[3L]], suffix))
  canonical_source_scope <-
    identical(dimnames(value)[[1L]], pin$years) &&
    identical(dim(value)[[2L]], pin$input_count)
  if (
    canonical_source_scope &&
    !identical(length(output_positions), pin$output_count)
  ) {
    stop(
      sprintf(
        "WIOD %s requires exactly %s `%s` GFCF output columns; found %s.",
        sub("^wiodr", "", method),
        pin$output_count,
        pin$demand,
        length(output_positions)
      ),
      call. = FALSE
    )
  }
  wlv_wiodr_analyze_negative_gfcf(
    value[, , output_positions, drop = FALSE],
    method = method,
    input_unit = input_unit
  )
}

wlv_wiodr_canonical_gfcf_diagnostic_observations <- function(value, method) {
  analysis <- wlv_wiodr_analyze_m_io_negative_gfcf(
    value,
    method = method,
    input_unit = "million_usd"
  )
  observed <- analysis$observations
  observed$value <- observed$value_million_usd
  observed$policy_id <- rep(
    paste0(method, "_negative_gfcf_v1"),
    nrow(observed)
  )
  observed$action <- rep(
    "truncate_allowlisted_negative_gfcf",
    nrow(observed)
  )
  observed
}

wlv_wiodr_apply_negative_gfcf_policy <- function(
    value,
    method,
    input_unit = "usd") {
  wlv_wiodr_assert_gfcf_array(value)
  method <- as.character(method)
  if (length(method) != 1L || is.na(method) || !nzchar(method)) {
    stop("`method` must be one non-empty string.", call. = FALSE)
  }
  pin <- wlv_wiodr_negative_gfcf_pin(method)
  observed <- wlv_wiodr_observe_negative_gfcf(value, input_unit)
  canonical_scope <- wlv_wiodr_is_canonical_gfcf_scope(value, pin)
  if (!canonical_scope && nrow(observed)) {
    stop(
      sprintf(
        "WIOD %s negative GFCF cannot be accepted outside the pinned full source scope.",
        sub("^wiodr", "", method)
      ),
      call. = FALSE
    )
  }
  if (canonical_scope) {
    wlv_wiodr_assert_negative_gfcf_coordinates(observed, method, pin)
  }

  observed$country <- sub("[.](c41|c60)$", "", observed$output)
  observed$policy_id <- rep(
    paste0(method, "_negative_gfcf_v1"),
    nrow(observed)
  )
  observed$action <- rep(
    "truncate_allowlisted_negative_gfcf",
    nrow(observed)
  )
  result <- pmax(value, 0)
  attr(result, "wlv.truncated_negative_gfcf") <- observed
  result
}

wlv_wiodr_sanitize_negative_gfcf <- function(
    value,
    method,
    input_unit = "usd") {
  wlv_wiodr_apply_negative_gfcf_policy(
    value,
    method = method,
    input_unit = input_unit
  )
}

wlv_record_observed_transformations <- function(
    runtime,
    observed,
    artifact,
    indicator,
    checkpoint,
    stage,
    module,
    coordinate_columns) {
  if (is.null(observed) || !nrow(observed)) {
    return(invisible(runtime))
  }
  if (
    !is.data.frame(observed) ||
    !all(c("value", "policy_id", "action") %in% names(observed)) ||
    length(unique(observed$policy_id)) != 1L ||
    length(unique(observed$action)) != 1L ||
    !is.character(coordinate_columns) ||
    is.null(names(coordinate_columns)) ||
    any(!names(coordinate_columns) %in% c("year", "country", "sector", "output")) ||
    any(!coordinate_columns %in% names(observed)) ||
    anyDuplicated(names(coordinate_columns))
  ) {
    stop("Invalid observed-transformation contract payload.", call. = FALSE)
  }

  context <- wlv_contract_context_for(
    runtime,
    artifact = artifact,
    indicator = indicator,
    checkpoint = checkpoint,
    stage = stage,
    module = module,
    policy_id = unique(observed$policy_id)
  )
  coordinates <- stats::setNames(
    rep(list(rep(NA_character_, nrow(observed))), 4L),
    c("year", "country", "sector", "output")
  )
  for (role in names(coordinate_columns)) {
    coordinates[[role]] <- as.character(observed[[coordinate_columns[[role]]]])
  }
  anomalies <- data.frame(
    artifact = rep(context$artifact, nrow(observed)),
    indicator = rep(context$indicator, nrow(observed)),
    checkpoint = rep(context$checkpoint, nrow(observed)),
    stage = rep(context$stage, nrow(observed)),
    module = rep(context$module, nrow(observed)),
    year = coordinates$year,
    country = coordinates$country,
    sector = coordinates$sector,
    output = coordinates$output,
    original_value = vapply(
      observed$value,
      wlv_format_original_value,
      character(1L)
    ),
    policy_id = observed$policy_id,
    action = observed$action,
    stringsAsFactors = FALSE
  )
  wlv_contract_record(runtime, anomalies)
}
