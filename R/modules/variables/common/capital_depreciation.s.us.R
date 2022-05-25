# Soma a depreciação em USD
sea_sectors[lists$years,"capital_depreciation.s.us",,] <- 
  m_io[lists$years, "k_depreciation", 1:nums$input, 1:nums$input] %>%
  newDim(c(nums$years, nums$input, nums$input)) %>%
  apply(1, colSums, na.rm = TRUE) %>%
  aperm(c(2,1))
