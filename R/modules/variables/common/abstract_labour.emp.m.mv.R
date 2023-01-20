# Jornada de trabalho média - pessoas ocupadas - em magnitude de valor

code <- "abstract_labour.emp.m.mv"

meta_indicators[code,"name"] <-
  "Working day of persons engaged per year (magnitude of value)"
meta_indicators[code,"description"] <- paste0(
  'Average magnitude of value "created" by persons engaged per year. Includes ',
  "productive and unproductive workers.")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "value"
meta_indicators[code,"group"] <- "Labour and employment"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[lists$years,code,,] <- 
  sea_sectors[lists$years,"abstract_labour.emp.s.mv",,] /
  sea_sectors[lists$years,"emp.s.un",,]
