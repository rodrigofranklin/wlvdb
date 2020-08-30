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

##########################################
# Calcula coeficientes e leontief
##########################################
  
# Calcula a matriz de coeficientes técnicos

coeficientes <- m_wio[1:tamanho,1:tamanho]/producao_bruta_pm_matriz
coeficientes[is.infinite(coeficientes)] <- 0
coeficientes[is.nan(coeficientes)] <- 0

depreciacao <- m_depreciacao/producao_bruta_pm_matriz
depreciacao[is.infinite(depreciacao)] <- 0
depreciacao[is.nan(depreciacao)] <- 0

#Added depreciation matrix to Leontief's inverse calculus
# Calcula a matriz leontief
leontief <- solve(diag(tamanho)+((-coeficientes-depreciacao)*filtro_produtivo_matriz))

#############################
# Calcula o Fator Trabalho (o parâmetro de multiplicação de cada setor para
# o cálculo do Produto Total em Trabalho - ProdutoTotalT)
##############################

# Calcula a relação trabalho/produto de cada setor (i.e., requerimentos diretos de trabalho)
requerimentos_diretos <- (sea$trabalho/sea$producao_bruta_precos_mercado)*filtro_produtivo
requerimentos_diretos[is.infinite(requerimentos_diretos)] <- 0
requerimentos_diretos[is.na(requerimentos_diretos)] <- 0

# Calcula o Fator Trabalho
fator_t <- requerimentos_diretos%*%leontief

####################################
# Calcula tudo em termos de trabalho
#####################################

m_t <- matrix(0, ncol=tamanho_completo, nrow=tamanho_completo)

m_t[1:tamanho, 1:tamanho_completo] <- m_wio[1:tamanho,1:tamanho_completo]*matrix(fator_t, ncol = tamanho_completo, nrow = tamanho, byrow = FALSE)
m_t[lin_produto_total,1:tamanho] <- sea$producao_bruta_precos_mercado*fator_t
sea$producao_bruta_valores <- m_t[lin_produto_total,1:tamanho]

print("Fim da transformacao.")
