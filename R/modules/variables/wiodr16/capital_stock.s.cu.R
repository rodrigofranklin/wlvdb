# Capital stock - current USD prices
sea_sectors[,"capital_stock.s.cu",,] <-
  sea_source[,"K",lists$sectors,] / 
  sea_sectors[,"go_price.r.id",,] * 100 /
  (sea_sectors[1,"exchange.r.us",,] %>% 
     rep(times = nums$years) %>% 
     newDim(c(nums$sectors, nums$countries, nums$years)) %>% 
     aperm(c(3,1,2)))