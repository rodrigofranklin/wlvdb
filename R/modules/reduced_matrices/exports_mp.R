# Input-output matrix dimensions covered in this script
a <- nums$years
d1 <- nums$input
d2 <- nums$output
x <- 1:d1
y <- 1:d2

# Exports in market prices ----
print("Exports in market prices...")
m_countries[lists$years,"exports_mp",,] <- 
#  parApply(
#    cl = my.cluster,
  apply(
    m_io_source[, x, y] %>% newDim(c(a, d1, d2)), 1,
    tapply, m_io_filters["countries", x, y], sum, na.rm = TRUE
  ) %>% aperm(c(2,1)) * filter

# clear environment
rm(a, d1, d2, x, y)
gc()
