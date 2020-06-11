#######################################################################
#
# Cálculo do emprego mundial
#

emp.row.total <- row.emp[which(row.emp==versao),as.character(z)]
was_w_row <- as.numeric(row.emp[which(row.emp=='was_w'),as.character(z)])/100
emp.wiod <- sum(emp)

pos.row <- (num.paises-1)*num.setores
tamanho <- dim(emp)

ponderacao <- emp

for (setor in 1:num.setores) {
  posicao <- setor+pos.row
  emp.setor.wiod <- sum(emp[seq(setor,tamanho,num.setores)])
  h.emp.setor.wiod <- sum(h.emp[seq(setor,tamanho,num.setores)])
  va.setor.wiod <- sum(m.wio[lin.va,seq(setor,tamanho-num.setores,num.setores)])
  ponderacao[posicao] <- m.wio[lin.va,posicao]*emp.setor.wiod/va.setor.wiod
}

posicao <- which(pais.lins==paises[paises[,3]=="ROW",2])


total.ponderacao <- sum(ponderacao[posicao])
ponderacao[posicao] <- ponderacao[posicao]/total.ponderacao
emp[posicao] <- ponderacao[posicao]*emp.row.total
h.emp[posicao] <- emp[posicao]*(h.emp.setor.wiod/emp.setor.wiod)
empe[posicao] <- emp[posicao]*was_w_row
h.empe[posicao] <- h.emp[posicao]*was_w_row

emp[is.na(emp)] <- 0
h.emp[is.na(h.emp)] <- 0
empe[is.na(empe)] <- 0
h.empe[is.na(h.empe)] <- 0
