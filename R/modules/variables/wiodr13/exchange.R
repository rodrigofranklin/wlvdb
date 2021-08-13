# Exchange rate from Value Added in local currency and USD
sea_sectors[,"exchange_rate",,] <-
  as.numeric(sea_source[,"VA",lists$sectors,]) / 
  as.numeric(sea_source[,"VA_USD",lists$sectors,])
