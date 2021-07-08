sea_setores[,"renda_real",,which(lista_paises!="ROW")] <-
  sea_fonte[,"LAB",lista_setores,] /
  sea_fonte[,"VA_PI",lista_setores,] * 100
