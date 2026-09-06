# Soma dos valores recebidos via comércio internacional dos setores improdutivos
code <- "trade_transfers.u.s.mv"

meta_indicators[code,"name"] <- 
  "Transfer of value through trade (unproductive sectors)"
meta_indicators[code,"description"] <- 
  paste0("The transfer of value through trade in unproductive sectors refers ",
         "to the value represented by the amount of money received (in exports) ",
         "or sent (in imports) in transactions involving unproductive sectors.")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "value"
meta_indicators[code,"group"] <- "International trade"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[lists$years,code,,] <- 
  sea_sectors[lists$years,"trade_transfers.s.mv",,] -
  sea_sectors[lists$years,"trade_transfers.p.s.mv",,]
