#################################
#
# Script para cálculo das matrizes IO em valor trabalho
#
#################################

library(readxl)

# Define a versão do WIOD que será utilizada: July14 ou Nov16
versao <- 'July14'
#versao <- 'Nov16'

# Define a variável que será utilizada para o cálculo dos valores
#variavel_trabalho <- 'sea$h_emp'
# variavel_trabalho <- 'Tciz'
#variavel_trabalho <- 'sea$emp'
#variavel_trabalho <- 'sea$h_emp_alternativo'
variavel_trabalho  <- "sea$h_emp_ponderado"
potencia_h <- 6.25
potencia_m <- 2.5
## Método Ochoa com índice salarial por hora de trabalho
#variavel_trabalho <- 'Tciz_hora'
#variavel_trabalho <- 'Tciz_n'

## Método de ponderação pela média dos salários conforme qualificação
#variavel_trabalho <- 'h_emp_ponderado_salario'


#Cria o diretório para salvar os resultados
ver_num <- readRDS("resultados/ver_num.rds")
versao_resultado <- paste0(versao, "_" , ver_num)
caminho <- paste0("resultados/", versao_resultado)
dir.create(caminho)

# Carrega variáveis de controle
source("R/lib/variaveis_controle.R")

# Carrega as informações das contas socioeconômicas
source("R/lib/importar_sea_variaveis.R")

# Suposições para o resto do mundo
source(paste0(getwd(),"/R/modulos/pressupostos/suposicoes_row_variaveis.R"))

# Suposições para China
source(paste0(getwd(),"/R/modulos/pressupostos/suposicoes_china_variaveis.R"))

