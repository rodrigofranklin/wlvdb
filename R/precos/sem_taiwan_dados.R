#Junta os dados de Taiwan com os do resto do mundo

m.wio[,row.demanda] <- m.wio[,row.demanda] + m.wio[,twn.demanda]
m.wio[,row.cols] <- m.wio[,row.cols] + m.wio[,twn.cols]
m.wio[row.cols,] <- m.wio[row.cols,] + m.wio[twn.cols,]
m.wio <- m.wio[c(twn.n_cols,(last(twn.n_cols)+1):nrow(m.wio)),c(twn.n_cols,(last(twn.n_cols)+1):ncol(m.wio))]

m.t[,row.cols] <- m.t[,row.cols] + m.t[,twn.cols]
m.t[row.cols,] <- m.t[row.cols,] + m.t[twn.cols,]
m.t <- m.t[c(twn.n_cols,(last(twn.n_cols)+1):nrow(m.t)),c(twn.n_cols,(last(twn.n_cols)+1):ncol(m.t))]

k.composicao[,row.cols] <- k.composicao[,row.cols] + k.composicao[,twn.cols]
k.composicao[row.cols,] <- k.composicao[row.cols,] + k.composicao[twn.cols,]
k.composicao <- k.composicao[twn.n_cols,twn.n_cols]

m.depreciacao[,row.cols] <- m.depreciacao[,row.cols] + m.depreciacao[,twn.cols]
m.depreciacao[row.cols,] <- m.depreciacao[row.cols,] + m.depreciacao[twn.cols,]
m.depreciacao <- m.depreciacao[twn.n_cols,twn.n_cols]

lab.usd[row.cols] <- lab.usd[row.cols] + lab.usd[twn.cols]
lab.usd <- lab.usd[twn.n_cols]

lin.produto.total <- lin.produto.total - num.setores
