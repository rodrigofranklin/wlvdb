sea_sectors[lists$years,"gdp.s.mv",,] <- 
  sea_sectors[lists$years,"abstract_labour.emp.s.mv",,] * 
  rep(rows$productive, each = nums$years)
