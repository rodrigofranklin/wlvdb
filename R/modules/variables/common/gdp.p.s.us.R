sea_sectors[lists$years,"gdp.p.s.us",,] <- 
  sea_sectors[lists$years,"gdp.s.us",,] * 
  rep(rows$productive, each = nums$years)
