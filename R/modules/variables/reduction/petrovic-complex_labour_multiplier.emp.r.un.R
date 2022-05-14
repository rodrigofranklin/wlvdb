## Solution to the reduction problem.
## Petrovic: average wage of each skill level of the labour power and 
## the average wage of the least complex labour

w_hs <- 
  ((sea_sectors[,"compensation.emp.s.us",,] *
     sea_sectors[,"compensation.empe_hs.r.pc",,]) %>%
  apply (1, sum, na.rm = TRUE)) /
  ((sea_sectors[,"hours_worked.emp.s.hr",,] *
     sea_sectors[,"hours_worked.empe_hs.r.pc",,]) %>%
  apply (1, sum, na.rm = TRUE))

w_ms <- 
  ((sea_sectors[,"compensation.emp.s.us",,] *
     sea_sectors[,"compensation.empe_ms.r.pc",,]) %>%
  apply (1, sum, na.rm = TRUE)) /
  ((sea_sectors[,"hours_worked.emp.s.hr",,] *
     sea_sectors[,"hours_worked.empe_ms.r.pc",,]) %>%
  apply (1, sum, na.rm = TRUE))

w_ls <- 
  ((sea_sectors[,"compensation.emp.s.us",,] *
     sea_sectors[,"compensation.empe_ls.r.pc",,]) %>%
  apply (1, sum, na.rm = TRUE)) /
  ((sea_sectors[,"hours_worked.emp.s.hr",,] *
     sea_sectors[,"hours_worked.empe_ls.r.pc",,]) %>%
  apply (1, sum, na.rm = TRUE))

multiplier_h <- w_hs/w_ls
multiplier_m <- w_ms/w_ls

sea_sectors[,"complex_labour_multiplier.emp.r.un",,] <- 
  (multiplier_h * sea_sectors[,"hours_worked.empe_hs.r.pc",,]) +
  (multiplier_m * sea_sectors[,"hours_worked.empe_ms.r.pc",,]) +
  sea_sectors[,"hours_worked.empe_ls.r.pc",,]


