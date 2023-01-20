# Soma dos valores recebidos via comércio internacional dos setores produtivos
# TROCA DESIGUAL (em % do valor produzido)
code <- "trade_transfers.p.m.pc"

meta_indicators[code,"name"] <- 
  "Transfer of value through trade (productive sectors) (% of GDP)"
meta_indicators[code,"description"] <- 
  paste0("Transfer of value through trade in productive sectors represents the ",
         "value received from (if positive) or sent to (if negative) to the rest ",
         "of the world as a result of the diference between ",
         "the value represented by the amount of money received (from ",
         "exports) or sent (from imports) and the actually abstract labour ",
         "embodied in commodities traded. This ",
         'data is equivalent of what some authors call "unequal exchange" ',
         "(Bettleheim and others). Data are in percentage of GDP in magnitude ",
         "of value.")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "percent"
meta_indicators[code,"group"] <- "International trade"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[lists$years,code,,] <- 
  sea_sectors[lists$years,"trade_transfers.p.s.mv",,] /
  sea_sectors[lists$years,"gdp.s.mv",,]