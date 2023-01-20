# Hours worked by employed persons
code <- "hours_worked.emp.s.hr"

meta_indicators[code,"name"] <- "Total hours worked by persons engaged"
meta_indicators[code,"description"] <- 
  paste0("Total hours worked by persons engaged represents the sum of hours ",
         "worker in a year by persons engaged.")
meta_indicators[code,"observation"] <- 
  paste0("Estimated from the average hours worked by employees.")
meta_indicators[code,"type"] <- "hours"
meta_indicators[code,"group"] <- "Labour and employment"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[,code,,] <-
  sea_source[,"H_EMPE",lists$sectors,] /
  sea_source[,"EMPE",lists$sectors,] * 
  sea_source[,"EMP",lists$sectors,] * 1000000

