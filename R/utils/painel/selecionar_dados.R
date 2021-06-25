########################################################################
##
## Seleciona os dados que serão exibidos no painel (para reduzir uso da
## memória). Todos os dados serão salvos na pasta "dados".
##
########################################################################

## Seleciona versões
#####
versao_13  <- "July14"
versao_resultado_13 <- "July14_1011"
versao_16  <- "Nov16"
versao_resultado_16 <- "Nov16_1010"


## Carrega os dados
#####
paises <- read.csv2(file = "R/utils/painel/dados/paises.csv", row.names = 1, check.names = F)
num_paises <- dim(paises)[1]

m_io_13 <- readRDS(file = paste0("resultados/",versao_resultado_13,"/m_io.RDS"))
m_io_filtros_13 <- readRDS(file = paste0("resultados/",versao_resultado_13,"/m_io_filtros.RDS"))
# m_paises_13 <- readRDS(file = paste0("resultados/",versao_resultado_13,"/m_paises.RDS"))
sea_paises_13 <- readRDS(file = paste0("resultados/",versao_resultado_13,"/sea_paises.RDS"))
sea_setores_13 <- readRDS(file = paste0("resultados/",versao_resultado_13,"/sea_setores.RDS"))

m_io_16 <- readRDS(file = paste0("resultados/",versao_resultado_16,"/m_io.RDS"))
m_io_filtros_16 <- readRDS(file = paste0("resultados/",versao_resultado_16,"/m_io_filtros.RDS"))
# m_paises_16 <- readRDS(file = paste0("resultados/",versao_resultado_16,"/m_paises.RDS"))
sea_paises_16 <- readRDS(file = paste0("resultados/",versao_resultado_16,"/sea_paises.RDS"))
sea_setores_16 <- readRDS(file = paste0("resultados/",versao_resultado_16,"/sea_setores.RDS"))

## Cria as listas das dimensões (que serão utilizadas como inputs)
#####
lista_versoes <- c("WIOD13", "WIOD16")
lista_anos <- unique(c(rownames(sea_paises_13[,1,]), rownames(sea_paises_16[,1,])))
lista_variaveis_sea <- unique(c(rownames(sea_paises_13[1,,]), rownames(sea_paises_16[1,,])))
lista_paises <- paises[,3]
names(lista_paises) <- paises[match(paises[,3], lista_paises),1]
lista_setores_13 <- colnames(sea_setores_13[1,,])
lista_setores_16 <- colnames(sea_setores_16[1,,])
lista_variaveis_comercio <- c("exportações.pm", "exportações.valores", "transferências.valores")
# lista_variaveis_comercio <- c("exportações.pm", "exportações.valores",
#                               "transferencias.vaores", "saldo.pm",
#                               "saldo.valores", "transferencias.envios",
#                               "transferências.recebimentos")

## Mescla os bancos de dados das duas versões em um único arquivo.

## Mescla o arquivo sea_paises
#####
sea_paises <- array(data = NA, dim = c(length(lista_versoes),
                                       length(lista_anos),
                                       length(lista_variaveis_sea),
                                       length(lista_paises)),
                    dimnames = list(lista_versoes,
                                    lista_anos,
                                    lista_variaveis_sea,
                                    lista_paises))
# Ainda preciso automatixar o 1:41 e 1:44
sea_paises["WIOD13",
           match(rownames(sea_paises_13[,1,]), lista_anos),
           match(rownames(sea_paises_13[1,,]), lista_variaveis_sea),
           match(colnames(sea_paises_13[1,,1:41]), lista_paises)] <- sea_paises_13[,,1:41]
sea_paises["WIOD16",
           match(rownames(sea_paises_16[,1,]), lista_anos),
           match(rownames(sea_paises_16[1,,]), lista_variaveis_sea),
           match(colnames(sea_paises_16[1,,1:44]), lista_paises)] <- sea_paises_16[,,1:44]



## Separa informações das transações internacionais
#####

