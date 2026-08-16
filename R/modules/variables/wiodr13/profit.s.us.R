# capital compensation
code <- "profit.s.us"

meta_indicators[code,"name"] <- "Profit (USD)"
meta_indicators[code,"description"] <- 
  paste0("Profit and others capital compensations.")
meta_indicators[code,"observation"] <- 
  paste0("Converted from national currency using the exchange rate.")
meta_indicators[code,"type"] <- "usd"
meta_indicators[code,"group"] <- "Capital"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[,code,,] <-
  sea_source[,"CAP",lists$sectors,] /
  sea_sectors[,"exchange.r.us",,]
