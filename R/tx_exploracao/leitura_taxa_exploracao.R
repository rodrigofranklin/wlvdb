# Script para leitura das taxas de exploração

# versao = versao_fonte  <- "July14"
# versao_resultado <- "July14_1015"
# anos <- 1995:2009
versao = versao_fonte <- "Nov16"
versao_resultado <- "Nov16_1016"
anos <- 2000:2014

# Define a variável que será utilizada para o cálculo dos valores
variavel_trabalho <- 'h.emp'
# variavel_trabalho <- 'Tciz'
#variavel_trabalho <- 'emp'
#variavel_trabalho <- 'h.emp_alternativo'

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

paises.setores <- data.frame(country=rep(paises$Legenda,each=num.setores))
paises.setores$description <- setores$Setor
paises.setores$code <- setores$Code

resultado_temp <- paises.setores
resultado_temp$variable <- 'taxa_exploracao'
resultado <- resultado_temp

taxa_exploracao_media_mundo <-  NULL

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
  h.emp <- sea["h.emp",]
  emp <- sea["emp",]
  trabalho <- sea["trabalho",]
  vft <- sea["valor_forca_trabalho",]
  
  print("Fim da leitura")
  
  resultado$temp <- sea["taxa_exploracao"]
  names(resultado)[names(resultado) == "temp"] <- ano

  paises$exp <- tapply(trabalho, pais.cols, sum, na.rm = TRUE)/tapply(vft, pais.cols, sum, na.rm = TRUE) -1
  names(paises)[names(paises) == "exp"] <- ano
}

write.csv2(resultado, file = paste0("resultados/",versao_resultado,"/tx_exploracao_setores_",versao_resultado,".csv"))
write.csv2(paises, file = paste0("resultados/",versao_resultado,"/tx_exploracao_paises_",versao_resultado,".csv"))
