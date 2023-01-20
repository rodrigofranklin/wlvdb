# Capital stock - current USD prices
code <- "capital_stock.s.us"

meta_indicators[code,"name"] <- "Capital stock (USD)"
meta_indicators[code,"description"] <- 
  paste0("Capital stock is the prices in current USD of capital assets.")
meta_indicators[code,"observation"] <- 
  paste0("Converted from national currency using the exchange rate.")
meta_indicators[code,"type"] <- "usd"
meta_indicators[code,"group"] <- "Capital"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[,code,,] <-
  sea_source[,"K",lists$sectors,] * 1000000 /
  sea_sectors[,"exchange.r.us",,]
