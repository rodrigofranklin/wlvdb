########################################################################
###
### Script padrão para cálculos de variáveis em versões pré-calculadas
###
########################################################################

###
### Variáveis de versão
###
versao = versao_fonte  <- "July14"
versao_resultado <- "July14_1015"
anos <- 1995:2011
# versao = versao_fonte <- "Nov16"
# versao_resultado <- "Nov16_1016"
# anos <- 2000:2014
variavel_trabalho <- ''


caminho <- paste0("resultados/", versao_resultado)

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

taxas_exploracao_mundo <- NULL
taxas_exploracao_hs_mundo <- NULL
taxas_exploracao_ms_mundo <- NULL
taxas_exploracao_ls_mundo <- NULL
taxas_exploracao_produtivo_mundo <- NULL
taxas_exploracao_nao_assalariado_mundo <- NULL
taxas_exploracao_total_mundo <- NULL
taxas_exploracao_total_hs_mundo <- NULL
taxas_exploracao_total_ms_mundo <- NULL
taxas_exploracao_total_ls_mundo <- NULL
taxas_lucro_media_mundo <- NULL

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

  if (versao == 'July14') {
    sea$h_empe_hs = sea$h_emp_hs <- sea$h_hs
    sea$h_empe_ms = sea$h_emp_ms <- sea$h_ms
    sea$h_empe_ls = sea$h_emp_ls <- sea$h_ls
  }

  producao_bruta_pm_matriz <- matrix(sea$producao_bruta_precos_mercado, nrow = tamanho, ncol=tamanho, byrow = TRUE)
  source(paste0(getwd(),"/R/modulos/calculos/transformar.R"))
  
  source("R/modulos/calculos/cesta_consumo.R")
  
  source("R/modulos/calculos/tx_exploracao/taxa_exploracao.R")
  taxas_exploracao_mundo <- c(taxas_exploracao_mundo, taxa_exploracao_mundo)
  taxas_exploracao_produtivo_mundo <- c(taxas_exploracao_produtivo_mundo, taxa_exploracao_produtivo_mundo)
  taxas_exploracao_nao_assalariado_mundo <- c(taxas_exploracao_nao_assalariado_mundo, taxa_exploracao_nao_assalariado_mundo)
  taxas_exploracao_total_mundo <- c(taxas_exploracao_total_mundo, taxa_exploracao_total_mundo)
  if (versao == 'July14') {
    taxas_exploracao_hs_mundo <- c(taxas_exploracao_hs_mundo, taxa_exploracao_hs_mundo)
    taxas_exploracao_ms_mundo <- c(taxas_exploracao_ms_mundo, taxa_exploracao_ms_mundo)
    taxas_exploracao_ls_mundo <- c(taxas_exploracao_ls_mundo, taxa_exploracao_ls_mundo)

    taxas_exploracao_total_hs_mundo <- c(taxas_exploracao_total_hs_mundo, taxa_exploracao_total_hs_mundo)
    taxas_exploracao_total_ms_mundo <- c(taxas_exploracao_total_ms_mundo, taxa_exploracao_total_ms_mundo)
    taxas_exploracao_total_ls_mundo <- c(taxas_exploracao_total_ls_mundo, taxa_exploracao_total_ls_mundo)
  }

  saveRDS(sea, file = paste0(caminho, "/socioeconomicas_",as.character(ano), " - ", versao_resultado, ".rds"), compress = T)
  write.csv2(pais, file = paste0(caminho, "/resultados_",as.character(ano)," - ", versao_resultado, ".csv"))
}

mundo <- t(cbind(taxas_exploracao_mundo, taxas_exploracao_hs_mundo, 
                 taxas_exploracao_ms_mundo, taxas_exploracao_ls_mundo, 
                 taxas_exploracao_nao_assalariado_mundo, 
                 taxas_exploracao_total_mundo, taxas_exploracao_total_hs_mundo,
                 taxas_exploracao_total_ms_mundo, taxas_exploracao_total_ls_mundo,
                 taxas_lucro_media_mundo))
colnames(mundo) <- anos
write.csv2(mundo,
           file = paste0(caminho,"/__dados_mundiais_",versao_resultado,".csv"))

###
### Área para registro das informações
###

write.csv2(paises, file = paste0("resultados/",versao_resultado,"/tx_exploracao_paises_",versao_resultado,".csv"), row.names = FALSE)
