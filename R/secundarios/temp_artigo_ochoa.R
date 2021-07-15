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

lista_variaveis <- c('Tx.Exp', 'Tx.Exp_HS', 'Tx.Exp_MS', 'Tx.Exp_LS', 'Salarios', 'Horas_assalariadas')

for (variavel in lista_variaveis) {
  resultado_temp <- paises_setores
  resultado_temp$variable <- variavel
  resultado_temp$versao <- 0
  resultado <- rbind(resultado, resultado_temp)
}
resultado_temp <- resultado

resultado_ver <- NULL

series <- data.frame(matrix(0, ncol = length(anos_14), nrow = length(versoes_14)), row.names = versoes_14)
colnames(series) <- anos_14
tx_exp_mundo_hs = tx_exp_mundo_ms = tx_exp_mundo_ls = tx_exp_mundo = transf_eua_br = tx_exp_eua = tx_exp_br = transf_eua_br_prop =  transf_eua_mex = transf_eua_mex_prop <- series


paises_painel <- c("JPN","USA","BRA","MEX")
painel <- data.frame(matrix(0, ncol = length(versoes_14), nrow = length(paises_painel)), row.names = paises_painel)
colnames(painel) <- versoes_14
tx_exp_hs = tx_exp_ms = tx_exp_ls = va_pm = va_pd = produto_total_pd = produto_total_pm = transfs = tx_exp <- painel


for (versao_resultado in versoes_14) {
  for (ano in anos) {
    print(versao_resultado)

    #Carrega os dados brutos da versão especificada
    #source("R/lib/dados_brutos.R")
  
    #Carrega os dados pré-calculados da versão especificada
    source("R/lib/dados_pre_calculados.R")
    
    ###
    ### Área para os cálculos desejados
    ###

    if (ano == 2009) {
      tx_exp[,versao_resultado] <- pais[paises_painel,]$taxa_exploracao
      transfs[,versao_resultado] <- pais[paises_painel,]$transferencias/pais[paises_painel,]$trabalho_produtivo
      produto_total_pm[,versao_resultado] <- pais[paises_painel,]$producao_bruta_precos_mercado
      produto_total_pd[,versao_resultado] <- pais[paises_painel,]$producao_bruta_precos_diretos
      va_pm[,versao_resultado] <- pais[paises_painel,]$va_usd
      va_pd[,versao_resultado] <- pais[paises_painel,]$trabalho_produtivo*(pais[paises_painel,]$producao_bruta_precos_diretos/pais[paises_painel,]$producao_bruta_valores)
      tx_exp_hs[,versao_resultado] <- pais[paises_painel,]$taxa_exploracao_hs
      tx_exp_ms[,versao_resultado] <- pais[paises_painel,]$taxa_exploracao_ms
      tx_exp_ls[,versao_resultado] <- pais[paises_painel,]$taxa_exploracao_ls
    }
    
    transf_eua_br[versao_resultado,as.character(ano)] <- transferencias[5,40]
    transf_eua_br_prop[versao_resultado,as.character(ano)] <- transferencias[5,40]/pais[5,]$trabalho_produtivo
    transf_eua_mex[versao_resultado,as.character(ano)] <- transferencias['México',40]
    transf_eua_mex_prop[versao_resultado,as.character(ano)] <- transferencias['México',40]/pais['MEX',]$trabalho_produtivo
    
    tx_exp_br[versao_resultado,as.character(ano)] <- pais['BRA',]$taxa_exploracao
    tx_exp_eua[versao_resultado,as.character(ano)] <- pais['USA',]$taxa_exploracao
    tx_exp_mundo[versao_resultado,as.character(ano)] <- ((sum(pais$trabalho_assalariado)-sum(pais$valor_forca_trabalho))/sum(pais$valor_forca_trabalho))
    tx_exp_mundo_hs[versao_resultado,as.character(ano)] <- sum(sea$trabalho_assalariado*sea$h_empe_hs, na.rm = TRUE)/sum(sea$valor_forca_trabalho*sea$labhs) -1
    tx_exp_mundo_ms[versao_resultado,as.character(ano)] <- sum(sea$trabalho_assalariado*sea$h_empe_ms, na.rm = TRUE)/sum(sea$valor_forca_trabalho*sea$labms) -1
    tx_exp_mundo_ls[versao_resultado,as.character(ano)] <- sum(sea$trabalho_assalariado*sea$h_empe_ls, na.rm = TRUE)/sum(sea$valor_forca_trabalho*sea$labls) -1
    
    resultado$temp <- t(cbind(t(sea$taxa_exploracao), t(sea$taxa_exploracao_hs), t(sea$taxa_exploracao_ms), t(sea$taxa_exploracao_ls), t(sea$comp_usd), t(sea$h_empe)))
    names(resultado)[names(resultado) == "temp"] <- ano
  
  }
  resultado$versao <- versao_resultado
  resultado_ver_temp <- resultado
  resultado_ver <- rbind(resultado_ver, resultado_ver_temp)
  resultado <- resultado_temp
}
###
### Área para registro das informações
###

library("xlsx")
arquivo <- paste0("resultados/Ochoa.xlsx")
write.xlsx(tx_exp, file = arquivo, sheetName = "tx_exp", append = FALSE)
write.xlsx(tx_exp_hs, file = arquivo, sheetName = "tx_exp_hs", append = FALSE)
write.xlsx(tx_exp_ms, file = arquivo, sheetName = "tx_exp_ms", append = FALSE)
write.xlsx(tx_exp_ls, file = arquivo, sheetName = "tx_exp_ls", append = FALSE)
write.xlsx(tx_exp_br, file = arquivo, sheetName = "tx_exp_br", append = TRUE)
write.xlsx(tx_exp_eua, file = arquivo, sheetName = "tx_exp_eua", append = TRUE)
write.xlsx(tx_exp_mundo, file = arquivo, sheetName = "tx_exp_mundo", append = TRUE)
write.xlsx(tx_exp_mundo_hs, file = arquivo, sheetName = "tx_exp_mundo_hs", append = TRUE)
write.xlsx(tx_exp_mundo_ms, file = arquivo, sheetName = "tx_exp_mundo_ms", append = TRUE)
write.xlsx(tx_exp_mundo_ls, file = arquivo, sheetName = "tx_exp_mundo_ls", append = TRUE)
write.xlsx(produto_total_pm, file = arquivo, sheetName = "produto_total_pm", append = TRUE)
write.xlsx(produto_total_pd, file = arquivo, sheetName = "produto_total_pd", append = TRUE)
write.xlsx(va_pm, file = arquivo, sheetName = "va_pm", append = TRUE)
write.xlsx(va_pd, file = arquivo, sheetName = "va_pd", append = TRUE)
write.xlsx(transfs, file = arquivo, sheetName = "transfs", append = TRUE)
write.xlsx(transf_eua_br_prop, file = arquivo, sheetName = "transf_eua_br_prop", append = TRUE)
write.xlsx(transf_eua_mex_prop, file = arquivo, sheetName = "transf_eua_mex_prop", append = TRUE)
write.xlsx(resultado_ver[resultado_ver$country %in% paises_painel,], file = arquivo, sheetName = "geral", row.names = FALSE, append = TRUE)