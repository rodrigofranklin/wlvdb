## Calculates value transfers resulting from international trade

# Input-output matrix dimensions covered in this script
a <- nums$years
d1 <- nums$input
d2 <- nums$output
x <- 1:d1
y <- 1:d2

#### Annual balance_factor vector.
# balance_factor = factor to convert market prices into labor hours.
# (The inverse process of direct prices, that is, this conversion allows us to
# show how much labour the amount of currency exchanged should
# represent). Warning: this factor is calculated only with the balance of
# international trade, so it becomes more suitable for evaluating
# international trade, but cannot be used for internal exchange analysis.
# Formula: 
# (sum of export values) / (sum of prices of productive exports)
balance_factor <- 
  (m_io[,"values",x,y] * 
     (m_io_filters["trade",x,y] %>% rep(each = nums$years))) %>%
  newDim(c(a, d1, d2)) %>%
  apply (1, sum, na.rm = TRUE) /
  (m_io_source[,x,y] *
     ((m_io_filters["trade",x,y] * 
         m_io_filters["productive_sectors",x,y]) %>% rep(each = nums$years))) %>%
  newDim(c(a, d1, d2)) %>%
  apply (1, sum, na.rm = TRUE)

#### Calculates matrices containing gross sector transfers.
# Gross sector transfers are calculated by deducting transactions
# international in values than international transactions in
# prices represent in terms of values (ie. inverse of direct prices).
# ATTENTION: THESE TRANSFERS INCLUDE UNEQUAL EXCHANGE AND APPROPRIATION OF
# UNPRODUCTIVE SECTORS. To separate the two effects, you must apply the filter 
# "productive_sectors".
m_io[,"transfers_values",x,y] <-
  (m_io_source[,x,y] * 
     (m_io_filters["trade",x,y] %>%  rep(each = nums$years)) * 
     balance_factor) -
  (m_io[,"values",x,y] * 
     (m_io_filters["trade",x,y] %>% rep(each = nums$years)))

# clear environment
rm(a, d1, d2, x, y)
gc()
