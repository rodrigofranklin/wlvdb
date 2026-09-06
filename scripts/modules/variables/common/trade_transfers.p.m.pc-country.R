# Soma dos valores recebidos via comércio internacional dos setores produtivos
# TROCA DESIGUAL (em % do valor produzido)

country_indicator <- "trade_transfers.p.m.pc"
ratio_numerator <- sea_countries[lists$years, "trade_transfers.p.s.mv", ]
ratio_denominator <- sea_countries[lists$years, "gdp.s.mv", ]
sea_countries[lists$years, country_indicator, ] <- if (
  exists("wlv_contract_runtime", inherits = FALSE)
) {
  wlv_ratio_runtime(
    wlv_contract_runtime, ratio_numerator, ratio_denominator,
    zero = "not_applicable", artifact = "sea_countries",
    indicator = country_indicator, checkpoint = "after_country_module",
    stage = 5L, module = "common/trade_transfers.p.m.pc-country.R",
    axes = c(year = 1L, country = 2L)
  )
} else ratio_numerator / ratio_denominator
rm(country_indicator, ratio_numerator, ratio_denominator)
