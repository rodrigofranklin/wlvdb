# Native WIOD 2013 preparation --------------------------------------------

wlv_wiodr13_mat_members_native <- function() {
  c("WIOT95_00.mat", "WIOT01_05.mat", "WIOT06_09.mat", "WIOT08_11.mat")
}

wlv_wiodr13_download_manifest_native <- function(root) {
  source_dir <- file.path(root, "source_data", "wiodr13")
  list(
    wiots = list(
      url = "https://dataverse.nl/api/access/datafile/199125",
      destination = file.path(source_dir, "WIOTS_in_MATLAB.zip"),
      size = 292278662,
      hash_algorithm = "sha1",
      hash = "7e921fda5e3b80605a27e7404ac16fbf1f5a3cd7"
    ),
    sea = list(
      url = "https://dataverse.nl/api/access/datafile/199111",
      destination = file.path(
        source_dir,
        "Socio_Economic_Accounts_July14.xlsx"
      ),
      size = 7831205,
      hash_algorithm = "sha1",
      hash = "4056b31e2399fd2bb92a311109f279f07ff15faa"
    )
  )
}

wlv_wiodr13_required_services_native <- function() {
  unique(c(
    "download_verified",
    "validate_zip_members",
    "excel_sheets",
    "read_excel",
    "unzip",
    "read_mat",
    "write_label_table",
    "validate_wiodr13_workbook_missingness",
    "validate_wiodr13_arrays",
    "canonical_gfcf_observations",
    "catalog_unit_contract",
    "catalog_unit_contract_sidecar",
    "normalize_source",
    "publish_normalized_source",
    "write_fst_array",
    wlv_euklems_required_services()
  ))
}

