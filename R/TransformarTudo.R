#################################
# Script para realizar as transformações de todos os anos
#
################################

library(readxl)
library(beepr)

# Define a versão do WIOD que será utilizada: July14 ou Nov16
#VERSAO <- 'July14'
VERSAO <- 'Nov16'

#Paises y sectores - Inicialmente LinProds ColProds PaisLins pasado a módulo propio
source('R/sectorespaises.R')


# Obtém informações sobre as colunas de demanda
Demanda<-read.csv2(paste0(getwd(),"/sourcedata/",VERSAO,"/demanda.csv"))
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
source("R/importar_sea.R")

# Carrega as informações da estimativa do EMP do RoW
ROW_EMP <- as.data.frame(read_xlsx(paste0(getwd(),"/sourcedata/ROW_EMP/Emprego_ROW.xlsx"), sheet = "DATA", col_names = T))

for (Z in Anos) {

  #Carrega a matriz insumo-produto multirregional
  if (VERSAO == "July14") {
    M <- readRDS(paste0(getwd(),"/sourcedata/",VERSAO,"/WIOT_",as.character(Z),".rds"))
    LinProdutoTotal <- nrow(M)
    LinVA <- 1441
  } else {
    load(paste0(getwd(),"/sourcedata/Nov16/WIOT",as.character(Z),"_October16_ROW.RData"))
    M <- as.matrix(wiot[,6:ncol(wiot)])
    LinProdutoTotal <- which(wiot[,'IndustryCode'] == 'GO')
    LinVA <- which(wiot[,'IndustryCode'] == 'VA')
  }
  
  # Separa as variáveis desejadas da tabela de contas socioeconômicas
  H_EMP = H_EMPE = EMP = EMPE = COMP_REAL = LAB_REAL = K_USD = CAP_USD = LAB_USD = COMP_USD <- array(data = 0, dim = Num_Paises*Num_Setores)
  w <- 1
  for (x in 1:(Num_Paises-1)) {
    Linhas_Pais_H_EMP <- Linhas_H_EMP[which(SEA[Linhas_H_EMP,'country'] == as.character(Paises[x,3]))]
    Linhas_Pais_H_EMPE <- Linhas_H_EMPE[which(SEA[Linhas_H_EMPE,'country'] == as.character(Paises[x,3]))]
    Linhas_Pais_EMP <- Linhas_EMP[which(SEA[Linhas_EMP,'country'] == as.character(Paises[x,3]))]
    Linhas_Pais_EMPE <- Linhas_EMPE[which(SEA[Linhas_EMPE,'country'] == as.character(Paises[x,3]))]
    Linhas_Pais_GO <- Linhas_GO[which(SEA[Linhas_GO,'country'] == as.character(Paises[x,3]))]
    Linhas_Pais_VA <- Linhas_VA[which(SEA[Linhas_VA,'country'] == as.character(Paises[x,3]))]
    Linhas_Pais_VA_P <- Linhas_VA_P[which(SEA[Linhas_VA_P,'country'] == as.character(Paises[x,3]))]
    Linhas_Pais_COMP <- Linhas_COMP[which(SEA[Linhas_COMP,'country'] == as.character(Paises[x,3]))]
    Linhas_Pais_LAB <- Linhas_LAB[which(SEA[Linhas_LAB,'country'] == as.character(Paises[x,3]))]
    Linhas_Pais_CAP <- Linhas_CAP[which(SEA[Linhas_CAP,'country'] == as.character(Paises[x,3]))]
    Linhas_Pais_K_GFCF <- Linhas_K_GFCF[which(SEA[Linhas_K_GFCF,'country'] == as.character(Paises[x,3]))]
    Linhas_Pais_GFCF_P <- Linhas_GFCF_P[which(SEA[Linhas_GFCF_P,'country'] == as.character(Paises[x,3]))]
    Linhas_Pais_K <- Linhas_K[which(SEA[Linhas_K,'country'] == as.character(Paises[x,3]))]
    
    for (y in 1:Num_Setores) {
      Linhas_Setor_Pais_H_EMP <- Linhas_Pais_H_EMP[which(SEA[Linhas_Pais_H_EMP,'code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_H_EMPE <- Linhas_Pais_H_EMPE[which(SEA[Linhas_Pais_H_EMPE,'code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_EMP <- Linhas_Pais_EMP[which(SEA[Linhas_Pais_EMP,'code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_EMPE <- Linhas_Pais_EMPE[which(SEA[Linhas_Pais_EMPE,'code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_GO <- Linhas_Pais_GO[which(SEA[Linhas_Pais_GO,'code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_VA <- Linhas_Pais_VA[which(SEA[Linhas_Pais_VA,'code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_VA_P <- Linhas_Pais_VA_P[which(SEA[Linhas_Pais_VA_P,'code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_COMP <- Linhas_Pais_COMP[which(SEA[Linhas_Pais_COMP,'code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_LAB <- Linhas_Pais_LAB[which(SEA[Linhas_Pais_LAB,'code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_CAP <- Linhas_Pais_CAP[which(SEA[Linhas_Pais_CAP,'code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_K_GFCF <- Linhas_Pais_K_GFCF[which(SEA[Linhas_Pais_K_GFCF,'code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_GFCF_P <- Linhas_Pais_GFCF_P[which(SEA[Linhas_Pais_GFCF_P,'code'] == as.character(Setores[y,1]))]
      Linhas_Setor_Pais_K <- Linhas_Pais_K[which(SEA[Linhas_Pais_K,'code'] == as.character(Setores[y,1]))]
      
      CAMBIO <- ifelse(as.numeric(SEA[Linhas_Setor_Pais_VA,ColunaSEA]) !=0,M[LinVA,w]/as.numeric(SEA[Linhas_Setor_Pais_VA,ColunaSEA]),0)
      H_EMPE[w]<-as.numeric(SEA[Linhas_Setor_Pais_H_EMPE,ColunaSEA])*1000000
      EMP[w]<-as.numeric(SEA[Linhas_Setor_Pais_EMP,ColunaSEA])*1000
      EMPE[w]<-as.numeric(SEA[Linhas_Setor_Pais_EMPE,ColunaSEA])*1000
      COMP_REAL[w] <- as.numeric(SEA[Linhas_Setor_Pais_COMP,ColunaSEA])/as.numeric(SEA[Linhas_Setor_Pais_VA_P,ColunaSEA])*100
      LAB_REAL[w] <- as.numeric(SEA[Linhas_Setor_Pais_LAB,ColunaSEA])/as.numeric(SEA[Linhas_Setor_Pais_VA_P,ColunaSEA])*100
      CAP_USD[w] <- as.numeric(SEA[Linhas_Setor_Pais_CAP,ColunaSEA])*CAMBIO
      LAB_USD[w] <- as.numeric(SEA[Linhas_Setor_Pais_LAB,ColunaSEA])*CAMBIO
      COMP_USD[w] <- as.numeric(SEA[Linhas_Setor_Pais_COMP,ColunaSEA])*CAMBIO
      if (VERSAO == 'July14') {
        H_EMP[w] <- as.numeric(SEA[Linhas_Setor_Pais_H_EMP,ColunaSEA])*1000000
        K_USD[w] <- as.numeric(SEA[Linhas_Setor_Pais_K_GFCF,ColunaSEA])*as.numeric(SEA[Linhas_Setor_Pais_GFCF_P,ColunaSEA])/100*CAMBIO
      } else {
        K_USD[w] <- as.numeric(SEA[Linhas_Setor_Pais_K,ColunaSEA])*CAMBIO
      }
      w <- w+1
    }
  }
  ColunaSEA <- ColunaSEA+1

  # Estimativa do EMP e H_EMP para o RoW
  EMP_ROW_TOTAL <- ROW_EMP[which(ROW_EMP==VERSAO),as.character(Z)]
  source(paste0(getwd(),"/R/Trabalho_RoW.R"))
  
  source(paste0(getwd(),"/R/Transformar.R"))

  source(paste0(getwd(),"/R/estimar-vars.R"))

  saveRDS(MT, file = paste0(getwd(),"/Resultados/",VERSAO,"_WIOD_HORAS_",as.character(Z),".rds"))
  write.csv2(Resultados, file = paste0(getwd(),"/Resultados/",VERSAO,"_Resultados",as.character(Z),".csv"))
  write.csv2(TransferenciaPais,
             file = paste0(getwd(),"/Resultados/",VERSAO,"_Transferencias",as.character(Z),".csv"),
             row.names = Paises[,1])
  beep(sound=2)
}
beep(sound=3)

