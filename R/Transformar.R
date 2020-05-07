###################################################
# Script para transformar a WIOD em WIOD Marxista.
#
# Parâmetros necessários:
#
# M - Matriz contendo todos os dados da WIOD (incluindo trabalho e capital)
#
###################################################

##########################################
# Calcula Coeficientes e Leontief
##########################################
  
# Aloca espaços da matriz de coeficientes técnicos
cols <- length(col.prods)
lins <- length(lin.prods)
Coeficientes <- matrix(0, nrow = length(lin.prods), ncol = length(col.prods))


# Calcula a matriz de coeficientes técnicos (Repare na diferença entre x,y e X,Y)
x<- seq(1,lins)
Coeficientes[x,x] <- M[col.prods,lin.prods]/matrix(M[lin.produto.total,lin.prods], nrow = cols, ncol=cols, byrow = TRUE)
Coeficientes[is.infinite(Coeficientes)] <- 0
Coeficientes[is.nan(Coeficientes)] <- 0


# Calcula a matriz Leontief (falta acrescentar a depreciação)
Leontief <- solve(diag(1,nrow = cols)-Coeficientes)

#############################
# Calcula o Fator Trabalho (o parâmetro de multiplicação de cada setor para
# o cálculo do Produto Total em Trabalho - ProdutoTotalT)
##############################
  
# Aloca espaço em matriz temporária
requerimentos_diretos <- matrix(0, nrow=1,ncol=cols)

# Calcula a relação trabalho/produto de cada setor (i.e., requerimentos diretos de trabalho)
requerimentos_diretos[1,x] <- ifelse(M[lin.produto.total,col.prods]==0, 0 , trabalho[col.prods]/M[lin.produto.total,col.prods])

# Calcula o Fator Trabalho
FatorT <- requerimentos_diretos%*%Leontief

####################################
# Calcula tudo em termos de trabalho
#####################################

MT <- matrix(0, ncol=ncol(M), nrow=nrow(M))

y<- seq(1:ncol(M))
MT[lin.prods,y] <- M[lin.prods,y]*FatorT[1,x]
MT[lin.produto.total,col.prods] <- M[lin.produto.total,col.prods]*FatorT[1,x]
