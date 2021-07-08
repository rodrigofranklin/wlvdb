# Lucro
sea_setores[,"lucro",,which(lista_paises!="ROW")] <-
  sea_fonte[,"CAP",lista_setores,] * 
  sea_setores[,"cambio",,which(lista_paises!="ROW")]