# Balança comercial em dólares

sea_sectors[lists$years,"trade_balance.s.mv",,] <- 
  sea_sectors[lists$years,"exports.s.mv",,] -
  sea_sectors[lists$years,"imports.s.mv",,]