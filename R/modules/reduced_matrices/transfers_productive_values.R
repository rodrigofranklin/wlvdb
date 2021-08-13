# Input-output matrix dimensions covered in this script
a <- nums$years
d1 <- nums$input
d2 <- nums$output
x <- 1:d1
y <- 1:d2

# Productive transfers in values ----
# Unequal exchange
print("Productive transfers in values...")
m_countries[lists$years,"transfers_productive_values",,] <- 
  parApply(
    cl = my.cluster,
    (m_io[,"transfers_values", x, y] * 
       (m_io_filters["productive_sectors", x, y] %>% rep(each = nums$years))) %>%
      newDim(c(a, d1, d2)), 1,
    tapply, m_io_filters["countries", x, y], sum, na.rm = TRUE
  ) %>% aperm(c(2,1)) * filter

# clear environment
rm(a, d1, d2, x, y)
gc()
