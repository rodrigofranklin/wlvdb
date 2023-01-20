# Soma dos valores recebidos via comércio internacional
code <- "trade_transfers.s.mv"

meta_indicators[code,"name"] <- "Transfer of value through trade"
meta_indicators[code,"description"] <- 
  paste0("Transfer of value through trade represents the value received from ",
         "(if positive) or sent to (if negative) to the rest of the world as a ",
         "result of the diference between the magnitude of value and the value ",
         "represented by the prices of commodities. This data enconpass two ",
         "kinds of value transfers: transfers originated from unproductive ",
         "sectors, in such case the amount of money received/sent represents ",
         "value, but no value are given or received in return; transfers ",
         "originated from productive sectors, in this case the amount of money ",
         "received (in exports) or sent (in imports) can represent an ",
         "amount of value distintic of the actualy abstract labour embodied in ",
         "commodities traded.")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "value"
meta_indicators[code,"group"] <- "International trade"
meta_indicators[code,"reverted"] <- FALSE

a <- nums$years
d1 <- nums$input
d2 <- nums$output
x <- 1:d1
y <- 1:d2

sea_sectors[lists$years,code,,] <- 
  ((m_io[lists$years, "transfers_values", x, y] %>%
     newDim(c(a, d1, d2)) %>%
     apply(1, rowSums, na.rm = TRUE)) - 
  (m_io[lists$years, "transfers_values", x, y] %>%
     newDim(c(a, d1, d2)) %>%
     myApply(1, tapply, m_io_filters["imports", x, y], sum, na.rm = TRUE))) %>%
  aperm(c(2,1))

rm(x,y,a,d1,d2)