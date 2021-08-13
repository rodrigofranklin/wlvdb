# wages
sea_sectors[,"wages",,] <-
  sea_source[,"COMP",lists$sectors,] / 
  sea_sectors[,"exchange_rate",,]
