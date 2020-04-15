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
Coeficientes <- matrix(0, nrow = length(LinProds), ncol = length(ColProds))


# Calcula a matriz de coeficientes técnicos (Repare na diferença entre x,y e X,Y)
x <- 1
y <- 1
for (X in LinProds) {
  for (Y in ColProds) {
    Coeficientes[x,y] <- ifelse (M[LinProdutoTotal,Y]==0, 0, M[X,Y]/M[LinProdutoTotal,Y])
    y <- y+1
  }
  y <- 1
  x <- x+1
}


# Calcula a matriz Leontief (falta acrescentar a depreciação)
Cols <- ncol(Coeficientes)
Leontief <- solve(diag(1,nrow = Cols)-Coeficientes)

#############################
# Calcula o Fator Trabalho (o parâmetro de multiplicação de cada setor para
# o cálculo do Produto Total em Trabalho - ProdutoTotalT)
##############################
  
# Aloca espaço em matriz temporária
Trabalho <- matrix(0, nrow=1,ncol=Cols)

# Calcula a relação trabalho/produto de cada setor (i.e., requerimentos diretos de trabalho)
x <- 1
for (X in ColProds) {
  Trabalho[1,x] <- ifelse(M[LinProdutoTotal,X]==0, 0 , EMP[X]/M[LinProdutoTotal,X])
  x <- x+1
}

# Calcula o Fator Trabalho
FatorT <- Trabalho%*%Leontief

####################################
# Calcula tudo em termos de trabalho
#####################################

MT <- matrix(0, ncol=ncol(M), nrow=nrow(M))

x <- 1
for (X in LinProds) {
    for (Y in 1:ncol(M)) MT[X,Y] <- M[X,Y]*FatorT[1,x]
  x <- x+1
}

x <- 1
for (X in ColProds) {
  MT[LinProdutoTotal,X] <- M[LinProdutoTotal,X]*FatorT[1,x]
  x <- x+1
}
