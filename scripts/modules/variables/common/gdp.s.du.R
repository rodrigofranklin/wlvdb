# Gross domestic product by value added in direct price
code <- "gdp.s.du"

meta_indicators[code,"name"] <- "Gross Domestic Product (direct prices - USD) "
meta_indicators[code,"description"] <- 
  paste0("Gross Domestic Product calculated by value added approach represents ",
         "all value created by residents. Data are in direct prices (prices ",
         "proportional to value), thus it enconpass productive sectors only.")
meta_indicators[code,"observation"] <- 
  paste0("Obtained by converting the sum of abstract labour performed in ",
         "productive sectors into prices throught the relation between the sum ",
         " of gross output in market prices and the sum of gross output in ",
         "value of whole world.")
meta_indicators[code,"type"] <- "usd"
meta_indicators[code,"group"] <- "Product"
meta_indicators[code,"reverted"] <- FALSE

direct_price_numerator <-
  sea_sectors[lists$years, "gross_output.s.us", , ] %>%
  newDim(c(nums$years, nums$sectors, nums$countries)) %>%
  apply(1, sum)
direct_price_denominator <-
  sea_sectors[lists$years, "gross_output.s.mv", , ] %>%
  newDim(c(nums$years, nums$sectors, nums$countries)) %>%
  apply(1, sum)
k <- if (exists("wlv_contract_runtime", inherits = FALSE)) {
  wlv_safe_divide_runtime(
    wlv_contract_runtime, direct_price_numerator, direct_price_denominator,
    zero = "error", artifact = "sea_sectors",
    indicator = "direct_price_coefficient", checkpoint = "after_stage_5",
    stage = 5L, module = "common/gdp.s.du.R", axes = c(year = 1L)
  )
} else direct_price_numerator / direct_price_denominator

sea_sectors[lists$years,code,,] <- 
  sea_sectors[lists$years,"gdp.s.mv",,] * 
  rep(k, times = nums$countries_sectors)
rm(direct_price_numerator, direct_price_denominator)
