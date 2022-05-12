## Solution to the reduction problem.
## Ochoa 1: national average wage index

w_average <- 
  sea_sectors[,"compensation.empe.s.us",,] /
  sea_sectors[,"hours_worked.empe.s.hr",,]

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

sea_sectors[,"complex_labour_multiplier.empe.r.un",,] <- 
  w_average / w_nationa_min
