#preços diretos
print("Calculando precos diretos...")

#### Preços diretos com base mundial
k <- sum(sea$producao_bruta_precos_mercado)/sum(sea$producao_bruta_valores)
sea$producao_bruta_precos_diretos <- k * sea$producao_bruta_valores
pais$producao_bruta_precos_diretos <-  tapply(sea$producao_bruta_precos_diretos, pais_lins, sum, na.rm = TRUE)

#### Preços diretos com base nacional
k_n <- pais$producao_bruta_precos_mercado/pais$producao_bruta_valores
sea$producao_bruta_precos_diretos_nacionais <- sea$producao_bruta_valores * rep(k_n, each=num_setores)


### Desvios médios absolutos com base nacional

### K apenas considerando setores produtivos para cálculo de desvio
kpr <- sum(sea[sea$producao_bruta_valores>0,"producao_bruta_precos_mercado"])/
  sum(sea$producao_bruta_valores)

### Kpr com base nacional
kpr_n <- pais$producao_bruta_produtivo_precos_mercado/pais$producao_bruta_valores
sea$producao_bruta_precos_diretos_nacionais_pr <- sea$producao_bruta_valores * rep(kpr_n, each=num_setores)
  
  
pais$mad <- (sea%>%
  filter(producao_bruta_valores>0)%>%
  group_by(pais)%>%
  summarize(mad=MAPE(producao_bruta_precos_diretos_nacionais_pr,
                     producao_bruta_precos_mercado)))[[2]]

