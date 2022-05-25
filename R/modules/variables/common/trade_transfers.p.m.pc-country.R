# Soma dos valores recebidos via comércio internacional dos setores produtivos
# TROCA DESIGUAL (em % do valor produzido)

sea_countries[lists$years,"trade_transfers.p.m.pc",] <- 
  sea_countries[lists$years,"trade_transfers.p.s.mv",] /
  sea_countries[lists$years,"gdp.s.mv",]