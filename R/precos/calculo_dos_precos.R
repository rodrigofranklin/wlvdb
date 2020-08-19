valores <- m.t[lin.produto.total, 1:tamanho]
precos_mercado <- m.wio[lin.produto.total, col.prods]
k <- sum(precos_mercado)/sum(valores)
precos_diretos <-  k * valores
precos_mercado <- m.wio[lin.produto.total, 1:tamanho]

Cols <- max(pais.cols[])
k_n = ProdutoTotalMPais = ProdutoTotalTPais <- matrix(0,1,Cols)

#[K + (A + b.a0)<t>] (I - A - b.a0 - D)-1

A <- m.wio[1:tamanho,1:tamanho]/matrix(m.wio[lin.produto.total,1:tamanho], nrow = tamanho, ncol=tamanho, byrow = TRUE)
A[is.infinite(A)] <- 0
A[is.nan(A)] <- 0

K <- k.composicao/matrix(m.wio[lin.produto.total,1:tamanho], nrow = tamanho, ncol=tamanho, byrow = TRUE)
K[is.infinite(K)] <- 0
K[is.nan(K)] <- 0

D <- m.depreciacao/matrix(m.wio[lin.produto.total,1:tamanho], nrow = tamanho, ncol=tamanho, byrow = TRUE)
D[is.infinite(D)] <- 0
D[is.nan(D)] <- 0

t <- diag(tamanho)
t[is.infinite(t)] <- 0
t[is.nan(t)] <- 0

I <- diag(tamanho)

prop_demanda_familias <- as.data.frame(prop.table(m.wio[1:tamanho,col.demanda.final], margin = 2))
prop_demanda_familias <- as.matrix(prop_demanda_familias[rep(names(prop_demanda_familias), each = num.setores)])

b.a0 <- (matrix(sea["lab.usd",], ncol = tamanho, nrow = tamanho, byrow = TRUE)*prop_demanda_familias)/matrix(m.wio[lin.produto.total,1:tamanho], nrow = tamanho, ncol=tamanho, byrow = TRUE)
b.a0[is.infinite(b.a0)] <- 0
b.a0[is.nan(b.a0)] <- 0

#[K + (A + b.a0)<t>] (I - A - b.a0 - D)-1
prec_prod <- eigen(t((K + (A+b.a0)%*%t ) * solve(I -A -b.a0 -D)))

ro <- 1/Re(prec_prod[["values"]][1])
prec_prod <- Re(prec_prod[["vectors"]][,1])

k <- sum(m.wio[lin.produto.total,1:tamanho])/sum(m.wio[lin.produto.total,1:tamanho]*prec_prod)
prec_prod <- k*prec_prod*m.wio[lin.produto.total,1:tamanho]

for (x in 1:num.paises){
  #Produto total em horas de trabalho e em moeda (soma dos setores produtivos)
  ProdutoTotalTPais[x] <- sum(m.t[lin.produto.total, col.prods[which(pais.cols[col.prods]==x)]])
  ProdutoTotalMPais[x] <- sum(m.wio[lin.produto.total, col.prods[which(pais.cols[col.prods]==x)]])
  
  #Variável K para o cálculo dos preços diretos (base nacional)
  k_n[x] <- ProdutoTotalMPais[x]/ProdutoTotalTPais[x]
  
  # O FatorDemanda é uma espécide de constate K exclusiva para o consumo das famílias.
  # Por isso, a utilizei para o cálculo do valor da força de trabalho
  #FatorDemanda[x] <- DemandaFinalTPais[x]/DemandaFinalMPais[x]
}

precos_diretos_n <- valores * rep(k_n, each=num.setores)