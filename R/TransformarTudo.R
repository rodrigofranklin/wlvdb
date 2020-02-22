#################################
# Script para realizar as transformações de todos os anos
#
# Utiliza as seguintes informações:
# Parametros.mat -> arquivo do matlab com os parâmetros necessários para os cálculos
# M*.mat -> arquivos com os dados WIOD. esses arquivos incluem um conjunto de linhas 
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

for (Z in 1995:2009) {
  Parametros<-readMat(paste0(getwd(),"/sourcedata/Parametros.mat"))
  LinProds <- Parametros$LinProds
  ColProds <- Parametros$ColProds
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

  source(paste0(getwd(),"/R/Transformar.R"))

  write.csv2(Resultados, file = paste0(getwd(),"/Resultados/Resultados",as.character(Z),".csv"))
  write.csv2(TransferenciaPais,
             file = paste0(getwd(),"/Resultados/Transferencias",as.character(Z),".csv"),
             row.names = c("Austrália","Áustria",
                           "Bélgica","Bulgária","Brasil","Canadá","China","Chipre","Tchéquia","Alemanha","Dinamarca","Espanha",
                           "Estônia","Finlândia","França","Reino Unido","Grécia","Hungria","Indonésia","Índia","Irlanda","Itália",
                           "Japão","Coreia do Sul","Lituânia","Luxemburgo","Letônia","México","Malta","Países Baixos","Polônia",
                           "Portugal","Romênia","Federação Russa","Eslováquia","Eslovênia","Suécia","Turquia","Taiwan",
                           "Estados Unidos","Mundo"))
  rm(list = ls())
}

