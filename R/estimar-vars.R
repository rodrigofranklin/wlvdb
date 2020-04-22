##Variáveis básicas e análise


####################################
# Calcula as variáveis que eu quero
#####################################
# Primeiro, aloca o espaço de todas as variáveis desejadas

Cols <- max(PaisCols[])

ExportacaoMPais <- matrix(0,Cols,Cols)
ExportacaoTPais <- matrix(0,Cols,Cols)

FatorDINN = ProdutoTotalMPais = ProdutoTotalTPais <- matrix(0,1,Cols)

PIBTPais <- matrix(0,1,Cols)
PIBMPais <- matrix(0,1,Cols)

FatorDemanda = DemandaFinalTPais <- matrix(0,1,Cols)
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

for (X in 1:Num_Paises){
  #Produto total em horas de trabalho e em moeda (soma dos setores produtivos)
  x <- ColProds[which(PaisCols[ColProds]==X)]
  ProdutoTotalTPais[X] <- sum(MT[LinProdutoTotal,x])
  ProdutoTotalMPais[X] <- sum(M[LinProdutoTotal, x])
  
  # Valor agregado total em horas de trabalho e em moeda (dos setores produtivos).
  # O valor agregado (valor novo criado) em termos de horas de trabalho consiste
  # na soma das horas trabalhadas nos setores produtivos.
  PIBTPais[X] <- sum(trabalho[x])
  # O valor agregado em termos de moeda consiste no produto total menos o custo intermediário.
  # Obs: é preciso deduzir também a depreciação do capital. Além disso, deveríamos somar a margem de comércio.
  PIBMPais[X] <- sum(M[LinProdutoTotal, x]- M[LinConsumoIntermediario, x])
  
  # Número de pessoas engajadas na produção e sua remuneração (nominal e real)
  TrabalhadoresPais[X] <- sum(EMP[x])
  RemuneracaoMPais[X] <- sum(LAB_USD[x])
  RemuneracaoRealPais[X] <- sum(LAB_REAL[x])
  
  # Número de trabalhadores assalariados, jornada de trabalho total e remuneração total (nominal e real)
  JornadaTotalPais[X] <- sum(H_EMPE[x])
  AssalariadosPais[X] <- sum(EMPE[x])
  SalarioMPais[X] <- sum(COMP_USD[x])
  SalarioRealPais[X] <- sum(COMP_REAL[x])
  
  # Compensação do capital e estoque de capital
  LucroMPais[X] <- sum(CAP_USD[x])
  CapitalMPais[X] <- sum(K_USD[x])
  
  ConsumoIntermediarioPPais[X] <- sum(M[LinConsumoIntermediario, x])
                                        
  # Soma os consumos intermediários produtivos em variáveis temporárias (Capital constate = trabalho, insumo produtivo = moeda)
  CapitalConstanteTotalPais[X] <- sum(MT[LinProds, x])

  # Soma a formação bruta de capital fixo (em moeda e trabalho) e acrescenta aos insumos produtivos
  xFBCF <- ColFBCF[which(PaisCols[ColFBCF]==X)]
  FBCFMPais[X] <- sum(M[LinProds, xFBCF])
  FBCFTPais[X] <- sum(MT[LinProds, xFBCF])

  for (Y in 1:Num_Paises) {
    y <- LinProds[which(PaisLins[LinProds]==Y)]
    InsumosProdutivosPais[Y,X] <- sum(M[y, x], M[y,xFBCF])

    #Soma todas as exportações dos setores produtivos (todos os destinos de cada linha de setor produtivo)
    if (X != Y) { #ignora as transações internas de cada país
      ExportacaoMPais[Y,X]<- sum(M[y,which(PaisCols==X)])
      ExportacaoTPais[Y,X]<- sum(MT[y,which(PaisCols==X)])
    }
  }

  # Soma a demanda final em moeda e trabalho
  xDemandaFinal <- ColDemandaFinal[which(PaisCols[ColDemandaFinal]==X)]
  DemandaFinalTPais[X] <- sum(MT[1:tamanho, xDemandaFinal])
  DemandaFinalMPais[X] <- sum(M[1:tamanho, xDemandaFinal])

  # Capital Constante total por pais (Para o cálculo da composição orgânica)
  # Esse cálculo soma o estoque de capital (ponderado pela estrutura da formação bruta de k fixo) em horas de trabalho
  CapitalConstanteTotalPais[X] <- ((CapitalMPais[X]/FBCFMPais[X])*FBCFTPais[X])+CapitalConstanteTotalPais[X]
  
  # O FatorDINN corresponde à constate K de Ochoa para o cálculo dos preços diretos
  FatorDINN[X] <- ProdutoTotalTPais[X]/ProdutoTotalMPais[X]
  # O FatorDemanda é uma espécide de constate K exclusiva para o consumo das famílias.
  # Por isso, a utilizei para o cálculo do valor da força de trabalho
  FatorDemanda[X] <- DemandaFinalTPais[X]/DemandaFinalMPais[X]
  
  # Calcula as rendas em trabalho de cada país usando FatorDemanda
  # (das pessoas engajadas e dos trabalhadores assalariados)
  RemuneracaoTPais[X]<- sum(LAB_USD[x])*FatorDemanda[X]
  SalarioTPais[X]<- sum(COMP_USD[x])*FatorDemanda[X]
}

