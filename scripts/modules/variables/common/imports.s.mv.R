# Total imports (magnitude of value)
code <- "imports.s.mv"

meta_indicators[code,"name"] <- 
  "Imports of goods and services (magnitude of value)"
meta_indicators[code,"description"] <- 
  paste0("Imports of goods and services represent the socially necessary ",
         "labour-time to produce all goods and other market services received ",
         "from the rest of the world.")
meta_indicators[code,"observation"] <- 
  paste0("Obtained from the sum of embodied productive labour of all commodities ",
         "received from other countries.")
meta_indicators[code,"type"] <- "value"
meta_indicators[code,"group"] <- "International trade"
meta_indicators[code,"reverted"] <- FALSE

a <- nums$years
d1 <- nums$input
d2 <- nums$output
x <- 1:d1
y <- 1:d2

sea_sectors[lists$years,code,,] <- 
  (m_io[lists$years, "values", x, y] *
  (m_io_filters["trade",x,y] %>% rep(each = a))) %>%
  newDim(c(a, d1, d2)) %>%
  myApply(1, tapply, m_io_filters["imports", x, y], sum, na.rm = TRUE) %>%
  aperm(c(2,1))

rm(x,y,a,d1,d2)