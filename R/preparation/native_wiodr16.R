# Native WIOD 2016 preparation --------------------------------------------

wlv_wiodr16_contract_native <- function() {
  years <- as.character(2000:2014)
  countries <- c(
    "AUS", "AUT", "BEL", "BGR", "BRA", "CAN", "CHE", "CHN", "CYP",
    "CZE", "DEU", "DNK", "ESP", "EST", "FIN", "FRA", "GBR", "GRC",
    "HRV", "HUN", "IDN", "IND", "IRL", "ITA", "JPN", "KOR", "LTU",
    "LUX", "LVA", "MEX", "MLT", "NLD", "NOR", "POL", "PRT", "ROU",
    "RUS", "SVK", "SVN", "SWE", "TUR", "TWN", "USA"
  )
  sea_variables <- c(
    "CAP", "COMP", "EMP", "EMPE", "GO", "GO_PI", "GO_QI", "H_EMPE",
    "II", "II_PI", "II_QI", "K", "LAB", "VA", "VA_PI", "VA_QI"
  )
  sectors <- c(
    "A01", "A02", "A03", "B", "C10-C12", "C13-C15", "C16", "C17",
    "C18", "C19", "C20", "C21", "C22", "C23", "C24", "C25", "C26",
    "C27", "C28", "C29", "C30", "C31_C32", "C33", "D35", "E36",
    "E37-E39", "F", "G45", "G46", "G47", "H49", "H50", "H51", "H52",
    "H53", "I", "J58", "J59_J60", "J61", "J62_J63", "K64", "K65",
    "K66", "L68", "M69_M70", "M71", "M72", "M73", "M74_M75", "N",
    "O84", "P85", "Q", "R_S", "T", "U"
  )
  demand <- paste0("c", 57:61)
  list(
    years = years,
    countries = countries,
    sea_variables = sea_variables,
    sectors = sectors,
    demand = demand,
    rdata_members = sprintf(
      "WIOT%d_October16_ROW.RData",
      as.integer(years)
    )
  )
}

wlv_wiodr16_download_manifest_native <- function(root) {
  source_dir <- file.path(root, "source_data", "wiodr16")
  list(
    wiots = list(
      url = "https://dataverse.nl/api/access/datafile/199101",
      destination = file.path(source_dir, "WIOTS_in_R.zip"),
      size = 641578409,
      hash_algorithm = "sha1",
      hash = "51efc2a6c0358cff485e24d6b4b96ffe27f4e23a"
    ),
    sea = list(
      url = "https://dataverse.nl/api/access/datafile/199095",
      destination = file.path(source_dir, "Socio_Economic_Accounts.xlsx"),
      size = 5536437,
      hash_algorithm = "sha1",
      hash = "821bba29c42f3a42009eb1b14dbdaa2922d01236"
    )
  )
}

wlv_wiodr16_required_services_native <- function() {
  unique(c(
    "download_verified",
    "excel_sheets",
    "read_excel",
    "unzip",
    "load_wiodr16_wiot",
    "write_label_table",
    "validate_wiodr16_sea_data",
    "validate_wiodr16_arrays",
    "canonical_gfcf_observations",
    "catalog_unit_contract",
    "catalog_unit_contract_sidecar",
    "normalize_source",
    "publish_normalized_source",
    "write_fst_array",
    wlv_euklems_required_services()
  ))
}

wlv_validate_wiodr16_archive_native <- function(path, members, unzip_archive) {
  listing <- unzip_archive(path, list = TRUE)
  if (!is.data.frame(listing) || !all(c("Name", "Length") %in% names(listing))) {
    stop("WIOD16 WIOT ZIP listing is invalid.", call. = FALSE)
  }
  missing <- setdiff(members, listing$Name)
  unexpected <- setdiff(listing$Name, members)
  if (length(missing) || length(unexpected)) {
    stop(
      sprintf(
        paste0(
          "WIOD16 WIOT ZIP members differ from the pinned release; ",
          "missing: %s; unexpected: %s."
        ),
        if (length(missing)) paste(missing, collapse = ", ") else "none",
        if (length(unexpected)) paste(unexpected, collapse = ", ") else "none"
      ),
      call. = FALSE
    )
  }
  required_sizes <- listing$Length[match(members, listing$Name)]
  if (anyNA(required_sizes) || any(required_sizes <= 0)) {
    stop("One or more WIOD16 WIOT ZIP members are empty.", call. = FALSE)
  }
  invisible(TRUE)
}

