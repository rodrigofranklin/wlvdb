# labour_compensation
sea_sectors[,"appropriated_profit.r.pc",,] <-
  (sea_sectors[,"profit.s.us",lists$sectors,] - 
     sea_sectors[,"capital_depreciation.s.us",lists$sectors,]) /
  sea_sectors[,"capital_stock.s.us",,]
