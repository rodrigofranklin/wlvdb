###################################################
# Script para transformar a WIOD em WIOD Marxista.
#
# Parâmetros necessários:
#
# M - Matriz contendo todos os dados da WIOD (incluindo trabalho e capital)
#
# LinProds - Linhas dos setores produtivos
# ColProds - Colunas dos setores produtivos
# ColFBCF - Colunas da Formação Bruta de Capital Fixo
# PaisLins - País a que pertence cada linha
# PaisCols - País a que pertence cada coluna
# LinProdutoTotal - Linha do Produto Total
# LinConsumoIntermediario - Linha do consumo intermediário
#
# LinCapital - Linha do estoque de capital
# LinLucro - Linha dos lucros
#
# LinTrabalhoAssalariado - Linha das horas trabalhadas por assalariados
# LinSalarios - Linha dos salários
# LinSalarioReal
# LinAssalariados
#
# LinTrabalho - Linha das horas trabalhadas
# LinRemuneracao - Linha da remuneração do trabalho
# LinRemuneracaoReal
# LinTrabalhadores - Linha da quantidade de trabalhadores
#
###################################################

library(matlib)

##########################################
# Calcula Coeficientes e Leontief
##########################################
  
# Aloca espaços da matriz de coeficientes técnicos
Coeficientes <- matrix(0, nrow = ncol(LinProds), ncol = ncol(ColProds))


# Calcula a matriz de coeficientes técnicos
x <- 1
y <- 1

for (X in LinProds[1,]) {
  for (Y in ColProds[1,]) {
    Coeficientes[x,y] <- ifelse (M[LinProdutoTotal,Y]==0, 0, M[X,Y]/M[LinProdutoTotal,Y])
    y <- y+1
  }
  y <- 1
  x <- x+1
}


# Calcula a matriz Leontief (falta acrescentar a depreciação)
Cols <- ncol(Coeficientes)
Leontief = solve(diag(1,nrow = Cols)-Coeficientes)

#############################
# Calcula o Fator Trabalho (o parâmetro de multiplicação de cada setor para
# o cálculo do Produto Total em Trabalho - ProdutoTotalT)
##############################
  
# Aloca espaço em matriz temporária
Trabalho = matrix(0, nrow=1,ncol=Cols)

# Calcula a relação trabalho/produto de cada setor (i.e., requerimentos diretos de trabalho)
x <- 1
for (X in ColProds[1,]) {
  Trabalho[1,x] <- ifelse(M[LinProdutoTotal,X]==0, 0 , M[LinTrabalho, X]/M[LinProdutoTotal,X])
  x <- x+1
}

# Calcula o Fator Trabalho
FatorT <- Trabalho%*%Leontief

####################################
# Calcula tudo em termos de trabalho
#####################################

MT <- matrix(0, ncol=ncol(M), nrow=nrow(M))

x <- 1
for (X in LinProds[1,]) {
    for (Y in 1:ncol(M)) MT[X,Y] <- M[X,Y]*FatorT[1,x]
  x <- x+1
}

x <- 1
for (X in ColProds[1,]) {
  MT[LinProdutoTotal,X] <- M[LinProdutoTotal,X]*FatorT[1,x]
  x <- x+1
}


####################################
# Calcula as variáveis que eu quero
#####################################
# Primeiro, aloca o espaço de todas as variáveis desejadas

Cols <- max(PaisCols[1,])

ExportacaoMPais <- matrix(0,Cols,Cols)
ExportacaoTPais <- matrix(0,Cols,Cols)
FatorD <- matrix(0,Cols,Cols)
FatorH <- matrix(0,Cols,Cols)

ProdutoTotalTPais <- matrix(0,1,Cols)
ProdutoTotalMPais <- matrix(0,1,Cols)

PIBTPais <- matrix(0,1,Cols)
PIBMPais <- matrix(0,1,Cols)

DemandaFinalTPais <- matrix(0,1,Cols)
DemandaFinalMPais <- matrix(0,1,Cols)

