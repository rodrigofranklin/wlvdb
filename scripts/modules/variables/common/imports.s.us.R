# Total imports (USD)
code <- "imports.s.us"

meta_indicators[code,"name"] <- 
  "Imports of goods and services (USD)"
meta_indicators[code,"description"] <- 
  paste0("Imports of goods and services represent the sum of prices of all ",
         "goods and other market services received from the rest of the world.")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "usd"
meta_indicators[code,"group"] <- "International trade"
meta_indicators[code,"reverted"] <- FALSE

a <- nums$years
d1 <- nums$input
d2 <- nums$output
x <- 1:d1
y <- 1:d2

sea_sectors[lists$years,code,,] <- 
  (m_io_source[lists$years, x, y] *
  (m_io_filters["trade",x,y] %>% rep(each = a))) %>%
  newDim(c(a, d1, d2)) %>%
  myApply(1, tapply, m_io_filters["imports", x, y], sum, na.rm = TRUE) %>%
  aperm(c(2,1))

rm(x,y,a,d1,d2)