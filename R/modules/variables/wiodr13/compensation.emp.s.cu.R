# labour_compensation in constant dollars of 2000
code <- "compensation.emp.s.cu"

meta_indicators[code,"name"] <- "Labour compensation (constant USD)"
meta_indicators[code,"description"] <- 
  paste0("Labour compensation expressed in market prices represents ",
         "the income received all persons engaged as a result of their labour. ",
         "It includes wages, salaries, and income received by non-waged and ",
         "non-salaried workers (self-employed, etc.). Data are in constant USD ",
         "(base year = 2000).")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "usd"
meta_indicators[code,"group"] <- "Wages and value of labour force"
meta_indicators[code,"reverted"] <- FALSE

## Change the base year of consumption basket price index
sea_sectors[,"basket_price.r.pc",,] <- 
  sea_sectors[,"basket_price.r.pc",,] /
  (sea_sectors["2000","basket_price.r.pc",,] %>% 
     rep(times = nums$years)%>% 
     newDim(c(nums$sectors, nums$countries, nums$years)) %>% 
     aperm(c(3,1,2)))

sea_sectors[,code,,] <-
  sea_source[,"LAB",lists$sectors,] *1000000 / 
  sea_sectors[,"basket_price.r.pc",,] /
  (sea_sectors["2000","exchange.r.us",,] %>% 
     rep(times = nums$years)%>% 
     newDim(c(nums$sectors, nums$countries, nums$years)) %>% 
     aperm(c(3,1,2)))

## go_price.r.id takes a ride (to change the base year)
sea_sectors[,"go_price.r.id",,] <- 
  sea_sectors[,"go_price.r.id",,] /
  (sea_sectors["2000","go_price.r.id",,] %>% 
     rep(times = nums$years)%>% 
     newDim(c(nums$sectors, nums$countries, nums$years)) %>% 
     aperm(c(3,1,2)))