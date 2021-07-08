sea_setores[,"salario_real",,which(lista_paises!="ROW")] <-
  sea_fonte[,"COMP",lista_setores,] /
  sea_fonte[,"VA_PI",lista_setores,] * 100