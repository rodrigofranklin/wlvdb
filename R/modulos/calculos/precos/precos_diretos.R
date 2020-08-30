#preços diretos
print("Calculando precos diretos...")

#### Preços diretos com base mundial
k <- sum(sea$producao_bruta_precos_mercado)/sum(sea$producao_bruta_valores)
sea$producao_bruta_precos_diretos <- k * sea$producao_bruta_valores
pais$producao_bruta_precos_diretos <-  tapply(sea$producao_bruta_precos_diretos, pais_lins, sum, na.rm = TRUE)

#### Preços diretos com base nacional
k_n <- pais$producao_bruta_precos_mercado/pais$producao_bruta_valores
sea$producao_bruta_precos_diretos_nacionais <- sea$producao_bruta_valores * rep(k_n, each=num_setores)
