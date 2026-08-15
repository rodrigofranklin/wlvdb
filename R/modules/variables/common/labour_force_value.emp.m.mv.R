# Sum of labour force value of each sector
code <- "labour_force_value.emp.m.mv"

meta_indicators[code,"name"] <- "Worker's average reproduction value"
meta_indicators[code,"description"] <- 
  paste0("Worker's average reproduction value representes the socially ",
         "necessary labour-time required to produce the consumptio basket ",
         "consumed by person engaged.")
meta_indicators[code,"observation"] <- 
  paste0("Obtained by dividing labour compensation in magnitude of value by the ",
  "number of persons engaged.")
meta_indicators[code,"type"] <- "value"
meta_indicators[code,"group"] <- "Wages and value of labour force"
meta_indicators[code,"reverted"] <- FALSE

ratio_numerator <- sea_sectors[lists$years, "labour_force_value.emp.s.mv", , ]
ratio_denominator <- sea_sectors[lists$years, "emp.s.un", , ]
sea_sectors[lists$years, code, , ] <- if (exists("wlv_contract_runtime", inherits = FALSE)) {
  wlv_ratio_runtime(
    wlv_contract_runtime, ratio_numerator, ratio_denominator,
    zero = "not_applicable", artifact = "sea_sectors",
    indicator = code, checkpoint = "after_stage_5", stage = 5L,
    module = "common/labour_force_value.emp.m.mv.R",
    axes = c(year = 1L, sector = 2L, country = 3L)
  )
} else ratio_numerator / ratio_denominator
rm(ratio_numerator, ratio_denominator)
