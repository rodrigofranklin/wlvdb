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

# Issue #13 validation overlay: this is the same historical assignment made
# by basket_price.r.pc.R before its first scientific use, moved before the
# after_assumptions checkpoint without changing the resulting values.
sea_sectors[,"go_price.r.id",,"ROW"] <-
  sea_sectors[,"go_price.r.id",,"USA"]
