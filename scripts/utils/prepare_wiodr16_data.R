# Download and prepare WIOD 2016 data.

if (!exists("wlv_download_verified", mode = "function", inherits = FALSE)) {
  sys.source("scripts/utils/preparation_downloads.R", envir = environment())
}
if (!exists("write_fst_array", mode = "function", inherits = FALSE)) {
  sys.source("scripts/lib/functions.R", envir = environment())
}
if (!exists("wiodr16_download_manifest", inherits = FALSE)) {
  sys.source("scripts/utils/wiodr16_preparation.R", envir = environment())
}
if (!exists("wlv_normalize_source", mode = "function", inherits = FALSE)) {
  sys.source("scripts/lib/source_normalization.R", envir = environment())
}
if (!exists("wlv_build_source_manifest", mode = "function", inherits = FALSE)) {
  sys.source("scripts/lib/source_manifest.R", envir = environment())
}
if (!exists("wlv_catalog_unit_contract", mode = "function", inherits = FALSE)) {
  sys.source("scripts/lib/catalog.R", envir = environment())
}

if (
  !exists("wlv_catalog", inherits = FALSE) ||
    !inherits(wlv_catalog, "wlv_catalog") ||
    !exists("wlv_source_record", inherits = FALSE) ||
    !is.data.frame(wlv_source_record) || nrow(wlv_source_record) != 1L ||
    !identical(wlv_source_record$source[[1L]], "wiodr16")
) {
  stop(
    "WIOD16 preparation requires its validated catalog and source record.",
    call. = FALSE
  )
}

dir.create("source_data", recursive = TRUE, showWarnings = FALSE)
dir.create("source_data/wiodr16", recursive = TRUE, showWarnings = FALSE)
if (!dir.exists("source_data/wiodr16")) {
  stop("Cannot create WIOD16 source-data directory.", call. = FALSE)
}

wiots_manifest <- wiodr16_download_manifest()$wiots
wlv_download_verified(
  url = wiots_manifest$url,
  destination = wiots_manifest$destination,
  expected_size = wiots_manifest$size,
  expected_hash = wiots_manifest$hash,
  hash_algorithm = wiots_manifest$hash_algorithm,
  validator = wlv_validate_wiodr16_wiots_archive
)

sea_manifest <- wiodr16_download_manifest()$sea
wlv_download_verified(
  url = sea_manifest$url,
  destination = sea_manifest$destination,
  expected_size = sea_manifest$size,
  expected_hash = sea_manifest$hash,
  hash_algorithm = sea_manifest$hash_algorithm,
  validator = wlv_validate_wiodr16_sea_workbook
)

message("Converting WIOD16 files...")

sea <- as.data.frame(
  readxl::read_excel(
    sea_manifest$destination,
    sheet = "DATA",
    col_names = TRUE,
    na = "NA"
  ),
  stringsAsFactors = FALSE
)
sea_validation <- wlv_validate_wiodr16_sea_data(sea)
message(
  sprintf(
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
  )
)

countries <- c(wiodr16_countries(), "ROW")
sea_variables <- c(wiodr16_sea_variables(), "VA_USD", "GO_USD")
input_labels <- as.vector(vapply(
  countries,
  function(country) paste(country, wiodr16_sectors(), sep = "."),
  character(length(wiodr16_sectors()))
))
final_demand_labels <- as.vector(vapply(
  countries,
  function(country) paste(country, wiodr16_demand(), sep = "."),
  character(length(wiodr16_demand()))
))
output_labels <- c(input_labels, final_demand_labels)

sea_source <- array(
  NA_real_,
  dim = c(
    length(wiodr16_years()), length(sea_variables), length(wiodr16_sectors()),
    length(countries)
  ),
  dimnames = list(
    wiodr16_years(), sea_variables, wiodr16_sectors(), countries
  )
)
for (row_index in seq_len(nrow(sea))) {
  sea_source[
    , sea$variable[[row_index]], sea$code[[row_index]], sea$country[[row_index]]
  ] <- as.numeric(sea[row_index, wiodr16_years()])
}

