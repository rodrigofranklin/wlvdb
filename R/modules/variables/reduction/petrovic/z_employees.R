## Solution to the reduction problem.
## Petrovic: average wage of each skill level of the labour power and 
## the average wage of the least complex labour

w_hs <- 
  ((sea_sectors[,"wages",,] *
     sea_sectors[,"compensation_ratio_hs",,]) %>%
  apply (1, sum, na.rm = TRUE)) /
  ((sea_sectors[,"hours_employees",,] *
     sea_sectors[,"hours_ratio_hs",,]) %>%
  apply (1, sum, na.rm = TRUE))

w_ms <- 
  ((sea_sectors[,"wages",,] *
     sea_sectors[,"compensation_ratio_ms",,]) %>%
  apply (1, sum, na.rm = TRUE)) /
  ((sea_sectors[,"hours_employees",,] *
     sea_sectors[,"hours_ratio_ms",,]) %>%
  apply (1, sum, na.rm = TRUE))

w_ls <- 
  ((sea_sectors[,"wages",,] *
     sea_sectors[,"compensation_ratio_ls",,]) %>%
  apply (1, sum, na.rm = TRUE)) /
  ((sea_sectors[,"hours_employees",,] *
     sea_sectors[,"hours_ratio_ls",,]) %>%
  apply (1, sum, na.rm = TRUE))

multiplier_h <- w_hs/w_ls
multiplier_m <- w_ms/w_ls

sea_sectors[,"z_employees",,] <- 
  (multiplier_h * sea_sectors[,"hours_ratio_hs",,]) +
  (multiplier_m * sea_sectors[,"hours_ratio_ms",,]) +
  sea_sectors[,"hours_ratio_ls",,]

# sets new rates for hours ratio (of abstract labour) to employees
sea_sectors[,"hours_ratio_hs",,] <- 
  (multiplier_h * sea_sectors[,"hours_ratio_hs",,]) / 
  sea_sectors[,"z_employees",,]

sea_sectors[,"hours_ratio_ms",,] <- 
  (multiplier_m * sea_sectors[,"hours_ratio_ms",,]) / 
  sea_sectors[,"z_employees",,]

sea_sectors[,"hours_ratio_ls",,] <- 
  sea_sectors[,"hours_ratio_ls",,] / 
  sea_sectors[,"z_employees",,]

