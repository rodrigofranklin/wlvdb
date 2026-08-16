wlv_fixture_read_csv <- function(path) {
  utils::read.csv(
    path,
    sep = ";",
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

wlv_copy_fixture_tree <- function(source, destination) {
  source <- normalizePath(source, winslash = "/", mustWork = TRUE)
  dir.create(destination, recursive = TRUE, showWarnings = FALSE)

  directories <- normalizePath(
    list.dirs(source, recursive = TRUE, full.names = TRUE),
    winslash = "/",
    mustWork = TRUE
  )
  directories <- directories[directories != source]
  if (length(directories)) {
    relative_directories <- substring(directories, nchar(source) + 2L)
    invisible(lapply(
      file.path(destination, relative_directories),
      dir.create,
      recursive = TRUE,
      showWarnings = FALSE
    ))
  }

  files <- list.files(
    source,
    recursive = TRUE,
    full.names = TRUE,
    all.files = TRUE,
    include.dirs = FALSE,
    no.. = TRUE
  )
  if (!length(files)) {
    return(invisible(destination))
  }

  normalized_files <- normalizePath(files, winslash = "/", mustWork = TRUE)
  relative_files <- substring(normalized_files, nchar(source) + 2L)
  targets <- file.path(destination, relative_files)
  copied <- file.copy(normalized_files, targets, overwrite = TRUE)
  if (!all(copied)) {
    stop(
      sprintf(
        "Could not copy synthetic fixture file(s): %s",
        paste(relative_files[!copied], collapse = ", ")
      ),
      call. = FALSE
    )
  }

  invisible(destination)
}

wlv_make_synthetic_calculation_fixture <- function() {
  template <- file.path(wlv_test_root, "tests", "fixtures", "synthetic")
  root <- tempfile("wlv-synthetic-")
  dir.create(root, recursive = TRUE)

  wlv_copy_fixture_tree(file.path(wlv_test_root, "R"), file.path(root, "R"))
  wlv_copy_fixture_tree(template, root)

  input_path <- file.path(template, "input")
  source_path <- file.path(root, "source_data", "synthetic")
  dir.create(source_path, recursive = TRUE, showWarnings = FALSE)
  source_csv <- c("countries.csv", "demand.csv")
  copied <- file.copy(
    file.path(input_path, source_csv),
    file.path(source_path, source_csv),
    overwrite = TRUE
  )
  if (!all(copied)) {
    stop("Could not materialize the synthetic source metadata.", call. = FALSE)
  }

  countries <- wlv_fixture_read_csv(file.path(input_path, "countries.csv"))
  demands <- wlv_fixture_read_csv(file.path(input_path, "demand.csv"))
  sea_table <- wlv_fixture_read_csv(file.path(input_path, "sea.csv"))
  io_table <- wlv_fixture_read_csv(file.path(input_path, "m_io.csv"))

  years <- unique(as.character(sea_table$year))
  country_names <- countries$country.source
  sector_names <- unique(sea_table$sector)
  sea_variables <- setdiff(names(sea_table), c("year", "country", "sector"))

  sea <- array(
    NA_real_,
    dim = c(
      length(years), length(sea_variables), length(sector_names),
      length(country_names)
    ),
    dimnames = list(years, sea_variables, sector_names, country_names)
  )
  for (index in seq_len(nrow(sea_table))) {
    row <- sea_table[index, ]
    sea[
      as.character(row$year),
      sea_variables,
      row$sector,
      row$country
    ] <- as.numeric(row[sea_variables])
  }

  inputs <- as.vector(t(outer(country_names, sector_names, paste, sep = ".")))
  final_demand <- as.vector(
    t(outer(country_names, demands$demand, paste, sep = "."))
  )
  outputs <- c(inputs, final_demand)
  m_io <- array(
    NA_real_,
    dim = c(length(years), length(inputs), length(outputs)),
    dimnames = list(years, inputs, outputs)
  )
  for (index in seq_len(nrow(io_table))) {
    row <- io_table[index, ]
    m_io[as.character(row$year), row$input, row$output] <- row$value_millions
  }
  if (anyNA(sea) || anyNA(m_io)) {
    stop("The synthetic fixture does not completely define its input arrays.", call. = FALSE)
  }

  functions_environment <- new.env(parent = baseenv())
  sys.source(
    file.path(root, "R", "lib", "functions.R"),
    envir = functions_environment
  )
  functions_environment$write_fst_array(sea, file.path(source_path, "sea.fst"))
  functions_environment$write_fst_array(m_io, file.path(source_path, "m_io.fst"))

  source_environment <- new.env(parent = globalenv())
  for (script in c(
    "catalog.R", "source_manifest.R", "source_normalization.R"
  )) {
    sys.source(
      file.path(root, "R", "lib", script),
      envir = source_environment
    )
  }
  source_environment$write_fst_array <- functions_environment$write_fst_array
  normalization_contract <- source_environment$wlv_new_source_normalization_contract(
    source = "synthetic",
    contract_id = "synthetic_source_normalization_v1",
    m_io_multiplier = 1e6,
    sea_multipliers = c(LAB = 1, GO = 1e6, PRICE = 1),
    m_io_source_unit = "million_current_usd",
    m_io_canonical_unit = "current_usd",
    sea_source_units = c(
      LAB = "abstract_labour_hour",
      GO = "million_current_usd",
      PRICE = "index"
    ),
    sea_canonical_units = c(
      LAB = "abstract_labour_hour",
      GO = "current_usd",
      PRICE = "index"
    )
  )
  normalized <- source_environment$wlv_normalize_source(
    m_io,
    sea,
    source = "synthetic",
    contract = normalization_contract
  )
  catalog <- source_environment$wlv_load_catalog(root)
  unit_contract <- source_environment$wlv_catalog_unit_contract(
    catalog,
    "synthetic_units_v1"
  )
  source_environment$wlv_publish_normalized_source(
    normalized = normalized,
    source_dir = source_path,
    unit_contract_id = "synthetic_units_v1",
    unit_contract_version = as.character(
      unit_contract$metadata$schema_version[[1L]]
    ),
    unit_contract_paths = file.path(
      root,
      c(
        unit_contract$metadata$units[[1L]],
        unit_contract$metadata$aggregations[[1L]]
      )
    ),
    unit_contract_sidecar = source_environment$wlv_catalog_unit_contract_sidecar(
      catalog,
      "synthetic_units_v1"
    ),
    label_files = c("countries.csv", "demand.csv"),
    writer = functions_environment$write_fst_array
  )

  list(
    root = normalizePath(root, winslash = "/", mustWork = TRUE),
    method = "synthetic",
    source_path = source_path,
    input = list(sea = sea, m_io = m_io),
    expected = list(
      sea_sectors = wlv_fixture_read_csv(
        file.path(template, "expected", "sea_sectors.csv")
      ),
      trade = wlv_fixture_read_csv(file.path(template, "expected", "trade.csv"))
    )
  )
}

wlv_remove_synthetic_calculation_fixture <- function(fixture) {
  root <- normalizePath(fixture$root, winslash = "/", mustWork = TRUE)
  temporary_root <- normalizePath(tempdir(), winslash = "/", mustWork = TRUE)
  prefix <- paste0(sub("/+$", "", temporary_root), "/")
  if (!startsWith(root, prefix) || basename(root) == basename(temporary_root)) {
    stop(sprintf("Refusing to remove non-temporary fixture path: %s", root), call. = FALSE)
  }
  unlink(root, recursive = TRUE, force = TRUE)
  invisible(NULL)
}

wlv_read_fixture_array <- function(fixture, ...) {
  functions_environment <- new.env(parent = baseenv())
  sys.source(
    file.path(fixture$root, "R", "lib", "functions.R"),
    envir = functions_environment
  )
  functions_environment$read_fst_array(file.path(fixture$root, ...))
}

wlv_write_fixture_array <- function(fixture, value, ...) {
  functions_environment <- new.env(parent = baseenv())
  sys.source(
    file.path(fixture$root, "R", "lib", "functions.R"),
    envir = functions_environment
  )
  functions_environment$write_fst_array(value, file.path(fixture$root, ...))
}

wlv_run_synthetic_calculation <- function(
    fixture,
    workers = 1L,
    warn_legacy = FALSE) {
  old_working_directory <- setwd(fixture$root)
  on.exit(setwd(old_working_directory), add = TRUE)

  runtime <- new.env(parent = globalenv())
  sys.source(file.path(fixture$root, "R", "main.R"), envir = runtime)
  calculate <- function() {
    runtime$get_wlv(
      fixture$method,
      workers = workers,
      allow_experimental = TRUE
    )
  }
  output <- capture.output(
    result <- if (warn_legacy) calculate() else suppressWarnings(calculate()),
    type = "output"
  )

  list(result = result, runtime = runtime, output = output)
}

wlv_recalculate_synthetic_fixture <- function(
    fixture,
    runtime,
    at_stage = 1L,
    sea_vars = NULL,
    workers = 1L,
    warn_legacy = FALSE) {
  old_working_directory <- setwd(fixture$root)
  on.exit(setwd(old_working_directory), add = TRUE)

  recalculate <- function() {
    runtime$recalc_wlv(
      fixture$method,
      at_stage = at_stage,
      sea_vars = sea_vars,
      workers = workers,
      allow_experimental = TRUE
    )
  }
  capture.output(
    if (warn_legacy) recalculate() else suppressWarnings(recalculate()),
    type = "output"
  )
  invisible(fixture$method)
}
