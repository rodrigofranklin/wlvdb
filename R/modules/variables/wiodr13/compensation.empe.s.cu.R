# labour_compensation in constant dollars
sea_sectors[,"compensation.empe.s.cu",,] <-
  sea_source[,"COMP",lists$sectors,] / 
  sea_source[,"VA_P",lists$sectors,] * 100 / 
  rep(sea_sectors[1,"exchange.r.us",,], each = nums$years)
