# Script para leitura das taxas de exploração


###
### Variáveis de versão
###
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

# Carrega variáveis de controle
source('R/lib/variaveis_controle.R')


###
### Área para inicialização das variáveis de resultado
###

paises.setores <- data.frame(country=rep(paises$Legenda,each=num.setores))
paises.setores$description <- setores$Setor
paises.setores$code <- setores$Code

resultado_temp <- paises.setores
resultado_temp$variable <- 'taxa_exploracao'
resultado <- resultado_temp

taxa_exploracao_media_mundo <-  NULL

for (ano in anos) {

  #Carrega os dados pré-calculados da versão especificada
  source("R/lib/dados_pre_calculados.R")
  
  ###
  ### Área para os cálculos desejados
  ###
  
  resultado$temp <- sea["taxa_exploracao"]
  names(resultado)[names(resultado) == "temp"] <- ano

  paises$exp <- tapply(trabalho, pais.cols, sum, na.rm = TRUE)/tapply(valor_forca_trabalho, pais.cols, sum, na.rm = TRUE) -1
  names(paises)[names(paises) == "exp"] <- ano
}

###
### Área para registro das informações
###

write.csv2(resultado, file = paste0("resultados/",versao_resultado,"/tx_exploracao_setores_",versao_resultado,".csv"))
write.csv2(paises, file = paste0("resultados/",versao_resultado,"/tx_exploracao_paises_",versao_resultado,".csv"))