wlv_validate_wiodr13_sea_workbook_native <- function(
    path,
    excel_sheets,
    read_excel) {
  sheets <- excel_sheets(path)
  if (!"DATA" %in% sheets) {
    stop("WIOD13 SEA workbook lacks the `DATA` sheet.", call. = FALSE)
  }
  columns <- names(read_excel(path, sheet = "DATA", n_max = 0))
  required_columns <- c(
    "Country", "Variable", "Description", "Code", paste0("_", 1995:2011)
  )
  missing <- setdiff(required_columns, columns)
  if (length(missing)) {
    stop(
      sprintf(
        "WIOD13 SEA workbook lacks columns: %s",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

wlv_assert_wiodr13_wiot_dimensions_native <- function(value, expected, label) {
  if (!identical(dim(value), as.integer(expected))) {
    stop(
      sprintf(
        "%s has dimensions %s; expected %s.",
        label,
        paste(dim(value), collapse = " x "),
        paste(expected, collapse = " x ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

wlv_prepare_wiodr13_task <- function(ctx) {
  catalog <- ctx$catalog()
  source_record <- ctx$source_record()
  if (!inherits(catalog, "wlv_catalog") ||
      !is.data.frame(source_record) || nrow(source_record) != 1L ||
      !identical(as.character(source_record$source[[1L]]), "wiodr13")) {
    stop(
      "WIOD13 preparation requires its validated catalog and source record.",
      call. = FALSE
    )
  }

  ensure_directory <- ctx$service("ensure_directory")
  cache_dir <- ensure_directory(ctx$path("source_data", "wiodr13"))
  stage_dir <- ensure_directory(ctx$stage_path("source_data", "wiodr13"))

  mat_members <- wlv_wiodr13_mat_members_native()
  download_manifest <- wlv_wiodr13_download_manifest_native(ctx$root)
  download_verified <- ctx$service("download_verified")
  validate_zip_members <- ctx$service("validate_zip_members")
  excel_sheets <- ctx$service("excel_sheets")
  read_excel <- ctx$service("read_excel")

  wiots_manifest <- download_manifest$wiots
  download_verified(
    url = wiots_manifest$url,
    destination = normalizePath(
      wiots_manifest$destination,
      winslash = "/",
      mustWork = FALSE
    ),
    expected_size = wiots_manifest$size,
    expected_hash = wiots_manifest$hash,
    hash_algorithm = wiots_manifest$hash_algorithm,
    validator = function(path) validate_zip_members(path, mat_members)
  )
  sea_manifest <- download_manifest$sea
  download_verified(
    url = sea_manifest$url,
    destination = normalizePath(
      sea_manifest$destination,
      winslash = "/",
      mustWork = FALSE
    ),
    expected_size = sea_manifest$size,
    expected_hash = sea_manifest$hash,
    hash_algorithm = sea_manifest$hash_algorithm,
    validator = function(path) {
      wlv_validate_wiodr13_sea_workbook_native(
        path,
        excel_sheets = excel_sheets,
        read_excel = read_excel
      )
    }
  )
  ctx$checkpoint("wiodr13_after_downloads")
  message("Converting WIOD13 files...")

  sea <- as.data.frame(
    read_excel(
      sea_manifest$destination,
      sheet = "DATA",
      col_names = TRUE,
      na = "NA"
    )
  )
  colnames(sea) <- tolower(gsub("_", "", colnames(sea), fixed = TRUE))
  required_sea_columns <- c(
    "country", "variable", "description", "code", as.character(1995:2009)
  )
  missing_sea_columns <- setdiff(required_sea_columns, colnames(sea))
  if (length(missing_sea_columns)) {
    stop(
      sprintf(
        "Prepared WIOD13 SEA data lacks columns: %s",
        paste(missing_sea_columns, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (anyNA(sea[c("country", "variable", "description", "code")])) {
    stop("WIOD13 SEA identifiers contain missing values.", call. = FALSE)
  }
  if (anyDuplicated(sea[c("country", "variable", "code")])) {
    stop(
      "WIOD13 SEA contains duplicate country-variable-sector rows.",
      call. = FALSE
    )
  }

  sea_year_columns <- as.character(1995:2009)
  sea_missingness <- ctx$service(
    "validate_wiodr13_workbook_missingness"
  )(sea, years = sea_year_columns)
  sea_missing_by_year <- sea_missingness$by_year
  sea_missing_values <- sea_missingness$count
  message(sprintf(
    paste0(
      "WIOD13 SEA: replacing %s pinned missing observations with zero for ",
      "1995-2009 (%s; md5=%s)."
    ),
    sea_missing_values,
    paste(
      names(sea_missing_by_year),
      sea_missing_by_year,
      sep = "=",
      collapse = ", "
    ),
    sea_missingness$md5
  ))
  for (year_column in sea_year_columns) {
    sea[[year_column]][is.na(sea[[year_column]])] <- 0
  }

  lists <- list(
    years = as.character(1995:2009),
    countries = unique(sea$country),
    sea_variables = unique(sea$variable),
    sectors = unique(sea$code)
  )
  if (
    length(lists$countries) != 40L ||
      length(lists$sea_variables) != 25L ||
      length(lists$sectors) != 36L ||
      !identical(lists$sectors[[1L]], "TOT")
  ) {
    stop(
      paste0(
        "WIOD13 SEA dimensions differ from the expected 40 countries, ",
        "25 variables and 36 sectors."
      ),
      call. = FALSE
    )
  }
  lists$sea_variables <- c(lists$sea_variables, "VA_USD", "GO_USD")
  lists$countries <- c(lists$countries, "ROW")
  nums <- list(
    years = length(lists$years),
    sea_variables = length(lists$sea_variables),
    countries = length(lists$countries),
    sectors = length(lists$sectors)
  )
  sea_source <- array(
    NA_real_,
    dim = c(
      nums$years,
      nums$sea_variables,
      nums$sectors,
      nums$countries
    ),
    dimnames = list(
      lists$years,
      lists$sea_variables,
      lists$sectors,
      lists$countries
    )
  )
  year_indexes <- seq_len(nums$years)
  for (row_index in seq_len(nrow(sea))) {
    sea_source[
      year_indexes,
      sea$variable[[row_index]],
      sea$code[[row_index]],
      sea$country[[row_index]]
    ] <- as.matrix(sea[row_index, year_indexes + 4L])
  }
  lists$sectors <- lists$sectors[-1L]
  nums$sectors <- length(lists$sectors)
  sea_source <- sea_source[, , lists$sectors, , drop = FALSE]

  unzip_archive <- ctx$service("unzip")
  unzip_archive(
    wiots_manifest$destination,
    files = mat_members,
    exdir = stage_dir,
    overwrite = TRUE
  )
  mat_paths <- file.path(stage_dir, mat_members)
  missing_mat_paths <- mat_paths[!ctx$service("files_exist")(mat_paths)]
  if (length(missing_mat_paths)) {
    stop(
      sprintf(
        "WIOD13 extraction failed for: %s",
        paste(missing_mat_paths, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  read_mat <- ctx$service("read_mat")
  wiot_1 <- as.matrix(read_mat(mat_paths[[1L]])$WIOT95.00)
  wiot_2 <- as.matrix(read_mat(mat_paths[[2L]])$WIOT01.05)
  wiot_3 <- as.matrix(read_mat(mat_paths[[3L]])$WIOT06.09)
  wiot_4 <- as.matrix(read_mat(mat_paths[[4L]])$WIOT08.11)
  wlv_assert_wiodr13_wiot_dimensions_native(
    wiot_1,
    c(1443, 1641 * 6),
    "WIOT95_00.mat"
  )
  wlv_assert_wiodr13_wiot_dimensions_native(
    wiot_2,
    c(1443, 1641 * 5),
    "WIOT01_05.mat"
  )
  wlv_assert_wiodr13_wiot_dimensions_native(
    wiot_3,
    c(1443, 1641 * 4),
    "WIOT06_09.mat"
  )
  wlv_assert_wiodr13_wiot_dimensions_native(
    wiot_4,
    c(1443, 1641 * 4),
    "WIOT08_11.mat"
  )

  m_io <- cbind(wiot_1, wiot_2, wiot_3)
  dim(m_io) <- c(1443, 1641, 15)
  m_io[, , 14:15] <- wiot_4[seq_len(1443), seq_len(1641 * 2)]
  m_io <- aperm(m_io, c(3, 1, 2))
  lists$demand <- paste0("c", c(37, 38, 39, 41, 42))
  nums$demand <- length(lists$demand)
  lists$input <- paste0(
    rep(lists$countries, each = nums$sectors),
    ".",
    rep(lists$sectors, times = nums$countries)
  )
  nums$input <- length(lists$input)
  lists$output <- c(
    lists$input,
    paste0(
      rep(lists$countries, each = nums$demand),
      ".",
      rep(lists$demand, times = nums$countries)
    )
  )
  nums$output <- length(lists$output)
  sea_source[, "VA_USD", , ] <- m_io[, 1441, seq_len(nums$input)]
  sea_source[, "GO_USD", , ] <- m_io[, 1443, seq_len(nums$input)]
  m_io <- m_io[, seq_len(nums$input), seq_len(nums$output), drop = FALSE]
  dimnames(m_io) <- list(lists$years, lists$input, lists$output)
  if (!identical(dim(m_io), c(15L, 1435L, 1640L))) {
    stop(
      "Prepared WIOD13 input-output matrix has unexpected dimensions.",
      call. = FALSE
    )
  }
  if (!identical(dim(sea_source), c(15L, 27L, 35L, 41L))) {
    stop("Prepared WIOD13 SEA array has unexpected dimensions.", call. = FALSE)
  }

  raw_validation <- ctx$service("validate_wiodr13_arrays")(
    m_io = m_io,
    sea = sea_source,
    countries = lists$countries,
    sectors = lists$sectors,
    demands = lists$demand
  )
  message(sprintf(
    paste0(
      "WIOD13 in-memory raw validation passed: %s known negative GFCF ",
      "cells; maximum gross-output residual %.12g."
    ),
    raw_validation$known_negative_gfcf_count,
    raw_validation$maximum_absolute_gross_output_residual
  ))
  ctx$checkpoint("wiodr13_after_validation")

  write_label_table <- ctx$service("write_label_table")
  staged_labels <- c(
    demand = file.path(stage_dir, "demand.csv"),
    countries = file.path(stage_dir, "countries.csv"),
    sectors = file.path(stage_dir, "sectors.csv")
  )
  write_label_table(
    lists$demand,
    staged_labels[["demand"]],
    "demand",
    quote = TRUE
  )
  write_label_table(
    lists$countries,
    staged_labels[["countries"]],
    "country.source",
    quote = TRUE
  )
  write_label_table(
    lists$sectors,
    staged_labels[["sectors"]],
    "sector.source",
    quote = TRUE
  )

  gfcf_observations <- ctx$service("canonical_gfcf_observations")(
    m_io,
    method = "wiodr13"
  )
  unit_contract_id <- as.character(source_record$unit_contract[[1L]])
  unit_contract <- ctx$service("catalog_unit_contract")(
    catalog,
    unit_contract_id
  )
  unit_contract_metadata <- unit_contract$metadata
  unit_contract_paths <- file.path(
    catalog$root,
    unlist(
      unit_contract_metadata[c("units", "aggregations")],
      use.names = FALSE
    )
  )
  unit_contract_sidecar <- ctx$service("catalog_unit_contract_sidecar")(
    catalog,
    unit_contract_id
  )
  normalized <- ctx$service("normalize_source")(
    m_io = m_io,
    sea = sea_source,
    source = "wiodr13"
  )
  source_manifest <- ctx$service("publish_normalized_source")(
    normalized = normalized,
    source_dir = stage_dir,
    unit_contract_id = unit_contract_id,
    unit_contract_version = unit_contract_metadata$schema_version[[1L]],
    unit_contract_paths = unit_contract_paths,
    unit_contract_sidecar = unit_contract_sidecar,
    gfcf_observations = gfcf_observations,
    writer = ctx$service("write_fst_array")
  )
  ctx$checkpoint("wiodr13_after_normalization")

  source_promotions <- list(
    wiodr13.normalized = wlv_preparation_promotion(
      file.path(stage_dir, "normalized"),
      file.path(cache_dir, "normalized")
    ),
    wiodr13.demand = wlv_preparation_promotion(
      staged_labels[["demand"]],
      file.path(cache_dir, "demand.csv")
    ),
    wiodr13.countries = wlv_preparation_promotion(
      staged_labels[["countries"]],
      file.path(cache_dir, "countries.csv")
    ),
    wiodr13.sectors = wlv_preparation_promotion(
      staged_labels[["sectors"]],
      file.path(cache_dir, "sectors.csv")
    )
  )
  source_diagnostics <- list(
    raw_validation = raw_validation,
    sea_missingness = sea_missingness,
    source_manifest = source_manifest,
    download_manifest = download_manifest
  )

  rm(
    m_io,
    sea_source,
    sea,
    wiot_1,
    wiot_2,
    wiot_3,
    wiot_4,
    normalized
  )
  gc(verbose = FALSE)
  euklems <- wlv_prepare_euklems_outputs(
    ctx,
    years = ctx$arg("euklems_years")
  )
  ctx$checkpoint("wiodr13_after_euklems")

  wlv_preparation_result(
    promotions = c(source_promotions, euklems$promotions),
    diagnostics = list(
      wiodr13 = source_diagnostics,
      euklems = euklems$diagnostics
    )
  )
}

wlv_wiodr13_preparation_spec <- function() {
  wlv_preparation_task_spec(
    source = "wiodr13",
    run = wlv_prepare_wiodr13_task,
    services = wlv_wiodr13_required_services_native(),
    parameters = list(
      euklems_years = wlv_preparation_parameter(
        type = "integer_vector",
        default = as.integer(1995:2010),
        validator = function(value) {
          !anyDuplicated(value) && all(value >= 1900L & value <= 2200L)
        }
      )
    ),
    locks = c("wiodr13", "euklems"),
    source_record_required = TRUE
  )
}