TrabalhadoresPais <- matrix(0,1,Cols)
RemuneracaoTPais <- matrix(0,1,Cols)
RemuneracaoMPais <- matrix(0,1,Cols)
RemuneracaoRealPais <- matrix(0,1,Cols)

JornadaTotalPais <- matrix(0,1,Cols)
AssalariadosPais <- matrix(0,1,Cols)
SalarioTPais <- matrix(0,1,Cols)
SalarioMPais <- matrix(0,1,Cols)
SalarioRealPais <- matrix(0,1,Cols)

LucroMPais <- matrix(0,1,Cols)
LucroTPais <- matrix(0,1,Cols)

CapitalMPais <- matrix(0,1,Cols)
FBCFMPais <- matrix(0,1,Cols)
FBCFTPais <- matrix(0,1,Cols)
ConsumoIntermediarioPPais <- matrix(0,1,Cols)
CapitalConstanteTotalPais <- matrix(0,1,Cols)
InsumosProdutivosPais <- matrix(0,Cols,Cols)

for (X in ColProds[1,]){
  #Produto total em horas de trabalho e em moeda (soma dos setores produtivos)
  ProdutoTotalTPais[1,PaisCols[1,X]] <- ProdutoTotalTPais[1,PaisCols[1,X]] + MT[LinProdutoTotal, X]
  ProdutoTotalMPais[1,PaisCols[1,X]] <- ProdutoTotalMPais[1,PaisCols[1,X]] + M[LinProdutoTotal, X]

  # Valor agregado total em horas de trabalho e em moeda (dos setores produtivos).
  # O valor agregado (valor novo criado) em termos de horas de trabalho consiste
  # na soma das horas trabalhadas nos setores produtivos.
  PIBTPais[1,PaisCols[1,X]] <- PIBTPais[1,PaisCols[1,X]] + M[LinTrabalho, X]
  # O valor agregado em termos de moeda consiste no produto total menos o custo intermediário.
  # Obs: é preciso deduzir também a depreciação do capital. Além disso, deveríamos somar a margem de comércio.
  PIBMPais[1,PaisCols[1,X]] <- PIBMPais[1,PaisCols[1,X]] + (M[LinProdutoTotal, X]- M[LinConsumoIntermediario, X])

  # Número de pessoas engajadas na produção e sua remuneração (nominal e real)
  TrabalhadoresPais[1,PaisCols[1,X]] <- TrabalhadoresPais[1,PaisCols[1,X]] + M[LinTrabalhadores, X]
  RemuneracaoMPais[1,PaisCols[1,X]] <- RemuneracaoMPais[1,PaisCols[1,X]] + M[LinRemuneracao, X]
  RemuneracaoRealPais[1,PaisCols[1,X]] <- RemuneracaoRealPais[1,PaisCols[1,X]] + M[LinRemuneracaoReal, X]

  # Número de trabalhadores assalariados, jornada de trabalho total e remuneração total (nominal e real)
  JornadaTotalPais[1,PaisCols[1,X]]<-JornadaTotalPais[1,PaisCols[1,X]]+M[LinTrabalhoAssalariado,X]
  AssalariadosPais[1,PaisCols[1,X]] <- AssalariadosPais[1,PaisCols[1,X]] + M[LinAssalariados, X]
  SalarioMPais[1,PaisCols[1,X]] <- SalarioMPais[1,PaisCols[1,X]] + M[LinSalarios, X]
  SalarioRealPais[1,PaisCols[1,X]] <- SalarioRealPais[1,PaisCols[1,X]] + M[LinSalarioReal, X]

  # Compensação do capital e estoque de capital
  LucroMPais[1,PaisCols[1,X]] <- LucroMPais[1,PaisCols[1,X]] + M[LinLucro, X]
  CapitalMPais[1,PaisCols[1,X]] <- CapitalMPais[1,PaisCols[1,X]] + M[LinCapital, X]

  ConsumoIntermediarioPPais[1,PaisCols[1,X]] <- ConsumoIntermediarioPPais[1,PaisCols[1,X]] + M[LinConsumoIntermediario, X]

  # Soma os consumos intermediários produtivos em variáveis temporárias (Capital constate = trabalho, insumo produtivo = moeda)
  for (Y in LinProds[1,]){
    CapitalConstanteTotalPais[1,PaisCols[1,X]] <- CapitalConstanteTotalPais[1,PaisCols[1,X]] + MT[Y, X]
    InsumosProdutivosPais[PaisLins[Y,1],PaisCols[1,X]] <- InsumosProdutivosPais[PaisLins[Y,1],PaisCols[1,X]] + M[Y, X]
  }
}


