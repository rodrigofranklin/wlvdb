# Exchange rate from Value Added in local currency and USD
code <- "exchange.r.us"

meta_indicators[code,"name"] <- "Exchange rate (local currency per USD)"
meta_indicators[code,"description"] <-
  paste0("Current exchange rate measured in units of local currency per ",
         "current USD (LCU/USD).")
meta_indicators[code,"observation"] <-
  paste0("Calculated for each country-year as total Value Added in local ",
         "currency divided by total Value Added in current USD, then broadcast ",
         "to every sector. USA totals are validated against 1 USD/USD before ",
         "being canonicalized to exactly 1.")
meta_indicators[code,"type"] <- "usd"
meta_indicators[code,"group"] <- "Others"
meta_indicators[code,"reverted"] <- FALSE

exchange_numerator <- sea_source[, "VA", lists$sectors, ]
exchange_denominator <- sea_source[, "VA_USD", lists$sectors, ]
sea_sectors[, code, , ] <- wlv_exchange_rate_by_country(
  exchange_numerator,
  exchange_denominator
)

rm(exchange_numerator, exchange_denominator)
