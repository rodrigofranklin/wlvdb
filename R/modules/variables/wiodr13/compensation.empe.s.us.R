# wages
code <- "compensation.empe.s.us"

meta_indicators[code,"name"] <- "Salaries and wages (USD)"
meta_indicators[code,"description"] <- 
  paste0("Remuneration received by wage and salaried workers.")
meta_indicators[code,"observation"] <- 
  paste0("Converted from national currency using the exchange rate.")
meta_indicators[code,"type"] <- "usd"
meta_indicators[code,"group"] <- "Wages and value of labour force"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[,code,,] <-
  sea_source[,"COMP",lists$sectors,] * 1000000 / 
  sea_sectors[,"exchange.r.us",,]
