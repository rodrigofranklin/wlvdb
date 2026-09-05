# Native scientific assumptions -------------------------------------------

wlv_native_parameters_contract <- function() {
  wlv_resource_contract(scope = "run", value_type = "data.frame")
}

wlv_native_parameters_ref <- function(alias = "parameters", producer = NULL) {
  stats::setNames(
    list(wlv_resource_ref(
      "configuration/parameters",
      wlv_native_parameters_contract(),
      producer = producer
    )),
    alias
  )
}

wlv_native_parameters_output <- function(predecessor, alias = "parameters") {
  stats::setNames(
    list(wlv_resource_output(
      wlv_resource_ref(
        "configuration/parameters",
        wlv_native_parameters_contract()
      ),
      action = "replace",
      predecessor = wlv_resource_ref(
        "configuration/parameters",
        wlv_native_parameters_contract(),
        producer = predecessor
      )
    )),
    alias
  )
}

wlv_native_replace_indicator <- function(indicator, alias, predecessor) {
  wlv_native_indicator_output(
    indicator,
    alias = alias,
    action = "replace",
    predecessor = predecessor
  )
}

wlv_native_assumption_table_ref <- function(key, alias) {
  wlv_native_run_ref(key, alias, "data.frame")
}

wlv_assumption_china_wiodr13_spec <- function() {
  wlv_native_module_spec(
  id = "assumption.china.wiodr13",
  scope = "run",
  checkpoint = "after_assumptions",
  operations = c("calculate", "recalculate"),
  parameters = list(),
  requires = c(
    wlv_native_parameters_ref(producer = wlv_runtime_seed_producer()),
    wlv_native_indicator_ref("emp.s.un", "employment", producer = "indicator.emp.s.un"),
    wlv_native_indicator_ref(
      "hours_worked.emp.s.hr",
      "hours",
      producer = "indicator.hours_worked.emp.s.hr"
    ),
    wlv_native_indicator_ref("empe.s.un", "employees", producer = "indicator.empe.s.un"),
    wlv_native_indicator_ref(
      "hours_worked.empe.s.hr",
      "employee_hours",
      producer = "indicator.hours_worked.empe.s.hr"
    )
  ),
  provides = c(
    wlv_native_parameters_output(wlv_runtime_seed_producer()),
    wlv_native_replace_indicator("empe.s.un", "employees", "indicator.empe.s.un"),
    wlv_native_replace_indicator(
      "hours_worked.empe.s.hr",
      "employee_hours",
      "indicator.hours_worked.empe.s.hr"
    )
  ),
  run = function(ctx) {
    parameters <- ctx$input("parameters")
    employees <- ctx$input("employees")
    employee_hours <- ctx$input("employee_hours")
    employment <- ctx$input("employment")
    hours <- ctx$input("hours")
    parameters$description <- paste0(
      "China: all persons engaged was considered employee. ",
      parameters$description
    )
    employees[, , "CHN"] <- employment[, , "CHN"]
    employee_hours[, , "CHN"] <- hours[, , "CHN"]
    wlv_module_result(outputs = list(
      parameters = parameters,
      employees = employees,
      employee_hours = employee_hours
    ))
  }
)
}

wlv_assumption_china_reduction_spec <- function() {
  wlv_native_module_spec(
  id = "assumption.china.reduction_problem",
  scope = "run",
  checkpoint = "after_assumptions",
  operations = c("calculate", "recalculate"),
  parameters = list(),
  requires = c(
    wlv_native_parameters_ref(producer = wlv_runtime_seed_producer()),
    wlv_native_indicator_ref("emp.s.un", "employment", producer = "indicator.emp.s.un"),
    wlv_native_indicator_ref(
      "hours_worked.emp.s.hr",
      "hours",
      producer = "indicator.hours_worked.emp.s.hr"
    ),
    wlv_native_indicator_ref("empe.s.un", "employees", producer = "indicator.empe.s.un"),
    wlv_native_indicator_ref(
      "hours_worked.empe.s.hr",
      "employee_hours",
      producer = "indicator.hours_worked.empe.s.hr"
    ),
    wlv_native_assumption_table_ref(
      "assumption/employment_china",
      "employment_china"
    )
  ),
  provides = c(
    wlv_native_parameters_output(wlv_runtime_seed_producer()),
    wlv_native_replace_indicator("empe.s.un", "employees", "indicator.empe.s.un"),
    wlv_native_replace_indicator(
      "hours_worked.empe.s.hr",
      "employee_hours",
      "indicator.hours_worked.empe.s.hr"
    )
  ),
  run = function(ctx) {
    parameters <- ctx$input("parameters")
    employment <- ctx$input("employment")
    hours <- ctx$input("hours")
    employees <- ctx$input("employees")
    employee_hours <- ctx$input("employee_hours")
    employment_china <- ctx$input("employment_china")
    years <- dimnames(employment)[[1L]]
    names(employment_china) <- sub("^X", "", names(employment_china))
    wage_share <- as.numeric(employment_china[1L, years, drop = TRUE]) / 100
    parameters$description <- paste0(
      "China: data about employee as a percentage of employment obtained ",
      "from World Bank (SL.EMP.WORK.ZS); hours worked by employee was ",
      "projected considering the same working hours of the persons engaged. ",
      parameters$description
    )
    employees[, , "CHN"] <- employment[, , "CHN"] * wage_share
    employee_hours[, , "CHN"] <- hours[, , "CHN"] * wage_share
    wlv_module_result(outputs = list(
      parameters = parameters,
      employees = employees,
      employee_hours = employee_hours
    ))
  }
)
}

