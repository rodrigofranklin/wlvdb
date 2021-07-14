########################################################################
###
### Levantamentos de dados para o artigo de resposta ao método de Ochoa
### sobre redução do trabalho complexo ao simples.
###
### Informações levantadas:
### - Produto e valores;
### - Taxas de exploração;
### - Transferências.
###
########################################################################

###
### Variáveis de versão
###

versao <- "July14"
versoes_14 <- c("July14_1020", "July14_1021", "July14_1011", "July14_1029", "July14_1028")
anos = anos_14 <- 1995:2009
# Carrega variáveis de controle
source('R/lib/variaveis_controle.R')

###
### Área para inicialização das variáveis de resultado
###

paises_setores <- data.frame(country=rep(paises$Legenda,each=num_setores))
paises_setores$description <- setores$Setor
paises_setores$code <- setores$Code

resultado <- NULL

lista_variaveis <- c('producao_bruta_pm', 'producao_bruta_pd', 'PIB_pm', 'PIB_pd')

for (variavel in lista_variaveis) {
  resultado_temp <- paises_setores
  resultado_temp$variable <- variavel
  resultado_temp$versao <- 0
  resultado <- rbind(resultado, resultado_temp)
}
resultado_temp <- resultado

resultado_ver <- NULL

versao_resultado <-  versoes_14[1]
paises_painel <- c("JPN","USA","BRA","MEX")

for (versao_resultado in versoes_14) {
  # for (ano in anos) {
  ano <- 2009
  print(versao_resultado)

  #Carrega os dados brutos da versão especificada
  source("R/lib/dados_brutos.R")

  #Carrega os dados pré-calculados da versão especificada
  source("R/lib/dados_pre_calculados.R")
  
  ###
  ### Área para os cálculos desejados
  ###

  
  sea$va_pm <- m_wio[lin_va,1:tamanho]
  
  sea$va_pd <- sea$trabalho * 
    sea$producao_bruta_precos_diretos / 
    sea$producao_bruta_valores
  
  sea$va_pd[is.nan(sea$va_pd)] <- 0

  resultado$temp <- t(cbind(t(sea$producao_bruta_precos_mercado), 
                            t(sea$producao_bruta_precos_diretos), 
                            t(sea$va_pm), 
                            t(sea$va_pd)))
  names(resultado)[names(resultado) == "temp"] <- ano
  # }
  resultado$versao <- versao_resultado
  resultado_ver_temp <- resultado
  resultado_ver <- rbind(resultado_ver, resultado_ver_temp)
  resultado <- resultado_temp
}
###
### Área para registro das informações
###

library(openxlsx)
arquivo <- paste0("resultados/Ochoa2.csv")
write.csv2(resultado_ver[resultado_ver$country %in% paises_painel,], file = arquivo, row.names = FALSE)
