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

ratio_numerator <- sea_sectors[lists$years, "trade_transfers.p.s.mv", , ]
ratio_denominator <- sea_sectors[lists$years, "gdp.s.mv", , ]
sea_sectors[lists$years, code, , ] <- if (exists("wlv_contract_runtime", inherits = FALSE)) {
  wlv_ratio_runtime(
    wlv_contract_runtime, ratio_numerator, ratio_denominator,
    zero = "not_applicable", artifact = "sea_sectors",
    indicator = code, checkpoint = "after_stage_5", stage = 5L,
    module = "common/trade_transfers.p.m.pc.R",
    axes = c(year = 1L, sector = 2L, country = 3L)
  )
} else ratio_numerator / ratio_denominator
rm(ratio_numerator, ratio_denominator)
