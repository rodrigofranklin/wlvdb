##Variáveis básicas e análise


####################################
# Calcula as variáveis que eu quero
#####################################
# Primeiro, aloca o espaço de todas as variáveis desejadas

Cols <- max(pais.cols[])

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


prop_demanda_familias <- as.data.frame(prop.table(m.wio[1:tamanho,col.demanda.final], margin = 2))
prop_demanda_familias <- as.matrix(prop_demanda_familias[rep(names(prop_demanda_familias), each = num.setores)])
cesta_consumo <- (matrix(lab.usd, ncol = tamanho, nrow = tamanho, byrow = TRUE)*prop_demanda_familias)
cesta_consumo[is.infinite(cesta_consumo)] <- 0
cesta_consumo[is.nan(cesta_consumo)] <- 0

valor_forca_trabalho <- colSums(cesta_consumo*matrix(fator.t, ncol = tamanho, nrow = tamanho, byrow = FALSE))
taxa_exploracao <- (trabalho/valor_forca_trabalho) - 1 
taxa_exploracao_pais <- tapply(trabalho, pais.lins, sum, na.rm = TRUE)/tapply(valor_forca_trabalho, pais.lins, sum, na.rm = TRUE) -1
taxa_exploracao_media_mundo <- c(taxa_exploracao_media_mundo, sum(trabalho)/sum(valor_forca_trabalho))
taxa_exploracao_pais_produtivos <-  tapply(trabalho, pais.lins*filtro_produtivo, sum, na.rm = TRUE)/tapply(valor_forca_trabalho, pais.lins*filtro_produtivo, sum, na.rm = TRUE) -1

for (X in 1:num.paises){
  #Produto total em horas de trabalho e em moeda (soma dos setores produtivos)
  x <- col.prods[which(pais.cols[col.prods]==X)]
  ProdutoTotalTPais[X] <- sum(m.t[lin.produto.total,x])
  ProdutoTotalMPais[X] <- sum(m.wio[lin.produto.total, x])
  
  # Valor agregado total em horas de trabalho e em moeda (dos setores produtivos).
  # O valor agregado (valor novo criado) em termos de horas de trabalho consiste
  # na soma das horas trabalhadas nos setores produtivos.
  PIBTPais[X] <- sum(trabalho[x])
  # O valor agregado em termos de moeda consiste no produto total menos o custo intermediário.
  # Obs: é preciso deduzir também a depreciação do capital. Além disso, deveríamos somar a margem de comércio.
  PIBMPais[X] <- sum(m.wio[lin.produto.total, x]- m.wio[lin.consumo.intermediario, x])
  
  # Número de pessoas engajadas na produção e sua remuneração (nominal e real)
  TrabalhadoresPais[X] <- sum(emp[x])
  RemuneracaoMPais[X] <- sum(lab.usd[x])
  RemuneracaoRealPais[X] <- sum(lab.real[x])
  
  # Número de trabalhadores assalariados, jornada de trabalho total e remuneração total (nominal e real)
  JornadaTotalPais[X] <- sum(h.empe[x])
  AssalariadosPais[X] <- sum(empe[x])
  SalarioMPais[X] <- sum(comp.usd[x])
  SalarioRealPais[X] <- sum(comp.real[x])
  
  # Compensação do capital e estoque de capital
  LucroMPais[X] <- sum(cap.usd[x])
  CapitalMPais[X] <- sum(k.usd[x])
  
  ConsumoIntermediarioPPais[X] <- sum(m.wio[lin.consumo.intermediario, x])
                                        
  # Soma os consumos intermediários produtivos em variáveis temporárias (Capital constate = trabalho, insumo produtivo = moeda)
  CapitalConstanteTotalPais[X] <- sum(m.t[lin.prods, x])

  # Soma a formação bruta de capital fixo (em moeda e trabalho) e acrescenta aos insumos produtivos
  xFBCF <- col.fbcf[which(pais.cols[col.fbcf]==X)]
  FBCFMPais[X] <- sum(m.wio[lin.prods, xFBCF])
  FBCFTPais[X] <- sum(m.t[lin.prods, xFBCF])

  for (Y in 1:num.paises) {
    y <- lin.prods[which(pais.lins[lin.prods]==Y)]
    InsumosProdutivosPais[Y,X] <- sum(m.wio[y, x], m.wio[y,xFBCF])

    #Soma todas as exportações dos setores produtivos (todos os destinos de cada linha de setor produtivo)
    if (X != Y) { #ignora as transações internas de cada país
      ExportacaoMPais[Y,X]<- sum(m.wio[y,which(pais.cols==X)])
      ExportacaoTPais[Y,X]<- sum(m.t[y,which(pais.cols==X)])
    }
  }

  # Soma a demanda final em moeda e trabalho
  xDemandaFinal <- col.demanda.final[which(pais.cols[col.demanda.final]==X)]
  DemandaFinalTPais[X] <- sum(m.t[1:tamanho, xDemandaFinal])
  DemandaFinalMPais[X] <- sum(m.wio[1:tamanho, xDemandaFinal])

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
  RemuneracaoTPais[X]<- sum(lab.usd[x])*FatorDemanda[X]
  SalarioTPais[X]<- sum(comp.usd[x])*FatorDemanda[X]
}

#Calcula saldo das transferências pelo Fator Dinheiro Mundial - DECIDI
#APRESENTAR OS SALDOS DE HORAS EXPORTADAS E IMPORTADAS, ASSIM COMO OS
#SALDOS MONETÁRIOS EXPORTADOS E IMPORTADOS.

