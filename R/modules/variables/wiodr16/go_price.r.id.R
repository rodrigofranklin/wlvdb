code <- "go_price.r.id"

meta_indicators[code,"name"] <- "Gross output price index (national currency)"
meta_indicators[code,"description"] <- 
  paste0("Price levels of gross output. Base year = 2000.")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "index"
meta_indicators[code,"group"] <- "Others"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[,code,,] <- 
  sea_source[,"GO_PI",,] /
  (sea_source["2000","GO_PI",,] %>% 
     rep(times = nums$years)%>% 
     newDim(c(nums$sectors, nums$countries, nums$years)) %>% 
     aperm(c(3,1,2))) * 100