wlv_assumption_china_wiodr16_spec <- function() {
  wlv_native_module_spec(
  id = "assumption.china.wiodr16",
  scope = "run",
  checkpoint = "after_assumptions",
  operations = c("calculate", "recalculate"),
  parameters = list(),
  requires = c(
    wlv_native_parameters_ref(producer = wlv_runtime_seed_producer()),
    wlv_native_indicator_ref("emp.s.un", "employment", producer = "indicator.emp.s.un"),
    wlv_native_indicator_ref(
      "hours_worked.emp.s.hr",
      "hours",
      producer = "indicator.hours_worked.emp.s.hr"
    ),
    wlv_native_indicator_ref("empe.s.un", "employees", producer = "indicator.empe.s.un"),
    wlv_native_indicator_ref(
      "hours_worked.empe.s.hr",
      "employee_hours",
      producer = "indicator.hours_worked.empe.s.hr"
    ),
    list(hours_per_worker = wlv_resource_ref(
      "assumption/china_hours_per_worker",
      wlv_native_array_contract(
        scope = "run",
        axes = c("year", "sector"),
        missingness = "none"
      ),
      producer = wlv_runtime_seed_producer()
    ))
  ),
  provides = c(
    wlv_native_parameters_output(wlv_runtime_seed_producer()),
    wlv_native_replace_indicator(
      "hours_worked.emp.s.hr",
      "hours",
      "indicator.hours_worked.emp.s.hr"
    ),
    wlv_native_replace_indicator("empe.s.un", "employees", "indicator.empe.s.un"),
    wlv_native_replace_indicator(
      "hours_worked.empe.s.hr",
      "employee_hours",
      "indicator.hours_worked.empe.s.hr"
    )
  ),
  run = function(ctx) {
    parameters <- ctx$input("parameters")
    employment <- ctx$input("employment")
    hours <- ctx$input("hours")
    employees <- ctx$input("employees")
    employee_hours <- ctx$input("employee_hours")
    hours_per_worker <- ctx$input("hours_per_worker")
    china_employment <- employment[, , "CHN"]
    if (anyNA(china_employment) || any(!is.finite(china_employment))) {
      stop("WIOD16 China employment must be finite before applying hours.", call. = FALSE)
    }
    parameters$description <- paste0(
      "China: annual hours per person engaged were inferred from WIOD13 ",
      "H_EMP/EMP, mapped to the WIOD16 sectors; the 2009 observation was ",
      "replicated through 2014. Because WIOD16 provides no separate employee ",
      "labour input for China, all persons engaged were treated as employees. ",
      parameters$description
    )
    hours[, , "CHN"] <- china_employment * hours_per_worker * 1000
    employees[, , "CHN"] <- employment[, , "CHN"]
    employee_hours[, , "CHN"] <- hours[, , "CHN"]
    wlv_module_result(outputs = list(
      parameters = parameters,
      hours = hours,
      employees = employees,
      employee_hours = employee_hours
    ))
  }
)
}

