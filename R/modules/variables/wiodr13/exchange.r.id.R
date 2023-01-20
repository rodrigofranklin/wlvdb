# Exchange rate index from Value Added in local currency and USD
code <- "exchange.r.id"

meta_indicators[code,"name"] <- "Exchange rate index (2000 = 100)"
meta_indicators[code,"description"] <- 
  paste0("Exchange rate is the correspondence between local currency and USD.")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "index"
meta_indicators[code,"group"] <- "Others"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[,code,,] <-
  sea_sectors[,"exchange.r.us",,] / 
  (sea_sectors["2000","exchange.r.us",,] %>% 
     rep(times = nums$years) %>%
     newDim(c(nums$sectors, nums$countries, nums$years)) %>% 
     aperm(c(3,1,2)))

sea_sectors[lists$years,code,,"ROW"] <- 
  sea_sectors[lists$years,code,,"USA"]

# replace "0" for country mean
zcountries <- (rows$country|>rep(each = nums$years))[sea_sectors[,code,,] == 0] |> unique()
for (country in zcountries) {
  zyears <- (lists$years|>rep(times = nums$sectors))[sea_sectors[,code,,country] == 0]
  for (year in zyears) {
    zsector <- lists$sector[sea_sectors[year,code,,country] == 0]
    sea_sectors[year,code,zsector,country] <- 
      mean(sea_sectors[
        year,
        code,
        (lists$sectors %in% zsector) |> not(),
        country])
  }
}

