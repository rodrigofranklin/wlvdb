library("wiod")
library(dplyr)
library(matlib)




#http://www.wiod.org/protected3/data13/SEA/WIOD_SEA_July14.xlsx



#Indica los años todos - primera prueba en la primera versión - WIOD2013
anosv1 <- 1995:2009

#importa SEA y completa los datos de horas trabajadas
source("usdbylabourhours.R")


laborvaluesv1 <- function(ano = 2000) {
  ####1) Coeficientes Técnicos
  #carga wiot correspondiente de la v1
  do.call(data,list(paste0("wiot_",ano)))
  wiotbase <- get(paste0("wiot_",ano))
  rm(list=ls(pattern="wiot_\\d+"))
  gc()
  intermed <- wiotbase$inter
  coef_tec <- prop.table(intermed,2)
  coef_tec <- as.matrix(coef_tec)
  matident <- diag(nrow(coef_tec))
  ####2)Inversa de Leontief
  
  ainverter <- matident - coef_tec
  
  leontief <- solve(ainverter)
  
  ####3) Vector de coeficientes de trabajo por setor - en script separado - distintas posibilidades
  #  source("usdbylabourhours.R") más arriba
    laborvector <- directlaboureq[directlaboureq$year == ano,4]
  #4) multiplicar vector de requerimientos directos trabajo por inversa de leontief
   print(summary(laborvector))
    #horas-trabajo / producción bruta
  laborvector %*% leontief
}

valor2000 <- laborvaluesv1()
valorestodos <- lapply(anosv1, laborvaluesv1)
