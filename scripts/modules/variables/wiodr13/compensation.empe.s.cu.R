# wages in constant dollars of 2000
code <- "compensation.empe.s.cu"

meta_indicators[code,"name"] <- "Salaries and wages (constant USD)"
meta_indicators[code,"description"] <- 
  paste0("Remuneration received by wage and salaried workers in constant ",
         "USD (base year = 2000).")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "usd"
meta_indicators[code,"group"] <- "Wages and value of labour force"
meta_indicators[code,"reverted"] <- FALSE

basket_current <- sea_sectors[, "basket_price.r.pc", , ]
exchange_base <- sea_sectors["2000", "exchange.r.us", , ] %>%
  rep(times = nums$years) %>%
  newDim(c(nums$sectors, nums$countries, nums$years)) %>%
  aperm(c(3, 1, 2))
dimnames(exchange_base) <- dimnames(basket_current)
compensation_numerator <-
  sea_source[, "COMP", lists$sectors, ]
if (exists("wlv_contract_runtime", inherits = FALSE)) {
  sea_sectors[, code, , ] <- wlv_sequential_ratio_runtime(
    wlv_contract_runtime,
    compensation_numerator,
    denominators = list(
      "basket_price.r.pc" = basket_current,
      "exchange.r.us" = exchange_base
    ),
    zero = "not_applicable",
    artifact = "sea_sectors",
    indicator = code,
    checkpoint = "after_stage_5",
    stage = 5L,
    module = "wiodr13/compensation.empe.s.cu.R",
    axes = c(year = 1L, sector = 2L, country = 3L)
  )
} else {
  sea_sectors[, code, , ] <-
    compensation_numerator / basket_current / exchange_base
}
rm(
  basket_current, exchange_base, compensation_numerator
)

