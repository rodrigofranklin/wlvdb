# Soma dos valores recebidos via comércio internacional dos setores improdutivos

sea_sectors[lists$years,"trade_transfers.u.s.mv",,] <- 
  sea_sectors[lists$years,"trade_transfers.s.mv",,] -
  sea_sectors[lists$years,"trade_transfers.p.s.mv",,]
