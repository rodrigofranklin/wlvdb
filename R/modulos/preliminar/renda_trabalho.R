# Remuneração de pessoas ocupadas
sea_setores[,"renda_trabalho",,which(lista_paises!="ROW")] <-
  sea_fonte[,"LAB",lista_setores,] * 
  sea_setores[,"cambio",,which(lista_paises!="ROW")]