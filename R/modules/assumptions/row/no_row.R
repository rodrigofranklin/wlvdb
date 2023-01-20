####
# Cálculo sem pressupostos sobre RoW
####
parameters$description <- 
  paste0("Rest of World: all data for RoW was considered zero. ",
         parameters$description)

sea_sectors[,"emp.s.un",,"ROW"] <- 0

sea_sectors[,"hours_worked.emp.s.hr",,"ROW"] <- 0

sea_sectors[,"empe.s.un",,"ROW"] <- 0

sea_sectors[,"hours_worked.empe.s.hr",,"ROW"] <- 0

sea_sectors[,"compensation.emp.s.us",,"ROW"] <- 0

sea_sectors[,"compensation.empe.s.us",,"ROW"] <- 0

sea_sectors[,"capital_stock.s.us",,"ROW"] <- 0
