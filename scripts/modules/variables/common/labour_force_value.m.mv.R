# Sum of labour force value of each sector
code <- "labour_force_value.m.mv"

meta_indicators[code,"name"] <- "Labour force average value"
meta_indicators[code,"description"] <- 
  paste0("Average value of labour force is the socially necessary labour-time ",
         "required to produce the consumption basket of an average worker.")
meta_indicators[code,"observation"] <- 
  paste0("Obtained by dividing variable capital by the number of employees.")
meta_indicators[code,"type"] <- "value"
meta_indicators[code,"group"] <- "Wages and value of labour force"
meta_indicators[code,"reverted"] <- FALSE

ratio_numerator <- sea_sectors[lists$years, "labour_force_value.s.mv", , ]
ratio_denominator <- sea_sectors[lists$years, "empe.s.un", , ]
sea_sectors[lists$years, code, , ] <- if (exists("wlv_contract_runtime", inherits = FALSE)) {
  wlv_ratio_runtime(
    wlv_contract_runtime, ratio_numerator, ratio_denominator,
    zero = "not_applicable", artifact = "sea_sectors",
    indicator = code, checkpoint = "after_stage_5", stage = 5L,
    module = "common/labour_force_value.m.mv.R",
    axes = c(year = 1L, sector = 2L, country = 3L)
  )
} else ratio_numerator / ratio_denominator
rm(ratio_numerator, ratio_denominator)
