#######################################################################
#
# Calcula emprego e capital para o resto do mundo
# + Salários

pos_row <- (num_paises-1)*num_setores
posicao_row <- which(pais_lins==paises[paises[,3]=="ROW",2])

#Cálculo do emprego e das horas trabalhadas
emp_row_total <- row_emp[which(row_emp==versao),as.character(ano)]
was_w_row <- as.numeric(row_emp[which(row_emp=='was_w'),as.character(ano)])/100

soma_emp_setor <- tapply(sea$emp[1:pos_row], rep(1:num_setores,times = num_paises-1), sum)
soma_h_emp_setor <- tapply(sea$h_emp[1:pos_row], rep(1:num_setores,times = num_paises-1), sum)
soma_va_setor <- tapply(m_wio[lin_va, 1:pos_row], rep(1:num_setores,times = num_paises-1), sum)

sea$emp[posicao_row] <- emp_row_total*prop.table(m_wio[lin_va,posicao_row]*soma_emp_setor/soma_va_setor)
sea$h_emp[posicao_row] <- sea$emp[posicao_row]*(soma_h_emp_setor/soma_emp_setor)
sea$empe[posicao_row] <- sea$emp[posicao_row]*was_w_row
sea$h_empe[posicao_row] <- sea$h_emp[posicao_row]*was_w_row

sea$emp[is.na(sea$emp)] <- 0
sea$h_emp[is.na(sea$h_emp)] <- 0
sea$empe[is.na(sea$empe)] <- 0
sea$h_empe[is.na(sea$h_empe)] <- 0

if (versao == "July14") {
  sea$h_hs[posicao_row] <- tapply(sea$h_hs[1:pos_row], rep(1:num_setores,times = num_paises-1), mean, na.rm = TRUE)
  sea$h_ms[posicao_row] <- tapply(sea$h_ms[1:pos_row], rep(1:num_setores,times = num_paises-1), mean, na.rm = TRUE)
  sea$h_ls[posicao_row] <- 1 - sea$h_hs[posicao_row] - sea$h_ms[posicao_row]

  sea$labhs[posicao_row] <- tapply(sea$labhs[1:pos_row], rep(1:num_setores,times = num_paises-1), mean, na.rm = TRUE)
  sea$labms[posicao_row] <- tapply(sea$labms[1:pos_row], rep(1:num_setores,times = num_paises-1), mean, na.rm = TRUE)
  sea$labls[posicao_row] <- 1 - sea$labhs[posicao_row] - sea$labms[posicao_row]
}

#Cálculo dos salários
lab_row_total <- (sum(sea$lab_usd))/sum(m_wio[lin_va,1:(tamanho-num_setores)])*sum(m_wio[lin_va,posicao_row])
soma_lab_setor <- tapply(sea$lab_usd[1:pos_row], rep(1:num_setores,times = num_paises-1), sum)
sea$lab_usd[posicao_row] <- lab_row_total*prop.table(m_wio[lin_va,posicao_row]*soma_lab_setor/soma_emp_setor)

comp_row_total <- (sum(sea$comp_usd))/sum(m_wio[lin_va,1:(tamanho-num_setores)])*sum(m_wio[lin_va,posicao_row])
soma_comp_setor <- tapply(sea$comp_usd[1:pos_row], rep(1:num_setores,times = num_paises-1), sum)
sea$comp_usd[posicao_row] <- comp_row_total*prop.table(m_wio[lin_va,posicao_row]*soma_comp_setor/soma_emp_setor)

#Cálculo do capital a partir da intensidade de k dos países pobres
paises_pobres <- c(17, 18, 4, 5, 37, 27, 7, 32, 31, 29, 16, 23, 24, 33, 11, 9)
filtro <- rep(0, times=pos_row)
for (y in 1: length(paises_pobres)) {
  filtro <- filtro + c(rep(0, times = (num_setores*(paises_pobres[y]-1))),rep(1,times=num_setores),rep(0,times=num_setores*(num_paises-1-paises_pobres[y])))
}
filtro <- filtro*rep(1:num_setores,times = num_paises-1)

sea$k_usd[posicao_row] <- m_wio[lin_va,posicao_row]*tapply(sea$k_usd[1:pos_row], filtro, sum, simplify = TRUE)[2:(num_setores+1)]/tapply(m_wio[lin_va,1:pos_row], filtro, sum, simplify = TRUE)[2:(num_setores+1)]
