# "Exploitation rate" of employed persons (productive sectors)
code <- "surplus_value.emp_p.r.pc"

meta_indicators[code,"name"] <- 
  "Rate of surplus value of persons engaged (productive workers)"
meta_indicators[code,"description"] <- 
  paste0("Rate of surplus value of persons engage, include only productive ",
         "sectors.")
meta_indicators[code,"observation"] <- 
  paste0("Obtained by dividing the sum of abstract labour of persons engaged ",
         "by the labour compensation of productive sectors, minus one.")
meta_indicators[code,"type"] <- "percent"
meta_indicators[code,"group"] <- "Rate of surplus value"
meta_indicators[code,"reverted"] <- TRUE

source_value <- sea_sectors[, "surplus_value.emp.r.pc", , ]
sea_sectors[,code,,] <-
  source_value *
  rows$productive %>% rep(each = nums$years)
if (exists("wlv_contract_runtime", inherits = FALSE)) {
  wlv_contract_copy_indicator_states(
    wlv_contract_runtime,
    artifact = "sea_sectors",
    source_indicator = "surplus_value.emp.r.pc",
    target_indicator = code,
    value = source_value,
    checkpoint = "after_stage_5"
  )
}
rm(source_value)
