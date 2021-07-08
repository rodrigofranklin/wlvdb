########################################################################
###
### Script padrão para cálculos de variáveis em versões pré-calculadas
###
########################################################################

###
### Variáveis de versão
###
# versao = versao_fonte  <- "July14"
# versao_resultado <- "July14_1015"
# anos <- 1995:2009
versao = versao_fonte <- "Nov16"
versao_resultado <- "Nov16_1016"
anos <- 2000:2014

# Carrega variáveis de controle
source('R/lib/variaveis_controle.R')

###
### Área para inicialização das variáveis de resultado
###

# paises.setores <- data.frame(country=rep(paises$Legenda,each=num.setores))
# paises.setores$description <- setores$Setor
# paises.setores$code <- setores$Code
# resultado_temp <- paises.setores
# resultado_temp$variable <- 'EXEMPLO'
# resultado <- resultado_temp

for (ano in anos) {
  
  #Carrega os dados brutos da versão especificada
  source("R/lib/dados_brutos.R")

  #Carrega os dados pré-calculados da versão especificada
  source("R/lib/dados_pre_calculados.R")
  
  ###
  ### Área para os cálculos desejados
  ###
  
  # resultado$temp <- 'EXEMPLO'
  # names(resultado)[names(resultado) == "temp"] <- ano

}

###
### Área para registro das informações
###

# write.csv2(resultado, file = paste0("resultados/",versao_resultado,"/EXEMPLO_",versao_resultado,".csv"))