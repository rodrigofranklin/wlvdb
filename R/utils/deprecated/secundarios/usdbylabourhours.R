library(readxl)
library(data.table)
library(tidyr)
library(dplyr)
#Para tipos de cambio - verificar a futuro conveniencia de library(wbstats)

library("imfr")
#ENDA_XDC_USD_RATE
library(countrycode)





# a futuro - convertir en función
#seadireclabor <- function(ano = 2000, restow = "IDN")
  #PERMITIR INDICAR 1 PAÍS O varios - por estandar Indonesia
  # a futuro - establecer los distintos métodos en la misma función
  #metodo = "paises" | "promedio mundial"

##genera vector de requerimientos directos de trabajo,
# horas totales por USD para todos los años disponibles




source("R/seaimport.R")

hoursvector <- sea[Variable == "H_EMP" & Code != "TOT"]

#más clareza en nomenclatura
names(hoursvector)[6] <- "hours"
names(hoursvector)[4] <- "sectors"

#combina países y sectores
pasect <- expand.grid(sectors = unique(hoursvector$sectors), stringsAsFactors = F, countries = wiot_1995$countries)


#obtiene el producto total de las wiot, ordenados año a año

paisecvtan <- function (ano = 2000) {
  wtbase <- get(paste0("wiot_",ano))
  cbind(year = wtbase$year,pasect,output = wtbase$output)
  }

vtotvector <-  rbindlist(lapply(anosv1, paisecvtan))

#define nombres de columnas como los de SEA por claridad de código 
names(vtotvector) <- c("year","sectors","Country","Valor Total")
#Preparar el vector - completar información ausente - 1400 x 1435
#seaano[Variable == "H_EMP" & Code != "TOT", ] <- selecciona indonesia


directlaboureq <- hoursvector %>% left_join(vtotvector, by = c("Country","sectors","year"))

#mantener en millón de horas
directlaboureq$hourusd <- directlaboureq$hours/(1000000*directlaboureq$`Valor Total`)

#troca NA por 0 - setores sem informação de produção de valor
directlaboureq[is.na(directlaboureq$hourusd),8] <- 0

#Troca infinito por 0 - setor sem informação de valor adicionado
directlaboureq[is.infinite(directlaboureq$hourusd),8] <- 0
### Especifica el RoW como copia de indonesia

rowdle <- directlaboureq[directlaboureq$Country == "IDN",] %>% mutate("Country" = "RoW")

directlaboureq <- rbind(directlaboureq,rowdle)


#Simplifica resultado para quedarse apenas con País, año, sector y horasusd

directlaboureq <- directlaboureq[,c(1,4,5,8)]

#fix ordering
directlaboureq <- directlaboureq %>% arrange(year,Country)




#A futuro - comprobar si ya hay estimativa completa con el nombre final del objeto
#if(exists(laborvector)) 
#  laborvector <- as.numeric(laborvector)
#  else



#Función para importar datos y completarlos de manera a obtener el vector de horas de trabajo /USD
#Centraliza en el año elegido y la función