# Soma a formação bruta de capital fixo (em moeda e trabalho) e acrescenta aos insumos produtivos
for (X in ColFBCF[1,]){
  for (Y in LinProds[1,]) {
    FBCFMPais[1,PaisCols[1,X]] <- FBCFMPais[1,PaisCols[1,X]] + M[Y, X]
    FBCFTPais[1,PaisCols[1,X]] <- FBCFTPais[1,PaisCols[1,X]] + MT[Y, X]
    InsumosProdutivosPais[PaisLins[Y,1],PaisCols[1,X]] <- InsumosProdutivosPais[PaisLins[Y,1],PaisCols[1,X]] + M[Y, X]
  }
}

# Capital Constante total por pais (Para o cálculo da composição orgânica)
# Esse cálculo soma o estoque de capital (ponderado pela estrutura da formação bruta de k fixo) em horas de trabalho
CapitalConstanteTotalPais <- ((CapitalMPais/FBCFMPais)*FBCFTPais)+CapitalConstanteTotalPais


# Soma a demanda final em moeda e trabalho
for (X in ColDemandaFinal[1,]) {
  for (Y in 1:1435) {
    DemandaFinalTPais[1,PaisCols[1,X]] <- DemandaFinalTPais[1,PaisCols[1,X]] + MT[Y, X]
    DemandaFinalMPais[1,PaisCols[1,X]] <- DemandaFinalMPais[1,PaisCols[1,X]] + M[Y, X]
  }
}

# O FatorDINN corresponde à constate K de Ochoa para o cálculo dos preços diretos
FatorDINN <- ProdutoTotalTPais/ProdutoTotalMPais
# O FatorDemanda é uma espécide de constate K exclusiva para o consumo das famílias.
# Por isso, a utilizei para o cálculo do valor da força de trabalho
FatorDemanda <- DemandaFinalTPais/DemandaFinalMPais

# Calcula as rendas em trabalho de cada país usando FatorDemanda
# (das pessoas engajadas e dos trabalhadores assalariados)
for (Y in ColProds[1,]){
  RemuneracaoTPais[1,PaisCols[1,Y]]<-RemuneracaoTPais[1,PaisCols[1,Y]]+(M[LinRemuneracao,Y]*FatorDemanda[1,PaisCols[1,Y]])
  SalarioTPais[1,PaisCols[1,Y]]<-SalarioTPais[1,PaisCols[1,Y]]+(M[LinSalarios,Y]*FatorDemanda[1,PaisCols[1,Y]])
}

#Calcula saldo das transferências pelo Fator Dinheiro Mundial - DECIDI
#APRESENTAR OS SALDOS DE HORAS EXPORTADAS E IMPORTADAS, ASSIM COMO OS
#SALDOS MONETÁRIOS EXPORTADOS E IMPORTADOS.


Cols <- ncol(M)-1 # -1 para desconsiderar a coluna do produto total