wlv_assumption_row_none_spec <- function() {
  wlv_native_module_spec(
  id = "assumption.row.none",
  scope = "run",
  checkpoint = "after_assumptions",
  operations = c("calculate", "recalculate"),
  parameters = list(
    variant = wlv_module_parameter("character", choices = "none"),
    source = wlv_module_parameter("character", choices = "wiodr13")
  ),
  requires = c(
    wlv_native_parameters_ref(producer = "assumption.china"),
    wlv_native_indicator_ref("emp.s.un", "employment", producer = "indicator.emp.s.un"),
    wlv_native_indicator_ref(
      "hours_worked.emp.s.hr",
      "hours",
      producer = "indicator.hours_worked.emp.s.hr"
    ),
    wlv_native_indicator_ref("empe.s.un", "employees", producer = "assumption.china"),
    wlv_native_indicator_ref(
      "hours_worked.empe.s.hr",
      "employee_hours",
      producer = "assumption.china"
    ),
    wlv_native_indicator_ref(
      "compensation.emp.s.us",
      "compensation",
      producer = "indicator.compensation.emp.s.us"
    ),
    wlv_native_indicator_ref(
      "compensation.empe.s.us",
      "employee_compensation",
      producer = "indicator.compensation.empe.s.us"
    ),
    wlv_native_indicator_ref(
      "capital_stock.s.us",
      "capital_stock",
      producer = "indicator.capital_stock.s.us"
    ),
    wlv_native_indicator_ref(
      "go_price.r.id",
      "go_price",
      producer = "indicator.go_price.r.id"
    )
  ),
  provides = c(
    wlv_native_parameters_output("assumption.china"),
    wlv_native_replace_indicator("emp.s.un", "employment", "indicator.emp.s.un"),
    wlv_native_replace_indicator(
      "hours_worked.emp.s.hr",
      "hours",
      "indicator.hours_worked.emp.s.hr"
    ),
    wlv_native_replace_indicator("empe.s.un", "employees", "assumption.china"),
    wlv_native_replace_indicator(
      "hours_worked.empe.s.hr",
      "employee_hours",
      "assumption.china"
    ),
    wlv_native_replace_indicator(
      "compensation.emp.s.us",
      "compensation",
      "indicator.compensation.emp.s.us"
    ),
    wlv_native_replace_indicator(
      "compensation.empe.s.us",
      "employee_compensation",
      "indicator.compensation.empe.s.us"
    ),
    wlv_native_replace_indicator(
      "capital_stock.s.us",
      "capital_stock",
      "indicator.capital_stock.s.us"
    ),
    wlv_native_replace_indicator(
      "go_price.r.id",
      "go_price",
      "indicator.go_price.r.id"
    )
  ),
  run = function(ctx) {
    outputs <- list(
      parameters = ctx$input("parameters"),
      employment = ctx$input("employment"),
      hours = ctx$input("hours"),
      employees = ctx$input("employees"),
      employee_hours = ctx$input("employee_hours"),
      compensation = ctx$input("compensation"),
      employee_compensation = ctx$input("employee_compensation"),
      capital_stock = ctx$input("capital_stock")
    )
    outputs$parameters$description <- paste0(
      "Rest of World: all data for RoW was considered zero. ",
      outputs$parameters$description
    )
    for (name in setdiff(names(outputs), "parameters")) {
      outputs[[name]][, , "ROW"] <- 0
    }
    go_price <- ctx$input("go_price")
    go_price[, , "ROW"] <- go_price[, , "USA"]
    outputs$go_price <- go_price
    wlv_module_result(outputs = outputs)
  }
)
}

wlv_native_row_hours_producer <- function(source) {
  if (identical(source, "wiodr16")) "assumption.china" else {
    "indicator.hours_worked.emp.s.hr"
  }
}

wlv_native_row_table_values <- function(value, row, years) {
  names(value) <- sub("^X", "", names(value))
  if (!row %in% row.names(value) || any(!years %in% names(value))) {
    stop(
      sprintf("ROW assumption data does not contain `%s` for all years.", row),
      call. = FALSE
    )
  }
  as.numeric(value[row, years, drop = TRUE])
}

wlv_native_row_sector_totals <- function(value, countries) {
  selected <- value[, , countries, drop = FALSE]
  result <- apply(selected, c(1L, 2L), sum)
  dimnames(result) <- dimnames(value)[c(1L, 2L)]
  result
}

wlv_native_row_sector_means <- function(value, countries) {
  selected <- value[, , countries, drop = FALSE]
  result <- apply(selected, c(1L, 2L), mean)
  dimnames(result) <- dimnames(value)[c(1L, 2L)]
  result
}

