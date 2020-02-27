library("wiod")
library(dplyr)
library(matlib)




#http://www.wiod.org/protected3/data13/SEA/WIOD_SEA_July14.xlsx




# actualmente el año 2009 no pude realizarlo por un error a verificar
anosv1 <- 1995:2008

#importa SEA y completa los datos de horas trabajadas
source("R/usdbylabourhours.R")


laborvaluesv1 <- function(ano = 2000) {
  ####1) Coeficientes Técnicos
  #carga wiot correspondiente de la v1
  do.call(data,list(paste0("wiot_",ano)))
  wiotbase <- get(paste0("wiot_",ano))
  rm(list=ls(pattern="wiot_\\d+"))
  gc()
  intermed <- wiotbase$inter
  coef_tec <- prop.table(intermed,2)
  coef_tec[is.na(coef_tec)] <- 0
  coef_tec <- as.matrix(coef_tec)
  matident <- diag(nrow(coef_tec))
  ####2)Inversa de Leontief
  
  ainverter <- matident - coef_tec
  
  leontief <- solve(ainverter)
  
  ####3) Vector de coeficientes de trabajo por setor - en script separado - distintas posibilidades
  #  source("usdbylabourhours.R") más arriba
    laborvector <- directlaboureq[directlaboureq$year == ano,4]
  #4) multiplicar vector de requerimientos directos trabajo por inversa de leontief
  # print(summary(laborvector))
    #horas-trabajo / producción bruta
  laborvector %*% leontief
}

valorestodos <- lapply(anosv1, function(x) as.vector(laborvaluesv1(x)))
names(valorestodos) <- anosv1


#Función (borrador) para visualizar un año de los valores estimados
visualizavalores <- function(ano = 2000, objvalor = valorestodos) {
  require(ggplot2)
  valoresconpais <- cbind(directlaboureq[directlaboureq$year == ano, 1:2],valorestodos[[paste0(ano)]])
  names(valoresconpais)[3] <- "values"
  graf <- ggplot(valoresconpais, aes(x = Code,
                             y = values, color = Country))+
    geom_line(aes(group = valoresconpais$Country))+
    theme_minimal()+
    scale_y_log10()+
    theme(legend.position="bottom", legend.title = element_blank())
  graf
}

visualizavalores()
