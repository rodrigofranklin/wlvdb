sea_sectors[,"go_price.r.id",,] <- 
  sea_source[,"GO_PI",,] /
  (sea_source["2000","GO_PI",,] %>% 
     rep(times = nums$years)%>% 
     newDim(c(nums$sectors, nums$countries, nums$years)) %>% 
     aperm(c(3,1,2))) * 100