#Soma todas as exportações dos setores produtivos (todos os destinos de cada linha de setor produtivo)
for (X in LinProds[1,]){
  for (Y in 1:Cols) {
    if (PaisLins[X,1] != PaisCols[1,Y]) { #ignora as transações internas de cada país
    ExportacaoMPais[PaisLins[X,1],PaisCols[1,Y]]<-ExportacaoMPais[PaisLins[X,1],PaisCols[1,Y]]+M[X,Y]
    ExportacaoTPais[PaisLins[X,1],PaisCols[1,Y]]<-ExportacaoTPais[PaisLins[X,1],PaisCols[1,Y]]+MT[X,Y]
    }
  }
}

# A importação é a transposta da exportação
ImportacaoMPais <- t(ExportacaoMPais)
ImportacaoTPais <- t(ExportacaoTPais)

# Calcula o total por país
ExpoTTotalPais <- colSums(ImportacaoTPais)
ExpoMTotalPais <- colSums(ImportacaoMPais)
ImpoTTotalPais <- colSums(ExportacaoTPais)
ImpoMTotalPais <- colSums(ExportacaoMPais)

# Calculando o saldo de transferências utilizando o fator H/$ das
# exportações do mundo todo (Novamente, um tipo de variável K específica do comércio mundial)
for (X in LinProds [1,]){
  for (Y in 1:Cols) {
    if (PaisLins[X,1] != PaisCols[1,Y]) {
      FatorD[PaisLins[X,1],PaisCols[1,Y]]<-FatorD[PaisLins[X,1],PaisCols[1,Y]]+M[X,Y]
      FatorH[PaisLins[X,1],PaisCols[1,Y]]<-FatorH[PaisLins[X,1],PaisCols[1,Y]]+MT[X,Y]
    }
  }
}

FatorSaldo <- sum(FatorH)/sum(FatorD)

TransferenciaPais <- (ExportacaoMPais*FatorSaldo)-ExportacaoTPais+ImportacaoTPais-(ImportacaoMPais*FatorSaldo)
TransferenciaPais <- t(TransferenciaPais)
TransfTotalPais <- as.matrix(colSums(TransferenciaPais))

# Composição Orgânica
# COX -> composição orgânica ponderada pelas exportações
# COI -> composição orgânica ponderada pelas importações
Y <- ncol(M)
PAISES <- ncol(ColFBCF)

Exp_Setor <- matrix(0,nrow = Y, ncol = PAISES)
Exp_Total <- matrix(0,nrow = 1, ncol = PAISES)
Imp_Setor <- matrix(0,nrow = Y, ncol = PAISES)
Imp_Total <- matrix(0,nrow = 1, ncol = PAISES)

COXK <- matrix(0,nrow = 1, ncol = PAISES)
COXT <- matrix(0,nrow = 1, ncol = PAISES)
COX <- matrix(0,nrow = 1, ncol = PAISES)

COIK <- matrix(0,nrow = 1, ncol = PAISES)
COIT <- matrix(0,nrow = 1, ncol = PAISES)
COI <- matrix(0,nrow = 1, ncol = PAISES)

#Não lembro para que isso serve...
#CORELK <- matrix(0,nrow = PAISES, ncol = PAISES)
#CORELT <- matrix(0,nrow = PAISES, ncol = PAISES)
#COREL <- matrix(0,nrow = PAISES, ncol = PAISES)

Cols <- ncol(M)-1 # -1 para desconsiderar a coluna do produto total

for (Y in LinProds[1,]) {
  for (X in 1:Cols) {
    if (PaisLins[Y,1] != PaisCols[1,X]) {
      Exp_Setor[Y,PaisLins[Y,1]] = Exp_Setor[Y,PaisLins[Y,1]] + M[Y,X]
      Exp_Total[PaisLins[Y,1]] = Exp_Total[PaisLins[Y,1]] + M[Y,X]
      Imp_Setor[Y,PaisCols[1,X]] = Imp_Setor[Y,PaisCols[1,X]] + M[Y,X]
      Imp_Total[PaisCols[1,X]] = Imp_Total[PaisCols[1,X]] + M[Y,X]
    }
  }
}

