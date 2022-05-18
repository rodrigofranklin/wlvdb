# Capital stock - current USD prices
sea_sectors[,"capital_stock.s.us",,] <-
  sea_source[,"K",lists$sectors,] /
  sea_sectors[,"exchange.r.us",,]
