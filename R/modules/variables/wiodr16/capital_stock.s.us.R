# Capital stock - current USD prices
if (!exists("wlv_wiodr16_sanitize_capital_stock", mode = "function")) {
  source("R/lib/wiodr16_allocation.R")
}

code <- "capital_stock.s.us"

meta_indicators[code,"name"] <- "Capital stock (USD)"
meta_indicators[code,"description"] <- 
  paste0("Capital stock is the prices in current USD of capital assets.")
meta_indicators[code,"observation"] <- 
  paste0("Converted from national currency using the exchange rate.")
meta_indicators[code,"type"] <- "usd"
meta_indicators[code,"group"] <- "Capital"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[,code,,] <-
  sea_source[,"K",lists$sectors,] * 1000000 /
  sea_sectors[,"exchange.r.us",,]

for (year in lists$years) {
  capital_stock <- as.numeric(sea_sectors[year, code, , ])
  capital_stock <- wlv_wiodr16_clean_structural_nonfinite_stock(
    capital_stock,
    lists$input
  )
  sea_sectors[year, code, , ] <- wlv_wiodr16_sanitize_capital_stock(
    capital_stock,
    year,
    lists$input
  )
}
rm(capital_stock)
