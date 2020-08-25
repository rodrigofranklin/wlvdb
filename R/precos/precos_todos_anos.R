# Script para leitura dos preços diretos, preços de produção e valores

versao = versao_fonte  <- "July14"
versao_resultado <- "July14_1011"
anos <- 1995:2009
# versao = versao_fonte <- "Nov16"
# versao_resultado <- "Nov16_1010"
# anos <- 2000:2014

source("R/precos/turnover-rotacion.R")

source('R/sectorespaises.R')
pais.cols <- pais.lins
tamanho <- num.paises*num.setores

# Obtém informações sobre as colunas de demanda das famílias
demanda<-read.csv2(paste0(getwd(),"/sourcedata/",versao,"/demanda.csv"))
num.demanda <- dim(demanda)[1]
col.demanda.final <- NULL
for (x in paises[,2]) {
  col.demanda.final <- c(col.demanda.final, (tamanho) + demanda[demanda == 'Final consumption expenditure by households',3] + (num.demanda*(x-1)))
}

source('R/precos/sem_taiwan_variaveis.R')

paises.setores <- data.frame(country=rep(paises$Legenda,each=num.setores))
paises.setores$description <- setores$Setor
paises.setores$code <- setores$Code

resultado_temp <- paises.setores
resultado_temp$variable <- 'valores'
resultado <- resultado_temp
resultado_temp$variable <- 'precos_diretos'
resultado <- rbind(resultado, resultado_temp)
resultado_temp$variable <- 'precos_diretos_n'
resultado <- rbind(resultado, resultado_temp)
resultado_temp$variable <- 'precos_mercado'
resultado <- rbind(resultado, resultado_temp)
resultado_temp$variable <- 'precos_producao'
resultado <- rbind(resultado, resultado_temp)
resultado_temp$variable <- 'precos_producao2'
resultado <- rbind(resultado, resultado_temp)

taxa_lucro_media_mundo <- NULL
taxa_lucro_media_mundo2 <- NULL

for (ano in anos) {
  print(paste0("Lendo dados do ano ",as.character(ano)))
  if (versao == "July14") {
    m.wio <- readRDS(paste0(getwd(),"/sourcedata/",versao,"/WIOT_",as.character(ano),".rds"))
    m.t <- readRDS(paste0(getwd(),"/resultados/",versao_resultado,"/wiod_horas_",as.character(ano),".rds"))
    k.composicao <- readRDS(paste0(getwd(),"/resultados/",versao_resultado,"/k_composicao_",as.character(ano),".rds"))
    m.depreciacao <- readRDS(paste0(getwd(),"/resultados/",versao_resultado,"/m_depreciacao_",as.character(ano),".rds"))
    sea <- readRDS(paste0(getwd(),"/resultados/",versao_resultado,"/socioeconomicas_",as.character(ano),".rds"))
    lin.produto.total <- nrow(m.wio)
  } else {
    load(paste0(getwd(),"/sourcedata/Nov16/WIOT",as.character(ano),"_October16_ROW.RData"))
    m.wio <- as.matrix(wiot[,6:ncol(wiot)])
    m.t <- readRDS(paste0(getwd(),"/resultados/",versao_resultado,"/wiod_horas_",as.character(ano),".rds"))
    k.composicao <- readRDS(paste0(getwd(),"/resultados/",versao_resultado,"/k_composicao_",as.character(ano),".rds"))
    m.depreciacao <- readRDS(paste0(getwd(),"/resultados/",versao_resultado,"/m_depreciacao_",as.character(ano),".rds"))
    sea <- readRDS(paste0(getwd(),"/resultados/",versao_resultado,"/socioeconomicas_",as.character(ano),".rds"))
    lin.produto.total <- which(wiot[,'IndustryCode'] == 'GO')
  }  
  
  produto_bruto_matriz <- matrix(m.wio[lin.produto.total,1:tamanho], nrow = tamanho, ncol=tamanho, byrow = TRUE)
  
  lab.usd <- sea["lab.usd",]

  print("Fim da leitura")
  
  source('R/precos/sem_taiwan_dados.R')
  calcular_precos_producao = TRUE
  source('R/precos/calculo_dos_precos.R')
  
  resultado$temp <- t(cbind(t(valores), t(precos_diretos), t(precos_diretos_n), t(precos_mercado), t(prec_prod), t(prec_prod2)))
  names(resultado)[names(resultado) == "temp"] <- ano
  taxa_lucro_media_mundo <- c(taxa_lucro_media_mundo, ro)
<<<<<<< HEAD:R/precos/precos_diretos.R
  print(paste("Ano",ano,"processado, 
              com taxa de lucro média mundial de",
              taxa_lucro_media_mundo))
=======
  taxa_lucro_media_mundo2 <- c(taxa_lucro_media_mundo2, ro2)
>>>>>>> c2127a3f831dfd77ee0eef8d4b64b58a19491112:R/precos/precos_todos_anos.R
}

write.csv2(resultado, file = paste0("resultados/",versao_resultado,"/precos_",versao_resultado,".csv"))
write.csv2(taxa_lucro_media_mundo, file = paste0("resultados/",versao_resultado,"/tx_lucro_",versao_resultado,".csv"))
write.csv2(taxa_lucro_media_mundo2, file = paste0("resultados/",versao_resultado,"/tx_lucro2_",versao_resultado,".csv"))

