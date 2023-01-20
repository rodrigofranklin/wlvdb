# Exploitation rate of employee
code <- "surplus_value.empe.r.pc"

meta_indicators[code,"name"] <- "Rate of surplus value"
meta_indicators[code,"description"] <- 
  paste0("Rate of surplus value of productive and unproductive employees. It ",
         "is a measure of exploitation of labour in a capitalist relation of ",
         "production.")
meta_indicators[code,"observation"] <- 
  paste0("Obtained by dividing the sum of abstract labour of productive and ",
         "unproductive employees by the variable capital, minus one.")
meta_indicators[code,"type"] <- "percent"
meta_indicators[code,"group"] <- "Rate of surplus value"
meta_indicators[code,"reverted"] <- TRUE

sea_sectors[,code,,] <- 
  (sea_sectors[,"abstract_labour.empe.s.mv",,] /
  sea_sectors[,"labour_force_value.s.mv",,]) -1


