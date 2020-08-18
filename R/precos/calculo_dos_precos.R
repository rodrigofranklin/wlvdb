valores <- m.t[lin.produto.total, 1:tamanho]
precos_mercado <- m.wio[lin.produto.total, col.prods]
k <- sum(precos_mercado)/sum(valores)
precos_diretos <-  k * valores
precos_mercado <- m.wio[lin.produto.total, 1:tamanho]

Cols <- max(pais.cols[])
k_n = ProdutoTotalMPais = ProdutoTotalTPais <- matrix(0,1,Cols)

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