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
  
# Aloca espaços da matriz de coeficientes técnicos
cols <- length(col.prods)
lins <- length(lin.prods)
coeficientes <- matrix(0, nrow = length(lin.prods), ncol = length(col.prods))


# Calcula a matriz de coeficientes técnicos
x<- seq(1,lins)
coeficientes[x,x] <- m.wio[col.prods,lin.prods]/matrix(m.wio[lin.produto.total,lin.prods], nrow = cols, ncol=cols, byrow = TRUE)
coeficientes[is.infinite(coeficientes)] <- 0
coeficientes[is.nan(coeficientes)] <- 0

#Loads depreciation matrix Carga la matriz de depreciacion
source("R/depreciacao.R")

#Added depreciation matrix to Leontief's inverse calculus
# Calcula a matriz leontief
leontief <- solve(diag(1,nrow = cols)-coeficientes-depreciacao)

#############################
# Calcula o Fator Trabalho (o parâmetro de multiplicação de cada setor para
# o cálculo do Produto Total em Trabalho - ProdutoTotalT)
##############################
  
# Aloca espaço em matriz temporária
requerimentos_diretos <- matrix(0, nrow=1,ncol=cols)

# Calcula a relação trabalho/produto de cada setor (i.e., requerimentos diretos de trabalho)
requerimentos_diretos[1,x] <- ifelse(m.wio[lin.produto.total,col.prods]==0, 0 , trabalho[col.prods]/m.wio[lin.produto.total,col.prods])

# Calcula o Fator Trabalho
fator.t <- requerimentos_diretos%*%leontief

####################################
# Calcula tudo em termos de trabalho
#####################################

m.t <- matrix(0, ncol=ncol(m.wio), nrow=nrow(m.wio))

y<- seq(1:ncol(m.wio))
m.t[lin.prods,y] <- m.wio[lin.prods,y]*fator.t[1,x]
m.t[lin.produto.total,col.prods] <- m.wio[lin.produto.total,col.prods]*fator.t[1,x]
