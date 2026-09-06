# Total exports (magnitude of value)
code <- "exports.s.mv"

meta_indicators[code,"name"] <- 
  "Exports of goods and services (magnitude of value)"
meta_indicators[code,"description"] <- 
  paste0("Exports of goods and services represent the socially necessary ",
         "labour-time to produce all goods and other market services provided ",
         "to the rest of the world.")
meta_indicators[code,"observation"] <- 
  paste0("Obtained from the sum of embodied productive labour of all commodities ",
         "provided to other countries.")
meta_indicators[code,"type"] <- "value"
meta_indicators[code,"group"] <- "International trade"
meta_indicators[code,"reverted"] <- FALSE

x <- nums$input
y <- nums$output

sea_sectors[lists$years,code,,] <- 
  ((m_io[lists$years, "values", 1:x, 1:y] *
     (m_io_filters["trade",1:x,1:y] %>% rep(each = nums$years))) %>%
  newDim(c(nums$years, x, y)) %>%
  apply(1, rowSums, na.rm = TRUE) %>%
  aperm(c(2,1)))

rm(x,y)