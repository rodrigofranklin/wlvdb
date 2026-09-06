# Taxa de lucro apropriado monetariamente
country_indicator <- "appropriated_profit.r.pc"
ratio_numerator <-
  sea_countries[, "profit.s.us", ] -
  sea_countries[, "capital_depreciation.s.us", ]
ratio_denominator <- sea_countries[, "capital_stock.s.us", ]
sea_countries[, country_indicator, ] <- if (
  exists("wlv_contract_runtime", inherits = FALSE)
) {
  wlv_ratio_runtime(
    wlv_contract_runtime, ratio_numerator, ratio_denominator,
    zero = "not_applicable", artifact = "sea_countries",
    indicator = country_indicator, checkpoint = "after_country_module",
    stage = 5L, module = "common/appropriated_profit.r.pc-country.R",
    axes = c(year = 1L, country = 2L)
  )
} else ratio_numerator / ratio_denominator
rm(country_indicator, ratio_numerator, ratio_denominator)
