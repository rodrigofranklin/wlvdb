####
#
# there is no data about capital stock. Assuming stock = 0
#
####

sea_sectors[,"capital_depreciation.s.us",,] <- 
  sea_source[,"Operating surplus: Consumption of fixed capital",,]
