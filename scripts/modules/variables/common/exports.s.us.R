# Total exports (USD)
code <- "exports.s.us"

meta_indicators[code,"name"] <- 
  "Exports of goods and services (USD)"
meta_indicators[code,"description"] <- 
  paste0("Exports of goods and services represent the sum of prices of all ",
         "goods and other market services provided to the rest of the world.")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "usd"
meta_indicators[code,"group"] <- "International trade"
meta_indicators[code,"reverted"] <- FALSE

x <- nums$input
y <- nums$output

sea_sectors[lists$years,code,,] <- 
  ((m_io_source[lists$years, 1:x, 1:y] *
     (m_io_filters["trade",1:x,1:y] %>% rep(each = nums$years))) %>%
  newDim(c(nums$years, x, y)) %>%
  apply(1, rowSums, na.rm = TRUE) %>%
  aperm(c(2,1)))

rm(x,y)