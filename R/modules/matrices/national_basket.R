# structure of the consumption basket
# one basket per country
# Assumption: household demand represents the structure of the consumption
# basket of all workers in all sectors

# Creates an array of matrices containing the distribution of the 
# consumption basket of each sector for each country. According to our
# assumption, all sectors of the same country have the same consumption 
# basket structure (= demand from families).
# Obs: "c37" = household final demand column

m_io[, "consumption_basket", 1:nums$input, 1:nums$input] <- 
  m_io_source[, 1:nums$input, grep("c37", columns$sector)] %>%
  newDim(c(nums$years, nums$input, nums$countries)) %>%
  apply (MARGIN = 1, prop.table, margin = 2) %>% 
  rep(each = nums$sectors) %>%
  newDim(c(nums$sectors, nums$sectors, 
           nums$countries, nums$countries, 
           nums$years)) %>%
  aperm(c(5,2,3,1,4)) %>%
  newDim(c(nums$years, nums$input, nums$input))

# distributes the income of each sector according to the structure of the 
# consumption basket

gc()
