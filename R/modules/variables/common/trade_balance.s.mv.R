# Trade balance in magnitude of value
code <- "trade_balance.s.mv"

meta_indicators[code,"name"] <- 
  "Trade balance on good and services (magnitude of value)"
meta_indicators[code,"description"] <- 
  paste0("Trade balance on goods and services equals exports of goods and ",
         "services minus imports of goods and services. Data are in magnitude ",
         "of value")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "value"
meta_indicators[code,"group"] <- "International trade"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[lists$years,code,,] <- 
  sea_sectors[lists$years,"exports.s.mv",,] -
  sea_sectors[lists$years,"imports.s.mv",,]