wlv_native_row_allocate_employment <- function(
    employment,
    hours,
    gdp,
    total_employment) {
  countries <- setdiff(dimnames(employment)[[3L]], "ROW")
  employment_by_sector <- wlv_native_row_sector_totals(employment, countries)
  hours_by_sector <- wlv_native_row_sector_totals(hours, countries)
  value_added_by_sector <- wlv_native_row_sector_totals(gdp, countries)
  weights <- gdp[, , "ROW"] * employment_by_sector / value_added_by_sector
  employment[, , "ROW"] <- as.numeric(total_employment) *
    prop.table(weights, margin = 1L)
  hours[, , "ROW"] <- employment[, , "ROW"] *
    hours_by_sector / employment_by_sector
  list(
    employment = employment,
    hours = hours,
    employment_by_sector = employment_by_sector,
    value_added_by_sector = value_added_by_sector
  )
}

wlv_native_row_capital_from_reference <- function(
    capital_stock,
    labour,
    contract_runtime,
    basis = c("hours", "workers"),
    module) {
  basis <- match.arg(basis)
  years <- dimnames(capital_stock)[[1L]]
  sectors <- dimnames(capital_stock)[[2L]]
  countries <- dimnames(capital_stock)[[3L]]
  for (year in years) {
    country_capital <- colSums(capital_stock[year, , , drop = TRUE], na.rm = TRUE)
    country_labour <- colSums(labour[year, , , drop = TRUE], na.rm = TRUE)
    intensity <- country_capital / country_labour
    intensity[intensity == 0] <- Inf
    candidates <- if (identical(basis, "hours")) {
      intensity[names(intensity) != "ROW"]
    } else {
      intensity
    }
    reference_country <- names(which.min(candidates))
    row_labour <- labour[year, , "ROW"]
    reference_capital <- capital_stock[year, , reference_country]
    reference_labour <- labour[year, , reference_country]
    names(row_labour) <- sectors
    names(reference_capital) <- sectors
    names(reference_labour) <- sectors
    capital_stock[year, , "ROW"] <- wlv_row_capital_stock_runtime(
      contract_runtime,
      row_labour,
      reference_capital,
      reference_labour,
      intensity[[reference_country]],
      year,
      reference_country,
      module = module,
      basis = basis
    )
  }
  capital_stock
}

wlv_native_row_standard_requires <- function(args) {
  source <- args$source
  hours_producer <- wlv_native_row_hours_producer(source)
  result <- c(
    wlv_native_parameters_ref(producer = "assumption.china"),
    wlv_native_indicator_ref("emp.s.un", "employment", producer = "indicator.emp.s.un"),
    wlv_native_indicator_ref(
      "hours_worked.emp.s.hr",
      "hours",
      producer = hours_producer
    ),
    wlv_native_indicator_ref("gdp.s.us", "gdp", producer = "indicator.gdp.s.us"),
    wlv_native_indicator_ref(
      "capital_stock.s.us",
      "capital_stock",
      producer = "indicator.capital_stock.s.us"
    ),
    wlv_native_indicator_ref(
      "go_price.r.id",
      "go_price",
      producer = "indicator.go_price.r.id"
    ),
    wlv_native_assumption_table_ref(
      "assumption/employment_row_current",
      "employment_row"
    )
  )
  if (identical(source, "wiodr16")) {
    result <- c(
      result,
      wlv_native_indicator_ref(
        "exchange.r.id",
        "exchange",
        producer = "indicator.exchange.r.id"
      ),
      wlv_native_indicator_ref(
        "capital_stock.s.cu",
        "constant_capital",
        producer = "indicator.capital_stock.s.cu"
      ),
      wlv_native_indicator_metadata_ref()
    )
  }
  result
}

wlv_native_row_standard_provides <- function(args) {
  source <- args$source
  hours_producer <- wlv_native_row_hours_producer(source)
  result <- c(
    wlv_native_parameters_output("assumption.china"),
    wlv_native_replace_indicator("emp.s.un", "employment", "indicator.emp.s.un"),
    wlv_native_replace_indicator(
      "hours_worked.emp.s.hr",
      "hours",
      hours_producer
    ),
    wlv_native_replace_indicator(
      "capital_stock.s.us",
      "capital_stock",
      "indicator.capital_stock.s.us"
    ),
    wlv_native_replace_indicator(
      "go_price.r.id",
      "go_price",
      "indicator.go_price.r.id"
    )
  )
  if (identical(source, "wiodr16")) {
    result <- c(
      result,
      wlv_native_replace_indicator(
        "capital_stock.s.cu",
        "constant_capital",
        "indicator.capital_stock.s.cu"
      ),
      wlv_native_indicator_metadata_output(wlv_runtime_seed_producer())
    )
  }
  result
}

