## Cálculos de dados nacionais

print("Calculando dados nacionais...")
pais <- paises[,c(1,3)]
pais[,1] <- NULL

pais$producao_bruta_precos_mercado <- tapply(sea$producao_bruta_precos_mercado, pais_lins, sum, na.rm = TRUE)
pais$producao_bruta_valores <- tapply(sea$producao_bruta_valores, pais_lins, sum, na.rm = TRUE)

producao_bruta_produtivo_precos_mercado <- tapply(sea$producao_bruta_precos_mercado, pais_lins*filtro_produtivo, sum, na.rm = TRUE)
pais$producao_bruta_produtivo_precos_mercado <- producao_bruta_produtivo_precos_mercado[2:(num_paises+1)]

pais$trabalho <-  tapply(sea$trabalho, pais_lins, sum, na.rm = TRUE)
pais$horas_trabalhadas <-  tapply(sea$h_emp, pais_lins, sum, na.rm = TRUE)
pais$trabalhadores <- tapply(sea$emp, pais_lins, sum, na.rm = TRUE)
pais$remuneracao_precos_mercado <- tapply(sea$lab_usd, pais_lins, sum, na.rm = TRUE)
pais$remuneracao_real <- tapply(sea$lab_real, pais_lins, sum, na.rm = TRUE)

pais$trabalho_assalariado <- tapply(sea$trabalho_assalariado, pais_lins, sum, na.rm = TRUE)
pais$jornada_total <- tapply(sea$h_empe, pais_lins, sum, na.rm = TRUE)
pais$assalariados <- tapply(sea$empe, pais_lins, sum, na.rm = TRUE)
pais$salario_precos_mercado <- tapply(sea$comp_usd, pais_lins, sum, na.rm = TRUE)
pais$salario_real <- tapply(sea$comp_real, pais_lins, sum, na.rm = TRUE)
pais$salario_medio <- pais$salario_precos_mercado/pais$assalariados

pais$lucro_bruto_precos_mercado <- tapply(sea$cap_usd, pais_lins, sum, na.rm = TRUE)
pais$capital_depreciacao_preco_mercado <- tapply(sea$k_dep, pais_lins, sum, na.rm = TRUE)
pais$capital_estoque_preco_mercado <- tapply(sea$k_usd, pais_lins, sum, na.rm = TRUE)
pais$lucro_liquido_precos_mercado <- pais$lucro_bruto_precos_mercado - pais$capital_depreciacao_preco_mercado

pais$consumo_intermediario_preco_mercado <- tapply(m_wio[tamanho+1, 1:tamanho], pais_lins, sum, na.rm = TRUE)
pais$va_usd <- tapply(m_wio[lin_va, 1:tamanho], pais_lins, sum, na.rm = TRUE)
