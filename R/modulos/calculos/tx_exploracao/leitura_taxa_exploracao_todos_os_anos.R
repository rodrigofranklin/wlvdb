########################################################################
###
### Script padrão para cálculos de variáveis em versões pré-calculadas
###
########################################################################

###
### Variáveis de versão
###
versao = versao_fonte  <- "July14"
versao_resultado <- "July14_1018"
anos <- 1995:2011
# versao = versao_fonte <- "Nov16"
# versao_resultado <- "Nov16_1016"
# anos <- 2000:2014

# Carrega variáveis de controle
source('R/lib/variaveis_controle.R')

###
### Área para inicialização das variáveis de resultado
###

paises_setores <- data.frame(country=rep(paises$Legenda,each=num_setores))
paises_setores$description <- setores$Setor
paises_setores$code <- setores$Code

resultado_temp <- paises_setores
resultado_temp$variable <- 'taxa_exploracao'
resultado <- resultado_temp

taxa_exploracao_media_mundo <-  NULL

for (ano in anos) {
  
  #Carrega os dados brutos da versão especificada
  source("R/lib/dados_brutos.R")

  #Carrega os dados pré-calculados da versão especificada
  source("R/lib/dados_pre_calculados.R")
  
  ###
  ### Área para os cálculos desejados
  ###
  
#  resultado$temp <- sea$taxa_exploracao
#  names(resultado)[names(resultado) == "temp"] <- ano

  paises$exp <- pais$taxa_exploracao_total
  names(paises)[names(paises) == "exp"] <- ano
  
}

###
### Área para registro das informações
###

write.csv2(paises, file = paste0("resultados/",versao_resultado,"/tx_exploracao_paises_",versao_resultado,".csv"), row.names = FALSE)
