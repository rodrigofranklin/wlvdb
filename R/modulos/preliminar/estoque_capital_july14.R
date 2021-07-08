# Estoque de capital - preços correntes
sea_setores[,"estoque_capital",,which(lista_paises!="ROW")] <-
  sea_fonte[,"K_GFCF",lista_setores,] *
  sea_fonte[,"GFCF_P",lista_setores,] / 100 *
  sea_setores[,"cambio",,which(lista_paises!="ROW")]
