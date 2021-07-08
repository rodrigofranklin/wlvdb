# Salário real - preços de 1995
sea_setores[,"salario_real",,which(lista_paises!="ROW")] <-
  sea_fonte[,"COMP",lista_setores,] /
  sea_fonte[,"VA_P",lista_setores,] * 100