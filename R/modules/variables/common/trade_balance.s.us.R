# Trade balance in usd
code <- "trade_balance.s.us"

meta_indicators[code,"name"] <- "Trade balance on good and services (USD)"
meta_indicators[code,"description"] <- 
  paste0("Trade balance on goods and services equals exports of goods and ",
         "services minus imports of goods and services.")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "usd"
meta_indicators[code,"group"] <- "International trade"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[lists$years,code,,] <- 
  sea_sectors[lists$years,"exports.s.us",,] -
  sea_sectors[lists$years,"imports.s.us",,]