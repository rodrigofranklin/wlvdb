if (versao == "July14") {
  m.wio <- readRDS(paste0(getwd(),"/sourcedata/",versao,"/WIOT_",as.character(ano),".rds"))
  m.t <- readRDS(paste0(getwd(),"/resultados/",versao_resultado,"/wiod_horas_",as.character(ano),".rds"))
  lin.produto.total <- nrow(m.wio)
} else {
  load(paste0(getwd(),"/sourcedata/Nov16/WIOT",as.character(ano),"_October16_ROW.RData"))
  m.wio <- as.matrix(wiot[,6:ncol(wiot)])
  m.t <- readRDS(paste0(getwd(),"/resultados/",versao_resultado,"/wiod_horas_",as.character(ano),".rds"))
  lin.produto.total <- which(wiot[,'IndustryCode'] == 'GO')
}  


tamanho <- num.paises*num.setores

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