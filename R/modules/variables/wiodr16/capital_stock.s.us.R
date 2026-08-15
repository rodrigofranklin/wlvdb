# Capital stock - current USD prices
if (!exists("wlv_wiodr16_sanitize_capital_stock", mode = "function")) {
  source("R/lib/wiodr16_allocation.R")
}
if (!exists("wlv_record_observed_transformations", mode = "function")) {
  source("R/lib/gfcf_contracts.R")
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
  sanitized_stock <- wlv_wiodr16_sanitize_capital_stock(
    capital_stock,
    year,
    lists$input
  )
  truncated_stock <- attr(sanitized_stock, "wlv.truncated_negative_stock")
  if (
    nrow(truncated_stock) &&
    exists("wlv_contract_runtime", inherits = FALSE)
  ) {
    wlv_record_observed_transformations(
      wlv_contract_runtime,
      truncated_stock,
      artifact = "sea_sectors",
      indicator = code,
      checkpoint = "after_stage_1",
      stage = 1L,
      module = "wiodr16/capital_stock.s.us.R",
      coordinate_columns = c(
        year = "year", country = "country", sector = "sector"
      )
    )
  }
  sea_sectors[year, code, , ] <- sanitized_stock
}
rm(capital_stock, sanitized_stock, truncated_stock)
