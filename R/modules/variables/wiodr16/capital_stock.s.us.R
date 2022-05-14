# Capital stock - current USD prices
sea_sectors[,"capital_stock.s.us",,] <-
  sea_source[,"K",lists$sectors,] / 100 /
  sea_sectors[,"exchange.r.us",,]
