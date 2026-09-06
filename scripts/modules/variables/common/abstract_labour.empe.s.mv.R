# l' = l x z
code <- "abstract_labour.empe.s.mv"

meta_indicators[code,"name"] <- "Total abstract labour of emplyees"
meta_indicators[code,"description"] <- 
  paste0("Total abstract labour of emplyees is the hours worked by ",
         "employees converted in abstract labour by the complex ",
         "labour multiplier.")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "value"
meta_indicators[code,"group"] <- "Labour and employment"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[,code,,] <- 
  sea_sectors[,"hours_worked.empe.s.hr",,] * 
  sea_sectors[,"complex_labour_multiplier.empe.r.un",,]
