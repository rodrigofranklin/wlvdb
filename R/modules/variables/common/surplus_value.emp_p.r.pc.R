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

sea_sectors[,code,,] <- 
  sea_sectors[,"surplus_value.emp.r.pc",,] *
  rows$productive %>% rep(each = nums$years)