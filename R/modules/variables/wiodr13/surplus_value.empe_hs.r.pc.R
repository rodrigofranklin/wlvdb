# exploitation rate of high skilled employees
code <- "surplus_value.empe_hs.r.pc"

meta_indicators[code,"name"] <- "Rate of surplus value (high skilled)"
meta_indicators[code,"description"] <- 
  paste0("Rate of surplus value high skilled employees. It is a measure of ",
         "exploitation of labour in a capitalist relation of production.")
meta_indicators[code,"observation"] <- 
  paste0("Obtained by dividing the sum of abstract labour of high skilled ",
         "employees by the sum of labour force value of high skilled employees, ",
         "minus one.")
meta_indicators[code,"type"] <- "percent"
meta_indicators[code,"group"] <- "Rate of surplus value"
meta_indicators[code,"reverted"] <- TRUE

sea_sectors[,code,,] <- 
  ((sea_sectors[,"abstract_labour.empe.s.mv",,] * 
      sea_sectors[,"hours_worked.empe_hs.r.pc",,]) /
     (sea_sectors[,"labour_force_value.s.mv",,] *
        sea_sectors[,"compensation.empe_hs.r.pc",,])) -1


