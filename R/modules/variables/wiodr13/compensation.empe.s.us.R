# wages
sea_sectors[,"compensation.empe.s.us",,] <-
  sea_source[,"COMP",lists$sectors,] / 
  sea_sectors[,"exchange.r.us",,]
