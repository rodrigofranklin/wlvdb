# Pure source-unit normalization for the stable WIOD inputs. This module does
# not read or write files; callers remain responsible for persisting the
# explicit normalization marker together with an artifact.

wlv_source_normalization_marker_name <- "wlv.source_normalization"

wlv_normalization_unit_vector <- function(value, variables, label) {
  if (is.null(value)) {
    return(stats::setNames(rep("unspecified", length(variables)), variables))
  }
  if (length(value) == 1L && is.null(names(value))) {
    value <- rep(as.character(value), length(variables))
    names(value) <- variables
  }
  if (
    !is.character(value) ||
    is.null(names(value)) ||
    anyNA(value) ||
    anyNA(names(value)) ||
    any(!nzchar(value)) ||
    any(!nzchar(names(value))) ||
    anyDuplicated(names(value)) ||
    !setequal(names(value), variables)
  ) {
    stop(
      sprintf("`%s` must name exactly every SEA variable once.", label),
      call. = FALSE
    )
  }
  value[variables]
}

wlv_new_source_normalization_contract <- function(
    source,
    m_io_multiplier,
    sea_multipliers,
    contract_id = paste0(source, "_source_normalization_v1"),
    m_io_source_unit = "unspecified",
    m_io_canonical_unit = "unspecified",
    sea_source_units = NULL,
    sea_canonical_units = NULL) {
  if (
    !is.character(source) || length(source) != 1L || is.na(source) ||
    !nzchar(source)
  ) {
    stop("`source` must be one non-empty string.", call. = FALSE)
  }
  if (
    !is.character(contract_id) || length(contract_id) != 1L ||
    is.na(contract_id) || !nzchar(contract_id)
  ) {
    stop("`contract_id` must be one non-empty string.", call. = FALSE)
  }
  if (
    !is.numeric(m_io_multiplier) || length(m_io_multiplier) != 1L ||
    is.na(m_io_multiplier) || !is.finite(m_io_multiplier) ||
    m_io_multiplier <= 0
  ) {
    stop("`m_io_multiplier` must be one positive finite number.", call. = FALSE)
  }
  if (
    !is.numeric(sea_multipliers) || !length(sea_multipliers) ||
    is.null(names(sea_multipliers)) || anyNA(sea_multipliers) ||
    any(!is.finite(sea_multipliers)) || any(sea_multipliers <= 0) ||
    anyNA(names(sea_multipliers)) || any(!nzchar(names(sea_multipliers))) ||
    anyDuplicated(names(sea_multipliers))
  ) {
    stop(
      paste0(
        "`sea_multipliers` must be a positive finite numeric vector with ",
        "unique non-empty names."
      ),
      call. = FALSE
    )
  }
  if (
    !is.character(m_io_source_unit) || length(m_io_source_unit) != 1L ||
    is.na(m_io_source_unit) || !nzchar(m_io_source_unit) ||
    !is.character(m_io_canonical_unit) ||
    length(m_io_canonical_unit) != 1L || is.na(m_io_canonical_unit) ||
    !nzchar(m_io_canonical_unit)
  ) {
    stop("m_io unit labels must be non-empty strings.", call. = FALSE)
  }

  variables <- names(sea_multipliers)
  source_units <- wlv_normalization_unit_vector(
    sea_source_units,
    variables,
    "sea_source_units"
  )
  canonical_units <- wlv_normalization_unit_vector(
    sea_canonical_units,
    variables,
    "sea_canonical_units"
  )

  structure(
    list(
      schema_version = 1L,
      contract_id = contract_id,
      source = source,
      m_io = list(
        source_unit = m_io_source_unit,
        canonical_unit = m_io_canonical_unit,
        multiplier = as.numeric(m_io_multiplier)
      ),
      sea = data.frame(
        variable = variables,
        source_unit = unname(source_units),
        canonical_unit = unname(canonical_units),
        multiplier = as.numeric(sea_multipliers),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    ),
    class = "wlv_source_normalization_contract"
  )
}

wlv_source_normalization_contract <- function(source) {
  if (
    !is.character(source) || length(source) != 1L || is.na(source) ||
    !nzchar(source)
  ) {
    stop("`source` must be one non-empty string.", call. = FALSE)
  }

  if (identical(source, "wiodr13")) {
    million_lcu <- c("GO", "II", "VA", "COMP", "LAB", "CAP", "GFCF")
    thousand_people <- c("EMP", "EMPE")
    million_hours <- c("H_EMP", "H_EMPE")
    price_indices <- c("GO_P", "II_P", "VA_P", "GFCF_P")
    volume_indices <- c("GO_QI", "II_QI", "VA_QI")
    shares <- c("LABHS", "LABMS", "LABLS", "H_HS", "H_MS", "H_LS")
    million_constant_lcu <- "K_GFCF"
    million_usd <- c("VA_USD", "GO_USD")
    variables <- c(
      million_lcu,
      thousand_people,
      million_hours,
      price_indices,
      volume_indices,
      shares,
      million_constant_lcu,
      million_usd
    )
    multipliers <- stats::setNames(rep(1, length(variables)), variables)
    multipliers[c(million_lcu, million_constant_lcu, million_usd)] <- 1e6
    multipliers[thousand_people] <- 1e3
    multipliers[million_hours] <- 1e6
    multipliers[c(price_indices, volume_indices)] <- 1 / 100

    source_units <- stats::setNames(rep("fraction", length(variables)), variables)
    canonical_units <- source_units
    source_units[million_lcu] <- "million_current_lcu"
    canonical_units[million_lcu] <- "current_lcu"
    source_units[thousand_people] <- "thousand_person"
    canonical_units[thousand_people] <- "person"
    source_units[million_hours] <- "million_hour"
    canonical_units[million_hours] <- "hour"
    source_units[price_indices] <- "price_index_1995_eq_100"
    canonical_units[price_indices] <- "price_index_1995_eq_1"
    source_units[volume_indices] <- "volume_index_1995_eq_100"
    canonical_units[volume_indices] <- "volume_index_1995_eq_1"
    source_units[million_constant_lcu] <- "million_constant_1995_lcu"
    canonical_units[million_constant_lcu] <- "constant_1995_lcu"
    source_units[million_usd] <- "million_current_usd"
    canonical_units[million_usd] <- "current_usd"

    return(wlv_new_source_normalization_contract(
      source = source,
      contract_id = "wiodr13_source_normalization_v1",
      m_io_multiplier = 1e6,
      sea_multipliers = multipliers,
      m_io_source_unit = "million_current_usd",
      m_io_canonical_unit = "current_usd",
      sea_source_units = source_units,
      sea_canonical_units = canonical_units
    ))
  }

  if (identical(source, "wiodr16")) {
    million_lcu <- c("GO", "II", "VA", "COMP", "LAB", "CAP", "K")
    thousand_people <- c("EMP", "EMPE")
    million_hours <- "H_EMPE"
    price_indices <- c("GO_PI", "II_PI", "VA_PI")
    volume_indices <- c("GO_QI", "II_QI", "VA_QI")
    million_usd <- c("VA_USD", "GO_USD")
    variables <- c(
      million_lcu,
      thousand_people,
      million_hours,
      price_indices,
      volume_indices,
      million_usd
    )
    multipliers <- stats::setNames(rep(1, length(variables)), variables)
    multipliers[c(million_lcu, million_hours, million_usd)] <- 1e6
    multipliers[thousand_people] <- 1e3
    multipliers[c(price_indices, volume_indices)] <- 1 / 100

    source_units <- stats::setNames(rep("fraction", length(variables)), variables)
    canonical_units <- source_units
    source_units[million_lcu] <- "million_current_lcu"
    canonical_units[million_lcu] <- "current_lcu"
    source_units[thousand_people] <- "thousand_person"
    canonical_units[thousand_people] <- "person"
    source_units[million_hours] <- "million_hour"
    canonical_units[million_hours] <- "hour"
    source_units[price_indices] <- "price_index_2010_eq_100"
    canonical_units[price_indices] <- "price_index_2010_eq_1"
    source_units[volume_indices] <- "volume_index_2010_eq_100"
    canonical_units[volume_indices] <- "volume_index_2010_eq_1"
    source_units[million_usd] <- "million_current_usd"
    canonical_units[million_usd] <- "current_usd"

    return(wlv_new_source_normalization_contract(
      source = source,
      contract_id = "wiodr16_source_normalization_v1",
      m_io_multiplier = 1e6,
      sea_multipliers = multipliers,
      m_io_source_unit = "million_current_usd",
      m_io_canonical_unit = "current_usd",
      sea_source_units = source_units,
      sea_canonical_units = canonical_units
    ))
  }

  stop(
    sprintf("Unknown source normalization contract `%s`.", source),
    call. = FALSE
  )
}

wlv_validate_source_normalization_contract <- function(contract) {
  if (!inherits(contract, "wlv_source_normalization_contract")) {
    stop("Invalid source normalization contract.", call. = FALSE)
  }
  required <- c("schema_version", "contract_id", "source", "m_io", "sea")
  if (!all(required %in% names(contract))) {
    stop("Incomplete source normalization contract.", call. = FALSE)
  }
  if (
    !identical(contract$schema_version, 1L) ||
    !is.character(contract$contract_id) || length(contract$contract_id) != 1L ||
    is.na(contract$contract_id) || !nzchar(contract$contract_id) ||
    !is.character(contract$source) || length(contract$source) != 1L ||
    is.na(contract$source) || !nzchar(contract$source)
  ) {
    stop("Invalid source normalization contract header.", call. = FALSE)
  }
  if (
    !is.list(contract$m_io) ||
    !all(c("source_unit", "canonical_unit", "multiplier") %in% names(contract$m_io)) ||
    !is.numeric(contract$m_io$multiplier) ||
    length(contract$m_io$multiplier) != 1L ||
    !is.finite(contract$m_io$multiplier) || contract$m_io$multiplier <= 0
  ) {
    stop("Invalid m_io normalization contract.", call. = FALSE)
  }
  required_sea <- c("variable", "source_unit", "canonical_unit", "multiplier")
  if (
    !is.data.frame(contract$sea) ||
    !identical(names(contract$sea), required_sea) ||
    !nrow(contract$sea) ||
    anyNA(contract$sea) ||
    any(!nzchar(contract$sea$variable)) ||
    anyDuplicated(contract$sea$variable) ||
    any(!is.finite(contract$sea$multiplier)) ||
    any(contract$sea$multiplier <= 0)
  ) {
    stop("Invalid SEA normalization contract.", call. = FALSE)
  }
  invisible(contract)
}

wlv_source_normalization_marker <- function(value) {
  attr(value, wlv_source_normalization_marker_name, exact = TRUE)
}

wlv_validate_source_array <- function(value, artifact, contract) {
  dimensions <- switch(artifact, m_io = 3L, sea = 4L)
  if (
    !is.array(value) ||
    !(is.double(value) || is.integer(value)) ||
    length(dim(value)) != dimensions ||
    any(dim(value) <= 0L)
  ) {
    stop(
      sprintf("`%s` must be a non-empty numeric %s-dimensional array.", artifact, dimensions),
      call. = FALSE
    )
  }
  labels <- dimnames(value)
  invalid_labels <-
    is.null(labels) ||
    length(labels) != dimensions ||
    any(vapply(labels, is.null, logical(1))) ||
    any(vapply(labels, function(x) anyNA(x) || any(!nzchar(x)), logical(1))) ||
    any(vapply(labels, anyDuplicated, integer(1)) > 0L)
  if (invalid_labels) {
    stop(
      sprintf("`%s` must have complete, non-duplicated labels on every axis.", artifact),
      call. = FALSE
    )
  }
  marker <- wlv_source_normalization_marker(value)
  if (!is.null(marker)) {
    marker_id <- if (is.list(marker) && !is.null(marker$contract_id)) {
      as.character(marker$contract_id)
    } else {
      "unknown"
    }
    stop(
      sprintf("`%s` is already source-normalized by `%s`.", artifact, marker_id),
      call. = FALSE
    )
  }
  if (identical(artifact, "sea")) {
    expected <- contract$sea$variable
    actual <- labels[[2L]]
    missing <- setdiff(expected, actual)
    unexpected <- setdiff(actual, expected)
    if (length(missing) || length(unexpected)) {
      details <- c(
        if (length(missing)) paste0("missing: ", paste(missing, collapse = ", ")),
        if (length(unexpected)) {
          paste0("unexpected: ", paste(unexpected, collapse = ", "))
        }
      )
      stop(
        sprintf(
          "SEA variable coverage differs from the contract (%s).",
          paste(details, collapse = "; ")
        ),
        call. = FALSE
      )
    }
  }
  invisible(value)
}

wlv_source_normalization_marker_value <- function(contract, artifact) {
  list(
    schema_version = contract$schema_version,
    contract_id = contract$contract_id,
    source = contract$source,
    artifact = artifact,
    canonical = TRUE
  )
}

wlv_normalize_source_array <- function(value, contract, artifact = c("m_io", "sea")) {
  artifact <- match.arg(artifact)
  wlv_validate_source_normalization_contract(contract)
  wlv_validate_source_array(value, artifact, contract)

  if (identical(artifact, "m_io")) {
    result <- value * contract$m_io$multiplier
  } else {
    result <- value
    multipliers <- stats::setNames(
      contract$sea$multiplier,
      contract$sea$variable
    )
    for (variable in dimnames(result)[[2L]]) {
      result[, variable, , ] <- result[, variable, , ] * multipliers[[variable]]
    }
  }
  attr(result, wlv_source_normalization_marker_name) <-
    wlv_source_normalization_marker_value(contract, artifact)
  result
}

wlv_normalize_source <- function(
    m_io,
    sea,
    source,
    contract = wlv_source_normalization_contract(source)) {
  wlv_validate_source_normalization_contract(contract)
  if (!identical(source, contract$source)) {
    stop(
      sprintf(
        "Requested source `%s` does not match contract source `%s`.",
        source,
        contract$source
      ),
      call. = FALSE
    )
  }

  # Validate both inputs before constructing either result, so a rejected pair
  # cannot leave a partially normalized return value.
  wlv_validate_source_array(m_io, "m_io", contract)
  wlv_validate_source_array(sea, "sea", contract)

  list(
    m_io = wlv_normalize_source_array(m_io, contract, "m_io"),
    sea = wlv_normalize_source_array(sea, contract, "sea"),
    contract = contract
  )
}

wlv_source_normalization_table <- function(contract) {
  wlv_validate_source_normalization_contract(contract)
  rbind(
    data.frame(
      artifact = "m_io",
      variable = "*",
      source_unit = contract$m_io$source_unit,
      canonical_unit = contract$m_io$canonical_unit,
      multiplier = format(
        contract$m_io$multiplier,
        scientific = FALSE,
        trim = TRUE,
        digits = 17L
      ),
      stringsAsFactors = FALSE,
      check.names = FALSE
    ),
    data.frame(
      artifact = rep("sea", nrow(contract$sea)),
      variable = contract$sea$variable,
      source_unit = contract$sea$source_unit,
      canonical_unit = contract$sea$canonical_unit,
      multiplier = vapply(
        contract$sea$multiplier,
        format,
        character(1L),
        scientific = FALSE,
        trim = TRUE,
        digits = 17L
      ),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
}

wlv_source_write_semicolon_table <- function(value, path) {
  if (!is.data.frame(value) || !nrow(value) || !dir.exists(dirname(path))) {
    stop("Cannot write an empty source contract table.", call. = FALSE)
  }
  value <- as.data.frame(
    lapply(value, as.character),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  temporary <- tempfile(
    pattern = paste0(".", basename(path), "-"),
    tmpdir = dirname(path),
    fileext = ".csv"
  )
  on.exit(unlink(temporary, force = TRUE), add = TRUE)
  utils::write.table(
    value,
    temporary,
    sep = ";",
    row.names = FALSE,
    col.names = TRUE,
    quote = TRUE,
    qmethod = "double",
    eol = "\n",
    fileEncoding = "UTF-8"
  )
  roundtrip <- utils::read.csv2(
    temporary,
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL,
    fileEncoding = "UTF-8"
  )
  if (!identical(value, roundtrip)) {
    stop("Source contract table failed exact UTF-8 round-trip verification.", call. = FALSE)
  }
  if (!file.rename(temporary, path)) {
    stop(sprintf("Could not install source contract table `%s`.", path), call. = FALSE)
  }
  invisible(path)
}

wlv_source_generation_path_is_within <- function(path, parent) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  parent <- normalizePath(parent, winslash = "/", mustWork = TRUE)
  comparison <- c(path, parent)
  if (.Platform$OS.type == "windows") {
    comparison <- tolower(comparison)
  }
  startsWith(comparison[[1L]], paste0(sub("/+$", "", comparison[[2L]]), "/"))
}

wlv_publish_normalized_source <- function(
    normalized,
    source_dir,
    unit_contract_id,
    unit_contract_version,
    unit_contract_paths,
    unit_contract_sidecar,
    label_files = c("countries.csv", "sectors.csv", "demand.csv"),
    gfcf_observations = NULL,
    writer = write_fst_array) {
  if (
    !is.list(normalized) ||
    !all(c("m_io", "sea", "contract") %in% names(normalized)) ||
    !is.function(writer) ||
    !dir.exists(source_dir)
  ) {
    stop("Invalid normalized source publication request.", call. = FALSE)
  }
  contract <- normalized$contract
  wlv_validate_source_normalization_contract(contract)
  for (artifact in c("m_io", "sea")) {
    marker <- wlv_source_normalization_marker(normalized[[artifact]])
    if (
      !is.list(marker) || !isTRUE(marker$canonical) ||
      !identical(marker$contract_id, contract$contract_id) ||
      !identical(marker$artifact, artifact)
    ) {
      stop(sprintf("Normalized `%s` lacks its canonical marker.", artifact), call. = FALSE)
    }
  }
  if (
    !is.character(unit_contract_id) || length(unit_contract_id) != 1L ||
    is.na(unit_contract_id) || !nzchar(unit_contract_id) ||
    !is.character(unit_contract_version) || length(unit_contract_version) != 1L ||
    is.na(unit_contract_version) || !nzchar(unit_contract_version) ||
    !is.data.frame(unit_contract_sidecar) || !nrow(unit_contract_sidecar)
  ) {
    stop("Invalid unit contract publication metadata.", call. = FALSE)
  }
  missing_labels <- label_files[!file.exists(file.path(source_dir, label_files))]
  if (length(missing_labels)) {
    stop(
      sprintf("Normalized source labels are missing: %s.", paste(missing_labels, collapse = ", ")),
      call. = FALSE
    )
  }
  if (!is.null(gfcf_observations) && !is.data.frame(gfcf_observations)) {
    stop("`gfcf_observations` must be NULL or a data frame.", call. = FALSE)
  }

  source_dir <- normalizePath(source_dir, winslash = "/", mustWork = TRUE)
  staging <- tempfile(".normalized-staging-", tmpdir = source_dir)
  backup <- tempfile(".normalized-backup-", tmpdir = source_dir)
  final <- file.path(source_dir, "normalized")
  safe_paths <- vapply(
    c(staging, backup, final),
    wlv_source_generation_path_is_within,
    logical(1L),
    parent = source_dir
  )
  if (!all(safe_paths) || !startsWith(basename(staging), ".normalized-staging-") ||
      !startsWith(basename(backup), ".normalized-backup-")) {
    stop("Refusing to publish normalized data through an unsafe path.", call. = FALSE)
  }
  if (!dir.create(staging, recursive = FALSE, showWarnings = FALSE)) {
    stop("Could not create normalized source staging.", call. = FALSE)
  }
  staging_open <- TRUE
  backup_open <- FALSE
  on.exit({
    if (staging_open && dir.exists(staging)) {
      unlink(staging, recursive = TRUE, force = TRUE)
    }
    if (backup_open && dir.exists(backup) && !dir.exists(final)) {
      file.rename(backup, final)
    }
  }, add = TRUE)

  writer(normalized$m_io, file.path(staging, "m_io.fst"))
  writer(normalized$sea, file.path(staging, "sea.fst"))
  copied <- file.copy(
    file.path(source_dir, label_files),
    file.path(staging, label_files),
    overwrite = FALSE,
    copy.mode = TRUE
  )
  if (!all(copied)) {
    stop("Could not stage normalized source labels.", call. = FALSE)
  }
  wlv_source_write_semicolon_table(
    wlv_source_normalization_table(contract),
    file.path(staging, "_normalization_contract.csv")
  )
  wlv_source_write_semicolon_table(
    unit_contract_sidecar,
    file.path(staging, "_unit_contract.csv")
  )
  if (!is.null(gfcf_observations)) {
    saveRDS(
      gfcf_observations,
      file.path(staging, "_gfcf_canonical.rds"),
      version = 3L
    )
  }

  artifacts <- c(
    "_normalization_contract.csv", "_unit_contract.csv",
    label_files,
    "m_io.fst", "m_io.fst.meta", "sea.fst", "sea.fst.meta"
  )
  roles <- c(
    "normalization_contract", "unit_contract",
    rep("label", length(label_files)),
    "input_output", "array_metadata", "socioeconomic", "array_metadata"
  )
  if (!is.null(gfcf_observations)) {
    artifacts <- c(artifacts, "_gfcf_canonical.rds")
    roles <- c(roles, "raw_gfcf_diagnostic")
  }
  manifest <- wlv_build_source_manifest(
    source_root = staging,
    artifacts = artifacts,
    artifact_roles = roles,
    contract_path = unit_contract_paths,
    contract_id = unit_contract_id,
    contract_version = unit_contract_version
  )
  wlv_write_source_manifest(manifest, file.path(staging, "_source_manifest.csv"))

  if (dir.exists(final)) {
    if (!file.rename(final, backup)) {
      stop("Could not preserve the previous normalized source generation.", call. = FALSE)
    }
    backup_open <- TRUE
  }
  if (!file.rename(staging, final)) {
    if (backup_open) {
      file.rename(backup, final)
      backup_open <- FALSE
    }
    stop("Could not install the normalized source generation.", call. = FALSE)
  }
  staging_open <- FALSE
  if (backup_open) {
    unlink(backup, recursive = TRUE, force = TRUE)
    if (dir.exists(backup)) {
      warning("Normalized source published, but its previous backup remains.", call. = FALSE)
    }
    backup_open <- FALSE
  }
  invisible(manifest)
}
