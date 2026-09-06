# Sum of labour force value of each sector

country_indicator <- "labour_force_value.emp.m.mv"
ratio_numerator <- sea_countries[lists$years, "labour_force_value.emp.s.mv", ]
ratio_denominator <- sea_countries[lists$years, "emp.s.un", ]
sea_countries[lists$years, country_indicator, ] <- if (
  exists("wlv_contract_runtime", inherits = FALSE)
) {
  wlv_ratio_runtime(
    wlv_contract_runtime, ratio_numerator, ratio_denominator,
    zero = "not_applicable", artifact = "sea_countries",
    indicator = country_indicator, checkpoint = "after_country_module",
    stage = 5L, module = "common/labour_force_value.emp.m.mv-country.R",
    axes = c(year = 1L, country = 2L)
  )
} else ratio_numerator / ratio_denominator
rm(country_indicator, ratio_numerator, ratio_denominator)