for (Y in LinProds[1,]) {
  for (X in 1:PAISES) {
    if (PaisLins[Y,1] == X) {
      # Pondera a participação do capital e do trabalho conforme a importância do setor para as exportações do país
      sigma = Exp_Setor[Y,X] / Exp_Total[X]
      COXK[1,X] = COXK[1,X] + ((M[LinCapital,Y] + M[LinConsumoIntermediario,Y]) * sigma)
      COXT[1,X] = COXT[1,X] + (M[LinTrabalho,Y] * sigma)
    } else {
      # Pondera a participação do capital e do trabalho conforme a importância do setor para as importações do país
      sigma = Imp_Setor[Y,X] / Imp_Total[X]
      COIK[1,X] = COIK[1,X] +((M[LinCapital,Y] + M[LinConsumoIntermediario,Y]) * sigma)
      COIT[1,X] = COIT[1,X] + (M[LinTrabalho,Y] * sigma)
      
#      CORELK[PaisLins[Y,1],X] = CORELK[PaisLins[Y,1],X] + ((M[LinCapital,Y] + M[LinConsumoIntermediario,Y]) * sigma)
#      CORELT[PaisLins[Y,1],X] = CORELT[PaisLins[Y,1],X] + (M[LinTrabalho,Y] * sigma)
    }
  }
}

#COREL = CORELK./CORELT

# Formatação do resultado
Resultados <- matrix(0, nrow = 28, ncol = PAISES, dimnames = list(c("","ExpoTTotalPais",
"ExpoMTotalPais","ImpoTTotalPais","ImpoMTotalPais","TransfTotalPais","ProdutoTotalTPais","ProdutoTotalMPais",
"FatorDINN","FatorDemanda","PIBTPais","PIBMPais","TrabalhadoresPais","RemuneracaoTPais","RemuneracaoMPais",
"RemuneracaoRealPais","JornadaTotalPais","AssalariadosPais","SalarioTPais","SalarioMPais","SalarioRealPais",
"LucroMPais","CapitalMPais","ConsumoIntermediarioPPais","COXK","COXT","COIK","COIT"),c("Austrália","Áustria",
"Bélgica","Bulgária","Brasil","Canadá","China","Chipre","Tchéquia","Alemanha","Dinamarca","Espanha",
"Estônia","Finlândia","França","Reino Unido","Grécia","Hungria","Indonésia","Índia","Irlanda","Itália",
"Japão","Coreia do Sul","Lituânia","Luxemburgo","Letônia","México","Malta","Países Baixos","Polônia",
"Portugal","Romênia","Federação Russa","Eslováquia","Eslovênia","Suécia","Turquia","Taiwan",
"Estados Unidos","Mundo")))
#Resultados[1,] <- 
Resultados[2,] <- ExpoTTotalPais
Resultados[3,] <- ExpoMTotalPais
Resultados[4,] <- ImpoTTotalPais
Resultados[5,] <- ImpoMTotalPais
Resultados[6,] <- TransfTotalPais
Resultados[7,] <- ProdutoTotalTPais
Resultados[8,] <- ProdutoTotalMPais
Resultados[9,] <- FatorDINN
Resultados[10,] <- FatorDemanda
Resultados[11,] <- PIBTPais
Resultados[12,] <- PIBMPais
Resultados[13,] <- TrabalhadoresPais
Resultados[14,] <- RemuneracaoTPais
Resultados[15,] <- RemuneracaoMPais
Resultados[16,] <- RemuneracaoRealPais
Resultados[17,] <- JornadaTotalPais
Resultados[18,] <- AssalariadosPais
Resultados[19,] <- SalarioTPais
Resultados[20,] <- SalarioMPais
Resultados[21,] <- SalarioRealPais
Resultados[22,] <- LucroMPais
Resultados[23,] <- CapitalMPais
Resultados[24,] <- ConsumoIntermediarioPPais
Resultados[25,] <- COXK
Resultados[26,] <- COXT
Resultados[27,] <- COIK
Resultados[28,] <- COIT
Resultados= t(Resultados)
