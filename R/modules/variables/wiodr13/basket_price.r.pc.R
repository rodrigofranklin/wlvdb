# labour_compensation in constant dollars of 2000
code <- "basket_price.r.pc"

meta_indicators[code,"name"] <- "Consumption basket price index (2000 = 1)"
meta_indicators[code,"description"] <- 
  paste0("Consumption basket price index reflects changes in the prices for ",
         "average worker of acquiring a fixed basket of goods and services. ",
         "The Laspeyres formula is used.")
meta_indicators[code,"observation"] <-
  "Calculated and published on the canonical base-one scale."
meta_indicators[code,"type"] <- "index"
meta_indicators[code,"group"] <- "Others"
meta_indicators[code,"reverted"] <- FALSE

if (!exists("basket_zero")) {
  basket_zero <-  
    m_io[1, "consumption_basket", 1:nums$input, 1:nums$input]
}

sea_sectors[,"go_price.r.id",,"ROW"] <- 
  sea_sectors[,"go_price.r.id",,"USA"]

sea_sectors[lists$years,code,,] <- 
  ((basket_zero %>%
      rep(times = nums$years) %>%
      newDim(c(nums$input, nums$input, nums$years)) %>% 
      aperm(c(3,1,2))) *
     (sea_sectors[lists$years,"go_price.r.id",,] %>%
        rep(times = nums$input) %>%
        newDim(c(nums$years, nums$input, nums$input)))) %>%
  apply(1, colSums, na.rm = TRUE) %>%
  aperm(c(2,1))

# xxxxx
# Ano base = 2000
# sea_sectors[,code,,] <-
#   sea_sectors[,code,,] /
#   (sea_sectors["2000",code,,] %>%
#      rep(times = nums$years) %>%
#      newDim(c(nums$sectors, nums$countries, nums$years)) %>%
#      aperm(c(3,1,2)))
