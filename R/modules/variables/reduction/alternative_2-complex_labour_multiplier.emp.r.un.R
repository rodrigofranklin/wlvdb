## Solution to the reduction problem.
## Alternative 2: arbitrary multipliers

multiplier_h <- 6.25
multiplier_m <- 2.5

sea_sectors[,"complex_labour_multiplier.emp.r.un",,] <- 
  (multiplier_h * sea_sectors[,"hours_worked.empe_hs.r.pc",,]) +
  (multiplier_m * sea_sectors[,"hours_worked.empe_ms.r.pc",,]) +
  sea_sectors[,"hours_worked.empe_ls.r.pc",,]

