#Cálculo do valor da força de trabalho e da taxa de exploração
print("Calculando taxas de exploracao...")
sea$valor_forca_trabalho <- colSums(cesta_consumo_assalariados*matrix(fator_t, ncol = tamanho, nrow = tamanho, byrow = FALSE))
pais$valor_forca_trabalho <- tapply(sea$valor_forca_trabalho, pais_lins, sum, na.rm = TRUE)
sea$taxa_exploracao <- (sea$trabalho_assalariado/sea$valor_forca_trabalho) - 1 
pais$taxa_exploracao <- pais$trabalho_assalariado/pais$valor_forca_trabalho -1
taxa_exploracao_pais_produtivos <-  tapply(sea$trabalho_assalariado, pais_lins*filtro_produtivo, sum, na.rm = TRUE)/tapply(sea$valor_forca_trabalho, pais_lins*filtro_produtivo, sum, na.rm = TRUE) -1
pais$taxa_exploracao_produtivos <- taxa_exploracao_pais_produtivos[2:(num_paises+1)]

sea$remuneracao_valor <- colSums(cesta_consumo*matrix(fator_t, ncol = tamanho, nrow = tamanho, byrow = FALSE))
pais$remuneracao_valor <- tapply(sea$remuneracao_valor, pais_lins, sum, na.rm = TRUE)
sea$taxa_exploracao_nao_assalariado <- (sea$trabalho - sea$trabalho_assalariado)/(sea$remuneracao_valor - sea$valor_forca_trabalho) - 1
pais$taxa_exploracao_nao_assalariado <- (pais$trabalho - pais$trabalho_assalariado)/(pais$remuneracao_valor - pais$valor_forca_trabalho) - 1
sea$taxa_exploracao_total <- sea$trabalho/sea$remuneracao_valor -1
pais$taxa_exploracao_total <- pais$trabalho/pais$remuneracao_valor -1

taxa_exploracao_mundo <- sum(sea$trabalho_assalariado)/sum(sea$valor_forca_trabalho) -1
taxa_exploracao_produtivo_mundo <- sum(sea$trabalho_assalariado*filtro_produtivo)/sum(sea$valor_forca_trabalho*filtro_produtivo) -1
taxa_exploracao_nao_assalariado_mundo <- sum(sea$trabalho - sea$trabalho_assalariado)/sum(sea$remuneracao_valor - sea$valor_forca_trabalho) -1
taxa_exploracao_total_mundo <- sum(sea$trabalho)/sum(sea$remuneracao_valor) -1

if (versao == 'July14') {
  sea$taxa_exploracao_total_hs <- (sea$trabalho*sea$h_hs)/(sea$remuneracao_valor*sea$labhs) -1
  sea$taxa_exploracao_total_ms <- (sea$trabalho*sea$h_ms)/(sea$remuneracao_valor*sea$labms) -1
  sea$taxa_exploracao_total_ls <- (sea$trabalho*sea$h_ls)/(sea$remuneracao_valor*sea$labls) -1
  pais$taxa_exploracao_total_hs <- tapply(sea$trabalho*sea$h_hs, pais_lins, sum, na.rm = TRUE)/tapply(sea$remuneracao_valor*sea$labhs, pais_lins, sum, na.rm = TRUE) -1
  pais$taxa_exploracao_total_ms <- tapply(sea$trabalho*sea$h_ms, pais_lins, sum, na.rm = TRUE)/tapply(sea$remuneracao_valor*sea$labms, pais_lins, sum, na.rm = TRUE) -1
  pais$taxa_exploracao_total_ls <- tapply(sea$trabalho*sea$h_ls, pais_lins, sum, na.rm = TRUE)/tapply(sea$remuneracao_valor*sea$labls, pais_lins, sum, na.rm = TRUE) -1
  taxa_exploracao_total_hs_mundo <- sum(sea$trabalho*sea$h_hs)/sum(sea$remuneracao_valor*sea$labhs) -1
  taxa_exploracao_total_ms_mundo <- sum(sea$trabalho*sea$h_ms)/sum(sea$remuneracao_valor*sea$labms) -1
  taxa_exploracao_total_ls_mundo <- sum(sea$trabalho*sea$h_ls)/sum(sea$remuneracao_valor*sea$labls) -1
}