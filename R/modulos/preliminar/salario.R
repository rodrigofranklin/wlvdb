# Salários
sea_setores[,"salarios",,which(lista_paises!="ROW")] <-
  sea_fonte[,"COMP",lista_setores,] * 
  sea_setores[,"cambio",,which(lista_paises!="ROW")]