# Jornada de trabalho média - trabalhadores assalariados - em magnitude de valor
code <- "abstract_labour.empe.m.mv"

meta_indicators[code,"name"] <-
  "Working day of employee per year (magnitude of value)"
meta_indicators[code,"description"] <- paste0(
  'Average magnitude of value "created" by employee per year. Includes ',
  "productive and unproductive workers.")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "value"
meta_indicators[code,"group"] <- "Labour and employment"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[lists$years,code,,] <- 
  sea_sectors[lists$years,"abstract_labour.empe.s.mv",,] /
  sea_sectors[lists$years,"empe.s.un",,]
