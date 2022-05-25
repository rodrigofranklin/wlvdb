# Soma dos valores recebidos via comércio internacional

a <- nums$years
d1 <- nums$input
d2 <- nums$output
x <- 1:d1
y <- 1:d2

sea_sectors[lists$years,"trade_transfers.s.mv",,] <- 
  ((m_io[lists$years, "transfers_values", x, y] %>%
     newDim(c(a, d1, d2)) %>%
     apply(1, rowSums, na.rm = TRUE)) - 
  (m_io[lists$years, "transfers_values", x, y] %>%
     newDim(c(a, d1, d2)) %>%
     myApply(1, tapply, m_io_filters["imports", x, y], sum, na.rm = TRUE))) %>%
  aperm(c(2,1))

rm(x,y,a,d1,d2)