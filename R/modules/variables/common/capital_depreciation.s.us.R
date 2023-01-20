# Soma a depreciação em USD
code <- "capital_depreciation.s.us"

meta_indicators[code,"name"] <- "Capital depreciation (USD)"
meta_indicators[code,"description"] <- 
  paste0("Capital depreciation refers to the physical exhaustion of a capital ",
         "asset measured in terms of the decline in its market price.")
meta_indicators[code,"observation"] <-
  paste0("See the assumptions of each method for more information about the ",
         "computation of capital composition em depreciation.")
meta_indicators[code,"type"] <- "usd"
meta_indicators[code,"group"] <- "Capital"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[lists$years,code,,] <- 
  m_io[lists$years, "k_depreciation", 1:nums$input, 1:nums$input] %>%
  newDim(c(nums$years, nums$input, nums$input)) %>%
  apply(1, colSums, na.rm = TRUE) %>%
  aperm(c(2,1))
