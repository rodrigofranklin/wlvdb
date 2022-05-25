# Taxa de lucro apropriado monetariamente
sea_countries[,"appropriated_profit.r.pc",] <-
  (sea_countries[,"profit.s.us",] - 
     sea_countries[,"capital_depreciation.s.us",]) /
  sea_countries[,"capital_stock.s.us",]
