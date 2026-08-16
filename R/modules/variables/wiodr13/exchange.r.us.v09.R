# Legacy sector-level exchange rate retained for v0.9 methods
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

exchange_numerator <- sea_source[, "VA", lists$sectors, ]
exchange_denominator <- sea_source[, "VA_USD", lists$sectors, ]
sea_sectors[, code, , ] <- wlv_exchange_rate_by_sector_legacy(
  exchange_numerator,
  exchange_denominator,
  runtime = if (exists("wlv_contract_runtime", inherits = FALSE)) {
    wlv_contract_runtime
  } else {
    NULL
  }
)

# Ignore the small source deviations in the USA rate, as in v0.9.
sea_sectors[, code, , "USA"] <- 1

rm(exchange_numerator, exchange_denominator)
