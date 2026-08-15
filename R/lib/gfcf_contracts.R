wlv_wiodr_negative_gfcf_pin <- function(method) {
  switch(
    method,
    wiodr13 = list(
      years = as.character(1995:2009),
      input_count = 1435L,
      output_count = 41L,
      count = 24L,
      md5 = "61cfd5d08a9934a703335e14968e5b43"
    ),
    wiodr16 = list(
      years = as.character(2000:2014),
      input_count = 2464L,
      output_count = 44L,
      count = 649L,
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

wlv_wiodr_sanitize_negative_gfcf <- function(value, method) {
  if (
    !is.array(value) ||
    !is.numeric(value) ||
    length(dim(value)) != 3L ||
    is.null(dimnames(value)) ||
    any(vapply(dimnames(value), is.null, logical(1L))) ||
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

  method <- as.character(method)
  if (length(method) != 1L || is.na(method) || !nzchar(method)) {
    stop("`method` must be one non-empty string.", call. = FALSE)
  }
  pin <- wlv_wiodr_negative_gfcf_pin(method)
  positions <- which(value < 0, arr.ind = TRUE)
  observed <- data.frame(
    year = dimnames(value)[[1L]][positions[, 1L]],
    input = dimnames(value)[[2L]][positions[, 2L]],
    output = dimnames(value)[[3L]][positions[, 3L]],
    value = if (nrow(positions)) value[positions] else numeric(),
    stringsAsFactors = FALSE
  )

  canonical_scope <-
    identical(dimnames(value)[[1L]], pin$years) &&
    identical(dim(value)[[2L]], pin$input_count) &&
    identical(dim(value)[[3L]], pin$output_count)
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
    keys <- paste(observed$year, observed$input, observed$output, sep = "|")
    observed_md5 <- wlv_wiodr_radix_key_md5(keys)
    if (
      !identical(nrow(observed), pin$count) ||
      !identical(observed_md5, pin$md5)
    ) {
      stop(
        sprintf(
          paste0(
            "WIOD %s negative GFCF differs from the pinned set ",
            "(count=%s, md5=%s)."
          ),
          sub("^wiodr", "", method),
          nrow(observed),
          observed_md5
        ),
        call. = FALSE
      )
    }
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
  value[positions] <- 0
  attr(value, "wlv.truncated_negative_gfcf") <- observed
  value
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
