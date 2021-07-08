###################################################
# Script para transformar a WIOD em WIOD Marxista.
#
# Parâmetros necessários:
#
# m_wio - matriz contendo todos os dados da WIOD (incluindo trabalho e capital)
# m_depreciacao - matriz contendo a depreciação do capital fixo
# sea$trabalho - vetor das horas trabalhadas em cada setor
# sea$producao_bruta_precos_mercado - produto bruto por setor
# producao_bruta_pm_matriz - transformação do produto_bruto em uma matriz
# filtro_produtivo - filtro para indicação do trabalho produtivo em cada setor
# filtro_produtivo_matriz - filtro para indicação do resultado produtivo em cada setor
#
###################################################

print("Transformando...")

# Cria matriz de filtro para seleção apenas dos setores produtivos.
# 1 = setor produtivo; 0 = setor improdutivo. Ao multiplicar o filtro pela
# matriz insumo-produto, só permanecem os dados sobre os setores produtivos.
filtro <- matrix(linhas$produtivo, nrow = num_paises_setores, 
                 ncol = num_paises_setores, byrow = TRUE ) * linhas$produtivo
#####.
# Calcula a matriz inversa de leontief = (I-A-D)^(-1), onde:
# I => matriz identidade;
# A => matriz de coeficientes técnicos: (consumo intermediário)/produto total
# D => matriz de coeficientes de depreciacao.
# Código projetado para economia de memória, aplicado a todos os anos.

# Passo 1: cria um array de matrizes anuais cujas colunas são o produto total
# de cada setor.
leontief <- rep(sea_setores[,"produto_total_pm",,],
                        times = num_paises_setores)
dim(leontief) <- c(num_anos, num_paises_setores, num_paises_setores)
leontief <- aperm(leontief, c(1,3,2))

# Passo 2: calcula -(A+D)
leontief <- 
  (m_io_fonte[,lista_paises_setores,lista_paises_setores] + 
     m_io[,"k_depreciacao",lista_paises_setores,lista_paises_setores]) /
  leontief * rep(filtro, each = num_anos) * (-1)

leontief[is.nan(leontief)] <- 0
leontief[is.infinite(leontief)] <- 0

# Passo 3: soma a matriz identidade.
leontief <- leontief + rep(diag(num_paises_setores), each = num_anos)

# Passo 4: inverte a matriz.
print("Invertendo matriz de leontief...")

leontief <- parApply(cl = my.cluster, leontief, 1, solve)

# Formata o resultado (o array colapsa com foreach)
dim(leontief) <- c(num_paises_setores,
                                    num_paises_setores,
                                    num_anos)
leontief <- aperm(leontief,c(3,1,2))

print("Fim da inversao...")

##############################.
# Calcula o Fator Trabalho (o parâmetro de multiplicação de cada setor para
# o cálculo do produto em valor-trabalho)
##############################.

# Calcula a relação trabalho/produto de cada setor produtivo
# (i.e., requerimentos diretos de trabalho)
requerimentos_diretos <- 
  (sea_setores[,"trabalho_abstrato",,] / 
     sea_setores[,"produto_total_pm",,]) * 
  rep(linhas$produtivo, each = num_anos)
dim(requerimentos_diretos) <- c(num_anos, num_paises_setores)
requerimentos_diretos[is.infinite(requerimentos_diretos)] <- 0
requerimentos_diretos[is.na(requerimentos_diretos)] <- 0

# Calcula o Fator Trabalho e converte a matriz monetária
fator_t <- requerimentos_diretos # Atribuição apenas para igualar a estrutura
for (ano in 1:num_anos) {
  fator_t[ano,] <-  requerimentos_diretos[ano,]%*%leontief[ano,,]
}

m_io[, "valores", 1:num_paises_setores, 1:num_output] <-
  m_io_fonte[, 1:num_paises_setores, 1:num_output] * 
  rep(fator_t, times = num_output)

print("Fim da transformacao.")
rm(filtro, requerimentos_diretos, leontief)
gc()
