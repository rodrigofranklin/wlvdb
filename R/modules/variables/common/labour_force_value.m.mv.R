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

sea_sectors[lists$years,code,,] <- 
  sea_sectors[lists$years,"labour_force_value.s.mv",,] /
  sea_sectors[lists$years,"empe.s.un",,]