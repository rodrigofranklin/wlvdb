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

library(readxl)
library(beepr)

# Lista dos países
Paises <- read.csv2(file = paste0(getwd(),"/sourcedata/Paises.csv"), row.names = 1)
Num_Paises <- dim(Paises)[1]

# Obtém a informação dos setores produtivos e prepara as variávels LinProds, ColProds e PaisLins
Setores<-read.csv2(paste0(getwd(),"/sourcedata/setores.csv"))
Num_Setores <- dim(Setores)[1]
LinProds <- NULL
PaisLins <- NULL
W=1
for (X in Paises[,2]) {
  for (Y in 1:Num_Setores){
    PaisLins <- c(PaisLins, X)
    if (Setores[Y,4]==1)  {LinProds <- c(LinProds,W)}
    W<-W+1
  }
}
LinProds <- t(LinProds)
ColProds <- LinProds
LinConsumoIntermediario <- Num_Paises*Num_Setores + 1

# Obtém informações sobre as colunas de demanda
Demanda<-read.csv2(paste0(getwd(),"/sourcedata/demanda.csv"))
Num_Demanda <- dim(Demanda)[1]
PaisCols <- PaisLins
ColFBCF <- NULL
ColDemandaFinal <- NULL
for (X in Paises[,2]) {
  ColFBCF <- c(ColFBCF, (Num_Setores*Num_Paises) + Demanda[Demanda == 'Gross fixed capital formation',3] + (Num_Demanda*(X-1)))
  ColDemandaFinal <- c(ColDemandaFinal, (Num_Setores*Num_Paises) + Demanda[Demanda == 'Final consumption expenditure by households',3] + (Num_Demanda*(X-1)))
  for (Y in 1:Num_Demanda){
    PaisCols <- c( PaisCols, X)
  }
}
ColProdutoTotal <- Num_Setores*Num_Paises + Num_Demanda*Num_Paises + 1

# Carrega as informações das contas socioeconômicas
SEA <- as.data.frame(read_xlsx(paste0(getwd(),"/sourcedata/WIOD_SEA_July14.xlsx"), sheet = "DATA", col_names = T, na = 'NA'))
SEA[is.na(SEA)] <- 0

