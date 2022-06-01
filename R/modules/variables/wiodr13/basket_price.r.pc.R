# labour_compensation in constant dollars of 2000

if (!exists("basket_zero")) {
  basket_zero <-  
    m_io[1, "consumption_basket", 1:nums$input, 1:nums$input]
}

sea_sectors[,"go_price.r.id",,"ROW"] <- 
  sea_sectors[,"go_price.r.id",,"USA"]

sea_sectors[lists$years,"basket_price.r.pc",,] <- 
  ((basket_zero %>%
      rep(times = nums$years) %>%
      newDim(c(nums$input, nums$input, nums$years)) %>% 
      aperm(c(3,1,2))) *
     ((sea_sectors[lists$years,"go_price.r.id",,]/100) %>%
        rep(times = nums$input) %>%
        newDim(c(nums$years, nums$input, nums$input)))) %>%
  apply(1, colSums, na.rm = TRUE) %>%
  aperm(c(2,1))
# xxxxx
# Ano base = 2000
# sea_sectors[,"basket_price.r.pc",,] <-
#   sea_sectors[,"basket_price.r.pc",,] /
#   (sea_sectors["2000","basket_price.r.pc",,] %>%
#      rep(times = nums$years) %>%
#      newDim(c(nums$sectors, nums$countries, nums$years)) %>%
#      aperm(c(3,1,2)))
