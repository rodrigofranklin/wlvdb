# Legacy sector-level exchange-rate index retained for v0.9 methods
code <- "exchange.r.id"

meta_indicators[code, "name"] <- "Exchange rate index (2000 = 1)"
meta_indicators[code, "description"] <-
  paste0("Unitless index of the legacy sector-level local-currency-per-current-",
         "USD exchange rate, normalized to 1 in 2000.")
meta_indicators[code, "observation"] <-
  paste0("Calculated for each sector as its current implicit VA exchange rate ",
         "divided by its 2000 implicit VA exchange rate. The ROW index mirrors ",
         "the USA index.")
meta_indicators[code, "type"] <- "index"
meta_indicators[code, "group"] <- "Others"
meta_indicators[code, "reverted"] <- FALSE

exchange_rate <- sea_sectors[, "exchange.r.us", , ]
exchange_rate_2000 <- sea_sectors["2000", "exchange.r.us", , ]
sea_sectors[, code, , ] <- sweep(
  exchange_rate,
  MARGIN = c(2L, 3L),
  STATS = exchange_rate_2000,
  FUN = "/"
)

sea_sectors[lists$years, code, , "ROW"] <-
  sea_sectors[lists$years, code, , "USA"]

rm(exchange_rate, exchange_rate_2000)
