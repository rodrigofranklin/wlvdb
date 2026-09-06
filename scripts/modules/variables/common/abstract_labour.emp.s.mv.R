# l' = l x z

code <- "abstract_labour.emp.s.mv"

meta_indicators[code,"name"] <- "Total abstract labour of persons engaged"
meta_indicators[code,"description"] <- 
  paste0("Total abstract labour of persons engaged is the hours worked by ",
         "persons engaged converted in abstract labour by the complex ",
         "labour multiplier.")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "value"
meta_indicators[code,"group"] <- "Labour and employment"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[,code,,] <- 
  sea_sectors[,"hours_worked.emp.s.hr",,] * 
  sea_sectors[,"complex_labour_multiplier.emp.r.un",,]
