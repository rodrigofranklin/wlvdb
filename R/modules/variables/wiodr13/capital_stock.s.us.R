# Capital stock - current USD prices
sea_sectors[,"capital_stock.s.us",,] <-
  sea_source[,"K_GFCF",lists$sectors,] *
  sea_source[,"GFCF_P",lists$sectors,] / 100 /
  sea_sectors[,"exchange.r.us",,]
