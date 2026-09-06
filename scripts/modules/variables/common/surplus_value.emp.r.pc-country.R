# exploitation rate of employee of each country and of the whole world
country_indicator <- "surplus_value.emp.r.pc"
ratio_numerator <- sea_countries[, "abstract_labour.emp.s.mv", ]
ratio_denominator <- sea_countries[, "labour_force_value.emp.s.mv", ]
ratio_value <- if (exists("wlv_contract_runtime", inherits = FALSE)) {
  wlv_ratio_runtime(
    wlv_contract_runtime, ratio_numerator, ratio_denominator,
    zero = "not_applicable", artifact = "sea_countries",
    indicator = country_indicator, checkpoint = "after_country_module",
    stage = 5L, module = "common/surplus_value.emp.r.pc-country.R",
    axes = c(year = 1L, country = 2L)
  )
} else ratio_numerator / ratio_denominator
sea_countries[, country_indicator, ] <- ratio_value - 1
rm(country_indicator, ratio_numerator, ratio_denominator, ratio_value)
