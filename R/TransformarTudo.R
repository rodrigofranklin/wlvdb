#################################
# Script para realizar as transformações de todos os anos
#
################################

library(readxl)
library(beepr)

# Define a versão do WIOD que será utilizada: July14 ou Nov16
versao <- 'July14'
#versao <- 'Nov16'

# 
variavel_trabalho <- 'h.emp'
#variavel_trabalho <- 'emp'
#variavel_trabalho <- 'h.emp_alternativo'


#paises y sectores - Inicialmente LinProds ColProds pais.lins pasado a módulo propio
source('R/sectorespaises.R')

# Obtém informações sobre as colunas de demanda
demanda<-read.csv2(paste0(getwd(),"/sourcedata/",versao,"/demanda.csv"))
num.demanda <- dim(demanda)[1]
pais.cols <- pais.lins
col.fbcf <- NULL
col.demanda.final <- NULL
for (x in paises[,2]) {
  col.fbcf <- c(col.fbcf, (num.setores*num.paises) + demanda[demanda == 'Gross fixed capital formation',3] + (num.demanda*(x-1)))
  col.demanda.final <- c(col.demanda.final, (num.setores*num.paises) + demanda[demanda == 'Final consumption expenditure by households',3] + (num.demanda*(x-1)))
  for (y in 1:num.demanda){
    pais.cols <- c( pais.cols, x)
  }
}
col.produto.total <- num.setores*num.paises + num.demanda*num.paises + 1

# Carrega as informações das contas socioeconômicas
source("R/importar_sea.R")

# Carrega as informações da estimativa do emp do RoW
row.emp <- as.data.frame(read_xlsx(paste0(getwd(),"/sourcedata/row_emp/emprego_row.xlsx"), sheet = "DATA", col_names = T))

# Carrega as informações da estimativa do empe da China
was_w_china <- as.data.frame(read_xlsx(paste0(getwd(),"/sourcedata/china/was_w.xlsx"), sheet = "DATA", col_names = T))
jornada_media_china <- read.csv2(file = paste0(getwd(),"/sourcedata/Nov16/China H_EMPE-EMPE.csv"), row.names = 1)
colnames(jornada_media_china) <- tolower(gsub("X","",colnames(jornada_media_china)))


