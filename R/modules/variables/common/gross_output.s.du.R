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

k <- 
  (sea_sectors[lists$years,"gross_output.s.us",,] %>%
     newDim(c(nums$years, nums$sectors, nums$countries)) %>%
     apply(1, sum, na.rm = TRUE)) /
  (sea_sectors[lists$years,"gross_output.s.mv",,] %>%
     newDim(c(nums$years, nums$sectors, nums$countries)) %>%
     apply(1, sum, na.rm = TRUE))

sea_sectors[lists$years,code,,] <- 
  sea_sectors[lists$years,"gross_output.s.mv",,] * rep(k, times = nums$input)
