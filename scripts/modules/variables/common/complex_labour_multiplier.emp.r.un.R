## Complex labour multiplier
code <- "complex_labour_multiplier.emp.r.un"

meta_indicators[code,"name"] <- "Complex labour multiplier"
meta_indicators[code,"description"] <- 
  paste0("Multiplier of labour accordingly it's complexty and intensity.")
meta_indicators[code,"observation"] <- 
  paste0("The standard treatment is to consider all labour as equal.")
meta_indicators[code,"type"] <- "index"
meta_indicators[code,"group"] <- "Others"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[,code,,] <- 1
