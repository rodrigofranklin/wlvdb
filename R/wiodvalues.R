library("wiod")
library(dplyr)
library(matlib)




#http://www.wiod.org/protected3/data13/SEA/WIOD_SEA_July14.xlsx



#Indica los años todos - primera prueba en la primera versión - WIOD2013
anosv1 <- 1995:2009

#Importa todas las tablas disponibles como 'built-in' en el paquete WIOD
lapply(anosv1,function(x) do.call(data,as.list(paste0("wiot_",x))))

#importa SEA y completa los datos de horas trabajadas
source("usdbylabourhours.R")

laborvaluesv1 <- function(ano = 2000) {
  ####1) Coeficientes Técnicos
  intermed <- as.array(get(paste0("wiot_",ano))$inter)
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
  
    #horas-trabajo / producción bruta
  laborvalues <- laborvector ** leontief
}

laborvaluesv1()
