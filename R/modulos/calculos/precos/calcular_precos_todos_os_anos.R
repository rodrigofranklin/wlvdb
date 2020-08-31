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
anos <- 1995:2009
# versao = versao_fonte <- "Nov16"
# versao_resultado <- "Nov16_1016"
# anos <- 2000:2014

# Carrega variáveis de controle
source('R/lib/variaveis_controle.R')

###
### Área para inicialização das variáveis de resultado
###

source('R/lib/sem_taiwan_variaveis.R')
pais <- paises[,c(1,3)]
pais[,1] <- NULL

paises_setores <- data.frame(country=rep(paises$Legenda,each=num_setores))
paises_setores$description <- setores$Setor
paises_setores$code <- setores$Code

resultado_temp <- paises_setores
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
  
  #Carrega os dados brutos da versão especificada
  source("R/lib/dados_brutos.R")

  #Carrega os dados pré-calculados da versão especificada
  source("R/lib/dados_pre_calculados.R")
  
  ###
  ### Área para os cálculos desejados
  ###
  source('R/lib/sem_taiwan_dados.R')

  pais$producao_bruta_precos_mercado <- tapply(sea$producao_bruta_precos_mercado, pais_lins, sum, na.rm = TRUE)
  pais$producao_bruta_valores <- tapply(sea$producao_bruta_valores, pais_lins, sum, na.rm = TRUE)
  source("R/modulos/calculos/precos/precos_diretos.R")
  
  source("R/modulos/calculos/cesta_consumo.R")
  rotacao <- 1
  source("R/modulos/calculos/precos/precos_producao.R")
  prec_prod <- sea$producao_bruta_precos_producao
  taxa_lucro_media_mundo <- c(taxa_lucro_media_mundo, ro)
  
  
  rotacao <- 2
  source("R/modulos/calculos/precos/precos_producao.R")
  prec_prod2 <- sea$producao_bruta_precos_producao
  taxa_lucro_media_mundo2 <- c(taxa_lucro_media_mundo, ro)
  
  resultado$temp <- t(cbind(t(sea$producao_bruta_valores), t(sea$producao_bruta_precos_diretos), t(sea$producao_bruta_precos_diretos_nacionais), t(sea$producao_bruta_precos_mercado), t(prec_prod), t(prec_prod2)))
  names(resultado)[names(resultado) == "temp"] <- ano
  
  print(paste("Ano",ano,"processado, com taxa de lucro média mundial de ", ro))
}

###
### Área para registro das informações
###

write.csv2(resultado, file = paste0("resultados/",versao_resultado,"/precos_",versao_resultado,".csv"))
write.csv2(taxa_lucro_media_mundo, file = paste0("resultados/",versao_resultado,"/tx_lucro_",versao_resultado,".csv"))
write.csv2(taxa_lucro_media_mundo2, file = paste0("resultados/",versao_resultado,"/tx_lucro2_",versao_resultado,".csv"))
