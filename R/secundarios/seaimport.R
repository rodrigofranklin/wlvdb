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
