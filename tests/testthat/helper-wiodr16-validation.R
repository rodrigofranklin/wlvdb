wiodr16_validation_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "gfcf_contracts.R"),
  envir = wiodr16_validation_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "wiodr13_validation.R"),
  envir = wiodr16_validation_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "wiodr16_allocation.R"),
  envir = wiodr16_validation_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "wiodr16_validation.R"),
  envir = wiodr16_validation_environment
)

wlv_make_wiodr16_validation_fixture <- function() {
  years <- c("2000", "2001")
  countries <- c("A", "CHN", "ROW")
  sectors <- c("S1", "S2")
  demands <- c("c57", "c58")
  raw_variables <- c("EMP", "EMPE", "H_EMPE", "COMP")
  inputs <- as.vector(vapply(
    countries,
    function(country) paste(country, sectors, sep = "."),
    character(length(sectors))
  ))
  final_demand <- as.vector(vapply(
    countries,
    function(country) paste(country, demands, sep = "."),
    character(length(demands))
  ))

  m_io <- array(
    seq_len(length(years) * length(inputs) * (length(inputs) + length(final_demand))) / 10,
    dim = c(length(years), length(inputs), length(inputs) + length(final_demand)),
    dimnames = list(years, inputs, c(inputs, final_demand))
  )
  gross_output <- apply(m_io, c(1L, 2L), sum)
  sea <- array(
    seq_len(length(years) * 6L * length(sectors) * length(countries)),
    dim = c(length(years), 6L, length(sectors), length(countries)),
    dimnames = list(
      years,
      c(raw_variables, "VA_USD", "GO_USD"),
      sectors,
      countries
    )
  )
  sea[, "VA_USD", , ] <- gross_output / 3
  sea[, "GO_USD", , ] <- gross_output
  sea[, raw_variables, , "ROW"] <- NA_real_
  sea[, c("EMPE", "H_EMPE"), , "CHN"] <- NA_real_

  list(
    years = years,
    countries = countries,
    sectors = sectors,
    demands = demands,
    raw_variables = raw_variables,
    m_io = m_io,
    sea = sea
  )
}

wlv_validate_wiodr16_fixture <- function(
    fixture,
    expected_country_count = length(fixture$countries),
    expected_countries = fixture$countries,
    expected_sector_count = length(fixture$sectors),
    expected_demand_count = length(fixture$demands),
    expected_demands = fixture$demands,
    expected_raw_variables = fixture$raw_variables,
    expected_raw_variable_count = length(fixture$raw_variables),
    ...) {
  wiodr16_validation_environment$wlv_validate_wiodr16_arrays(
    m_io = fixture$m_io,
    sea = fixture$sea,
    countries = fixture$countries,
    sectors = fixture$sectors,
    demands = fixture$demands,
    expected_years = fixture$years,
    expected_country_count = expected_country_count,
    expected_countries = expected_countries,
    expected_sector_count = expected_sector_count,
    expected_demand_count = expected_demand_count,
    expected_demands = expected_demands,
    expected_raw_variables = expected_raw_variables,
    expected_raw_variable_count = expected_raw_variable_count,
    ...
  )
}

wlv_materialize_wiodr16_validation_fixture <- function(fixture, source_dir) {
  dir.create(source_dir, recursive = TRUE, showWarnings = FALSE)
  utils::write.table(
    data.frame(country.source = fixture$countries),
    file.path(source_dir, "countries.csv"),
    row.names = FALSE,
    quote = FALSE,
    sep = ";"
  )
  utils::write.table(
    data.frame(sector.source = fixture$sectors),
    file.path(source_dir, "sectors.csv"),
    row.names = FALSE,
    quote = FALSE,
    sep = ";"
  )
  utils::write.table(
    data.frame(demand = fixture$demands),
    file.path(source_dir, "demand.csv"),
    row.names = FALSE,
    quote = FALSE,
    sep = ";"
  )

  write_array <- function(value, name) {
    path <- file.path(source_dir, name)
    fst::write_fst(data.frame(Data = as.vector(value)), path)
    saveRDS(
      c(list(dim = dim(value)), unname(dimnames(value))),
      paste0(path, ".meta")
    )
  }
  write_array(fixture$m_io, "m_io.fst")
  write_array(fixture$sea, "sea.fst")
  invisible(source_dir)
}
