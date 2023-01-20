## Solution to the reduction problem.
## Ochoa 2: national average wage index
code <- "complex_labour_multiplier.emp.r.un"

meta_indicators[code,"name"] <- "Complex labour multiplier"
meta_indicators[code,"description"] <- 
  paste0("Multiplier of labour accordingly it's complexty and intensity.")
meta_indicators[code,"observation"] <- 
  paste0("Reduction Problem: Ochoa 2: uses market wages as an index of skill ",
         "and intensity of labour in a national process of equalization of ",
         "rate of surplus value.")
meta_indicators[code,"type"] <- "index"
meta_indicators[code,"group"] <- "Others"
meta_indicators[code,"reverted"] <- FALSE

w_average <- 
  sea_sectors[,"compensation.emp.s.us",,] /
  sea_sectors[,"hours_worked.emp.s.hr",,]

# defines zeros as inifite to keep out of function "min"
w_average[is.na(w_average)] <- Inf
w_average[w_average==0] <- Inf

w_nationa_min <- 
  w_average %>%
  apply(1, tapply, rows$num_country, min, na.rm = TRUE)

w_nationa_min <- rep(w_nationa_min, times = nums$sectors)

dim(w_nationa_min) <- c(nums$countries, nums$years, nums$sectors)
w_nationa_min <- aperm(w_nationa_min, c(2,3,1))

w_average[is.infinite(w_average)] <- 0

sea_sectors[,"complex_labour_multiplier.emp.r.un",,] <- 
  w_average / w_nationa_min
