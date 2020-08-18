# Script para leitura dos preços diretos, preços de produção e valores

versao = versao_fonte <- "July14"
versao_resultado <- "July14_1006"
anos <- 1995:2009
# versao = versao_fonte <- "Nov16"
# versao_resultado <- "Nov16_1007"
# anos <- 2000:2014

source('R/sectorespaises.R')
pais.cols <- pais.lins

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

for (ano in anos) {
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
  source('R/precos/calculo_dos_precos.R')
  
  resultado$temp <- t(cbind(t(valores), t(precos_diretos), t(precos_diretos_n), t(precos_mercado)))
  names(resultado)[names(resultado) == "temp"] <- ano
}

write.csv2(resultado, file = paste0("resultados/",versao_resultado,"/precos_",versao_resultado,".csv"))


