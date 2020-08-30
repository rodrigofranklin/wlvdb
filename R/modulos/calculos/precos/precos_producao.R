#Cálculo dos preços de produção

print(paste0("calculando precos de producao do ano ",as.character(ano)))
A <- m_wio[1:tamanho,1:tamanho]/producao_bruta_pm_matriz
A[is.infinite(A)] <- 0
A[is.nan(A)] <- 0

K <- k_composicao/producao_bruta_pm_matriz
K[is.infinite(K)] <- 0
K[is.nan(K)] <- 0

D <- m_depreciacao/producao_bruta_pm_matriz
D[is.infinite(D)] <- 0
D[is.nan(D)] <- 0

b.a0 <- cesta_consumo/producao_bruta_pm_matriz
b.a0[is.infinite(b.a0)] <- 0
b.a0[is.nan(b.a0)] <- 0

t <- diag(rotacao, tamanho)
t[is.infinite(t)] <- 0
t[is.nan(t)] <- 0

I <- diag(tamanho)

#[K + (A + b.a0)<t>] (I - A - b.a0 - D)-1 -> turnover => 1 por ano
producao_bruta_precos_producao <- eigen(t((K + (A+b.a0)%*%t ) %*% solve(I -A -b.a0 -D)))

ro <- 1/Re(producao_bruta_precos_producao[["values"]][1])
sea$producao_bruta_precos_producao <- Re(producao_bruta_precos_producao[["vectors"]][,1])

k <- sum(sea$producao_bruta_precos_mercado)/sum(sea$producao_bruta_precos_mercado*sea$producao_bruta_precos_producao)
sea$producao_bruta_precos_producao <- k*sea$producao_bruta_precos_producao*sea$producao_bruta_precos_mercado
pais$producao_bruta_precos_producao <- tapply(sea$producao_bruta_precos_producao, pais_lins, sum, na.rm = TRUE)

print("Fim do calculo dos precos de producao")
