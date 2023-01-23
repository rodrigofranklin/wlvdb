####
# calculates missing data for the rest of the world (RoW):
# - employment
# - labour hours
# - capital
####
parameters$description <- 
  paste0("Rest of World: total persons engaged obtained from World Bank and ",
         "distributed by sectors according to the  average number of employees ",
         "weightned by value-added; hours worked determined by the average ",
         "working day of each sector; Capital stock determined according to ",
         "the country with the lowest capital stock per worker in each year. ",
         parameters$description)

# Load employment data from an external source (worldbank)
# emp_row_total => total employed persons
row_emp_data <-
  read.csv2("source_data/worldbank/employment_row.csv", row.names = 1)
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

# These data aren't necessary for value computation
# sea_sectors[,"empe.s.un",,"ROW"] <- NA
# 
# sea_sectors[,"hours_worked.empe.s.hr",,"ROW"] <- NA
# 
# sea_sectors[,"hours_worked.empe_hs.r.pc",,"ROW"] <- NA
# 
# sea_sectors[,"hours_worked.empe_ms.r.pc",,"ROW"] <- NA
# 
# sea_sectors[,"hours_worked.empe_ls.r.pc",,"ROW"] <- NA
# 
# sea_sectors[,"compensation.empe_hs.r.pc",,"ROW"] <- NA
# 
# sea_sectors[,"compensation.empe_ms.r.pc",,"ROW"] <- NA
# 
# sea_sectors[,"compensation.empe_ls.r.pc",,"ROW"] <- NA
# 
# sea_sectors[,"compensation.emp.s.us",,"ROW"] <- NA
# 
# sea_sectors[,"compensation.empe.s.us",,"ROW"] <-NA

for (x in lists$years) {
  temp_data <-
    sea_sectors[x,"capital_stock.s.us",,] %>% 
    tapply(rows$country, sum, na.rm = TRUE) / 
    sea_sectors[x,"emp.s.un",,] %>% 
    tapply(rows$country, sum, na.rm = TRUE)
  
  temp_data[temp_data==0] <- Inf
  least_developed <- names(which.min(temp_data))
  
  sea_sectors[x,"capital_stock.s.us",,"ROW"] <- 
    sea_sectors[x,"emp.s.un",, "ROW"] *
    sea_sectors[x,"capital_stock.s.us",,least_developed] /
    sea_sectors[x,"emp.s.un",,least_developed]
}

# Espelha o índice de preços dos EUA para o resto do mundo
sea_sectors[,"go_price.r.id",,"ROW"] <- sea_sectors[,"go_price.r.id",,"USA"]

# Clear all variables that will no longer be used
rm(row_emp_data, emp_row_total, sum_emp_sector, sum_h_emp_sector, sum_va_sector,
   least_developed, x, pre_row, row_position)
