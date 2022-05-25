# Balança comercial em dólares

sea_sectors[lists$years,"trade_balance.s.us",,] <- 
  sea_sectors[lists$years,"exports.s.us",,] -
  sea_sectors[lists$years,"imports.s.us",,]