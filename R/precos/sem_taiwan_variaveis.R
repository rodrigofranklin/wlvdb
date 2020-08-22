#Elimina taiwan das variáveis de controle

twn.demanda <- col.demanda.final[paises[paises[,3]=="TWN",2]]
twn.cols <- which(pais.cols==paises[paises[,3]=="TWN",2])
twn.n_cols <- which(pais.cols %in% paises[paises[,3]!="TWN",2])
row.demanda <- col.demanda.final[num.paises]
row.cols <- which(pais.cols==num.paises)

num.paises <- num.paises -1
paises <- paises[which(paises[,3]!="TWN"),]
tamanho <- num.paises*num.setores
col.demanda.final <- col.demanda.final[1:num.paises]-num.setores
pais.cols = pais.lins <- pais.cols[1:tamanho]
