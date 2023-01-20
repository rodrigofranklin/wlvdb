## Solution to the reduction problem.
## Petrovic: average wage of each skill level of the labour power and 
## the average wage of the least complex labour
code <- "complex_labour_multiplier.empe.r.un"

meta_indicators[code,"name"] <- "Complex labour multiplier (employees only)"
meta_indicators[code,"description"] <- 
  paste0("Multiplier of labour of emplyees accordingly it's complexty and ",
         "intensity.")
meta_indicators[code,"observation"] <- 
  paste0("Reduction Problem: Petrovic: uses the relationship between the ",
         "average wage of each skill level of the labour power and the average ",
         "wage of the least complex labour, as weights for complexity of labour.")
meta_indicators[code,"type"] <- "index"
meta_indicators[code,"group"] <- "Others"
meta_indicators[code,"reverted"] <- FALSE

w_hs <- 
  ((sea_sectors[,"compensation.empe.s.us",,] *
     sea_sectors[,"compensation.empe_hs.r.pc",,]) %>%
  apply (1, sum, na.rm = TRUE)) /
  ((sea_sectors[,"hours_worked.empe.s.hr",,] *
     sea_sectors[,"hours_worked.empe_hs.r.pc",,]) %>%
  apply (1, sum, na.rm = TRUE))

w_ms <- 
  ((sea_sectors[,"compensation.empe.s.us",,] *
     sea_sectors[,"compensation.empe_ms.r.pc",,]) %>%
  apply (1, sum, na.rm = TRUE)) /
  ((sea_sectors[,"hours_worked.empe.s.hr",,] *
     sea_sectors[,"hours_worked.empe_ms.r.pc",,]) %>%
  apply (1, sum, na.rm = TRUE))

w_ls <- 
  ((sea_sectors[,"compensation.empe.s.us",,] *
     sea_sectors[,"compensation.empe_ls.r.pc",,]) %>%
  apply (1, sum, na.rm = TRUE)) /
  ((sea_sectors[,"hours_worked.empe.s.hr",,] *
     sea_sectors[,"hours_worked.empe_ls.r.pc",,]) %>%
  apply (1, sum, na.rm = TRUE))

multiplier_h <- w_hs/w_ls
multiplier_m <- w_ms/w_ls

sea_sectors[,"complex_labour_multiplier.empe.r.un",,] <- 
  (multiplier_h * sea_sectors[,"hours_worked.empe_hs.r.pc",,]) +
  (multiplier_m * sea_sectors[,"hours_worked.empe_ms.r.pc",,]) +
  sea_sectors[,"hours_worked.empe_ls.r.pc",,]

# sets new rates for hours ratio (of abstract labour) to employees
sea_sectors[,"hours_worked.empe_hs.r.pc",,] <- 
  (multiplier_h * sea_sectors[,"hours_worked.empe_hs.r.pc",,]) / 
  sea_sectors[,"complex_labour_multiplier.empe.r.un",,]

sea_sectors[,"hours_worked.empe_ms.r.pc",,] <- 
  (multiplier_m * sea_sectors[,"hours_worked.empe_ms.r.pc",,]) / 
  sea_sectors[,"complex_labour_multiplier.empe.r.un",,]

sea_sectors[,"hours_worked.empe_ls.r.pc",,] <- 
  sea_sectors[,"hours_worked.empe_ls.r.pc",,] / 
  sea_sectors[,"complex_labour_multiplier.empe.r.un",,]

