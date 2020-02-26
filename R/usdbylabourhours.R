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




##Importa SEA de la WIOD v1


urlseav1 <- "http://www.wiod.org/protected3/data13/SEA/WIOD_SEA_July14.xlsx"
seav1 <- tempfile()
download.file(urlseav1,seav1)

#Importa sin formato la primera hoja con acrónimos - recupera países incluídos en el listado
# En el momento sirve para el vector de tipos de cambio
sealegend <- read_xlsx(seav1, range = "A7:F55", col_names = T)

#Importa los datos completos en la hoja
sea <- read_xlsx(seav1, sheet = "DATA", col_names = T)

#Cambia los nombres de las columnas para después reordenarlas
colnames(sea) <- c(colnames(sea)[1:4],1995:2011)

#Coloca las columnas de valores en valores numéricos
sea[,5:ncol(sea)] <- as.numeric(unlist(sea[,5:ncol(sea)]))
#Futuramente verificar si se han inserido NA's en puntos que

#colocar en formato tidy (columna para valores, columna para el año)
sea <- sea %>% pivot_longer(cols = -1:-4, names_to = "year", names_ptypes = integer(),
                            values_to = "value")

sea$year <- as.integer(sea$year)

#Coloca como data.table para dejar el código más compacto a la hora de filtrar columnas
sea <- data.table(sea)


hoursvector <- sea[Variable == "H_EMP" & Code != "TOT"]

vavector <- sea[Variable == "VA" & Code != "TOT"]


paiseswiod <- countrycode(unique(sealegend$Name[1:40]), origin = "country.name",destination = "iso2c")

eratevector <- imf_data('IFS','ENDA_XDC_USD_RATE', start = 1995, end = 2011, country = paiseswiod )
  #ENDA_XDC_USD_RATE

#convertir a iso3c - base de la wiod
eratevector$Country <- countrycode(eratevector$iso2c, origin = "iso2c", destination = "iso3c")

eratevector$year <- as.integer(eratevector$year)


vavector <- vavector %>% left_join(eratevector[,2:4], by = c("Country", "year"))


vavector$vausd <- vavector$value/vavector$ENDA_XDC_USD_RATE

#Preparar el vector - completar información ausente - 1400 x 1435
#seaano[Variable == "H_EMP" & Code != "TOT", ] <- selecciona indonesia


directlaboureq <- hoursvector %>% left_join(vavector[,c(1,4,5,8)], by = c("Country","Code","year"))


directlaboureq$hourusd <- directlaboureq$value/directlaboureq$vausd


### Especifica el RoW como copia de indonesia

rowdle <- directlaboureq[directlaboureq$Country == "IDN",] %>% mutate("Country" = "RoW")

directlaboureq <- rbind(directlaboureq,rowdle)

#Simplifica resultado para quedarse apenas con País, año, sector y horasusd

directlaboureq <- directlaboureq[,c(1,4,5,8)]

#A futuro - comprobar si ya hay estimativa completa con el nombre final del objeto
#if(exists(laborvector)) 
#  laborvector <- as.numeric(laborvector)
#  else



#Función para importar datos y completarlos de manera a obtener el vector de horas de trabajo /USD
#Centraliza en el año elegido y la función




