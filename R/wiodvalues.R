require("devtools")
library("wiod")
library(readxl)
library(dplyr)
library(matlib)
library(data.table)




#http://www.wiod.org/protected3/data13/SEA/WIOD_SEA_July14.xlsx



#Indica los años todos - primera prueba en la primera versión - WIOD2013
anosv1 <- 1995:2011

#Importa todas las tablas disponibles como 'built-in' en el paquete WIOD
lapply(anosv1,function(x) do.call(data,as.list(paste0("wiot_",x))))

laborvaluesv1 <- function(ano = 2000, intermed , laborvector) {
  ####1) Coeficientes Técnicos
  intermed <- as.array(intermed)
  matident <- diag(length(coef_tec))
  coef_tec <- prop.table(intermed,2)
  coef_tec <- as.matrix(coef_tec)
  ####2)Inversa de Leontief
  
  ainverter <- matident - coef_tec
  
  leontief <- solve(ainverter)
  
  ####3) Vector de coeficientes de trabajo por setor - en script separado - distintas posibilidades
  source("usdbylabourhours.R")
    
  #4) multiplicar vector de requerimientos directos trabajo por inversa de leontief
  
    #horas-trabajo / producción bruta
  laborvalues <- laborvector * leontief
}

