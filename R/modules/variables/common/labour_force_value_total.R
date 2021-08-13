# Sum of labour force value of each sector

sea_sectors[lists$years,"labour_force_value_total",,] <- 
  # distribute wages according to consumption basket
  (((sea_sectors[lists$years,"wages",,] %>%
       rep(each = nums$input) %>%
       newDim(c(nums$years, nums$input, nums$input))) * 
      (m_io[, "consumption_basket", 1:nums$input, 1:nums$input] %>%
         newDim(c(nums$years, nums$input, nums$input)))) *
     
     # transform monetary data into values
     rep(lambda, times = nums$input)) %>%
  
  # sum all value of the basket of each sector    
  newDim(c(nums$years, nums$input, nums$input)) %>%
  apply(1, colSums) %>%
  aperm(c(2,1))
