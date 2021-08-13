# labour_compensation
sea_sectors[,"labour_compensation",,] <-
  sea_source[,"LAB",lists$sectors,] / 
  sea_sectors[,"exchange_rate",,]