## Inicialização de variáveis de resultado
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

  # Carrega dados brutos do 'ano' específico para a 'versao' especificada
  source("R/lib/dados_brutos.R")
    
  # Carrega as informações das contas socioeconômicas
  source("R/lib/importar_sea_dados.R")

  print(paste0(as.character(ano)," - Carregando suposicoes..."))
  # Estimativas da distribuição do capital fixo e depreciacao
  print(paste0(as.character(ano)," - China..."))
  # Estimativa de variáveis para a China
  source(paste0(getwd(),"/R/modulos/pressupostos/suposicoes_china_dados.R"))
    
  print(paste0(as.character(ano)," - RoW..."))
  # Estimativa de variáveis para o RoW
  source(paste0(getwd(),"/R/modulos/pressupostos/suposicoes_row_dados.R"))

  print(paste0(as.character(ano)," - Capital fixo..."))
  source("R/modulos/pressupostos/depreciacao.R")

  # Define qual a variável que será utilizada para o cálculo do valor
  print(paste0(as.character(ano)," - Definindo variavel quantidade de trabalho"))
  if (versao == 'July14') {
    sea$h_empe_hs = sea$h_emp_hs <- sea$h_hs
    sea$h_empe_ms = sea$h_emp_ms <- sea$h_ms
    sea$h_empe_ls = sea$h_emp_ls <- sea$h_ls
  }
  if (variavel_trabalho == "sea$h_emp") {
    sea$trabalho <- sea$h_emp
    sea$trabalho_assalariado <- sea$h_empe
  } else if (variavel_trabalho == "sea$emp") {
    sea$trabalho <- sea$emp
    sea$trabalho_assalariado <- sea$empe
  } else if (variavel_trabalho == "Tciz") {
    # Pessoas engajadas
    remuneracao_media <- sea$lab_usd/sea$emp
    remuneracao_media[is.na(remuneracao_media)] <- 0
    remuneracao_media[is.infinite(remuneracao_media)] <- 0
    sea$trabalho <- sea$h_emp * remuneracao_media/min(remuneracao_media[remuneracao_media>0])
    # Pessoas assalariadas
    salario_medio <- sea$comp_usd/sea$empe
    salario_medio[is.na(salario_medio)] <- 0
    salario_medio[is.infinite(salario_medio)] <- 0
    sea$trabalho_assalariado <- sea$h_empe * salario_medio/min(salario_medio[salario_medio>0])
  } else if (variavel_trabalho == "Tciz_hora") {
    # Pessoas engajadas
    remuneracao_media <- sea$lab_usd/sea$h_emp
    remuneracao_media[is.na(remuneracao_media)] <- 0
    remuneracao_media[is.infinite(remuneracao_media)] <- 0
    sea$trabalho <- sea$h_emp * remuneracao_media/min(remuneracao_media[remuneracao_media>0])
    # Pessoas assalariadas
    salario_medio <- sea$comp_usd/sea$h_empe
    salario_medio[is.na(salario_medio)] <- 0
    salario_medio[is.infinite(salario_medio)] <- 0
    sea$trabalho_assalariado <- sea$h_empe * salario_medio/min(salario_medio[salario_medio>0])
  } else if (variavel_trabalho == "Tciz_n") {
    # Pessoas engajadas
    remuneracao_media <- sea$lab_usd/sea$h_emp
    remuneracao_media[is.na(remuneracao_media)] <- Inf
    remuneracao_media[remuneracao_media==0] <- Inf
    remuneracao_minima_nacional <- tapply(remuneracao_media, pais_lins, min, na.rn = TRUE)
    remuneracao_media[is.infinite(remuneracao_media)] <- 0
    sea$trabalho <- sea$h_emp * remuneracao_media/rep(remuneracao_minima_nacional, each = num_setores)
    # Pessoas assalariadas
    salario_medio <- sea$comp_usd/sea$h_empe
    salario_medio[is.na(salario_medio)] <- Inf
    salario_medio[salario_medio==0] <- Inf
    salario_minimo_nacional <- tapply(salario_medio, pais_lins, min, na.rn = TRUE)
    salario_medio[is.infinite(salario_medio)] <- 0
    sea$trabalho_assalariado <- sea$h_empe * salario_medio/rep(salario_minimo_nacional, each = num_setores)
  } else if (variavel_trabalho == "sea$h_emp_ponderado") {
    sea$trabalho <- sea$h_emp * ((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
    sea$trabalho_assalariado <- sea$h_empe * ((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
    sea$h_empe_hs = sea$h_emp_hs <- (potencia_h * sea$h_hs)/((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
    sea$h_empe_ms = sea$h_emp_ms <- (potencia_m * sea$h_ms)/((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
    sea$h_empe_ls = sea$h_emp_ls <- (sea$h_ls)/((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
  } else if (variavel_trabalho == "h_emp_ponderado_salario") {
    # Pessoas engajadas
    potencia_h <- (sum(sea$labhs*sea$lab_usd)/sum(sea$h_hs*sea$h_emp))/(sum(sea$labls*sea$lab_usd)/sum(sea$h_ls*sea$h_emp))
    potencia_m <- (sum(sea$labms*sea$lab_usd)/sum(sea$h_ms*sea$h_emp))/(sum(sea$labls*sea$lab_usd)/sum(sea$h_ls*sea$h_emp))
    sea$trabalho <- sea$h_emp * ((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
    sea$h_emp_hs <- (potencia_h * sea$h_hs)/((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
    sea$h_emp_ms <- (potencia_m * sea$h_ms)/((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
    sea$h_emp_ls <- (sea$h_ls)/((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
    # Pessoas assalariadas
    potencia_h <- (sum(sea$labhs*sea$comp_usd)/sum(sea$h_hs*sea$h_empe))/(sum(sea$labls*sea$comp_usd)/sum(sea$h_ls*sea$h_empe))
    potencia_m <- (sum(sea$labms*sea$comp_usd)/sum(sea$h_ms*sea$h_empe))/(sum(sea$labls*sea$comp_usd)/sum(sea$h_ls*sea$h_empe))
    sea$trabalho_assalariado <- sea$h_empe * ((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
    sea$h_empe_hs <- (potencia_h * sea$h_hs)/((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
    sea$h_empe_ms <- (potencia_m * sea$h_ms)/((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
    sea$h_empe_ls <- (sea$h_ls)/((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
  } else {
    sea$trabalho <- sea$h_empe/sea$empe*sea$emp
    sea$trabalho_assalariado <- sea$h_empe
  }
  sea$trabalho[is.na(sea$trabalho)] <- 0
  sea$trabalho[is.infinite(sea$trabalho)] <- 0
  sea$trabalho_assalariado[is.na(sea$trabalho_assalariado)] <- 0
  sea$trabalho_assalariado[is.infinite(sea$trabalho_assalariado)] <- 0
  
  ###
  ### Área dos cálculos
  ###
  source(paste0(getwd(),"/R/modulos/calculos/transformar.R"))

  source("R/modulos/calculos/dados_nacionais.R")
  
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
  source("R/modulos/calculos/precos/precos_diretos.R")
  
  # rotacao <- 1
  # source("R/modulos/calculos/precos/precos_producao.R")
  # taxas_lucro_media_mundo <- c(taxas_lucro_media_mundo, ro)
  taxas_lucro_media_mundo <- c(taxas_lucro_media_mundo, 0)
  
  print(paste0(as.character(ano)," - Calculando transferencias..."))
  source("R/modulos/calculos/transferencias.R")

  ###
  ### Área de gravação de dados anuais
  ###
  print(paste0(as.character(ano)," - Gravando..."))
  saveRDS(sea, file = paste0(caminho, "/socioeconomicas_",as.character(ano), " - ", versao_resultado, ".rds"), compress = T)
  saveRDS(m_depreciacao, file = paste0(caminho, "/m_depreciacao_",as.character(ano)," - ", versao_resultado, ".rds"), compress = T)
  saveRDS(k_composicao, file = paste0(caminho, "/k_composicao_",as.character(ano)," - ", versao_resultado, ".rds"), compress = T)
  saveRDS(m_t, file = paste0(caminho, "/wiod_horas_",as.character(ano)," - ", versao_resultado, ".rds"), compress = T)
  write.csv2(pais, file = paste0(caminho, "/resultados_",as.character(ano)," - ", versao_resultado, ".csv"), row.names = FALSE)
  write.csv2(transferencias,
             file = paste0(caminho, "/transferencias_",as.character(ano)," - ", versao_resultado, ".csv"),
             row.names = paises[,1])
}

###
### Área de gravação de dados gerais
###

mundo <- t(cbind(taxas_exploracao_mundo, taxas_exploracao_hs_mundo, 
                 taxas_exploracao_ms_mundo, taxas_exploracao_ls_mundo, 
                 taxas_exploracao_nao_assalariado_mundo, 
                 taxas_exploracao_total_mundo, taxas_exploracao_total_hs_mundo,
                 taxas_exploracao_total_ms_mundo, taxas_exploracao_total_ls_mundo,
                 taxas_lucro_media_mundo))
colnames(mundo) <- anos
write.csv2(mundo,
           file = paste0(caminho,"/__dados_mundiais_",versao_resultado,".csv"))

ver_num <- ver_num+1
saveRDS(ver_num, file = "resultados/ver_num.rds")
