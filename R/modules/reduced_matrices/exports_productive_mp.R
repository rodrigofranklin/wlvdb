# Input-output matrix dimensions covered in this script
a <- nums$years
d1 <- nums$input
d2 <- nums$output
x <- 1:d1
y <- 1:d2

# Productives exports in market prices ----
print("Productives exports in market prices...")

if (a==1) {
  m_countries[lists$years,"exports_productive_mp",,] <- 
    apply(
      (m_io_source[, x, y] * 
         (m_io_filters["productive_sectors", x, y] %>% rep(each = nums$years))) %>%
        newDim(c(a, d1, d2)), 1,
      tapply, m_io_filters["countries", x, y], sum, na.rm = TRUE
    ) %>% aperm(c(2,1)) * filter
} else {
  m_countries[lists$years,"exports_productive_mp",,] <- 
    parApply(
      cl = my.cluster,
      (m_io_source[, x, y] * 
         (m_io_filters["productive_sectors", x, y] %>% rep(each = nums$years))) %>%
        newDim(c(a, d1, d2)), 1,
      tapply, m_io_filters["countries", x, y], sum, na.rm = TRUE
    ) %>% aperm(c(2,1)) * filter
}
# clear environment
rm(a, d1, d2, x, y)
gc()
