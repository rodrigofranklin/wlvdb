# Soma dos valores recebidos via comércio internacional dos setores produtivos
# TROCA DESIGUAL (em % do valor produzido)

sea_sectors[lists$years,"trade_transfers.p.m.pc",,] <- 
  sea_sectors[lists$years,"trade_transfers.p.s.mv",,] /
  sea_sectors[lists$years,"gdp.s.mv",,]