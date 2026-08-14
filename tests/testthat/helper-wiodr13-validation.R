wiodr13_validation_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "wiodr13_validation.R"),
  envir = wiodr13_validation_environment
)

wlv_make_wiodr13_validation_fixture <- function() {
  years <- c("2000", "2001")
  countries <- c("A", "B", "ROW")
  sectors <- c("S1", "S2")
  demands <- c("HH", "INV")
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
  outputs <- c(inputs, final_demand)

  m_io <- array(
    seq_len(length(years) * length(inputs) * length(outputs)) / 10,
    dim = c(length(years), length(inputs), length(outputs)),
    dimnames = list(years, inputs, outputs)
  )
  m_io["2000", "A.S1", "A.INV"] <- -0.25
  m_io["2001", "B.S2", "B.INV"] <- 0

  gross_output <- apply(m_io, c(1L, 2L), sum)
  sea <- array(
    0,
    dim = c(length(years), 3L, length(sectors), length(countries)),
    dimnames = list(years, c("LAB", "VA_USD", "GO_USD"), sectors, countries)
  )
  sea[, "LAB", , ] <- seq_len(length(years) * length(sectors) * length(countries))
  sea[, "VA_USD", , ] <- gross_output / 3
  for (country in countries) {
    for (sector in sectors) {
      label <- paste(country, sector, sep = ".")
      sea[, "GO_USD", sector, country] <- gross_output[, label]
    }
  }
  sea[, "LAB", , "ROW"] <- NA_real_

  list(
    years = years,
    countries = countries,
    sectors = sectors,
    demands = demands,
    m_io = m_io,
    sea = sea
  )
}

wlv_validate_wiodr13_fixture <- function(fixture, ...) {
  wiodr13_validation_environment$wlv_validate_wiodr13_arrays(
    m_io = fixture$m_io,
    sea = fixture$sea,
    countries = fixture$countries,
    sectors = fixture$sectors,
    demands = fixture$demands,
    expected_years = fixture$years,
    ...
  )
}

wlv_materialize_wiodr13_validation_fixture <- function(fixture, source_dir) {
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