# A importação é a transposta da exportação
ImportacaoMPais <- t(ExportacaoMPais)
ImportacaoTPais <- t(ExportacaoTPais)

# Calcula o total por país
ExpoTTotalPais <- colSums(ImportacaoTPais)
Expom.totalPais <- colSums(ImportacaoMPais)
ImpoTTotalPais <- colSums(ExportacaoTPais)
Impom.totalPais <- colSums(ExportacaoMPais)

# Calculando o saldo de transferências utilizando o fator H/$ das
# exportações do mundo todo (Novamente, um tipo de variável K específica do comércio mundial)
FatorSaldo <- sum(ExportacaoTPais)/sum(ExportacaoMPais)

TransferenciaPais <- (ExportacaoMPais*FatorSaldo)-ExportacaoTPais+ImportacaoTPais-(ImportacaoMPais*FatorSaldo)
TransferenciaPais <- t(TransferenciaPais)
TransfTotalPais <- as.matrix(colSums(TransferenciaPais))

# Composição Orgânica
# COX -> composição orgânica ponderada pelas exportações
# COI -> composição orgânica ponderada pelas importações
Y <- ncol(m.wio)

Exp_Setor <- matrix(0,nrow = Y, ncol = num.paises)
Exp_Total <- matrix(0,nrow = 1, ncol = num.paises)
Imp_Setor <- matrix(0,nrow = Y, ncol = num.paises)
Imp_Total <- matrix(0,nrow = 1, ncol = num.paises)

COXK <- matrix(0,nrow = 1, ncol = num.paises)
COXT <- matrix(0,nrow = 1, ncol = num.paises)
COX <- matrix(0,nrow = 1, ncol = num.paises)

COIK <- matrix(0,nrow = 1, ncol = num.paises)
COIT <- matrix(0,nrow = 1, ncol = num.paises)
COI <- matrix(0,nrow = 1, ncol = num.paises)

#Não lembro para que isso serve...
#CORELK <- matrix(0,nrow = num.paises, ncol = num.paises)
#CORELT <- matrix(0,nrow = num.paises, ncol = num.paises)
#COREL <- matrix(0,nrow = num.paises, ncol = num.paises)

#Cols <- ncol(M)-1 # -1 para desconsiderar a coluna do produto total

#for (Y in lin.prods) {
#  for (X in 1:Cols) {
#    if (pais.lins[Y] != pais.cols[X]) {
#      Exp_Setor[Y,pais.lins[Y]] = Exp_Setor[Y,pais.lins[Y]] + m.wio[Y,X]
#      Exp_Total[pais.lins[Y]] = Exp_Total[pais.lins[Y]] + m.wio[Y,X]
#      Imp_Setor[Y,pais.cols[X]] = Imp_Setor[Y,pais.cols[X]] + m.wio[Y,X]
#      Imp_Total[pais.cols[X]] = Imp_Total[pais.cols[X]] + m.wio[Y,X]
#    }
#  }
#}

#for (Y in lin.prods) {
#  for (X in paises[,2]) {
#    if (pais.lins[Y] == X) {
#      # Pondera a participação do capital e do trabalho conforme a importância do setor para as exportações do país
#      sigma = Exp_Setor[Y,X] / Exp_Total[X]
#      COXK[1,X] = COXK[1,X] + ((k.usd[Y] + m.wio[lin.consumo.intermediario,Y]) * sigma)
#      COXT[1,X] = COXT[1,X] + (h.emp[Y] * sigma)
#    } else {
#      # Pondera a participação do capital e do trabalho conforme a importância do setor para as importações do país
#      sigma = Imp_Setor[Y,X] / Imp_Total[X]
#     COIK[1,X] = COIK[1,X] +((k.usd[Y] + m.wio[lin.consumo.intermediario,Y]) * sigma)
#      COIT[1,X] = COIT[1,X] + (h.emp[Y] * sigma)
#      #      CORELK[pais.lins[Y],X] = CORELK[pais.lins[Y],X] + ((k.usd[Y] + m.wio[lin.consumo.intermediario,Y]) * sigma)
#      #      CORELT[pais.lins[Y],X] = CORELT[pais.lins[Y],X] + (h.emp[Y] * sigma)
#    }
#  }
#}

#COREL = CORELK./CORELT

# Formatação do resultado
Resultados <- matrix(0, nrow = 28, ncol = num.paises, dimnames = list(c("Tx_Exploracao","ExpoTTotalPais",
                                                                        "Expom.totalPais","ImpoTTotalPais","Impom.totalPais","TransfTotalPais","ProdutoTotalTPais","ProdutoTotalMPais",
                                                                        "FatorDINN","FatorDemanda","PIBTPais","PIBMPais","TrabalhadoresPais","RemuneracaoTPais","RemuneracaoMPais",
                                                                        "RemuneracaoRealPais","JornadaTotalPais","AssalariadosPais","SalarioTPais","SalarioMPais","SalarioRealPais",
                                                                        "LucroMPais","CapitalMPais","ConsumoIntermediarioPPais","taxa_exploracao_pais_produtivos","COXT","COIK","COIT"),paises[,1]))
Resultados[1,] <- taxa_exploracao_pais
Resultados[2,] <- ExpoTTotalPais
Resultados[3,] <- Expom.totalPais
Resultados[4,] <- ImpoTTotalPais
Resultados[5,] <- Impom.totalPais
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
Resultados[25,] <- taxa_exploracao_pais_produtivos[2:(num.paises+1)]
Resultados[26,] <- COXT
Resultados[27,] <- COIK
Resultados[28,] <- COIT
Resultados= t(Resultados)