wlv_validate_wiodr16_workbook_native <- function(
    path,
    years,
    excel_sheets,
    read_excel) {
  sheets <- excel_sheets(path)
  if (!"DATA" %in% sheets) {
    stop("WIOD16 SEA workbook lacks the `DATA` sheet.", call. = FALSE)
  }
  columns <- names(read_excel(path, sheet = "DATA", n_max = 0))
  required_columns <- c(
    "country", "variable", "description", "code", years
  )
  missing <- setdiff(required_columns, columns)
  if (length(missing)) {
    stop(
      sprintf(
        "WIOD16 SEA workbook lacks columns: %s",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

wlv_prepare_wiodr16_task <- function(ctx) {
  catalog <- ctx$catalog()
  source_record <- ctx$source_record()
  if (!inherits(catalog, "wlv_catalog") ||
      !is.data.frame(source_record) || nrow(source_record) != 1L ||
      !identical(as.character(source_record$source[[1L]]), "wiodr16")) {
    stop(
      "WIOD16 preparation requires its validated catalog and source record.",
      call. = FALSE
    )
  }
  contract <- wlv_wiodr16_contract_native()
  ensure_directory <- ctx$service("ensure_directory")
  cache_dir <- ensure_directory(ctx$path("source_data", "wiodr16"))
  stage_dir <- ensure_directory(ctx$stage_path("source_data", "wiodr16"))

  download_manifest <- wlv_wiodr16_download_manifest_native(ctx$root)
  download_verified <- ctx$service("download_verified")
  unzip_archive <- ctx$service("unzip")
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
    validator = function(path) {
      wlv_validate_wiodr16_archive_native(
        path,
        members = contract$rdata_members,
        unzip_archive = unzip_archive
      )
    }
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
      wlv_validate_wiodr16_workbook_native(
        path,
        years = contract$years,
        excel_sheets = excel_sheets,
        read_excel = read_excel
      )
    }
  )
  ctx$checkpoint("wiodr16_after_downloads")
  message("Converting WIOD16 files...")

  sea <- as.data.frame(
    read_excel(
      sea_manifest$destination,
      sheet = "DATA",
      col_names = TRUE,
      na = "NA"
    ),
    stringsAsFactors = FALSE
  )
  sea_validation <- ctx$service("validate_wiodr16_sea_data")(
    sea,
    years = contract$years,
    countries = contract$countries,
    variables = contract$sea_variables,
    sectors = contract$sectors
  )
  message(sprintf(
    paste0(
      "WIOD16 SEA: preserving %s documented missing observations ",
      "for CHN EMPE and H_EMPE (%s)."
    ),
    sum(sea_validation$missing_by_year),
    paste(
      names(sea_validation$missing_by_year),
      sea_validation$missing_by_year,
      sep = "=",
      collapse = ", "
    )
  ))

  countries <- c(contract$countries, "ROW")
  sea_variables <- c(contract$sea_variables, "VA_USD", "GO_USD")
  input_labels <- as.vector(vapply(
    countries,
    function(country) paste(country, contract$sectors, sep = "."),
    character(length(contract$sectors))
  ))
  final_demand_labels <- as.vector(vapply(
    countries,
    function(country) paste(country, contract$demand, sep = "."),
    character(length(contract$demand))
  ))
  output_labels <- c(input_labels, final_demand_labels)
  sea_source <- array(
    NA_real_,
    dim = c(
      length(contract$years),
      length(sea_variables),
      length(contract$sectors),
      length(countries)
    ),
    dimnames = list(
      contract$years,
      sea_variables,
      contract$sectors,
      countries
    )
  )
  for (row_index in seq_len(nrow(sea))) {
    sea_source[
      ,
      sea$variable[[row_index]],
      sea$code[[row_index]],
      sea$country[[row_index]]
    ] <- as.numeric(sea[row_index, contract$years])
  }

  unzip_archive(
    wiots_manifest$destination,
    files = contract$rdata_members,
    exdir = stage_dir,
    overwrite = TRUE
  )
  rdata_paths <- file.path(stage_dir, contract$rdata_members)
  missing_rdata_paths <- rdata_paths[
    !ctx$service("files_exist")(rdata_paths)
  ]
  if (length(missing_rdata_paths)) {
    stop(
      sprintf(
        "WIOD16 extraction failed for: %s",
        paste(missing_rdata_paths, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  m_io <- array(
    NA_real_,
    dim = c(
      length(contract$years),
      length(input_labels),
      length(output_labels)
    ),
    dimnames = list(contract$years, input_labels, output_labels)
  )
  load_wiot <- ctx$service("load_wiodr16_wiot")
  for (year_index in seq_along(contract$years)) {
    year <- contract$years[[year_index]]
    message(sprintf("Converting WIOD16 WIOT %s...", year))
    converted <- load_wiot(
      rdata_paths[[year_index]],
      year = year,
      countries = countries,
      sectors = contract$sectors,
      demand = contract$demand
    )
    m_io[year_index, , ] <- converted$m_io
    sea_source[year_index, "VA_USD", , ] <- converted$value_added
    sea_source[year_index, "GO_USD", , ] <- converted$gross_output
    gross_output_residual <- rowSums(converted$m_io) - converted$gross_output
    gross_output_relative_residual <- max(
      abs(gross_output_residual) / pmax(1, abs(converted$gross_output))
    )
    if (gross_output_relative_residual > 1e-8) {
      stop(
        sprintf(
          paste0(
            "WIOD16 %s gross-output identity failed ",
            "(maximum relative residual %.3g)."
          ),
          year,
          gross_output_relative_residual
        ),
        call. = FALSE
      )
    }
    rm(converted)
    gc(verbose = FALSE)
  }

  if (!identical(dim(m_io), c(15L, 2464L, 2684L))) {
    stop(
      "Prepared WIOD16 input-output matrix has unexpected dimensions.",
      call. = FALSE
    )
  }
  if (!identical(dim(sea_source), c(15L, 18L, 56L, 44L))) {
    stop("Prepared WIOD16 SEA array has unexpected dimensions.", call. = FALSE)
  }
  if (anyNA(m_io) || any(!is.finite(m_io))) {
    stop(
      "Prepared WIOD16 input-output matrix contains missing or non-finite values.",
      call. = FALSE
    )
  }
  documented_sea_missing <- array(
    FALSE,
    dim = dim(sea_source),
    dimnames = dimnames(sea_source)
  )
  documented_sea_missing[, contract$sea_variables, , "ROW"] <- TRUE
  documented_sea_missing[, c("EMPE", "H_EMPE"), , "CHN"] <- TRUE
  if (!identical(is.na(sea_source), documented_sea_missing)) {
    stop(
      paste0(
        "Prepared WIOD16 SEA missingness differs from the documented ",
        "ROW/China profile."
      ),
      call. = FALSE
    )
  }
  if (any(!is.finite(sea_source[!documented_sea_missing]))) {
    stop(
      "Prepared WIOD16 SEA array contains unexpected non-finite values.",
      call. = FALSE
    )
  }

  preparation_validation <- ctx$service("validate_wiodr16_arrays")(
    m_io = m_io,
    sea = sea_source,
    countries = countries,
    sectors = contract$sectors,
    demands = contract$demand
  )
  message(sprintf(
    paste0(
      "WIOD16 in-memory validation passed: %s documented SEA missing values; ",
      "maximum gross-output residual %.12g."
    ),
    preparation_validation$observed_total_na_count,
    preparation_validation$maximum_absolute_gross_output_residual
  ))
  ctx$checkpoint("wiodr16_after_validation")

  write_label_table <- ctx$service("write_label_table")
  staged_labels <- c(
    demand = file.path(stage_dir, "demand.csv"),
    countries = file.path(stage_dir, "countries.csv"),
    sectors = file.path(stage_dir, "sectors.csv")
  )
  write_label_table(
    contract$demand,
    staged_labels[["demand"]],
    "demand",
    quote = FALSE
  )
  write_label_table(
    countries,
    staged_labels[["countries"]],
    "country.source",
    quote = FALSE
  )
  write_label_table(
    contract$sectors,
    staged_labels[["sectors"]],
    "sector.source",
    quote = FALSE
  )

  gfcf_observations <- ctx$service("canonical_gfcf_observations")(
    m_io,
    method = "wiodr16"
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
    source = "wiodr16"
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
  ctx$checkpoint("wiodr16_after_normalization")

  source_promotions <- list(
    wiodr16.normalized = wlv_preparation_promotion(
      file.path(stage_dir, "normalized"),
      file.path(cache_dir, "normalized")
    ),
    wiodr16.demand = wlv_preparation_promotion(
      staged_labels[["demand"]],
      file.path(cache_dir, "demand.csv")
    ),
    wiodr16.countries = wlv_preparation_promotion(
      staged_labels[["countries"]],
      file.path(cache_dir, "countries.csv")
    ),
    wiodr16.sectors = wlv_preparation_promotion(
      staged_labels[["sectors"]],
      file.path(cache_dir, "sectors.csv")
    )
  )
  source_diagnostics <- list(
    validation = preparation_validation,
    sea_missingness = sea_validation,
    source_manifest = source_manifest,
    download_manifest = download_manifest
  )

  rm(m_io, sea_source, sea, documented_sea_missing, normalized)
  gc(verbose = FALSE)
  euklems <- wlv_prepare_euklems_outputs(
    ctx,
    years = ctx$arg("euklems_years")
  )
  ctx$checkpoint("wiodr16_after_euklems")

  wlv_preparation_result(
    promotions = c(source_promotions, euklems$promotions),
    diagnostics = list(
      wiodr16 = source_diagnostics,
      euklems = euklems$diagnostics
    )
  )
}

wlv_wiodr16_preparation_spec <- function() {
  wlv_preparation_task_spec(
    source = "wiodr16",
    run = wlv_prepare_wiodr16_task,
    services = wlv_wiodr16_required_services_native(),
    parameters = list(
      euklems_years = wlv_preparation_parameter(
        type = "integer_vector",
        default = as.integer(2000:2015),
        validator = function(value) {
          !anyDuplicated(value) && all(value >= 1900L & value <= 2200L)
        }
      )
    ),
    locks = c("wiodr16", "euklems"),
    source_record_required = TRUE
  )
}