## WIOD13
tamanho_setores <- length(lista_setores_13)
tamanho_output <- length(m_io_13[1,1,1,])-1
lista_output <- names(m_io_13[1,1,1,1:tamanho_output])
lista_anos <- rownames(m_io_13[,1,,])

m_io_13_painel <- array(data = NA,
                        dim = c(length(lista_anos),
                                3,
                                tamanho_setores,
                                tamanho_output),
                        dimnames = list(lista_anos,
                                        lista_variaveis_comercio,
                                        lista_setores_13,
                                        lista_output))
for (ano in lista_anos){
  m_io_13_fonte <- readRDS(paste0("sourcedata/", versao_13,"/WIOT_", ano, ".rds"))

  m_io_13_painel[ano,"exportações.pm",,] <-
    m_io_13_fonte[1:tamanho_setores,1:tamanho_output]*
    m_io_filtros_13["filtro.comércio",1:tamanho_setores,1:tamanho_output]

  m_io_13_painel[ano,"exportações.valores",,] <-
    m_io_13[ano,"valores",1:tamanho_setores,1:tamanho_output]*
    m_io_filtros_13["filtro.comércio",1:tamanho_setores,1:tamanho_output]
  
  m_io_13_painel[ano,"transferências.valores",,] <-
    m_io_13[ano,"transferências.valores",1:tamanho_setores,1:tamanho_output]*
    m_io_filtros_13["filtro.comércio",1:tamanho_setores,1:tamanho_output]
}

## WIOD16
tamanho_setores <- length(lista_setores_16)
tamanho_output <- length(m_io_16[1,1,1,])-1
lista_output <- names(m_io_16[1,1,1,1:tamanho_output])
lista_anos <- rownames(m_io_16[,1,,])

m_io_16_painel <- array(data = NA,
                        dim = c(length(lista_anos),
                                3,
                                tamanho_setores,
                                tamanho_output),
                        dimnames = list(lista_anos,
                                        lista_variaveis_comercio,
                                        lista_setores_16,
                                        lista_output))
for (ano in lista_anos){
  load(paste0(getwd(),"/sourcedata/Nov16/WIOT",ano,"_October16_ROW.RData"))
  m_io_16_fonte <- as.matrix(wiot[,6:ncol(wiot)])
  
  m_io_16_painel[ano,"exportações.pm",,] <-
    m_io_16_fonte[1:tamanho_setores,1:tamanho_output]*
    m_io_filtros_16["filtro.comércio",1:tamanho_setores,1:tamanho_output]
  
  m_io_16_painel[ano,"exportações.valores",,] <-
    m_io_16[ano,"valores",1:tamanho_setores,1:tamanho_output]*
    m_io_filtros_16["filtro.comércio",1:tamanho_setores,1:tamanho_output]
  
  m_io_16_painel[ano,"transferências.valores",,] <-
    m_io_16[ano,"transferências.valores",1:tamanho_setores,1:tamanho_output]*
    m_io_filtros_16["filtro.comércio",1:tamanho_setores,1:tamanho_output]
}

# Exportações: Horas, $ e Transferências
# (As importações são as transpostas das exportações)

# comercio_paises_13 <- array(data = NA, dim = c(15,8,41,41),
#                             dimnames = list(lista_anos,
#                                             lista_variaveis_comercio,
#                                             lista_paises,
#                                             lista_paises))


# Saldo: Horas, $ e Transferências
# Exportações - t(exportações)

# Transferências: Enviados (>0), Recebidos (<0)



# dimnames(m_paises_13)

## Salva informações na pasta do painel
#####

saveRDS(sea_paises, file = "R/utils/painel/dados/sea_paises.RDS")
saveRDS(m_io_13_painel, file = "R/utils/painel/dados/m_io_13.RDS")
saveRDS(m_io_16_painel, file = "R/utils/painel/dados/m_io_16.RDS")

###
###



