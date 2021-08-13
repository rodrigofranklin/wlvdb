## Solution to the reduction problem.
## Alternative 2: arbitrary multipliers

sea_sectors[,"z_employees",,] <- sea_sectors[,"z",,]

# sets new rates for hours ratio (of abstract labour)
sea_sectors[,"hours_ratio_hs",,] <- 
  (multiplier_h * sea_sectors[,"hours_ratio_hs",,]) / sea_sectors[,"z",,]
sea_sectors[,"hours_ratio_ms",,] <- 
  (multiplier_m * sea_sectors[,"hours_ratio_ms",,]) / sea_sectors[,"z",,]
sea_sectors[,"hours_ratio_ls",,] <- 
  sea_sectors[,"hours_ratio_ls",,] / sea_sectors[,"z",,]
