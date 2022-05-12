## Solution to the reduction problem.
## Ochoa 1: average wage index

w_average <- 
  sea_sectors[,"compensation.empe.s.us",,] /
  sea_sectors[,"hours_worked.empe.s.hr",,]

w_average[is.nan(w_average)] <- 0
w_average[is.infinite(w_average)] <- 0

w_min <- w_average
w_min[w_min==0] <- Inf
w_min <- w_min %>%
  apply(1, min, na.rm = TRUE) %>%
  rep(times = nums$countries_sectors)

sea_sectors[,"complex_labour_multiplier.empe.r.un",,] <- 
  w_average/w_min

rm(w_average, w_min)
