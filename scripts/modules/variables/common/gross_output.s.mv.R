# gross output in magnitude of value
code <- "gross_output.s.mv"

meta_indicators[code,"name"] <- "Gross output (magnitude of value)"
meta_indicators[code,"description"] <- 
  paste0("Gross output is the sum of value of all goods and services produced ",
         "by residents, i.e., the total embodied productive labour presented in ",
         "all commodities. It includes the value added (variable capital and ",
         "surplus value) and the value of intermediate consumption (constant ",
         "capital).")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "usd"
meta_indicators[code,"group"] <- "Product"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[lists$years,code,,] <- 
  m_io[, "values", , ] %>%
  newDim(c(nums$years, nums$input, nums$output)) %>%
  apply(1, rowSums, na.rm = TRUE) %>%
  aperm(c(2,1))
