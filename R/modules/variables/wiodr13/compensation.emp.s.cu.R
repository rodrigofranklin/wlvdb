# labour_compensation in constant dollars
sea_sectors[,"compensation.emp.s.cu",,] <-
  sea_source[,"LAB",lists$sectors,] / 
  sea_source[,"VA_P",lists$sectors,] * 100 / 
  rep(sea_sectors[1,"exchange.r.us",,], each = nums$years)