wlv_assumption_row_standard_spec <- function() {
  wlv_native_module_spec(
  id = "assumption.row.standard",
  scope = "run",
  checkpoint = "after_assumptions",
  operations = c("calculate", "recalculate"),
  parameters = list(
    variant = wlv_module_parameter("character", choices = "standard"),
    source = wlv_module_parameter(
      "character",
      choices = c("wiodr13", "wiodr16")
    )
  ),
  requires = wlv_native_row_standard_requires,
  provides = wlv_native_row_standard_provides,
  services = "contract_runtime",
  run = function(ctx) {
    source <- ctx$arg("source")
    parameters <- ctx$input("parameters")
    employment <- ctx$input("employment")
    hours <- ctx$input("hours")
    gdp <- ctx$input("gdp")
    capital_stock <- ctx$input("capital_stock")
    go_price <- ctx$input("go_price")
    years <- dimnames(employment)[[1L]]
    total_employment <- wlv_native_row_table_values(
      ctx$input("employment_row"),
      source,
      years
    )
    parameters$description <- paste0(
      "Rest of World: total persons engaged obtained from World Bank (using ",
      "SL.TLF.TOTL.IN and SL.UEM.TOTL.ZS); Capital stock determined ",
      "according to the country with the lowest capital stock per hour. ",
      parameters$description
    )
    allocation <- wlv_native_row_allocate_employment(
      employment,
      hours,
      gdp,
      total_employment
    )
    employment <- allocation$employment
    hours <- allocation$hours
    capital_stock <- wlv_native_row_capital_from_reference(
      capital_stock,
      hours,
      ctx$service("contract_runtime"),
      basis = "hours",
      module = "assumption.row.standard"
    )
    go_price[, , "ROW"] <- go_price[, , "USA"]
    outputs <- list(
      parameters = parameters,
      employment = employment,
      hours = hours,
      capital_stock = capital_stock,
      go_price = go_price
    )
    diagnostics <- list()
    if (identical(source, "wiodr16")) {
      constant_capital <- ctx$input("constant_capital")
      exchange <- ctx$input("exchange")
      indicator_metadata <- ctx$input("indicator_metadata")
      row_current <- capital_stock[, , "ROW", drop = TRUE]
      row_exchange <- exchange[, , "ROW", drop = TRUE]
      row_price <- go_price[, , "ROW", drop = TRUE]
      dimnames(row_current) <- dimnames(capital_stock)[c(1L, 2L)]
      dimnames(row_exchange) <- dimnames(row_current)
      dimnames(row_price) <- dimnames(row_current)
      row_constant <- wlv_row_constant_capital_stock(
        current_stock = row_current,
        exchange_index = row_exchange,
        output_price_index = row_price,
        base_year = "2000",
        expected_zero_sectors = "M73"
      )
      constant_capital[, , "ROW"] <- row_constant
      observation <- paste0(
        " For the Rest of the World, the constant series is rebuilt after its ",
        "current-USD stock is constructed, using the 2000-based exchange-rate ",
        "index and the canonical 2000=1 gross-output price index."
      )
      indicator_metadata["capital_stock.s.cu", "observation"] <- paste0(
        indicator_metadata["capital_stock.s.cu", "observation"],
        observation
      )
      zeroes <- attr(row_constant, "wlv.row_constant_capital_zeroes", exact = TRUE)
      if (nrow(zeroes)) {
        wlv_record_observed_transformations(
          ctx$service("contract_runtime"),
          zeroes,
          artifact = "sea_sectors",
          indicator = "capital_stock.s.cu",
          checkpoint = "after_assumptions",
          stage = 1L,
          module = "assumption.row.standard",
          coordinate_columns = c(
            year = "year", country = "country", sector = "sector"
          )
        )
      }
      outputs$constant_capital <- constant_capital
      outputs$indicator_metadata <- indicator_metadata
      diagnostics$row_constant_capital_zeroes <- zeroes
    }
    wlv_module_result(outputs = outputs, diagnostics = diagnostics)
  }
)
}