#############
### VERSÃO ANTIGA
# ###
# ### Variáveis de versão
# ###
# versao = versao_fonte  <- "July14"
# versao_resultado <- "July14_1011"
# anos <- 1995:2009
# 
# # Carrega variáveis de controle
# source('R/lib/variaveis_controle.R')
# 
# ###
# ### Área para inicialização das variáveis de resultado
# ###
# 
# # paises_setores <- data.frame(country=rep(paises$Legenda,each=num_setores))
# # paises_setores$description <- setores$Setor
# # paises_setores$code <- setores$Code
# 
# resultado <- NULL
# 
# lista_variaveis <- c("taxa_exploracao", 'valor_forca_trabalho')
# 
# # for (variavel in lista_variaveis) {
# #   resultado_temp <- paises_setores
# #   resultado_temp$variable <- variavel
# #   resultado_temp$versao <- 0
# #   resultado <- rbind(resultado, resultado_temp)
# # }
# # resultado_temp <- resultado
# 
# paises_resultado <- read.csv2(file = paste0(getwd(),"/sourcedata/Nov16/paises.csv"), row.names = 1, check.names = F)
# # taxa_exploracao <- paises_resultado[,2:3]
# 
# for (variavel in lista_variaveis) {
#   resultado_temp <- paises_resultado[,2:3]
#   resultado_temp$Código <- variavel
#   resultado <- rbind(resultado, resultado_temp)
# }
# names(resultado)[names(resultado) == "Código"] <- "variavel"
# 
# resultado_temp <- resultado
# 
# dados_transacoes <- array(NA, dim = c(15,5,41,41),
#                           dimnames = list(c(1995:2009),
#                                           c("balanca_comercial_valores","balanca_comercial_pm",
#                                             "balanca_comercial_produtivos_pm","balanca_comercial_transferencias",
#                                             "transfs"),
#                                           as.matrix(paises[,3]),
#                                           as.matrix(paises[,3])))
# 
# for (ano in anos) {
#   
#   #Carrega os dados brutos da versão especificada
#   source("R/lib/dados_brutos.R")
#   
#   #Carrega os dados pré-calculados da versão especificada
#   source("R/lib/dados_pre_calculados.R")
# 
#   resultado$temp <- NA
#   for (variavel in lista_variaveis) {
#     resultado[resultado$variavel==variavel,]$temp[match(rownames(pais),resultado[,2])] <-  pais[,variavel]
#   }
#   names(resultado)[names(resultado) == "temp"] <- ano
#   
# 
# ### Separar as balancas comerciais em moeda e valores
#   
#   pais_cols_matriz <- matrix(rep(pais_cols, times = tamanho), ncol = tamanho_completo-1, nrow = tamanho, byrow = TRUE)
#   pais_lins_matriz <- matrix(rep(pais_lins, times = tamanho_completo-1), ncol = tamanho_completo-1, nrow = tamanho, byrow = FALSE)
#   filtro_paises <- pais_cols_matriz+(pais_lins_matriz/100)
#   
#   balanca_comercial_valores <- tapply(m_t[1:tamanho,1:(tamanho_completo-1)],filtro_paises,sum,na.rm = TRUE)
#   balanca_comercial_valores <- matrix(balanca_comercial_valores, ncol = num_paises, nrow = num_paises)*(1-diag(num_paises))
# 
#   balanca_comercial_pm <- tapply(m_wio[1:tamanho,1:(tamanho_completo-1)],filtro_paises,sum,na.rm = TRUE)
#   balanca_comercial_pm <- matrix(balanca_comercial_pm, ncol = num_paises, nrow = num_paises)*(1-diag(num_paises))
# 
#   filtro_produtivo_exportacao <- matrix(rep(filtro_produtivo, times = tamanho_completo-1), ncol = tamanho_completo-1, nrow = tamanho, byrow = FALSE)
#   balanca_comercial_produtivos_pm <- tapply(m_wio[1:tamanho,1:(tamanho_completo-1)]*filtro_produtivo_exportacao,filtro_paises,sum,na.rm = TRUE)
#   balanca_comercial_produtivos_pm <- matrix(balanca_comercial_produtivos_pm, ncol = num_paises, nrow = num_paises)*(1-diag(num_paises))
# 
# 
#   dados_transacoes[as.character(ano),"balanca_comercial_valores",,] <- balanca_comercial_valores
#   
#   #  colnames(balanca_comercial_produtivos_pm) =  row.names(balanca_comercial_produtivos_pm) = colnames(balanca_comercial_pm) =  row.names(balanca_comercial_pm) = colnames(balanca_comercial_valores) =  row.names(balanca_comercial_valores) <- paises$Legenda
# 
#   
#   # write.csv2(balanca_comercial_valores, file = paste0("R/utils/painel/dados/balanca_comercial_valores13_", ano, ".csv"))
#   # write.csv2(balanca_comercial_pm, file = paste0("R/utils/painel/dados/balanca_comercial_pm13_", ano, ".csv"))
#   # write.csv2(balanca_comercial_produtivos_pm, file = paste0("R/utils/painel/dados/balanca_comercial_produtivos_pm13_", ano, ".csv"))
#   
#   
#   # balanca_comercial_impordutivos_pm <- balanca_comercial_pm - balanca_comercial_produtivos_pm
#   # 
#   # fator_saldo <- sum(balanca_comercial_valores)/sum(balanca_comercial_produtivos_pm)
#   # 
#   # balanca_comercial_transferencias <-  (balanca_comercial_produtivos_pm * fator_saldo) - balanca_comercial_valores
#   # balanca_comercial_transferencias_improdutivos <- (balanca_comercial_impordutivos_pm)*fator_saldo
#   # 
#   # saldo_comercial_transferencias <- balanca_comercial_transferencias + balanca_comercial_transferencias_improdutivos
#   # 
#   # balanca_comercial_percentual <- (-balanca_comercial_transferencias_improdutivos)/balanca_comercial_valores
#   # 
#   # transfs <- balanca_comercial_transferencias - t(balanca_comercial_transferencias)
#   # transfs_total <- transfs + (balanca_comercial_transferencias_improdutivos-t(balanca_comercial_transferencias_improdutivos))
#   # 
#   # transfs <- sprintf("%.2f", transfs)
#   # 
#   # sum(transferencias)
#   #   
#   # transferencias_envios <- 
#   # transferencias_recebimentos <- 
#   # 
#   # colnames(transferencias) <- paises$Legenda
#   # row.names(transferencias) <- paises$Legenda
# 
#   
#   
#   
#   
# }
# 
# 
# write.csv2(resultado, file = paste0("R/utils/painel/dados/dados_paises13.csv"))
# 
# # resultado13 <- resultado
# # resultado13$versao <- "WIOD13"
# resultado <- resultado_temp
# 
# ## Próxima versão
# versao = versao_fonte <- "Nov16"
# versao_resultado <- "Nov16_1010"
# anos <- 2000:2014
# source('R/lib/variaveis_controle.R')
# 
# for (ano in anos) {
#   
#   #Carrega os dados brutos da versão especificada
#   source("R/lib/dados_brutos.R")
#   
#   #Carrega os dados pré-calculados da versão especificada
#   source("R/lib/dados_pre_calculados.R")
#   
#   resultado$temp <- NA
#   for (variavel in lista_variaveis) {
#     resultado[resultado$variavel==variavel,]$temp[match(rownames(pais),resultado[,2])] <-  pais[,variavel]
#   }
#   names(resultado)[names(resultado) == "temp"] <- ano
#   
# }
# 
# 
# write.csv2(resultado, file = paste0("R/utils/painel/dados/dados_paises16.csv"))
# 
# # resultado16 <- resultado
# # resultado16$versao <- "WIOD16"
# # resultado <- rbind(resultado13, resultado16)
# 
# 
# #write.csv2(resultado, file = paste0("R/utils/painel/dados/dados_paises13.csv"))