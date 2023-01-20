# Soma dos valores recebidos via comércio internacional dos setores produtivos
# TROCA DESIGUAL
code <- "trade_transfers.p.s.mv"

meta_indicators[code,"name"] <- 
  "Transfer of value through trade (productive sectors)"
meta_indicators[code,"description"] <- 
  paste0("Transfer of value through trade in productive sectors represents the ",
         "value received from (if positive) or sent to (if negative) to the rest ",
         "of the world as a result of the diference between ",
         "the value represented by the amount of money received (from ",
         "exports) or sent (from imports) and the actually abstract labour ",
         "embodied in commodities traded. This ",
         'data is equivalent of what some authors call "unequal exchange" ',
         "(Bettleheim and others).")
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
  (((m_io[lists$years, "transfers_values", x, y] *
      (m_io_filters["productive_sectors",x,y] %>%
         rep(each = a))) %>%
     newDim(c(a, d1, d2)) %>%
     apply(1, rowSums, na.rm = TRUE) ) - 
  ((m_io[lists$years, "transfers_values", x, y]*
      (m_io_filters["productive_sectors",x,y] %>%
         rep(each = a))) %>%
     newDim(c(a, d1, d2)) %>%
     myApply(1, tapply, m_io_filters["imports", x, y], sum, na.rm = TRUE))) %>%
  aperm(c(2,1))

rm(x,y,a,d1,d2)