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
  
  ####3) Vector de coeficientes de trabajo por setor
  
  ##genera vector de las horas totales y año indicado
  if(exists(laborvector)) laborvector <- as.numeric(laborvector)
  else
    ##Importa SEA de la WIOD v1
    urlseav1 <- "http://www.wiod.org/protected3/data13/SEA/WIOD_SEA_July14.xlsx"
    seav1 <- tempfile()
    download.file(urlseav1,seav1)
    sea95legend <- read_xlsx(seav1, range = "A7:F55", col_names = T)
    sea95 <- read_xlsx(seav1, sheet = "DATA", col_names = T)
    seaano <- sea95[c("Country","Variable","Code",paste0("_",ano))]
    seaano <- data.table(seaano)
    laborvector <- as.matrix(seaano[Variable == "H_EMP" & Code != "TOT", 4])
    laborvector <- as.double(laborvector)
  #Preparar el vector - completar información ausente - 1400 x 1435
    #seaano[Variable == "H_EMP" & Code != "TOT", ] <- selecciona indonesia
    
    
  #4) multiplicar vector de requerimientos directos trabajo por inversa de leontief
  
    #horas-trabajo / producción bruta
  laborvalues <- laborvector * leontief
}

