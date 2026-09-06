# capital compensation
sea_sectors[,"profit.s.us",,] <-
  (sea_source[,"Value added from NOS (000 USD).Total",,] +
  sea_source[,"Value added from NMI (000 USD).Total",,]) / 1000
  