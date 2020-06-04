#######################################################################
#
# Cálculo do emprego mundial
#

emp_row_total <- row_emp[which(row_emp==versao),as.character(z)]
was_w_row <- as.numeric(row_emp[which(row_emp=='was_w'),as.character(z)])/100
emp_wiod <- sum(emp)

posrow <- (num_paises-1)*num_setores
tamanho <- dim(emp)

ponderacao <- emp

for (setor in 1:num_setores) {
  posicao <- setor+posrow
  emp_setor_wiod <- sum(emp[seq(setor,tamanho,num_setores)])
  h_emp_setor_wiod <- sum(h_emp[seq(setor,tamanho,num_setores)])
  va_setor_wiod <- sum(m[linva,seq(setor,tamanho-num_setores,num_setores)])
  ponderacao[posicao] <- m[linva,posicao]*emp_setor_wiod/va_setor_wiod
}

posicao <- which(paislin==paises[paises[,3]=="ROW",2])


paisesponderacao <- sum(ponderacao[posicao])
ponderacao[posicao] <- ponderacao[posicao]/paisesponderacao
emp[posicao] <- ponderacao[posicao]*emp_row_total
h_emp[posicao] <- emp[posicao]*(h_emp_setor_wiod/emp_setor_wiod)
empE[posicao] <- emp[posicao]*was_w_row
h_empE[posicao] <- h_emp[posicao]*was_w_row

emp[is.na(emp)] <- 0
h_emp[is.na(h_emp)] <- 0
empE[is.na(empE)] <- 0
h_empE[is.na(h_empE)] <- 0
