####
# calculates missing data for the rest of the world (RoW):
# - employment
# - labour hours
# - wages
# - capital
####

# Load employment data from an external source (worldbank)
# emp_row_total => total employed persons
# was_w => wage and salaried workers as a percentage of employed population
row_emp_data <-
  read.csv2("source_data/worldbank/employment_row.csv")
colnames(row_emp_data) <- sub("X","",colnames(row_emp_data))

emp_row_total <- row_emp_data[1,lists$years]
was_w_row <- as.numeric(row_emp_data[2,lists$years])/100

# RoW position in rows (initial and list of positions)
pre_row <- nums$countries_sectors-nums$sectors
row_position <- grep("ROW",rows$country_sector)

# Calculation of employment and labour hours
sum_emp_sector <- 
  sea_sectors[,"employed_persons",,which(lists$countries!="ROW")] %>%
  apply(2, rowSums)
sum_h_emp_sector <- 
  sea_sectors[,"hours_employed",, which(lists$countries!="ROW")] %>%
  apply(2, rowSums)
sum_va_sector <- 
  sea_sectors[,"value_added_mp",, which(lists$countries!="ROW")] %>%
  apply(2, rowSums)

sea_sectors[,"employed_persons",,"ROW"] <- 
  as.numeric(emp_row_total) * 
  prop.table(sea_sectors[,"value_added_mp",, "ROW"]*
               sum_emp_sector/sum_va_sector, margin = 1)

sea_sectors[,"hours_employed",,"ROW"] <- 
  sea_sectors[,"employed_persons",,"ROW"] * 
  sum_h_emp_sector/sum_emp_sector

# Calculation of employee data, assuming same working day as employed
sea_sectors[,"employees",,"ROW"] <- 
  sea_sectors[,"employed_persons",,"ROW"] * was_w_row

sea_sectors[,"hours_employees",,"ROW"] <- 
  sea_sectors[,"hours_employed",,"ROW"] * was_w_row


## Skill strata
## Calculated as average of other countries
sea_sectors[,"hours_ratio_hs",,"ROW"] <- 
  sea_sectors[,"hours_ratio_hs",,which(lists$countries!="ROW")] %>%
  apply(2, rowMeans)

sea_sectors[,"hours_ratio_ms",,"ROW"] <- 
  sea_sectors[,"hours_ratio_ms",,which(lists$countries!="ROW")] %>%
  apply(2, rowMeans)

sea_sectors[,"hours_ratio_ls",,"ROW"] <- 
  1 - sea_sectors[,"hours_ratio_hs",,"ROW"] - 
  sea_sectors[,"hours_ratio_ms",,"ROW"]

sea_sectors[,"compensation_ratio_hs",,"ROW"] <- 
  sea_sectors[,"compensation_ratio_hs",,which(lists$countries!="ROW")] %>%
  apply(2, rowMeans)

sea_sectors[,"compensation_ratio_ms",,"ROW"] <- 
  sea_sectors[,"compensation_ratio_ms",,which(lists$countries!="ROW")] %>%
  apply(2, rowMeans)

sea_sectors[,"compensation_ratio_ls",,"ROW"] <- 
  1 - sea_sectors[,"compensation_ratio_hs",,"ROW"] - 
  sea_sectors[,"compensation_ratio_ms",,"ROW"]

# wages and labour compensation
# Considering the same value added distribution ratio
sum_va_countries <- 
  apply(sea_sectors[,"value_added_mp",, which(lists$countries!="ROW")], 1, sum)
sum_va_row <- 
  apply(sea_sectors[,"value_added_mp",, "ROW"], 1, sum)
sum_empe_sector <- 
  sea_sectors[,"employees",,which(lists$countries!="ROW")] %>% 
  apply(2, rowSums)

lab_row_total <- 
  sea_sectors[,"labour_compensation",,which(lists$countries!="ROW")] %>% 
  apply(1, sum) /
  sum_va_countries * sum_va_row

sum_lab_sector <- 
  sea_sectors[,"labour_compensation",,which(lists$countries!="ROW")] %>%
  apply(2, rowSums)

sea_sectors[,"labour_compensation",,"ROW"] <- 
  as.numeric(lab_row_total) * 
  prop.table(sea_sectors[,"value_added_mp",, "ROW"] *
               sum_lab_sector/sum_emp_sector, margin = 1)

comp_row_total <- 
  apply(sea_sectors[,"wages",,which(lists$countries!="ROW")], 1, sum)/
  sum_va_countries * sum_va_row

sum_comp_sector <- 
  sea_sectors[,"wages",,which(lists$countries!="ROW")] %>%
  apply(2, rowSums)

sea_sectors[,"wages",,"ROW"] <- 
  as.numeric(comp_row_total) * 
  prop.table(sea_sectors[,"value_added_mp",, "ROW"] *
               sum_comp_sector/sum_emp_sector, margin = 1)


# Capital stock
# Considers the same capital requirement by value added ratio
# from a set of pre-selected countries.

least_developed <- c("GRC","HUN","BGR","BRA","SWE","LVA","CHN","PRT","POL",
                   "MLT","GBR","JPN","KOR","ROU","DNK","CZE")

sum_k_usd_sector <- apply(sea_sectors[,"capital_stock",,least_developed],
                                 2, rowSums)
sum_va_sector_least <- 
  sea_sectors[,"value_added_mp",, least_developed] %>%
  apply(2, rowSums)

sea_sectors[,"capital_stock",,"ROW"] <- 
  sea_sectors[,"value_added_mp",, "ROW"] * 
  sum_k_usd_sector / sum_va_sector_least

# Clear all variables that will no longer be used
rm(row_emp_data, emp_row_total, was_w_row, pre_row, row_position, sum_emp_sector, 
   sum_h_emp_sector, sum_va_sector, sum_empe_sector, lab_row_total, 
   sum_lab_sector, comp_row_total, sum_comp_sector, sum_va_countries, sum_va_row, 
   least_developed, sum_k_usd_sector, sum_va_sector_least)
