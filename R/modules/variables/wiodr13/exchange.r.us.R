# Exchange rate from Value Added in local currency and USD
code <- "exchange.r.us"

meta_indicators[code,"name"] <- "Exchange rate (local currency per USD)"
meta_indicators[code,"description"] <- 
  paste0("Exchange rate is the correspondence between local currency and USD.")
meta_indicators[code,"observation"] <- 
  paste0("Calculated as the implicit exchange rate of Value Added (VA in local ",
         "currency / VA in USD).")
meta_indicators[code,"type"] <- "usd"
meta_indicators[code,"group"] <- "Others"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[,code,,] <-
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

# Desconsidera os pequenos desvios na taxa dos EUA
sea_sectors[,"exchange.r.us",,"USA"] <- 1

rm(temp_exchange_mean)