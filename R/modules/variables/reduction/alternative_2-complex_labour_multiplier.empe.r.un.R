## Solution to the reduction problem.
## Alternative 2: arbitrary multipliers

sea_sectors[,"complex_labour_multiplier.empe.r.un",,] <- 
  sea_sectors[,"complex_labour_multiplier.emp.r.un",,]

# sets new rates for hours ratio (of abstract labour)
sea_sectors[,"hours_worked.empe_hs.r.pc",,] <- 
  (multiplier_h * sea_sectors[,"hours_worked.empe_hs.r.pc",,]) / 
  sea_sectors[,"complex_labour_multiplier.emp.r.un",,]
sea_sectors[,"hours_worked.empe_ms.r.pc",,] <- 
  (multiplier_m * sea_sectors[,"hours_worked.empe_ms.r.pc",,]) / 
  sea_sectors[,"complex_labour_multiplier.emp.r.un",,]
sea_sectors[,"hours_worked.empe_ls.r.pc",,] <- 
  sea_sectors[,"hours_worked.empe_ls.r.pc",,] / 
  sea_sectors[,"complex_labour_multiplier.emp.r.un",,]
