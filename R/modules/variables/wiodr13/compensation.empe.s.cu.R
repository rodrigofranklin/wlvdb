# wages in constant dollars of 2000
code <- "compensation.empe.s.cu"

meta_indicators[code,"name"] <- "Salaries and wages (constant USD)"
meta_indicators[code,"description"] <- 
  paste0("Remuneration received by wage and salaried workers in constant ",
         "USD (base year = 2000).")
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
  sea_source[,"COMP",lists$sectors,] * 1000000 / 
  sea_sectors[,"basket_price.r.pc",,] /
  (sea_sectors["2000","exchange.r.us",,] %>% 
     rep(times = nums$years)%>% 
     newDim(c(nums$sectors, nums$countries, nums$years)) %>% 
     aperm(c(3,1,2)))

