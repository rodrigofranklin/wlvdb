####
# calculates missing data for the rest of the world (RoW):
# - employment
# - labour hours
# - capital
####
parameters$description <-
  paste0("Rest of World: total persons engaged obtained from World Bank (using ",
         "SL.TLF.TOTL.IN and SL.UEM.TOTL.ZS); Capital stock determined ",
         "according to the country with the lowest capital stock per hour. ",
         parameters$description)

# Load employment data from an external source (worldbank)
# emp_row_total => total employed persons
row_emp_data <-
  read.csv2("complementar/worldbank/employment_row.new.csv", row.names = 1)
colnames(row_emp_data) <- sub("X","",colnames(row_emp_data))

emp_row_total <- row_emp_data[source_version,lists$years]

# RoW position in rows (initial and list of positions)
pre_row <- nums$countries_sectors-nums$sectors
row_position <- grep("ROW",rows$country_sector)

# Calculation of employment and labour hours
sum_emp_sector <- 
  sea_sectors[,"emp.s.un",,which(lists$countries!="ROW")] %>%
  apply(2, rowSums)
sum_h_emp_sector <- 
  sea_sectors[,"hours_worked.emp.s.hr",, which(lists$countries!="ROW")] %>%
  apply(2, rowSums)
sum_va_sector <- 
  sea_sectors[,"gdp.s.us",, which(lists$countries!="ROW")] %>%
  apply(2, rowSums)

sea_sectors[,"emp.s.un",,"ROW"] <-
  as.numeric(emp_row_total) *
  prop.table(sea_sectors[,"gdp.s.us",, "ROW"]*
               sum_emp_sector/sum_va_sector, margin = 1)

sea_sectors[,"hours_worked.emp.s.hr",,"ROW"] <-
  sea_sectors[,"emp.s.un",,"ROW"] *
  sum_h_emp_sector/sum_emp_sector

for (x in lists$years) {
  country_capital <-
    sea_sectors[x,"capital_stock.s.us",,] %>%
    tapply(rows$country, sum, na.rm = TRUE)
  country_hours <-
    sea_sectors[x,"hours_worked.emp.s.hr",,] %>%
    tapply(rows$country, sum, na.rm = TRUE)
  temp_data <- country_capital / country_hours
  
  temp_data[temp_data==0] <- Inf
  least_developed <- names(which.min(temp_data[which(temp_data|>names()!="ROW")]))

  row_hours <- sea_sectors[x,"hours_worked.emp.s.hr",, "ROW"]
  reference_capital <- sea_sectors[x,"capital_stock.s.us",,least_developed]
  reference_hours <- sea_sectors[x,"hours_worked.emp.s.hr",,least_developed]
  names(row_hours) <- lists$sectors
  names(reference_capital) <- lists$sectors
  names(reference_hours) <- lists$sectors
  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    sea_sectors[x,"capital_stock.s.us",,"ROW"] <-
      wlv_row_capital_stock_runtime(
        wlv_contract_runtime,
        row_hours,
        reference_capital,
        reference_hours,
        temp_data[[least_developed]],
        x,
        least_developed
      )
  } else {
    sea_sectors[x,"capital_stock.s.us",,"ROW"] <-
      row_hours * reference_capital / reference_hours
  }
}

# Espelha o índice de preços dos EUA para o resto do mundo
sea_sectors[,"go_price.r.id",,"ROW"] <- sea_sectors[,"go_price.r.id",,"USA"]

# Reconstrói o estoque de capital do ROW a preços constantes depois de definir
# tanto o estoque corrente assumido quanto o índice de preços aplicável ao ROW.
if ("capital_stock.s.cu" %in% dimnames(sea_sectors)[[2L]]) {
  row_constant_indicators <- c(
    "capital_stock.s.us", "capital_stock.s.cu", "exchange.r.id",
    "go_price.r.id"
  )
  missing_row_constant_indicators <- setdiff(
    row_constant_indicators,
    dimnames(sea_sectors)[[2L]]
  )
  if (length(missing_row_constant_indicators)) {
    stop(
      sprintf(
        "ROW constant capital requires indicator(s): %s.",
        paste(missing_row_constant_indicators, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (!exists("wlv_row_constant_capital_stock", mode = "function")) {
    source("R/lib/row_capital.R")
  }

  row_current_capital <- matrix(
    sea_sectors[lists$years, "capital_stock.s.us", lists$sectors, "ROW"],
    nrow = length(lists$years),
    ncol = length(lists$sectors),
    dimnames = list(lists$years, lists$sectors)
  )
  row_exchange_index <- matrix(
    sea_sectors[lists$years, "exchange.r.id", lists$sectors, "ROW"],
    nrow = length(lists$years),
    ncol = length(lists$sectors),
    dimnames = dimnames(row_current_capital)
  )
  row_output_price_index <- matrix(
    sea_sectors[lists$years, "go_price.r.id", lists$sectors, "ROW"],
    nrow = length(lists$years),
    ncol = length(lists$sectors),
    dimnames = dimnames(row_current_capital)
  )
  row_constant_capital <- wlv_row_constant_capital_stock(
    current_stock = row_current_capital,
    exchange_index = row_exchange_index,
    output_price_index = row_output_price_index,
    base_year = "2000",
    expected_zero_sectors = if (identical(source_version, "wiodr16")) {
      "M73"
    } else {
      NULL
    }
  )
  row_constant_zeroes <- attr(
    row_constant_capital,
    "wlv.row_constant_capital_zeroes",
    exact = TRUE
  )
  sea_sectors[
    lists$years, "capital_stock.s.cu", lists$sectors, "ROW"
  ] <- row_constant_capital
  meta_indicators["capital_stock.s.cu", "observation"] <- paste0(
    meta_indicators["capital_stock.s.cu", "observation"],
    " For the Rest of the World, the constant series is rebuilt after its ",
    "current-USD stock is constructed, using the 2000-based exchange-rate ",
    "index and the 2000=100 gross-output price index."
  )

  if (
    nrow(row_constant_zeroes) &&
    exists("wlv_contract_runtime", inherits = FALSE)
  ) {
    if (!exists("wlv_record_observed_transformations", mode = "function")) {
      source("R/lib/gfcf_contracts.R")
    }
    wlv_record_observed_transformations(
      wlv_contract_runtime,
      row_constant_zeroes,
      artifact = "sea_sectors",
      indicator = "capital_stock.s.cu",
      checkpoint = "after_assumptions",
      stage = 1L,
      module = "row/row.R",
      coordinate_columns = c(
        year = "year", country = "country", sector = "sector"
      )
    )
  }
}

# Clear all variables that will no longer be used
rm(row_emp_data, emp_row_total, sum_emp_sector, sum_h_emp_sector, sum_va_sector,
   least_developed, x, pre_row, row_position, country_capital, country_hours,
   temp_data, row_hours, reference_capital, reference_hours)
rm(
  list = intersect(
    c(
      "row_constant_indicators", "missing_row_constant_indicators",
      "row_current_capital", "row_exchange_index", "row_output_price_index",
      "row_constant_capital", "row_constant_zeroes"
    ),
    ls(envir = environment(), all.names = TRUE)
  ),
  envir = environment()
)
