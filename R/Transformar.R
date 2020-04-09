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
# ColProdutoTotal - Coluna do Produto Total
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
Leontief = solve(diag(1,nrow = Cols)-Coeficientes)

#############################
# Calcula o Fator Trabalho (o parâmetro de multiplicação de cada setor para
# o cálculo do Produto Total em Trabalho - ProdutoTotalT)
##############################
  
# Aloca espaço em matriz temporária
Trabalho = matrix(0, nrow=1,ncol=Cols)

# Calcula a relação trabalho/produto de cada setor (i.e., requerimentos diretos de trabalho)
x <- 1
Num_Setores_Produtivos <- sum(Setores[,4])
for (X in ColProds) {
  Trabalho[1,x] <- ifelse(M[LinProdutoTotal,X]==0, 0 , H_EMP[X]/M[LinProdutoTotal,X])
  #Suposição para o resto do mundo: o mesmo da indonésia (19)
  if (PaisCols[X] == 41) {
    Trabalho[1,x] <- Trabalho[1,x-((41-19)*Num_Setores_Produtivos)]
    H_EMP[X] <- Trabalho[1,x] * M[LinProdutoTotal,X]
  }
  
  #Suposição para o resto do mundo: média dos países da amostra
#  if (PaisCols[X] == 41) {
#    Trabalho[1,x] <- mean(Trabalho[1,seq(x-(40*Num_Setores_Produtivos), x, by = Num_Setores_Produtivos)])
#    H_EMP[X] <- Trabalho[1,x] * M[LinProdutoTotal,X]
#  }
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


####################################
# Calcula as variáveis que eu quero
#####################################
# Primeiro, aloca o espaço de todas as variáveis desejadas

Cols <- max(PaisCols[])

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

for (X in ColProds){
  #Produto total em horas de trabalho e em moeda (soma dos setores produtivos)
  ProdutoTotalTPais[1,PaisCols[X]] <- ProdutoTotalTPais[1,PaisCols[X]] + MT[LinProdutoTotal, X]
  ProdutoTotalMPais[1,PaisCols[X]] <- ProdutoTotalMPais[1,PaisCols[X]] + M[LinProdutoTotal, X]

  # Valor agregado total em horas de trabalho e em moeda (dos setores produtivos).
  # O valor agregado (valor novo criado) em termos de horas de trabalho consiste
  # na soma das horas trabalhadas nos setores produtivos.
  PIBTPais[1,PaisCols[X]] <- PIBTPais[1,PaisCols[X]] + H_EMP[X]
  # O valor agregado em termos de moeda consiste no produto total menos o custo intermediário.
  # Obs: é preciso deduzir também a depreciação do capital. Além disso, deveríamos somar a margem de comércio.
  PIBMPais[1,PaisCols[X]] <- PIBMPais[1,PaisCols[X]] + (M[LinProdutoTotal, X]- M[LinConsumoIntermediario, X])

  # Número de pessoas engajadas na produção e sua remuneração (nominal e real)
  TrabalhadoresPais[1,PaisCols[X]] <- TrabalhadoresPais[1,PaisCols[X]] + EMP[X]
  RemuneracaoMPais[1,PaisCols[X]] <- RemuneracaoMPais[1,PaisCols[X]] + LAB_USD[X]
  RemuneracaoRealPais[1,PaisCols[X]] <- RemuneracaoRealPais[1,PaisCols[X]] + LAB_REAL[X]

  # Número de trabalhadores assalariados, jornada de trabalho total e remuneração total (nominal e real)
  JornadaTotalPais[1,PaisCols[X]] <- JornadaTotalPais[1,PaisCols[X]] + H_EMPE[X]
  AssalariadosPais[1,PaisCols[X]] <- AssalariadosPais[1,PaisCols[X]] + EMPE[X]
  SalarioMPais[1,PaisCols[X]] <- SalarioMPais[1,PaisCols[X]] + COMP_USD[X]
  SalarioRealPais[1,PaisCols[X]] <- SalarioRealPais[1,PaisCols[X]] + COMP_REAL[X]

  # Compensação do capital e estoque de capital
  LucroMPais[1,PaisCols[X]] <- LucroMPais[1,PaisCols[X]] + CAP_USD[X]
  CapitalMPais[1,PaisCols[X]] <- CapitalMPais[1,PaisCols[X]] + K_GFCF_USD[X]

  ConsumoIntermediarioPPais[1,PaisCols[X]] <- ConsumoIntermediarioPPais[1,PaisCols[X]] + M[LinConsumoIntermediario, X]

  # Soma os consumos intermediários produtivos em variáveis temporárias (Capital constate = trabalho, insumo produtivo = moeda)
  for (Y in LinProds){
    CapitalConstanteTotalPais[1,PaisCols[X]] <- CapitalConstanteTotalPais[1,PaisCols[X]] + MT[Y, X]
    InsumosProdutivosPais[PaisLins[Y],PaisCols[X]] <- InsumosProdutivosPais[PaisLins[Y],PaisCols[X]] + M[Y, X]
  }
}


# Soma a formação bruta de capital fixo (em moeda e trabalho) e acrescenta aos insumos produtivos
for (X in ColFBCF){
  for (Y in LinProds) {
    FBCFMPais[1,PaisCols[X]] <- FBCFMPais[1,PaisCols[X]] + M[Y, X]
    FBCFTPais[1,PaisCols[X]] <- FBCFTPais[1,PaisCols[X]] + MT[Y, X]
    InsumosProdutivosPais[PaisLins[Y],PaisCols[X]] <- InsumosProdutivosPais[PaisLins[Y],PaisCols[X]] + M[Y, X]
  }
}

# Capital Constante total por pais (Para o cálculo da composição orgânica)
# Esse cálculo soma o estoque de capital (ponderado pela estrutura da formação bruta de k fixo) em horas de trabalho
CapitalConstanteTotalPais <- ((CapitalMPais/FBCFMPais)*FBCFTPais)+CapitalConstanteTotalPais


# Soma a demanda final em moeda e trabalho
for (X in ColDemandaFinal) {
  for (Y in 1:1435) {
    DemandaFinalTPais[1,PaisCols[X]] <- DemandaFinalTPais[1,PaisCols[X]] + MT[Y, X]
    DemandaFinalMPais[1,PaisCols[X]] <- DemandaFinalMPais[1,PaisCols[X]] + M[Y, X]
  }
}

# O FatorDINN corresponde à constate K de Ochoa para o cálculo dos preços diretos
FatorDINN <- ProdutoTotalTPais/ProdutoTotalMPais
# O FatorDemanda é uma espécide de constate K exclusiva para o consumo das famílias.
# Por isso, a utilizei para o cálculo do valor da força de trabalho
FatorDemanda <- DemandaFinalTPais/DemandaFinalMPais

# Calcula as rendas em trabalho de cada país usando FatorDemanda
# (das pessoas engajadas e dos trabalhadores assalariados)
for (Y in ColProds){
  RemuneracaoTPais[1,PaisCols[Y]]<-RemuneracaoTPais[1,PaisCols[Y]]+(LAB_USD[Y]*FatorDemanda[1,PaisCols[Y]])
  SalarioTPais[1,PaisCols[Y]]<-SalarioTPais[1,PaisCols[Y]]+(COMP_USD[Y]*FatorDemanda[1,PaisCols[Y]])
}

#Calcula saldo das transferências pelo Fator Dinheiro Mundial - DECIDI
#APRESENTAR OS SALDOS DE HORAS EXPORTADAS E IMPORTADAS, ASSIM COMO OS
#SALDOS MONETÁRIOS EXPORTADOS E IMPORTADOS.


Cols <- ncol(M)-1 # -1 para desconsiderar a coluna do produto total

#Soma todas as exportações dos setores produtivos (todos os destinos de cada linha de setor produtivo)
for (X in LinProds){
  for (Y in 1:Cols) {
    if (PaisLins[X] != PaisCols[Y]) { #ignora as transações internas de cada país
    ExportacaoMPais[PaisLins[X],PaisCols[Y]]<-ExportacaoMPais[PaisLins[X],PaisCols[Y]]+M[X,Y]
    ExportacaoTPais[PaisLins[X],PaisCols[Y]]<-ExportacaoTPais[PaisLins[X],PaisCols[Y]]+MT[X,Y]
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
for (X in LinProds){
  for (Y in 1:Cols) {
    if (PaisLins[X] != PaisCols[Y]) {
      FatorD[PaisLins[X],PaisCols[Y]]<-FatorD[PaisLins[X],PaisCols[Y]]+M[X,Y]
      FatorH[PaisLins[X],PaisCols[Y]]<-FatorH[PaisLins[X],PaisCols[Y]]+MT[X,Y]
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

Exp_Setor <- matrix(0,nrow = Y, ncol = Num_Paises)
Exp_Total <- matrix(0,nrow = 1, ncol = Num_Paises)
Imp_Setor <- matrix(0,nrow = Y, ncol = Num_Paises)
Imp_Total <- matrix(0,nrow = 1, ncol = Num_Paises)

COXK <- matrix(0,nrow = 1, ncol = Num_Paises)
COXT <- matrix(0,nrow = 1, ncol = Num_Paises)
COX <- matrix(0,nrow = 1, ncol = Num_Paises)

COIK <- matrix(0,nrow = 1, ncol = Num_Paises)
COIT <- matrix(0,nrow = 1, ncol = Num_Paises)
COI <- matrix(0,nrow = 1, ncol = Num_Paises)

#Não lembro para que isso serve...
#CORELK <- matrix(0,nrow = Num_Paises, ncol = Num_Paises)
#CORELT <- matrix(0,nrow = Num_Paises, ncol = Num_Paises)
#COREL <- matrix(0,nrow = Num_Paises, ncol = Num_Paises)

Cols <- ncol(M)-1 # -1 para desconsiderar a coluna do produto total

for (Y in LinProds) {
  for (X in 1:Cols) {
    if (PaisLins[Y] != PaisCols[X]) {
      Exp_Setor[Y,PaisLins[Y]] = Exp_Setor[Y,PaisLins[Y]] + M[Y,X]
      Exp_Total[PaisLins[Y]] = Exp_Total[PaisLins[Y]] + M[Y,X]
      Imp_Setor[Y,PaisCols[X]] = Imp_Setor[Y,PaisCols[X]] + M[Y,X]
      Imp_Total[PaisCols[X]] = Imp_Total[PaisCols[X]] + M[Y,X]
    }
  }
}

for (Y in LinProds) {
  for (X in Paises[,2]) {
    if (PaisLins[Y] == X) {
      # Pondera a participação do capital e do trabalho conforme a importância do setor para as exportações do país
      sigma = Exp_Setor[Y,X] / Exp_Total[X]
      COXK[1,X] = COXK[1,X] + ((K_GFCF_USD[Y] + M[LinConsumoIntermediario,Y]) * sigma)
      COXT[1,X] = COXT[1,X] + (H_EMP[Y] * sigma)
    } else {
      # Pondera a participação do capital e do trabalho conforme a importância do setor para as importações do país
      sigma = Imp_Setor[Y,X] / Imp_Total[X]
      COIK[1,X] = COIK[1,X] +((K_GFCF_USD[Y] + M[LinConsumoIntermediario,Y]) * sigma)
      COIT[1,X] = COIT[1,X] + (H_EMP[Y] * sigma)
#      CORELK[PaisLins[Y],X] = CORELK[PaisLins[Y],X] + ((K_GFCF_USD[Y] + M[LinConsumoIntermediario,Y]) * sigma)
#      CORELT[PaisLins[Y],X] = CORELT[PaisLins[Y],X] + (H_EMP[Y] * sigma)
    }
  }
}

#COREL = CORELK./CORELT

# Formatação do resultado
Resultados <- matrix(0, nrow = 28, ncol = Num_Paises, dimnames = list(c("","ExpoTTotalPais",
"ExpoMTotalPais","ImpoTTotalPais","ImpoMTotalPais","TransfTotalPais","ProdutoTotalTPais","ProdutoTotalMPais",
"FatorDINN","FatorDemanda","PIBTPais","PIBMPais","TrabalhadoresPais","RemuneracaoTPais","RemuneracaoMPais",
"RemuneracaoRealPais","JornadaTotalPais","AssalariadosPais","SalarioTPais","SalarioMPais","SalarioRealPais",
"LucroMPais","CapitalMPais","ConsumoIntermediarioPPais","COXK","COXT","COIK","COIT"),Paises[,1]))
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
