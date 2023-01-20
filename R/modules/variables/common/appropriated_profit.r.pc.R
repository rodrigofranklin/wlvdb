# Profit rate - appropriated profit
code <- "appropriated_profit.r.pc"

meta_indicators[code,"name"] <- "Rate of appropriated profit"
meta_indicators[code,"description"] <- 
  paste0("Rate of appropriated profit represents the relation between the ",
         "net profit appropriated by a sector (profit minus capital ", 
         "depreciation) and its stock of capital. This is a first approximation ",
         "about the profit rate. It does not correspond to the Marxist concept ",
         "of profit rate (i.e., surplus value divided by constant and variable ",
         "capital).")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "percent"
meta_indicators[code,"group"] <- "Capital"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[,code,,] <-
  (sea_sectors[,"profit.s.us",lists$sectors,] - 
     sea_sectors[,"capital_depreciation.s.us",lists$sectors,]) /
  sea_sectors[,"capital_stock.s.us",,]
