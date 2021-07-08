# Estoque de capital - preços correntes
sea_setores[,"estoque_capital",,which(lista_paises!="ROW")] <-
  sea_fonte[,"K",lista_setores,] *
  sea_setores[,"cambio",,which(lista_paises!="ROW")]
