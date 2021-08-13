## Solution to the reduction problem.
## Alternative 2: arbitrary multipliers

multiplier_h <- 6.25
multiplier_m <- 2.5

sea_sectors[,"z",,] <- 
  (multiplier_h * sea_sectors[,"hours_ratio_hs",,]) +
  (multiplier_m * sea_sectors[,"hours_ratio_ms",,]) +
  sea_sectors[,"hours_ratio_ls",,]

