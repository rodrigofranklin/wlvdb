# Exchange rate from Value Added in local currency and USD
sea_sectors[,"exchange.r.id",,] <-
  sea_sectors[,"exchange.r.us",,] / 
  (sea_sectors[1,"exchange.r.us",,] %>% 
     rep(times = nums$years) %>%
     newDim(c(nums$sectors, nums$countries, nums$years)) %>% 
     aperm(c(3,1,2)))

sea_sectors[lists$years,"exchange.r.id",,"ROW"] <- 
  sea_sectors[lists$years,"exchange.r.id",,"USA"]
