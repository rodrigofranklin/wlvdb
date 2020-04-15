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
Cols <- length(ColProds)
Lins <- length(LinProds)
Coeficientes <- matrix(0, nrow = length(LinProds), ncol = length(ColProds))


# Calcula a matriz de coeficientes técnicos (Repare na diferença entre x,y e X,Y)
x<- seq(1,Lins)
Coeficientes[x,x] <- M[ColProds,LinProds]/matrix(M[LinProdutoTotal,LinProds], nrow = Cols, ncol=Cols, byrow = TRUE)
Coeficientes[is.infinite(Coeficientes)] <- 0
Coeficientes[is.nan(Coeficientes)] <- 0


# Calcula a matriz Leontief (falta acrescentar a depreciação)
Leontief <- solve(diag(1,nrow = Cols)-Coeficientes)

#############################
# Calcula o Fator Trabalho (o parâmetro de multiplicação de cada setor para
# o cálculo do Produto Total em Trabalho - ProdutoTotalT)
##############################
  
# Aloca espaço em matriz temporária
Trabalho <- matrix(0, nrow=1,ncol=Cols)

# Calcula a relação trabalho/produto de cada setor (i.e., requerimentos diretos de trabalho)
Trabalho[1,x] <- ifelse(M[LinProdutoTotal,ColProds]==0, 0 , EMP[ColProds]/M[LinProdutoTotal,ColProds])

# Calcula o Fator Trabalho
FatorT <- Trabalho%*%Leontief

####################################
# Calcula tudo em termos de trabalho
#####################################

MT <- matrix(0, ncol=ncol(M), nrow=nrow(M))

y<- seq(1:ncol(M))
MT[LinProds,y] <- M[LinProds,y]*FatorT[1,x]
MT[LinProdutoTotal,ColProds] <- M[LinProdutoTotal,ColProds]*FatorT[1,x]
