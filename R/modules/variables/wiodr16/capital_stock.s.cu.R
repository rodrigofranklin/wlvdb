# Capital stock - current USD prices
sea_sectors[,"capital_stock.s.cu",,] <-
  sea_source[,"K",lists$sectors,] / 
  sea_source[,"GO_PI",lists$sectors,] * 100 /
  rep(sea_sectors[1,"exchange.r.us",,], each = nums$years)
