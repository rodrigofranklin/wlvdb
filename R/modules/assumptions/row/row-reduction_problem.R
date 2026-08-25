####
# calculates missing data for the rest of the world (RoW):
# - employment
# - labour hours
# - compensation.empe.s.us
# - capital
####
parameters$description <- 
  paste0("Rest of World: total persons engaged obtained from World Bank and ",
         "distributed by sectors according to the  average number of employees ",
         "weightned by value-added; hours worked determined by the average ",
         "working day of each sector; Capital stock determined according to ",
         "an arbitrary group of countries considered less developed. ",
         parameters$description)

# Load employment data from an external source (worldbank)
# emp_row_total => total employed persons
# was_w => wage and salaried workers as a percentage of employed population
row_emp_data <-
  read.csv2("complementar/worldbank/employment_row.csv", row.names = 1)
colnames(row_emp_data) <- sub("X","",colnames(row_emp_data))

emp_row_total <- row_emp_data[source_version,lists$years]
was_w_row <- as.numeric(row_emp_data["was_w",lists$years])/100

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

# Calculation of employee data, assuming same working day as employed
sea_sectors[,"empe.s.un",,"ROW"] <- 
  sea_sectors[,"emp.s.un",,"ROW"] * was_w_row

sea_sectors[,"hours_worked.empe.s.hr",,"ROW"] <- 
  sea_sectors[,"hours_worked.emp.s.hr",,"ROW"] * was_w_row


## Skill strata
## Calculated as average of other countries
sea_sectors[,"hours_worked.empe_hs.r.pc",,"ROW"] <- 
  sea_sectors[,"hours_worked.empe_hs.r.pc",,which(lists$countries!="ROW")] %>%
  apply(2, rowMeans)

sea_sectors[,"hours_worked.empe_ms.r.pc",,"ROW"] <- 
  sea_sectors[,"hours_worked.empe_ms.r.pc",,which(lists$countries!="ROW")] %>%
  apply(2, rowMeans)

sea_sectors[,"hours_worked.empe_ls.r.pc",,"ROW"] <- 
  1 - sea_sectors[,"hours_worked.empe_hs.r.pc",,"ROW"] - 
  sea_sectors[,"hours_worked.empe_ms.r.pc",,"ROW"]

sea_sectors[,"compensation.empe_hs.r.pc",,"ROW"] <- 
  sea_sectors[,"compensation.empe_hs.r.pc",,which(lists$countries!="ROW")] %>%
  apply(2, rowMeans)

sea_sectors[,"compensation.empe_ms.r.pc",,"ROW"] <- 
  sea_sectors[,"compensation.empe_ms.r.pc",,which(lists$countries!="ROW")] %>%
  apply(2, rowMeans)

sea_sectors[,"compensation.empe_ls.r.pc",,"ROW"] <- 
  1 - sea_sectors[,"compensation.empe_hs.r.pc",,"ROW"] - 
  sea_sectors[,"compensation.empe_ms.r.pc",,"ROW"]

# compensation.empe.s.us and labour compensation
# Considering the same value added distribution ratio
sum_va_countries <- 
  apply(sea_sectors[,"gdp.s.us",, which(lists$countries!="ROW")], 1, sum)
sum_va_row <- 
  apply(sea_sectors[,"gdp.s.us",, "ROW"], 1, sum)
sum_empe_sector <- 
  sea_sectors[,"empe.s.un",,which(lists$countries!="ROW")] %>% 
  apply(2, rowSums)

lab_row_total <- 
  sea_sectors[,"compensation.emp.s.us",,which(lists$countries!="ROW")] %>% 
  apply(1, sum) /
  sum_va_countries * sum_va_row

sum_lab_sector <- 
  sea_sectors[,"compensation.emp.s.us",,which(lists$countries!="ROW")] %>%
  apply(2, rowSums)

sea_sectors[,"compensation.emp.s.us",,"ROW"] <- 
  as.numeric(lab_row_total) * 
  prop.table(sea_sectors[,"gdp.s.us",, "ROW"] *
               sum_lab_sector/sum_emp_sector, margin = 1)

comp_row_total <- 
  apply(sea_sectors[,"compensation.empe.s.us",,which(lists$countries!="ROW")], 1, sum)/
  sum_va_countries * sum_va_row

sum_comp_sector <- 
  sea_sectors[,"compensation.empe.s.us",,which(lists$countries!="ROW")] %>%
  apply(2, rowSums)

sea_sectors[,"compensation.empe.s.us",,"ROW"] <- 
  as.numeric(comp_row_total) * 
  prop.table(sea_sectors[,"gdp.s.us",, "ROW"] *
               sum_comp_sector/sum_emp_sector, margin = 1)

# Capital stock
# Considers the same capital requirement by value added ratio
# from a set of pre-selected countries.

least_developed <- c("GRC","HUN","BGR","BRA","SWE","LVA","CHN","PRT","POL",
                   "MLT","GBR","JPN","KOR","ROU","DNK","CZE")

sum_k_usd_sector <- apply(sea_sectors[,"capital_stock.s.us",,least_developed],
                                 2, rowSums)
sum_va_sector_least <- 
  sea_sectors[,"gdp.s.us",, least_developed] %>%
  apply(2, rowSums)

sea_sectors[,"capital_stock.s.us",,"ROW"] <- 
  sea_sectors[,"gdp.s.us",, "ROW"] * 
  sum_k_usd_sector / sum_va_sector_least

# Issue #13 validation overlay: this is the same historical assignment made
# by basket_price.r.pc.R before its first scientific use, moved before the
# after_assumptions checkpoint without changing the resulting values.
sea_sectors[,"go_price.r.id",,"ROW"] <-
  sea_sectors[,"go_price.r.id",,"USA"]

# Clear all variables that will no longer be used
rm(row_emp_data, emp_row_total, was_w_row, pre_row, row_position, sum_emp_sector, 
   sum_h_emp_sector, sum_va_sector, sum_empe_sector, lab_row_total, 
   sum_lab_sector, comp_row_total, sum_comp_sector, sum_va_countries, sum_va_row, 
   least_developed, sum_k_usd_sector, sum_va_sector_least)