wlv_native_row_v09_requires <- function(args) {
  c(
    wlv_native_parameters_ref(producer = "assumption.china"),
    wlv_native_indicator_ref("emp.s.un", "employment", producer = "indicator.emp.s.un"),
    wlv_native_indicator_ref(
      "hours_worked.emp.s.hr",
      "hours",
      producer = wlv_native_row_hours_producer(args$source)
    ),
    wlv_native_indicator_ref("gdp.s.us", "gdp", producer = "indicator.gdp.s.us"),
    wlv_native_indicator_ref(
      "capital_stock.s.us",
      "capital_stock",
      producer = "indicator.capital_stock.s.us"
    ),
    wlv_native_indicator_ref(
      "go_price.r.id",
      "go_price",
      producer = "indicator.go_price.r.id"
    ),
    wlv_native_assumption_table_ref(
      "assumption/employment_row_legacy",
      "employment_row"
    )
  )
}

wlv_native_row_v09_provides <- function(args) {
  c(
    wlv_native_parameters_output("assumption.china"),
    wlv_native_replace_indicator("emp.s.un", "employment", "indicator.emp.s.un"),
    wlv_native_replace_indicator(
      "hours_worked.emp.s.hr",
      "hours",
      wlv_native_row_hours_producer(args$source)
    ),
    wlv_native_replace_indicator(
      "capital_stock.s.us",
      "capital_stock",
      "indicator.capital_stock.s.us"
    ),
    wlv_native_replace_indicator(
      "go_price.r.id",
      "go_price",
      "indicator.go_price.r.id"
    )
  )
}

wlv_assumption_row_v09_spec <- function() {
  wlv_native_module_spec(
  id = "assumption.row.v09",
  scope = "run",
  checkpoint = "after_assumptions",
  operations = c("calculate", "recalculate"),
  parameters = list(
    variant = wlv_module_parameter("character", choices = "v09"),
    source = wlv_module_parameter(
      "character",
      choices = c("wiodr13", "wiodr16")
    )
  ),
  requires = wlv_native_row_v09_requires,
  provides = wlv_native_row_v09_provides,
  services = "contract_runtime",
  run = function(ctx) {
    source <- ctx$arg("source")
    parameters <- ctx$input("parameters")
    employment <- ctx$input("employment")
    hours <- ctx$input("hours")
    years <- dimnames(employment)[[1L]]
    parameters$description <- paste0(
      "Rest of World: total persons engaged obtained from World Bank and ",
      "distributed by sectors according to the  average number of employees ",
      "weightned by value-added; hours worked determined by the average ",
      "working day of each sector; Capital stock determined according to ",
      "the country with the lowest capital stock per worker in each year. ",
      parameters$description
    )
    allocation <- wlv_native_row_allocate_employment(
      employment,
      hours,
      ctx$input("gdp"),
      wlv_native_row_table_values(ctx$input("employment_row"), source, years)
    )
    employment <- allocation$employment
    hours <- allocation$hours
    capital_stock <- wlv_native_row_capital_from_reference(
      ctx$input("capital_stock"),
      employment,
      ctx$service("contract_runtime"),
      basis = "workers",
      module = "assumption.row.v09"
    )
    go_price <- ctx$input("go_price")
    go_price[, , "ROW"] <- go_price[, , "USA"]
    wlv_module_result(outputs = list(
      parameters = parameters,
      employment = employment,
      hours = hours,
      capital_stock = capital_stock,
      go_price = go_price
    ))
  }
)
}

