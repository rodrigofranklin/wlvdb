# Exchange rate from Value Added in local currency and USD
sea_sectors[,"exchange.r.us",,] <-
  as.numeric(sea_source[,"VA",lists$sectors,]) / 
  as.numeric(sea_source[,"VA_USD",lists$sectors,])

# Nan values are replaced by country's mean
temp_exchange_mean <- sea_sectors[,"exchange.r.us",,] %>%
  apply( 1, tapply, rows$num_country, mean, na.rm = TRUE) %>%
  rep(each = nums$sectors) %>%
  newDim(c(nums$sectors,nums$countries,nums$years)) %>%
  aperm(c(3,1,2))

sea_sectors[,"exchange.r.us",,][
  is.nan(sea_sectors[,"exchange.r.us",,])] <- 
  temp_exchange_mean[is.nan(sea_sectors[,"exchange.r.us",,])]

rm(temp_exchange_mean)