for (Z in 1995:2009) {

  M <- readRDS(paste0(getwd(),"/sourcedata/WIOT_",as.character(Z),".rds"))
  LinProdutoTotal <- nrow(M)

  # Separa as variáveis desejadas da tabela de contas socioeconômicas
  H_EMP = H_EMPE = EMP = EMPE = COMP_REAL = LAB_REAL = K_GFCF_USD = CAP_USD = LAB_USD = COMP_USD <- array(data = 0, dim = Num_Paises*Num_Setores)
  
  Linhas_H_EMP <- which(SEA[,'Variable'] == 'H_EMP')
  Linhas_H_EMPE <- which(SEA[,'Variable'] == 'H_EMPE')
  Linhas_EMP <- which(SEA[,'Variable'] == 'EMP')
  Linhas_EMPE <- which(SEA[,'Variable'] == 'EMPE')
  Linhas_GO <- which(SEA[,'Variable'] == 'GO')
  Linhas_VA <- which(SEA[,'Variable'] == 'VA')
  Linhas_VA_P <- which(SEA[,'Variable'] == 'VA_P')
  Linhas_COMP <- which(SEA[,'Variable'] == 'COMP')
  Linhas_LAB <- which(SEA[,'Variable'] == 'LAB')
  Linhas_CAP <- which(SEA[,'Variable'] == 'CAP')
  Linhas_K_GFCF <- which(SEA[,'Variable'] == 'K_GFCF')
  Linhas_GFCF_P <- which(SEA[,'Variable'] == 'GFCF_P')

  w <- 1
  for (x in 1:(Num_Paises-1)) {
    Linhas_Pais_H_EMP <- Linhas_H_EMP[which(SEA[Linhas_H_EMP,'Country'] == as.character(Paises[x,3]))]
    Linhas_Pais_H_EMPE <- Linhas_H_EMPE[which(SEA[Linhas_H_EMPE,'Country'] == as.character(Paises[x,3]))]
    Linhas_Pais_EMP <- Linhas_EMP[which(SEA[Linhas_EMP,'Country'] == as.character(Paises[x,3]))]
    Linhas_Pais_EMPE <- Linhas_EMPE[which(SEA[Linhas_EMPE,'Country'] == as.character(Paises[x,3]))]
    Linhas_Pais_GO <- Linhas_GO[which(SEA[Linhas_GO,'Country'] == as.character(Paises[x,3]))]
    Linhas_Pais_VA <- Linhas_VA[which(SEA[Linhas_VA,'Country'] == as.character(Paises[x,3]))]
    Linhas_Pais_VA_P <- Linhas_VA_P[which(SEA[Linhas_VA_P,'Country'] == as.character(Paises[x,3]))]
    Linhas_Pais_COMP <- Linhas_COMP[which(SEA[Linhas_COMP,'Country'] == as.character(Paises[x,3]))]
    Linhas_Pais_LAB <- Linhas_LAB[which(SEA[Linhas_LAB,'Country'] == as.character(Paises[x,3]))]
    Linhas_Pais_CAP <- Linhas_CAP[which(SEA[Linhas_CAP,'Country'] == as.character(Paises[x,3]))]
    Linhas_Pais_K_GFCF <- Linhas_K_GFCF[which(SEA[Linhas_K_GFCF,'Country'] == as.character(Paises[x,3]))]
    Linhas_Pais_GFCF_P <- Linhas_GFCF_P[which(SEA[Linhas_GFCF_P,'Country'] == as.character(Paises[x,3]))]
    
    for (y in 1:Num_Setores) {
      Linhas_Setor_Pais_H_EMP <- Linhas_Pais_H_EMP[which(SEA[Linhas_Pais_H_EMP,'Code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_H_EMPE <- Linhas_Pais_H_EMPE[which(SEA[Linhas_Pais_H_EMPE,'Code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_EMP <- Linhas_Pais_EMP[which(SEA[Linhas_Pais_EMP,'Code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_EMPE <- Linhas_Pais_EMPE[which(SEA[Linhas_Pais_EMPE,'Code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_GO <- Linhas_Pais_GO[which(SEA[Linhas_Pais_GO,'Code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_VA <- Linhas_Pais_VA[which(SEA[Linhas_Pais_VA,'Code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_VA_P <- Linhas_Pais_VA_P[which(SEA[Linhas_Pais_VA_P,'Code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_COMP <- Linhas_Pais_COMP[which(SEA[Linhas_Pais_COMP,'Code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_LAB <- Linhas_Pais_LAB[which(SEA[Linhas_Pais_LAB,'Code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_CAP <- Linhas_Pais_CAP[which(SEA[Linhas_Pais_CAP,'Code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_K_GFCF <- Linhas_Pais_K_GFCF[which(SEA[Linhas_Pais_K_GFCF,'Code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_GFCF_P <- Linhas_Pais_GFCF_P[which(SEA[Linhas_Pais_GFCF_P,'Code'] == as.character(Setores[y,1]))]
      
      CAMBIO <- ifelse(as.numeric(SEA[Linhas_Setor_Pais_VA,Z-1990]) !=0,M[1441,w]/as.numeric(SEA[Linhas_Setor_Pais_VA,Z-1990]),0)
      H_EMP[w] <- as.numeric(SEA[Linhas_Setor_Pais_H_EMP,Z-1990])*1000000
      H_EMPE[w]<-as.numeric(SEA[Linhas_Setor_Pais_H_EMPE,Z-1990])*1000000
      EMP[w]<-as.numeric(SEA[Linhas_Setor_Pais_EMP,Z-1990])*1000
      EMPE[w]<-as.numeric(SEA[Linhas_Setor_Pais_EMPE,Z-1990])*1000
      COMP_REAL[w] <- as.numeric(SEA[Linhas_Setor_Pais_COMP,Z-1990])/as.numeric(SEA[Linhas_Setor_Pais_VA_P,Z-1990])*100
      LAB_REAL[w] <- as.numeric(SEA[Linhas_Setor_Pais_LAB,Z-1990])/as.numeric(SEA[Linhas_Setor_Pais_VA_P,Z-1990])*100
      K_GFCF_USD[w] <- as.numeric(SEA[Linhas_Setor_Pais_K_GFCF,Z-1990])*as.numeric(SEA[Linhas_Setor_Pais_GFCF_P,Z-1990])/100*CAMBIO
      CAP_USD[w] <- as.numeric(SEA[Linhas_Setor_Pais_CAP,Z-1990])*CAMBIO
      LAB_USD[w] <- as.numeric(SEA[Linhas_Setor_Pais_LAB,Z-1990])*CAMBIO
      COMP_USD[w] <- as.numeric(SEA[Linhas_Setor_Pais_COMP,Z-1990])*CAMBIO
      
      w <- w+1
    }
  }
  
  source(paste0(getwd(),"/R/Transformar.R"))

  saveRDS(MT, file = paste0(getwd(),"/Resultados/WIOD_HORAS_",as.character(Z),".rds"))
  write.csv2(Resultados, file = paste0(getwd(),"/Resultados/Resultados",as.character(Z),".csv"))
  write.csv2(TransferenciaPais,
             file = paste0(getwd(),"/Resultados/Transferencias",as.character(Z),".csv"),
             row.names = Paises[,1])
  beep(sound=2)
}
beep(sound=3)

