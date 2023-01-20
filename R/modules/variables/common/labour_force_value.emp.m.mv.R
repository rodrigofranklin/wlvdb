# Sum of labour force value of each sector
code <- "labour_force_value.emp.m.mv"

meta_indicators[code,"name"] <- "Worker's average reproduction value"
meta_indicators[code,"description"] <- 
  paste0("Worker's average reproduction value representes the socially ",
         "necessary labour-time required to produce the consumptio basket ",
         "consumed by person engaged.")
meta_indicators[code,"observation"] <- 
  paste0("Obtained by dividing labour compensation in magnitude of value by the ",
  "number of persons engaged.")
meta_indicators[code,"type"] <- "value"
meta_indicators[code,"group"] <- "Wages and value of labour force"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[lists$years,code,,] <- 
  sea_sectors[lists$years,"labour_force_value.emp.s.mv",,] /
  sea_sectors[lists$years,"emp.s.un",,]