# labour_compensation
sea_sectors[,"compensation.emp.s.us",,] <-
  sea_source[,"LAB",lists$sectors,] / 
  sea_sectors[,"exchange.r.us",,]
