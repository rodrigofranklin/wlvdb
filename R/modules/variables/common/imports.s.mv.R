# Soma das importações

a <- nums$years
d1 <- nums$input
d2 <- nums$output
x <- 1:d1
y <- 1:d2

sea_sectors[lists$years,"imports.s.mv",,] <- 
  (m_io[lists$years, "values", x, y] *
  (m_io_filters["trade",x,y] %>% rep(each = a))) %>%
  newDim(c(a, d1, d2)) %>%
  myApply(1, tapply, m_io_filters["imports", x, y], sum, na.rm = TRUE) %>%
  aperm(c(2,1))

rm(x,y,a,d1,d2)