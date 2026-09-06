# gross output in direct price
code <- "gross_output.s.du"

meta_indicators[code,"name"] <- "Gross output (direct prices - USD)"
meta_indicators[code,"description"] <- 
  paste0("Gross output is the sum of prices of all goods and services produced ",
         "by residents. It includes the value added (variable capital and ",
         "surplus value) and the price of intermediate consumption (constant ",
         "capital). Data are in direct prices (prices proportional to values).")
meta_indicators[code,"observation"] <- NA
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
    stage = 5L, module = "common/gross_output.s.du.R", axes = c(year = 1L)
  )
} else direct_price_numerator / direct_price_denominator

sea_sectors[lists$years,code,,] <- 
  sea_sectors[lists$years,"gross_output.s.mv",,] * rep(k, times = nums$input)
rm(direct_price_numerator, direct_price_denominator)
