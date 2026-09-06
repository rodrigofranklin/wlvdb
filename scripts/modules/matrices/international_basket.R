# structure of the consumption basket
# one basket for the whole world
# Assumption: household demand represents the structure of the consumption
# basket of all workers in all sectors

# Creates an array of matrices containing the distribution of the 
# consumption basket of each sector for each country. According to our
# assumption, all sectors of the world have the same consumption 
# basket structure (= demand from families).
# Obs: "c37" = household final demand column

m_io[, "consumption_basket", 1:nums$input, 1:nums$input] <- 
  m_io_source[, 1:nums$input, grep("c37", columns$sector)] %>%
  newDim(c(nums$years, nums$input, nums$countries)) %>%
  apply (MARGIN = 1, rowSums, na.rm = TRUE) %>% 
  prop.table(margin = 2) %>% 
  rep(each = nums$countries_sectors) %>%
  newDim(c(nums$input, nums$input, nums$years)) %>%
  aperm(c(3,2,1))

gc()