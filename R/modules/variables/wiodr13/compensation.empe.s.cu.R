# labour_compensation in constant dollars of 2000

sea_sectors[,"basket_price.r.pc",,] <- 
  sea_sectors[,"basket_price.r.pc",,] /
  (sea_sectors["2000","basket_price.r.pc",,] %>% 
     rep(times = nums$years)%>% 
     newDim(c(nums$sectors, nums$countries, nums$years)) %>% 
     aperm(c(3,1,2)))

sea_sectors[,"compensation.empe.s.cu",,] <-
  sea_source[,"COMP",lists$sectors,] / 
  sea_sectors[,"basket_price.r.pc",,] /
  (sea_sectors["2000","exchange.r.us",,] %>% 
     rep(times = nums$years)%>% 
     newDim(c(nums$sectors, nums$countries, nums$years)) %>% 
     aperm(c(3,1,2)))

