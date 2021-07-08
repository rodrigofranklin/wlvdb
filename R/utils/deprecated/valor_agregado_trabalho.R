########################################################################
###
### Script padrão para cálculos de variáveis em versões pré-calculadas
###
########################################################################

###
### Variáveis de versão
###
#versao = versao_fonte  <- "July14"
#versao_resultado <- "July14_1021"
#anos <- 1995:2009
 versao = versao_fonte <- "Nov16"
 versao_resultado <- "Nov16_1023"
 anos <- 2000:2014

# Carrega variáveis de controle
source('R/lib/variaveis_controle.R')
caminho <- paste0("resultados/", versao_resultado)

###
### Área para inicialização das variáveis de resultado
###

# paises_setores <- data.frame(country=rep(paises$Legenda,each=num_setores))
# paises_setores$description <- setores$Setor
# paises_setores$code <- setores$Code
# resultado_temp <- paises_setores
# resultado_temp$variable <- 'EXEMPLO1'
# resultado <- resultado_temp
# resultado_temp$variable <- 'EXEMPLO2'
#resultado <- rbind(resultado, resultado_temp)

for (ano in anos) {
  
  #Carrega os dados brutos da versão especificada
  source("R/lib/dados_brutos.R")

  #Carrega os dados pré-calculados da versão especificada
  source("R/lib/dados_pre_calculados.R")
  
  ###
  ### Área para os cálculos desejados
  ###
  
  trabalho_produtivo <-  tapply(sea$trabalho, pais_lins*filtro_produtivo, sum, na.rm = TRUE)
  pais$trabalho_produtivo <-  trabalho_produtivo[2:(num_paises+1)]
  horas_trabalhadas_produtivo <-  tapply(sea$h_emp, pais_lins*filtro_produtivo, sum, na.rm = TRUE)
  pais$horas_trabalhadas_produtivo <-  horas_trabalhadas_produtivo[2:(num_paises+1)]
  write.csv2(pais, file = paste0(caminho, "/resultados_",as.character(ano)," - ", versao_resultado, ".csv"), row.names = TRUE)
  
}

###
### Área para registro das informações
###

# write.csv2(resultado, file = paste0("resultados/",versao_resultado,"/EXEMPLO_",versao_resultado,".csv"))