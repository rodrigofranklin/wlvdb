sea_sectors[lists$years,"value_added_values",,] <- 
  sea_sectors[lists$years,"abstract_labour",,] * 
  rep(rows$productive, each = nums$years)
