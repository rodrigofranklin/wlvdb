# structure of the consumption basket
# one basket for the whole world
# Assumption: household demand represents the structure of the consumption
# basket of all workers in all sectors

# Creates an array of matrices containing the distribution of the 
# consumption basket of each sector for each country. According to our
# assumption, all sectors of the world have the same consumption 
# basket structure (= demand from families).
# Obs: "c37" = household final demand column
consumption_basket <- 
  apply(m_io_source[,1:nums$countries_sectors,columns$sector=="c37"],
        MARGIN = 1, rowSums, na.rm = TRUE) %>%
  prop.table(margin = 2)
consumption_basket <- rep(consumption_basket, times = nums$countries_sectors)

dim(consumption_basket) <- c(nums$countries_sectors, nums$years,
                             nums$countries_sectors)
consumption_basket <- aperm(consumption_basket, c(2,1,3))

rm(income)
gc()