#Calcula saldo das transferências pelo Fator Dinheiro Mundial - DECIDI
#APRESENTAR OS SALDOS DE HORAS EXPORTADAS E IMPORTADAS, ASSIM COMO OS
#SALDOS MONETÁRIOS EXPORTADOS E IMPORTADOS.

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
FatorSaldo <- sum(ExportacaoTPais)/sum(ExportacaoMPais)

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

#Cols <- ncol(M)-1 # -1 para desconsiderar a coluna do produto total

#for (Y in LinProds) {
#  for (X in 1:Cols) {
#    if (PaisLins[Y] != PaisCols[X]) {
#      Exp_Setor[Y,PaisLins[Y]] = Exp_Setor[Y,PaisLins[Y]] + M[Y,X]
#      Exp_Total[PaisLins[Y]] = Exp_Total[PaisLins[Y]] + M[Y,X]
#      Imp_Setor[Y,PaisCols[X]] = Imp_Setor[Y,PaisCols[X]] + M[Y,X]
#      Imp_Total[PaisCols[X]] = Imp_Total[PaisCols[X]] + M[Y,X]
#    }
#  }
#}

#for (Y in LinProds) {
#  for (X in Paises[,2]) {
#    if (PaisLins[Y] == X) {
#      # Pondera a participação do capital e do trabalho conforme a importância do setor para as exportações do país
#      sigma = Exp_Setor[Y,X] / Exp_Total[X]
#      COXK[1,X] = COXK[1,X] + ((K_USD[Y] + M[LinConsumoIntermediario,Y]) * sigma)
#      COXT[1,X] = COXT[1,X] + (H_EMP[Y] * sigma)
#    } else {
#      # Pondera a participação do capital e do trabalho conforme a importância do setor para as importações do país
#      sigma = Imp_Setor[Y,X] / Imp_Total[X]
#     COIK[1,X] = COIK[1,X] +((K_USD[Y] + M[LinConsumoIntermediario,Y]) * sigma)
#      COIT[1,X] = COIT[1,X] + (H_EMP[Y] * sigma)
#      #      CORELK[PaisLins[Y],X] = CORELK[PaisLins[Y],X] + ((K_USD[Y] + M[LinConsumoIntermediario,Y]) * sigma)
#      #      CORELT[PaisLins[Y],X] = CORELT[PaisLins[Y],X] + (H_EMP[Y] * sigma)
#    }
#  }
#}

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
