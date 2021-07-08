# Cálculos da balança comercial e da troca desigual

pais_cols_matriz <- matrix(rep(pais_cols, times = tamanho), ncol = tamanho_completo-1, nrow = tamanho, byrow = TRUE)
pais_lins_matriz <- matrix(rep(pais_lins, times = tamanho_completo-1), ncol = tamanho_completo-1, nrow = tamanho, byrow = FALSE)
filtro_paises <- pais_cols_matriz+(pais_lins_matriz/100)

balanca_comercial_valores <- tapply(m_t[1:tamanho,1:(tamanho_completo-1)],filtro_paises,sum,na.rm = TRUE)
balanca_comercial_valores <- matrix(balanca_comercial_valores, ncol = num_paises, nrow = num_paises)*(1-diag(num_paises))
pais$importacoes_valores <- colSums(balanca_comercial_valores)
pais$exportacoes_valores <- rowSums(balanca_comercial_valores)

balanca_comercial_pm <- tapply(m_wio[1:tamanho,1:(tamanho_completo-1)],filtro_paises,sum,na.rm = TRUE)
balanca_comercial_pm <- matrix(balanca_comercial_pm, ncol = num_paises, nrow = num_paises)*(1-diag(num_paises))
pais$importacoes_preco_mercado <- colSums(balanca_comercial_pm)
pais$exportacoes_preco_mercado <- rowSums(balanca_comercial_pm)

filtro_produtivo_exportacao <- matrix(rep(filtro_produtivo, times = tamanho_completo-1), ncol = tamanho_completo-1, nrow = tamanho, byrow = FALSE)
balanca_comercial_produtivos_pm <- tapply(m_wio[1:tamanho,1:(tamanho_completo-1)]*filtro_produtivo_exportacao,filtro_paises,sum,na.rm = TRUE)
balanca_comercial_produtivos_pm <- matrix(balanca_comercial_produtivos_pm, ncol = num_paises, nrow = num_paises)*(1-diag(num_paises))
pais$importacoes_produtivos_preco_mercado <- colSums(balanca_comercial_produtivos_pm)
pais$exportacoes_produtivos_preco_mercado <- rowSums(balanca_comercial_produtivos_pm)

fator_saldo <- sum(balanca_comercial_valores)/sum(balanca_comercial_produtivos_pm)

transferencias <- ((t(balanca_comercial_produtivos_pm) - balanca_comercial_produtivos_pm) * fator_saldo) + balanca_comercial_valores - t(balanca_comercial_valores)
colnames(transferencias) <- paises$Legenda
pais$transferencias <- colSums(transferencias)
