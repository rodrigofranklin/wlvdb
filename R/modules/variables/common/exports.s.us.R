# Soma das exportações

x <- nums$input
y <- nums$output

sea_sectors[lists$years,"exports.s.us",,] <- 
  ((m_io_source[lists$years, 1:x, 1:y] *
     (m_io_filters["trade",1:x,1:y] %>% rep(each = nums$years))) %>%
  newDim(c(nums$years, x, y)) %>%
  apply(1, rowSums, na.rm = TRUE) %>%
  aperm(c(2,1)))

rm(x,y)