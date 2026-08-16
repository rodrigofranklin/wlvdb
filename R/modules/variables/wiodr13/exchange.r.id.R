# Exchange rate index from Value Added in local currency and USD
code <- "exchange.r.id"

meta_indicators[code,"name"] <- "Exchange rate index"
meta_indicators[code,"description"] <-
  paste0("Unitless index of the local-currency-per-current-USD exchange rate, ",
         "normalized to 1 in 2000.")
meta_indicators[code,"observation"] <-
  paste0("Calculated as the current country-year exchange rate (LCU/USD) ",
         "divided by that country's 2000 exchange rate. The ROW index mirrors ",
         "the USA index. The presentation scale is defined by method-specific ",
         "unit metadata.")
meta_indicators[code,"type"] <- "index"
meta_indicators[code,"group"] <- "Others"
meta_indicators[code,"reverted"] <- FALSE

exchange_rate <- sea_sectors[, "exchange.r.us", , ]
exchange_rate_2000 <- sea_sectors["2000", "exchange.r.us", , ]
sea_sectors[, code, , ] <- sweep(
  exchange_rate,
  MARGIN = c(2L, 3L),
  STATS = exchange_rate_2000,
  FUN = "/"
)

sea_sectors[lists$years,code,,"ROW"] <- 
  sea_sectors[lists$years,code,,"USA"]

rm(exchange_rate, exchange_rate_2000)

