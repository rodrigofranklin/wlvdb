###################################################
# Script para transformar a WIOD em WIOD Marxista.
#
# Parâmetros necessários:
#
# m.wio - matriz contendo todos os dados da WIOD (incluindo trabalho e capital)
#
###################################################

##########################################
# Calcula coeficientes e leontief
##########################################
  
# Calcula a matriz de coeficientes técnicos

coeficientes <- m.wio[1:tamanho,1:tamanho]/produto_bruto_matriz
coeficientes[is.infinite(coeficientes)] <- 0
coeficientes[is.nan(coeficientes)] <- 0

#Loads depreciation matrix Carga la matriz de depreciacion
source("R/depreciacao.R")

#Added depreciation matrix to Leontief's inverse calculus
# Calcula a matriz leontief
leontief <- solve(diag(tamanho)+((-coeficientes-depreciacao)*filtro_produtivo_matriz))

#############################
# Calcula o Fator Trabalho (o parâmetro de multiplicação de cada setor para
# o cálculo do Produto Total em Trabalho - ProdutoTotalT)
##############################

# Calcula a relação trabalho/produto de cada setor (i.e., requerimentos diretos de trabalho)
requerimentos_diretos <- (trabalho/m.wio[lin.produto.total,1:tamanho])*filtro_produtivo

# Calcula o Fator Trabalho
fator.t <- requerimentos_diretos%*%leontief

####################################
# Calcula tudo em termos de trabalho
#####################################

m.t <- matrix(0, ncol=tamanho_completo, nrow=tamanho_completo)

m.t[1:tamanho, 1:tamanho_completo] <- m.wio[1:tamanho,1:tamanho_completo]*matrix(fator.t, ncol = tamanho_completo, nrow = tamanho, byrow = FALSE)
m.t[lin.produto.total,1:tamanho] <- m.wio[lin.produto.total,1:tamanho]*fator.t