for (z in anos) {

  #Carrega a matriz insumo-produto multirregional
  if (versao == "July14") {
    m.wio <- readRDS(paste0(getwd(),"/sourcedata/",versao,"/WIOT_",as.character(z),".rds"))
    lin.produto.total <- nrow(m.wio)
    lin.va <- 1441
  } else {
    load(paste0(getwd(),"/sourcedata/Nov16/WIOT",as.character(z),"_October16_ROW.RData"))
    m.wio <- as.matrix(wiot[,6:ncol(wiot)])
    lin.produto.total <- which(wiot[,'IndustryCode'] == 'GO')
    lin.va <- which(wiot[,'IndustryCode'] == 'VA')
  }
  
  # Separa as variáveis desejadas da tabela de contas socioeconômicas
  h.emp = h.empe = emp = empe = comp.real = lab.real = k.usd = cap.usd = lab.usd = comp.usd <- array(data = 0, dim = num.paises*num.setores)
  w <- 1
  for (x in 1:(num.paises-1)) {
    linhas.pais.h.emp <- linhas.h.emp[which(sea[linhas.h.emp,'country'] == as.character(paises[x,3]))]
    linhas.pais.h.empe <- linhas.h.empe[which(sea[linhas.h.empe,'country'] == as.character(paises[x,3]))]
    linhas.pais.emp <- linhas.emp[which(sea[linhas.emp,'country'] == as.character(paises[x,3]))]
    linhas.pais.empe <- linhas.empe[which(sea[linhas.empe,'country'] == as.character(paises[x,3]))]
    linhas.pais.go <- linhas.go[which(sea[linhas.go,'country'] == as.character(paises[x,3]))]
    linhas.pais.va <- linhas.va[which(sea[linhas.va,'country'] == as.character(paises[x,3]))]
    linhas.pais.va.p <- linhas.va.p[which(sea[linhas.va.p,'country'] == as.character(paises[x,3]))]
    linhas.pais.comp <- linhas.comp[which(sea[linhas.comp,'country'] == as.character(paises[x,3]))]
    linhas.pais.lab <- linhas.lab[which(sea[linhas.lab,'country'] == as.character(paises[x,3]))]
    linhas.pais.cap <- linhas.cap[which(sea[linhas.cap,'country'] == as.character(paises[x,3]))]
    linhas.pais.k.gfcf <- linhas.k.gfcf[which(sea[linhas.k.gfcf,'country'] == as.character(paises[x,3]))]
    linhas.pais.gfcf.p <- linhas.gfcf.p[which(sea[linhas.gfcf.p,'country'] == as.character(paises[x,3]))]
    linhas.pais.k <- linhas.k[which(sea[linhas.k,'country'] == as.character(paises[x,3]))]
    
    for (y in 1:num.setores) {
      linhas.setor.pais.h.emp <- linhas.pais.h.emp[which(sea[linhas.pais.h.emp,'code'] == as.character(setores[y,1]))]
      linhas.setor.pais.h.empe <- linhas.pais.h.empe[which(sea[linhas.pais.h.empe,'code'] == as.character(setores[y,1]))]
      linhas.setor.pais.emp <- linhas.pais.emp[which(sea[linhas.pais.emp,'code'] == as.character(setores[y,1]))]
      linhas.setor.pais.empe <- linhas.pais.empe[which(sea[linhas.pais.empe,'code'] == as.character(setores[y,1]))]
      linhas.setor.pais.go <- linhas.pais.go[which(sea[linhas.pais.go,'code'] == as.character(setores[y,1]))]
      linhas.setor.pais.va <- linhas.pais.va[which(sea[linhas.pais.va,'code'] == as.character(setores[y,1]))]
      linhas.setor.pais.va.p <- linhas.pais.va.p[which(sea[linhas.pais.va.p,'code'] == as.character(setores[y,1]))]
      linhas.setor.pais.comp <- linhas.pais.comp[which(sea[linhas.pais.comp,'code'] == as.character(setores[y,1]))]
      linhas.setor.pais.lab <- linhas.pais.lab[which(sea[linhas.pais.lab,'code'] == as.character(setores[y,1]))]
      linhas.setor.pais.cap <- linhas.pais.cap[which(sea[linhas.pais.cap,'code'] == as.character(setores[y,1]))]
      linhas.setor.pais.k.gfcf <- linhas.pais.k.gfcf[which(sea[linhas.pais.k.gfcf,'code'] == as.character(setores[y,1]))]
      linhas.setor.pais.gfcf.p <- linhas.pais.gfcf.p[which(sea[linhas.pais.gfcf.p,'code'] == as.character(setores[y,1]))]
      linhas.setor.pais.k <- linhas.pais.k[which(sea[linhas.pais.k,'code'] == as.character(setores[y,1]))]
      
      cambio <- ifelse(as.numeric(sea[linhas.setor.pais.va,coluna.sea]) !=0,m.wio[lin.va,w]/as.numeric(sea[linhas.setor.pais.va,coluna.sea]),0)
      h.empe[w]<-as.numeric(sea[linhas.setor.pais.h.empe,coluna.sea])*1000000
      emp[w]<-as.numeric(sea[linhas.setor.pais.emp,coluna.sea])*1000
      empe[w]<-as.numeric(sea[linhas.setor.pais.empe,coluna.sea])*1000
      comp.real[w] <- as.numeric(sea[linhas.setor.pais.comp,coluna.sea])/as.numeric(sea[linhas.setor.pais.va.p,coluna.sea])*100
      lab.real[w] <- as.numeric(sea[linhas.setor.pais.lab,coluna.sea])/as.numeric(sea[linhas.setor.pais.va.p,coluna.sea])*100
      cap.usd[w] <- as.numeric(sea[linhas.setor.pais.cap,coluna.sea])*cambio
      lab.usd[w] <- as.numeric(sea[linhas.setor.pais.lab,coluna.sea])*cambio
      comp.usd[w] <- as.numeric(sea[linhas.setor.pais.comp,coluna.sea])*cambio
      if (versao == 'July14') {
        h.emp[w] <- as.numeric(sea[linhas.setor.pais.h.emp,coluna.sea])*1000000
        k.usd[w] <- as.numeric(sea[linhas.setor.pais.k.gfcf,coluna.sea])*as.numeric(sea[linhas.setor.pais.gfcf.p,coluna.sea])/100*cambio
      } else {
        k.usd[w] <- as.numeric(sea[linhas.setor.pais.k,coluna.sea])*cambio
      }
      w <- w+1
    }
  }
  if (versao == "Nov16") {
    h.emp <- h.empe/empe*emp
    h.emp[which(pais.lins==paises[paises[,3]=="CHN",2])] <- emp[which(pais.lins==paises[paises[,3]=="CHN",2])]*t(jornada_media_china[,as.character(z)])[1,]*1000
    h.emp[is.na(h.emp)] <- 0
  }
  empe[which(pais.lins==paises[paises[,3]=="CHN",2])] <- emp[which(pais.lins==paises[paises[,3]=="CHN",2])]*as.numeric(was_w_china[as.character(z)])/100
  h.empe[which(pais.lins==paises[paises[,3]=="CHN",2])] <- h.emp[which(pais.lins==paises[paises[,3]=="CHN",2])]*as.numeric(was_w_china[as.character(z)])/100
  coluna.sea <- coluna.sea+1

  # Estimativa do emp e h.emp para o RoW
  source(paste0(getwd(),"/R/Trabalho_RoW.R"))

  # Define qual a variável que será utilizada para o cálculo do valor
  if (variavel_trabalho == "h.emp") {
    trabalho <- h.emp
  } else if (variavel_trabalho == "emp") {
    trabalho <- emp
  } else {
    trabalho <- h.empe/empe*emp
    trabalho[is.na(trabalho)] <- 0
  }

  source(paste0(getwd(),"/R/Transformar.R"))

  source(paste0(getwd(),"/R/estimar-vars.R"))
  
  saveRDS(m.t, file = paste0(getwd(),"/Resultados/",versao,"_",variavel_trabalho,"_WIOD_HORAS_",as.character(z),".rds"))
  write.csv2(Resultados, file = paste0(getwd(),"/Resultados/",versao,"_",variavel_trabalho,"_Resultados",as.character(z),".csv"))
  write.csv2(TransferenciaPais,
             file = paste0(getwd(),"/Resultados/",versao,"_",variavel_trabalho,"_Transferencias",as.character(z),".csv"),
             row.names = paises[,1])
  beep(sound=2)
}
beep(sound=3)

