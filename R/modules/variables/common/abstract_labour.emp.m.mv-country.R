# Mean of abstract labour per person engaged

country_indicator <- "abstract_labour.emp.m.mv"
ratio_numerator <- sea_countries[lists$years, "abstract_labour.emp.s.mv", ]
ratio_denominator <- sea_countries[lists$years, "emp.s.un", ]
sea_countries[lists$years, country_indicator, ] <- if (
  exists("wlv_contract_runtime", inherits = FALSE)
) {
  wlv_ratio_runtime(
    wlv_contract_runtime, ratio_numerator, ratio_denominator,
    zero = "not_applicable", artifact = "sea_countries",
    indicator = country_indicator, checkpoint = "after_country_module",
    stage = 5L, module = "common/abstract_labour.emp.m.mv-country.R",
    axes = c(year = 1L, country = 2L)
  )
} else ratio_numerator / ratio_denominator
rm(country_indicator, ratio_numerator, ratio_denominator)
