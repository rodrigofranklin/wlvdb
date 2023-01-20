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

sea_sectors[,code,,] <- 
  (sea_sectors[,"abstract_labour.emp.s.mv",,] /
  sea_sectors[,"labour_force_value.emp.s.mv",,]) -1


