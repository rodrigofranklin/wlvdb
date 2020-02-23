#################################
# Script para realizar as transformações de todos os anos
#
# Utiliza as seguintes informações:
# Parametros.mat -> arquivo do matlab com os parâmetros necessários para os cálculos
# WIOD_*.csv -> arquivos com os dados WIOD. esses arquivos incluem um conjunto de linhas 
# em seu final contendo:
# - horas trabalhadas por pessoa engajada na produção (H_EMP*1000000),
# - horas trabalhadas pelos trabalhadores assalariados (H_EMPE*1000000),
# - Câmbio (essa variável não é utiliza nestas rotinas) (calculado a partir do valor agregado),
# - salários nominais (em US$) (COMP*Câmbio),
# - compensação nominal pelo trabalho (de todas as pessoas engajadas) (US$) (LAB*Câmbio),
# - compensação pelo capital (i.e., lucro) (CAP*Câmbio),
# - estoque de capital (K_GFCF*GFCF_P/100*Câmbio),
# - a quantidade de trabalhadores engajados na produção (EMP*1000),
# - quantidade de trabalhadores assalariados (EMPE*1000),
# - salários reais (COMP/VA_P*100),
# - compensação real pelo trabalho (LAB/VA_P*100).
# Todos esses dados foram incorporados a partir da tabela de contas
# socioeconômicas (versão 2014).
#
################################


library(R.matlab)
library(beepr)

for (Z in 1995:2009) {

  # Lista dos países
  Paises <- read.csv2(file = paste0(getwd(),"/sourcedata/Paises.csv"), row.names = 1)
  Num_Paises <- length(Paises[,2])
  
  # Obtém a informação dos setores produtivos e prepara as variávels LinProds e ColProds
  setores<-read.csv2(paste0(getwd(),"/sourcedata/setores.csv"))
  LinProds = NULL
  W=1
  for (X in Paises[,2]) {
    for (Y in 1:dim(setores)[1]){
      if (setores[Y,4]==1)  {LinProds <- c(LinProds,W)}
      W<-W+1
    }
  }
  ColProds <- LinProds
  
  Parametros<-readMat(paste0(getwd(),"/sourcedata/Parametros.mat"))
#  LinProds <- Parametros$LinProds
#  ColProds <- Parametros$ColProds
  ColFBCF <- Parametros$ColFBCF
  ColDemanda <- Parametros$ColDemanda
  ColDemandaFinal <- Parametros$ColDemandaFinal
  PaisLins <- Parametros$PaisLins
  PaisCols <- Parametros$PaisCols
  LinProdutoTotal <- Parametros$LinProdutoTotal
  LinConsumoIntermediario <- Parametros$LinConsumoIntermediario
  LinCapital <- Parametros$LinCapital
  LinLucro <- Parametros$LinLucro
  LinTrabalhoAssalariado <- Parametros$LinTrabalhoAssalariado
  LinSalarios <- Parametros$LinSalarios
  LinSalarioReal <- Parametros$LinSalarioReal
  LinAssalariados <- Parametros$LinAssalariados
  LinTrabalho <- Parametros$LinTrabalho
  LinRemuneracao <- Parametros$LinRemuneracao
  LinRemuneracaoReal <- Parametros$LinRemuneracaoReal
  LinTrabalhadores <- Parametros$LinTrabalhadores
  
  M <-readMat(paste0(getwd(),"/sourcedata/M",as.character(Z),".mat"))[[1]]
# Tentei converter os arquivos de Matlab para ".csv", mas fica dando erro...
#  M <- as.matrix(read.csv2(file = paste0(getwd(),"/sourcedata/WIOD_",as.character(Z),".csv"), row.names = 1))
  
  source(paste0(getwd(),"/R/Transformar.R"))

  write.csv2(MT, file = paste0(getwd(),"/Resultados/WIOD_HORAS_",as.character(Z),".csv"))
  write.csv2(Resultados, file = paste0(getwd(),"/Resultados/Resultados",as.character(Z),".csv"))
  write.csv2(TransferenciaPais,
             file = paste0(getwd(),"/Resultados/Transferencias",as.character(Z),".csv"),
             row.names = Paises[,1])
  rm(list = ls())
  beep(sound=2)
}
beep(sound=3)