utils::unzip(
  wiots_manifest$destination,
  files = wiodr16_rdata_members(),
  exdir = "source_data/wiodr16",
  overwrite = TRUE
)
wiodr16_rdata_paths <- file.path("source_data/wiodr16", wiodr16_rdata_members())
missing_rdata_paths <- wiodr16_rdata_paths[!file.exists(wiodr16_rdata_paths)]
if (length(missing_rdata_paths)) {
  stop(
    sprintf("WIOD16 extraction failed for: %s", paste(missing_rdata_paths, collapse = ", ")),
    call. = FALSE
  )
}

m_io <- array(
  NA_real_,
  dim = c(length(wiodr16_years()), length(input_labels), length(output_labels)),
  dimnames = list(wiodr16_years(), input_labels, output_labels)
)
for (year_index in seq_along(wiodr16_years())) {
  year <- wiodr16_years()[[year_index]]
  message(sprintf("Converting WIOD16 WIOT %s...", year))
  converted <- wlv_load_wiodr16_wiot(
    wiodr16_rdata_paths[[year_index]],
    year = year
  )
  m_io[year_index, , ] <- converted$m_io
  sea_source[year_index, "VA_USD", , ] <- converted$value_added
  sea_source[year_index, "GO_USD", , ] <- converted$gross_output
  gross_output_residual <-
    rowSums(converted$m_io) - converted$gross_output
  gross_output_relative_residual <- max(
    abs(gross_output_residual) / pmax(1, abs(converted$gross_output))
  )
  if (gross_output_relative_residual > 1e-8) {
    stop(
      sprintf(
        "WIOD16 %s gross-output identity failed (maximum relative residual %.3g).",
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
  stop("Prepared WIOD16 input-output matrix has unexpected dimensions.", call. = FALSE)
}
if (!identical(dim(sea_source), c(15L, 18L, 56L, 44L))) {
  stop("Prepared WIOD16 SEA array has unexpected dimensions.", call. = FALSE)
}
if (anyNA(m_io) || any(!is.finite(m_io))) {
  stop("Prepared WIOD16 input-output matrix contains missing or non-finite values.", call. = FALSE)
}
documented_sea_missing <- array(
  FALSE,
  dim = dim(sea_source),
  dimnames = dimnames(sea_source)
)
documented_sea_missing[, wiodr16_sea_variables(), , "ROW"] <- TRUE
documented_sea_missing[, c("EMPE", "H_EMPE"), , "CHN"] <- TRUE
if (!identical(is.na(sea_source), documented_sea_missing)) {
  stop(
    "Prepared WIOD16 SEA missingness differs from the documented ROW/China profile.",
    call. = FALSE
  )
}
if (any(!is.finite(sea_source[!documented_sea_missing]))) {
  stop("Prepared WIOD16 SEA array contains unexpected non-finite values.", call. = FALSE)
}

# Run the complete semantic validation before installing any prepared output.
if (!exists("wlv_wiodr13_validate_labels", mode = "function", inherits = FALSE)) {
  sys.source("scripts/lib/wiodr13_validation.R", envir = environment())
}
if (!exists("wlv_validate_wiodr16_arrays", mode = "function", inherits = FALSE)) {
  sys.source("scripts/lib/wiodr16_validation.R", envir = environment())
}
preparation_validation <- wlv_validate_wiodr16_arrays(
  m_io = m_io,
  sea = sea_source,
  countries = countries,
  sectors = wiodr16_sectors(),
  demands = wiodr16_demand()
)
message(
  sprintf(
    paste0(
      "WIOD16 in-memory validation passed: %s documented SEA missing values; ",
      "maximum gross-output residual %.12g."
    ),
    preparation_validation$observed_total_na_count,
    preparation_validation$maximum_absolute_gross_output_residual
  )
)

wlv_write_wiodr16_labels <- function(values, destination, column_name) {
  staged_path <- tempfile(
    pattern = paste0(".", basename(destination), "-write-"),
    tmpdir = dirname(destination),
    fileext = ".csv"
  )
  on.exit({
    if (file.exists(staged_path)) {
      unlink(staged_path, force = TRUE)
    }
  }, add = TRUE)
  table <- data.frame(values, stringsAsFactors = FALSE, check.names = FALSE)
  names(table) <- column_name
  utils::write.table(
    table,
    staged_path,
    row.names = FALSE,
    quote = FALSE,
    sep = ";"
  )
  wlv_install_files(staged_path, destination)
  invisible(destination)
}
wlv_write_wiodr16_labels(
  wiodr16_demand(),
  "source_data/wiodr16/demand.csv",
  "demand"
)
wlv_write_wiodr16_labels(
  countries,
  "source_data/wiodr16/countries.csv",
  "country.source"
)
wlv_write_wiodr16_labels(
  wiodr16_sectors(),
  "source_data/wiodr16/sectors.csv",
  "sector.source"
)

wiodr16_gfcf_observations <-
  wlv_wiodr_canonical_gfcf_diagnostic_observations(
    m_io,
    method = "wiodr16"
  )
wiodr16_unit_contract_id <- wlv_source_record$unit_contract[[1L]]
wiodr16_unit_contract <- wlv_catalog_unit_contract(
  wlv_catalog,
  wiodr16_unit_contract_id
)
wiodr16_unit_contract_metadata <- wiodr16_unit_contract$metadata
wiodr16_unit_contract_paths <- file.path(
  wlv_catalog$root,
  unlist(
    wiodr16_unit_contract_metadata[c("units", "aggregations")],
    use.names = FALSE
  )
)
wiodr16_unit_contract_sidecar <- wlv_catalog_unit_contract_sidecar(
  wlv_catalog,
  wiodr16_unit_contract_id
)
wiodr16_normalized <- wlv_normalize_source(
  m_io = m_io,
  sea = sea_source,
  source = "wiodr16"
)
wiodr16_source_manifest <- wlv_publish_normalized_source(
  normalized = wiodr16_normalized,
  source_dir = "source_data/wiodr16",
  unit_contract_id = wiodr16_unit_contract_id,
  unit_contract_version = wiodr16_unit_contract_metadata$schema_version[[1L]],
  unit_contract_paths = wiodr16_unit_contract_paths,
  unit_contract_sidecar = wiodr16_unit_contract_sidecar,
  gfcf_observations = wiodr16_gfcf_observations,
  writer = write_fst_array
)

# Keep the verified downloads in cache and remove only the extracted RData files.
unlink(wiodr16_rdata_paths, force = TRUE)
if (any(file.exists(wiodr16_rdata_paths))) {
  warning("One or more extracted WIOD16 RData files could not be removed.", call. = FALSE)
}

# Release the large WIOD arrays before preparing the EU KLEMS annual inputs.
rm(
  m_io, sea_source, sea, documented_sea_missing,
  wiodr16_gfcf_observations, wiodr16_unit_contract_id,
  wiodr16_unit_contract, wiodr16_unit_contract_metadata,
  wiodr16_unit_contract_paths, wiodr16_unit_contract_sidecar,
  wiodr16_normalized, wiodr16_source_manifest
)
gc()

wiodr16_preparation_environment <- environment()
wiodr16_had_euklems_years <- exists(
  "wlv_euklems_years",
  envir = wiodr16_preparation_environment,
  inherits = FALSE
)
wiodr16_previous_euklems_years <- if (wiodr16_had_euklems_years) {
  get(
    "wlv_euklems_years",
    envir = wiodr16_preparation_environment,
    inherits = FALSE
  )
} else {
  NULL
}
assign(
  "wlv_euklems_years",
  2000:2015,
  envir = wiodr16_preparation_environment
)
tryCatch(
  sys.source(
    "scripts/utils/prepare_euklems_data.R",
    envir = wiodr16_preparation_environment
  ),
  finally = {
    if (wiodr16_had_euklems_years) {
      assign(
        "wlv_euklems_years",
        wiodr16_previous_euklems_years,
        envir = wiodr16_preparation_environment
      )
    } else if (exists(
      "wlv_euklems_years",
      envir = wiodr16_preparation_environment,
      inherits = FALSE
    )) {
      rm("wlv_euklems_years", envir = wiodr16_preparation_environment)
    }
  }
)
rm(
  wiodr16_preparation_environment,
  wiodr16_had_euklems_years,
  wiodr16_previous_euklems_years
)
gc()
