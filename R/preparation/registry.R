# Native preparation registry and production services ---------------------

wlv_write_preparation_label_table <- function(
    values,
    destination,
    column_name,
    quote = TRUE) {
  if (!dir.exists(dirname(destination))) {
    stop("Preparation label destination directory does not exist.", call. = FALSE)
  }
  staged <- tempfile(
    pattern = paste0(".", basename(destination), "-write-"),
    tmpdir = dirname(destination),
    fileext = ".csv"
  )
  on.exit({
    if (file.exists(staged)) unlink(staged, force = TRUE)
  }, add = TRUE)
  table <- data.frame(values, stringsAsFactors = FALSE, check.names = FALSE)
  names(table) <- column_name
  utils::write.table(
    table,
    staged,
    row.names = FALSE,
    quote = quote,
    sep = ";"
  )
  wlv_install_files(staged, destination)
  invisible(destination)
}

wlv_default_preparation_services <- function() {
  list(
    ensure_directory = function(path) {
      if (!is.character(path) || length(path) != 1L || is.na(path) ||
          !nzchar(path)) {
        stop("Preparation directory must be one non-empty path.", call. = FALSE)
      }
      dir.create(path, recursive = TRUE, showWarnings = FALSE)
      if (!dir.exists(path)) {
        stop(sprintf("Cannot create preparation directory `%s`.", path), call. = FALSE)
      }
      normalizePath(path, winslash = "/", mustWork = TRUE)
    },
    files_exist = function(paths) {
      if (!is.character(paths) || anyNA(paths)) {
        stop("Preparation paths must be a character vector without NA.", call. = FALSE)
      }
      exists <- file.exists(paths)
      exists[exists] <- !file.info(paths[exists])$isdir
      exists
    },
    download_verified = wlv_download_verified,
    validate_zip_members = wlv_validate_zip_members,
    excel_sheets = readxl::excel_sheets,
    read_excel = readxl::read_excel,
    unzip = utils::unzip,
    read_mat = R.matlab::readMat,
    read_rds = base::readRDS,
    read_csv2 = utils::read.csv2,
    load_wiodr16_wiot = wlv_load_wiodr16_wiot,
    write_label_table = wlv_write_preparation_label_table,
    write_fst = function(value, destination) {
      wlv_write_fst_atomic(
        value,
        destination,
        writer = fst::write_fst
      )
    },
    write_fst_array = write_fst_array,
    validate_wiodr13_workbook_missingness =
      wlv_wiodr13_validate_workbook_missingness,
    validate_wiodr13_arrays = wlv_validate_wiodr13_arrays,
    validate_wiodr16_sea_data = wlv_validate_wiodr16_sea_data,
    validate_wiodr16_arrays = wlv_validate_wiodr16_arrays,
    canonical_gfcf_observations =
      wlv_wiodr_canonical_gfcf_diagnostic_observations,
    catalog_unit_contract = wlv_catalog_unit_contract,
    catalog_unit_contract_sidecar = wlv_catalog_unit_contract_sidecar,
    normalize_source = wlv_normalize_source,
    publish_normalized_source = wlv_publish_normalized_source,
    add_synthetic_depreciation_component =
      wlv_add_synthetic_depreciation_component
  )
}

wlv_default_preparation_registry <- function() {
  wlv_preparation_registry(
    wlv_euklems_preparation_spec(),
    wlv_wiodr13_preparation_spec(),
    wlv_wiodr16_preparation_spec()
  )
}
