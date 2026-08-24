# Native result assemblers -------------------------------------------------

wlv_native_collect_partitioned_resource <- function(
    partitions,
    expected_years,
    trailing_dimnames,
    label) {
  if (!length(partitions)) {
    stop(sprintf("Assembler has no partitions for `%s`.", label), call. = FALSE)
  }
  observed_years <- unlist(lapply(partitions, function(value) {
    dimnames(value)[[1L]]
  }), use.names = FALSE)
  duplicates <- unique(observed_years[duplicated(observed_years)])
  missing <- setdiff(expected_years, observed_years)
  unexpected <- setdiff(observed_years, expected_years)
  if (length(duplicates) || length(missing) || length(unexpected)) {
    stop(
      sprintf(
        "Assembler coverage for `%s` is not exact (duplicate=%s; missing=%s; unexpected=%s).",
        label,
        paste(duplicates, collapse = ","),
        paste(missing, collapse = ","),
        paste(unexpected, collapse = ",")
      ),
      call. = FALSE
    )
  }
  for (value in partitions) {
    if (!identical(dimnames(value)[-1L], trailing_dimnames)) {
      stop(sprintf("Assembler labels disagree for `%s`.", label), call. = FALSE)
    }
  }
  dimensions <- c(length(expected_years), vapply(trailing_dimnames, length, integer(1L)))
  result <- array(
    NA_real_,
    dim = dimensions,
    dimnames = c(list(year = expected_years), trailing_dimnames)
  )
  for (value in partitions) {
    indices <- c(
      list(dimnames(value)[[1L]]),
      rep(list(TRUE), length(trailing_dimnames)),
      list(value = value)
    )
    result <- do.call("[<-", c(list(result), indices))
  }
  result
}

wlv_native_matrix_assembler_requires <- function(args) {
  io <- unlist(lapply(args$io_resources, function(resource) {
    wlv_native_io_ref(
      resource,
      alias = paste0("io.", resource),
      partition = "*",
      collect = TRUE
    )
  }), recursive = FALSE)
  countries <- unlist(lapply(args$country_resources, function(resource) {
    wlv_native_country_matrix_ref(
      resource,
      alias = paste0("country.", resource),
      partition = "*",
      collect = TRUE
    )
  }), recursive = FALSE)
  c(
    wlv_native_run_ref("dimensions/lists", "lists", "list"),
    io,
    countries
  )
}

wlv_native_matrix_assembler_spec <- wlv_module_spec(
  id = "assembler.matrices",
  scope = "run",
  checkpoint = "pre_publish",
  operations = "calculate",
  parameters = list(
    io_resources = wlv_module_parameter("list", scalar = FALSE),
    country_resources = wlv_module_parameter("list", scalar = FALSE)
  ),
  requires = wlv_native_matrix_assembler_requires,
  provides = c(
    wlv_native_artifact_output(
      "m_io",
      c("year", "variable", "input", "output")
    ),
    wlv_native_artifact_output(
      "m_countries",
      c("year", "variable", "origin", "destination")
    )
  ),
  run = function(ctx) {
    lists <- ctx$input("lists")
    io_resources <- unlist(ctx$arg("io_resources"), use.names = FALSE)
    country_resources <- unlist(ctx$arg("country_resources"), use.names = FALSE)
    first_io <- ctx$input(paste0("io.", io_resources[[1L]]))[[1L]]
    m_io <- array(
      NA_real_,
      dim = c(
        length(lists$years), length(io_resources),
        length(lists$input), length(lists$output)
      ),
      dimnames = list(
        year = lists$years,
        variable = io_resources,
        input = lists$input,
        output = lists$output
      )
    )
    for (index in seq_along(io_resources)) {
      resource <- io_resources[[index]]
      m_io[, index, , ] <- wlv_native_collect_partitioned_resource(
        ctx$input(paste0("io.", resource)),
        lists$years,
        dimnames(first_io)[-1L],
        paste0("io/", resource)
      )
    }
    first_country <- ctx$input(
      paste0("country.", country_resources[[1L]])
    )[[1L]]
    m_countries <- array(
      NA_real_,
      dim = c(
        length(lists$years), length(country_resources),
        length(lists$countries), length(lists$countries)
      ),
      dimnames = list(
        year = lists$years,
        variable = country_resources,
        origin = lists$countries,
        destination = lists$countries
      )
    )
    for (index in seq_along(country_resources)) {
      resource <- country_resources[[index]]
      m_countries[, index, , ] <- wlv_native_collect_partitioned_resource(
        ctx$input(paste0("country.", resource)),
        lists$years,
        dimnames(first_country)[-1L],
        paste0("country_matrix/", resource)
      )
    }
    wlv_module_result(outputs = list(
      m_io = m_io,
      m_countries = m_countries
    ))
  }
)

wlv_native_panel_assembler_requires <- function(args) {
  indicators <- unlist(args$indicators, use.names = FALSE)
  sectors <- unlist(lapply(indicators, function(indicator) {
    wlv_native_indicator_ref(
      indicator,
      alias = paste0("sector.", indicator)
    )
  }), recursive = FALSE)
  countries <- unlist(lapply(indicators, function(indicator) {
    wlv_native_indicator_ref(
      indicator,
      alias = paste0("country.", indicator),
      level = "country"
    )
  }), recursive = FALSE)
  c(
    wlv_native_run_ref("dimensions/lists", "lists", "list"),
    sectors,
    countries
  )
}

wlv_native_panel_assembler_spec <- wlv_module_spec(
  id = "assembler.panel",
  scope = "run",
  checkpoint = "pre_publish",
  operations = c("calculate", "recalculate"),
  parameters = list(
    indicators = wlv_module_parameter("list", scalar = FALSE)
  ),
  requires = wlv_native_panel_assembler_requires,
  provides = c(
    wlv_native_artifact_output(
      "sea_sectors",
      c("year", "indicator", "sector", "country")
    ),
    wlv_native_artifact_output(
      "sea_countries",
      c("year", "indicator", "country")
    )
  ),
  run = function(ctx) {
    lists <- ctx$input("lists")
    indicators <- unlist(ctx$arg("indicators"), use.names = FALSE)
    sea_sectors <- array(
      NA_real_,
      dim = c(
        length(lists$years), length(indicators),
        length(lists$sectors), length(lists$countries)
      ),
      dimnames = list(
        year = lists$years,
        indicator = indicators,
        sector = lists$sectors,
        country = lists$countries
      )
    )
    sea_countries <- array(
      NA_real_,
      dim = c(
        length(lists$years), length(indicators),
        length(lists$countries) + 1L
      ),
      dimnames = list(
        year = lists$years,
        indicator = indicators,
        country = c(lists$countries, "WWW")
      )
    )
    for (indicator in indicators) {
      sector <- ctx$input(paste0("sector.", indicator))
      country <- ctx$input(paste0("country.", indicator))
      if (!identical(dimnames(sector), dimnames(sea_sectors)[c(1L, 3L, 4L)]) ||
          !identical(dimnames(country), dimnames(sea_countries)[c(1L, 3L)])) {
        stop(
          sprintf("Indicator `%s` has incompatible assembler labels.", indicator),
          call. = FALSE
        )
      }
      sea_sectors[, indicator, , ] <- sector
      sea_countries[, indicator, ] <- country
    }
    wlv_module_result(outputs = list(
      sea_sectors = sea_sectors,
      sea_countries = sea_countries
    ))
  }
)
