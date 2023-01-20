# Sum of labour force value of each sector
code <- "labour_force_value.emp.s.mv"

meta_indicators[code,"name"] <- "Labour compensation (magnitude of value)"
meta_indicators[code,"description"] <- 
  paste0("Labour compensation expressed in magnitude of value represents ",
         "the socially necessary labour-time to produce the commodities ",
         "consumed by all persons engaged. It includes variable capital and ",
         "income received by non-waged and non-salaried workers.")
meta_indicators[code,"observation"] <- 
  paste0("Obtained by converting the monetary labour compensation into value ",
         "accordingly to the embodied value in the consumption basket.")
meta_indicators[code,"type"] <- "value"
meta_indicators[code,"group"] <- "Wages and value of labour force"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[lists$years,code,,] <- 
  # distribute wages according to consumption basket
  (((sea_sectors[lists$years,"compensation.emp.s.us",,] %>%
       rep(times = nums$input) %>%
       newDim(c(nums$years, nums$input, nums$input)) %>%
       aperm(c(1,3,2))) * 
      (m_io[, "consumption_basket", 1:nums$input, 1:nums$input] %>%
         newDim(c(nums$years, nums$input, nums$input)))) *
     
     # transform monetary data into values
     rep(lambda, times = nums$input)) %>%
  
  # sum all value of the basket of each sector    
  newDim(c(nums$years, nums$input, nums$input)) %>%
  apply(1, colSums) %>%
  aperm(c(2,1))
