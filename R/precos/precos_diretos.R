# Script para leitura dos preços diretos, preços de produção e valores

versao = versao_fonte <- "July14"
versao_resultado <- "July14_1001"

source('R/sectorespaises.R')
pais.cols <- pais.lins

ano <- 1995

m.wio <- readRDS(paste0(getwd(),"/sourcedata/",versao_fonte,"/WIOT_",as.character(ano),".rds"))
m.t <- readRDS(paste0(getwd(),"/resultados/",versao_resultado,"/wiod_horas_",as.character(ano),".rds"))

tamanho <- num.paises*num.setores


if (versao == "July14") {
  lin.produto.total <- nrow(m.wio)
} else {
  lin.produto.total <- which(wiot[,'IndustryCode'] == 'GO')
}

valores <- m.t[lin.produto.total, 1:tamanho]
precos_mercado <- m.wio[lin.produto.total, col.prods]
k <- sum(precos_mercado)/sum(valores)
precos_diretos <-  k * valores

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

sum(valores)
sum(precos_diretos)
sum(precos_diretos_n)
sum(precos_mercado)