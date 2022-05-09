# Capital stock - current USD prices
sea_sectors[,"capital_stock",,] <-
  sea_source[,"K",lists$sectors,] / 100 /
  sea_sectors[,"exchange_rate",,]
