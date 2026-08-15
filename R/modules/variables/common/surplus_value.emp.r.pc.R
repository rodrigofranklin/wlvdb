# Exploitation rate of employee
code <- "surplus_value.emp.r.pc"

meta_indicators[code,"name"] <- "Rate of surplus value of persons engaged"
meta_indicators[code,"description"] <- 
  paste0("Rate of surplus value of persons engaged. It includes productive and ",
         "unproductive sectors.")
meta_indicators[code,"observation"] <- 
  paste0("Obtained by dividing the sum of abstract labour of productive and ",
         "unproductive persons engaged by the labour compensation in magnitude ",
         "of value, minus one.")
meta_indicators[code,"type"] <- "percent"
meta_indicators[code,"group"] <- "Rate of surplus value"
meta_indicators[code,"reverted"] <- TRUE

ratio_numerator <- sea_sectors[, "abstract_labour.emp.s.mv", , ]
ratio_denominator <- sea_sectors[, "labour_force_value.emp.s.mv", , ]
ratio_value <- if (exists("wlv_contract_runtime", inherits = FALSE)) {
  wlv_ratio_runtime(
    wlv_contract_runtime, ratio_numerator, ratio_denominator,
    zero = "not_applicable", artifact = "sea_sectors",
    indicator = code, checkpoint = "after_stage_5", stage = 5L,
    module = "common/surplus_value.emp.r.pc.R",
    axes = c(year = 1L, sector = 2L, country = 3L)
  )
} else ratio_numerator / ratio_denominator
sea_sectors[, code, , ] <- ratio_value - 1
rm(ratio_numerator, ratio_denominator, ratio_value)


