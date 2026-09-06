## Solution to the reduction problem.
## Ochoa 1: average wage index
code <- "complex_labour_multiplier.emp.r.un"

meta_indicators[code,"name"] <- "Complex labour multiplier"
meta_indicators[code,"description"] <- 
  paste0("Multiplier of labour accordingly it's complexty and intensity.")
meta_indicators[code,"observation"] <- 
  paste0("Reduction Problem: Ochoa 1: uses market wages as an index of skill ",
         "and intensity of labour in a world wide process of equalization of ",
         "rate of surplus value.")
meta_indicators[code,"type"] <- "index"
meta_indicators[code,"group"] <- "Others"
meta_indicators[code,"reverted"] <- FALSE

w_average <- 
  sea_sectors[,"compensation.emp.s.us",,] /
  sea_sectors[,"hours_worked.emp.s.hr",,]

w_average[is.nan(w_average)] <- 0
w_average[is.infinite(w_average)] <- 0

w_min <- w_average
w_min[w_min==0] <- Inf
w_min <- w_min %>%
  apply(1, min, na.rm = TRUE) %>%
  rep(times = nums$countries_sectors)

sea_sectors[,"complex_labour_multiplier.emp.r.un",,] <- 
  w_average/w_min

rm(w_average, w_min)