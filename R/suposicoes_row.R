#######################################################################
#
# Calcula emprego e capital para o resto do mundo
# + Salários

pos.row <- (num.paises-1)*num.setores
posicao.row <- which(pais.lins==paises[paises[,3]=="ROW",2])

#Cálculo do emprego e das horas trabalhadas
emp.row.total <- row.emp[which(row.emp==versao),as.character(z)]
was_w_row <- as.numeric(row.emp[which(row.emp=='was_w'),as.character(z)])/100
emp.wiod <- sum(emp)

soma.emp.setor <- tapply(emp[1:pos.row], rep(1:num.setores,times = num.paises-1), sum)
soma.h.emp.setor <- tapply(h.emp[1:pos.row], rep(1:num.setores,times = num.paises-1), sum)
soma.va.setor <- tapply(m.wio[lin.va, 1:pos.row], rep(1:num.setores,times = num.paises-1), sum)

emp[posicao.row] <- emp.row.total*prop.table(m.wio[lin.va,posicao.row]*soma.emp.setor/soma.va.setor)
h.emp[posicao.row] <- emp[posicao.row]*(soma.h.emp.setor/soma.emp.setor)
empe[posicao.row] <- emp[posicao.row]*was_w_row
h.empe[posicao.row] <- h.emp[posicao.row]*was_w_row

emp[is.na(emp)] <- 0
h.emp[is.na(h.emp)] <- 0
empe[is.na(empe)] <- 0
h.empe[is.na(h.empe)] <- 0

#Cálculo dos salários
lab.row.total <- (sum(lab.usd))/sum(m.wio[lin.va,1:(tamanho-num.setores)])*sum(m.wio[lin.va,posicao.row])
soma.lab.setor <- tapply(lab.usd[1:pos.row], rep(1:num.setores,times = num.paises-1), sum)
soma.emp.setor <- tapply(emp[1:pos.row], rep(1:num.setores,times = num.paises-1), sum)
lab.usd[posicao.row] <- lab.row.total*prop.table(m.wio[lin.va,posicao.row]*soma.lab.setor/soma.emp.setor)

#Cálculo do capital a partir da intensidade de k dos países pobres
paises.pobres <- c(17, 18, 4, 5, 37, 27, 7, 32, 31, 29, 16, 23, 24, 33, 11, 9)
filtro <- rep(0, times=pos.row)
for (y in 1: length(paises.pobres)) {
  filtro <- filtro + c(rep(0, times = (num.setores*(paises.pobres[y]-1))),rep(1,times=num.setores),rep(0,times=num.setores*(num.paises-1-paises.pobres[y])))
}
filtro <- filtro*rep(1:num.setores,times = num.paises-1)

k.usd[posicao.row] <- m.wio[lin.va,posicao.row]*tapply(k.usd[1:pos.row], filtro, sum, simplify = TRUE)[2:(num.setores+1)]/tapply(m.wio[lin.va,1:pos.row], filtro, sum, simplify = TRUE)[2:(num.setores+1)]
