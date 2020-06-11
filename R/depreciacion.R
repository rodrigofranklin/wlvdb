#K Depreciation - Depreciación de Capit
#version inicial, sin depreciación
#remover ) and -Depreciation)

#Distribui o capital presente nas SEA em seus diversos tipos
k.composicao <- matrix(rep(t(prop.table(m.wio[1:(tamanho),col.fbcf],2)),each=num.setores), ncol = tamanho, nrow = tamanho, byrow = TRUE)*matrix(k.usd,nrow=tamanho,ncol=tamanho, byrow= TRUE)

#Calcula as taxas de depreciacao
tx.depreciacao <- matrix(0.15 , nrow = tamanho , ncol = tamanho)

#Aplica as taxas de depreciacao ao capital total
m.depreciacao <- k.composicao*tx.depreciacao

#Separa a depreciacao apenas dos capitais provenientes de setores produtivos
depreciacao <- matrix(0, nrow = length(lin.prods), ncol = length(col.prods))
depreciacao[x,x] <- m.depreciacao[col.prods,lin.prods]/matrix(m.wio[lin.produto.total,lin.prods], nrow = cols, ncol=cols, byrow = TRUE)
depreciacao[is.infinite(depreciacao)] <- 0
depreciacao[is.nan(depreciacao)] <- 0