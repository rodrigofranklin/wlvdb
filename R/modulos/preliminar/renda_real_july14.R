# Remuneração real por pessoa ocupada - preços 1995
sea_setores[,"renda_real",,which(lista_paises!="ROW")] <-
  sea_fonte[,"LAB",lista_setores,] /
  sea_fonte[,"VA_P",lista_setores,] * 100