wlv_assumption_row_reduction_spec <- function() {
  wlv_native_module_spec(
  id = "assumption.row.reduction_problem",
  scope = "run",
  checkpoint = "after_assumptions",
  operations = c("calculate", "recalculate"),
  parameters = list(
    variant = wlv_module_parameter("character", choices = "reduction_problem"),
    source = wlv_module_parameter("character", choices = "wiodr13")
  ),
  requires = c(
    wlv_native_parameters_ref(producer = "assumption.china"),
    wlv_native_indicator_ref("emp.s.un", "employment", producer = "indicator.emp.s.un"),
    wlv_native_indicator_ref(
      "hours_worked.emp.s.hr",
      "hours",
      producer = "indicator.hours_worked.emp.s.hr"
    ),
    wlv_native_indicator_ref("empe.s.un", "employees", producer = "assumption.china"),
    wlv_native_indicator_ref(
      "hours_worked.empe.s.hr",
      "employee_hours",
      producer = "assumption.china"
    ),
    wlv_native_indicator_ref(
      "hours_worked.empe_hs.r.pc",
      "hours_high_skill",
      producer = "indicator.hours_worked.empe_hs.r.pc"
    ),
    wlv_native_indicator_ref(
      "hours_worked.empe_ms.r.pc",
      "hours_medium_skill",
      producer = "indicator.hours_worked.empe_ms.r.pc"
    ),
    wlv_native_indicator_ref(
      "hours_worked.empe_ls.r.pc",
      "hours_low_skill",
      producer = "indicator.hours_worked.empe_ls.r.pc"
    ),
    wlv_native_indicator_ref(
      "compensation.empe_hs.r.pc",
      "compensation_high_skill",
      producer = "indicator.compensation.empe_hs.r.pc"
    ),
    wlv_native_indicator_ref(
      "compensation.empe_ms.r.pc",
      "compensation_medium_skill",
      producer = "indicator.compensation.empe_ms.r.pc"
    ),
    wlv_native_indicator_ref(
      "compensation.empe_ls.r.pc",
      "compensation_low_skill",
      producer = "indicator.compensation.empe_ls.r.pc"
    ),
    wlv_native_indicator_ref(
      "compensation.emp.s.us",
      "compensation",
      producer = "indicator.compensation.emp.s.us"
    ),
    wlv_native_indicator_ref(
      "compensation.empe.s.us",
      "employee_compensation",
      producer = "indicator.compensation.empe.s.us"
    ),
    wlv_native_indicator_ref("gdp.s.us", "gdp", producer = "indicator.gdp.s.us"),
    wlv_native_indicator_ref(
      "capital_stock.s.us",
      "capital_stock",
      producer = "indicator.capital_stock.s.us"
    ),
    wlv_native_indicator_ref(
      "go_price.r.id",
      "go_price",
      producer = "indicator.go_price.r.id"
    ),
    wlv_native_assumption_table_ref(
      "assumption/employment_row_legacy",
      "employment_row"
    )
  ),
  provides = c(
    wlv_native_parameters_output("assumption.china"),
    wlv_native_replace_indicator("emp.s.un", "employment", "indicator.emp.s.un"),
    wlv_native_replace_indicator(
      "hours_worked.emp.s.hr",
      "hours",
      "indicator.hours_worked.emp.s.hr"
    ),
    wlv_native_replace_indicator("empe.s.un", "employees", "assumption.china"),
    wlv_native_replace_indicator(
      "hours_worked.empe.s.hr",
      "employee_hours",
      "assumption.china"
    ),
    wlv_native_replace_indicator(
      "hours_worked.empe_hs.r.pc",
      "hours_high_skill",
      "indicator.hours_worked.empe_hs.r.pc"
    ),
    wlv_native_replace_indicator(
      "hours_worked.empe_ms.r.pc",
      "hours_medium_skill",
      "indicator.hours_worked.empe_ms.r.pc"
    ),
    wlv_native_replace_indicator(
      "hours_worked.empe_ls.r.pc",
      "hours_low_skill",
      "indicator.hours_worked.empe_ls.r.pc"
    ),
    wlv_native_replace_indicator(
      "compensation.empe_hs.r.pc",
      "compensation_high_skill",
      "indicator.compensation.empe_hs.r.pc"
    ),
    wlv_native_replace_indicator(
      "compensation.empe_ms.r.pc",
      "compensation_medium_skill",
      "indicator.compensation.empe_ms.r.pc"
    ),
    wlv_native_replace_indicator(
      "compensation.empe_ls.r.pc",
      "compensation_low_skill",
      "indicator.compensation.empe_ls.r.pc"
    ),
    wlv_native_replace_indicator(
      "compensation.emp.s.us",
      "compensation",
      "indicator.compensation.emp.s.us"
    ),
    wlv_native_replace_indicator(
      "compensation.empe.s.us",
      "employee_compensation",
      "indicator.compensation.empe.s.us"
    ),
    wlv_native_replace_indicator(
      "capital_stock.s.us",
      "capital_stock",
      "indicator.capital_stock.s.us"
    ),
    wlv_native_replace_indicator(
      "go_price.r.id",
      "go_price",
      "indicator.go_price.r.id"
    )
  ),
  run = function(ctx) {
    parameters <- ctx$input("parameters")
    parameters$description <- paste0(
      "Rest of World: total persons engaged obtained from World Bank and ",
      "distributed by sectors according to the  average number of employees ",
      "weightned by value-added; hours worked determined by the average ",
      "working day of each sector; Capital stock determined according to ",
      "an arbitrary group of countries considered less developed. ",
      parameters$description
    )
    employment <- ctx$input("employment")
    hours <- ctx$input("hours")
    gdp <- ctx$input("gdp")
    years <- dimnames(employment)[[1L]]
    row_table <- ctx$input("employment_row")
    allocation <- wlv_native_row_allocate_employment(
      employment,
      hours,
      gdp,
      wlv_native_row_table_values(row_table, ctx$arg("source"), years)
    )
    employment <- allocation$employment
    hours <- allocation$hours
    wage_share <- wlv_native_row_table_values(row_table, "was_w", years) / 100
    employees <- ctx$input("employees")
    employee_hours <- ctx$input("employee_hours")
    employees[, , "ROW"] <- employment[, , "ROW"] * wage_share
    employee_hours[, , "ROW"] <- hours[, , "ROW"] * wage_share
    countries <- setdiff(dimnames(employment)[[3L]], "ROW")
    hours_high_skill <- ctx$input("hours_high_skill")
    hours_medium_skill <- ctx$input("hours_medium_skill")
    hours_low_skill <- ctx$input("hours_low_skill")
    hours_high_skill[, , "ROW"] <- wlv_native_row_sector_means(
      hours_high_skill,
      countries
    )
    hours_medium_skill[, , "ROW"] <- wlv_native_row_sector_means(
      hours_medium_skill,
      countries
    )
    hours_low_skill[, , "ROW"] <- 1 - hours_high_skill[, , "ROW"] -
      hours_medium_skill[, , "ROW"]
    compensation_high_skill <- ctx$input("compensation_high_skill")
    compensation_medium_skill <- ctx$input("compensation_medium_skill")
    compensation_low_skill <- ctx$input("compensation_low_skill")
    compensation_high_skill[, , "ROW"] <- wlv_native_row_sector_means(
      compensation_high_skill,
      countries
    )
    compensation_medium_skill[, , "ROW"] <- wlv_native_row_sector_means(
      compensation_medium_skill,
      countries
    )
    compensation_low_skill[, , "ROW"] <- 1 -
      compensation_high_skill[, , "ROW"] -
      compensation_medium_skill[, , "ROW"]
    value_added_countries <- apply(gdp[, , countries, drop = FALSE], 1L, sum)
    value_added_row <- apply(gdp[, , "ROW", drop = TRUE], 1L, sum)
    compensation <- ctx$input("compensation")
    employee_compensation <- ctx$input("employee_compensation")
    labour_total <- apply(
      compensation[, , countries, drop = FALSE],
      1L,
      sum
    ) / value_added_countries * value_added_row
    labour_by_sector <- wlv_native_row_sector_totals(compensation, countries)
    compensation[, , "ROW"] <- as.numeric(labour_total) * prop.table(
      gdp[, , "ROW"] * labour_by_sector / allocation$employment_by_sector,
      margin = 1L
    )
    employee_total <- apply(
      employee_compensation[, , countries, drop = FALSE],
      1L,
      sum
    ) / value_added_countries * value_added_row
    employee_by_sector <- wlv_native_row_sector_totals(
      employee_compensation,
      countries
    )
    employee_compensation[, , "ROW"] <- as.numeric(employee_total) * prop.table(
      gdp[, , "ROW"] * employee_by_sector / allocation$employment_by_sector,
      margin = 1L
    )
    least_developed <- c(
      "GRC", "HUN", "BGR", "BRA", "SWE", "LVA", "CHN", "PRT",
      "POL", "MLT", "GBR", "JPN", "KOR", "ROU", "DNK", "CZE"
    )
    capital_stock <- ctx$input("capital_stock")
    capital_by_sector <- wlv_native_row_sector_totals(
      capital_stock,
      least_developed
    )
    value_added_least <- wlv_native_row_sector_totals(gdp, least_developed)
    capital_stock[, , "ROW"] <- gdp[, , "ROW"] *
      capital_by_sector / value_added_least
    go_price <- ctx$input("go_price")
    go_price[, , "ROW"] <- go_price[, , "USA"]
    wlv_module_result(outputs = list(
      parameters = parameters,
      employment = employment,
      hours = hours,
      employees = employees,
      employee_hours = employee_hours,
      hours_high_skill = hours_high_skill,
      hours_medium_skill = hours_medium_skill,
      hours_low_skill = hours_low_skill,
      compensation_high_skill = compensation_high_skill,
      compensation_medium_skill = compensation_medium_skill,
      compensation_low_skill = compensation_low_skill,
      compensation = compensation,
      employee_compensation = employee_compensation,
      capital_stock = capital_stock,
      go_price = go_price
    ))
  }
)
}
