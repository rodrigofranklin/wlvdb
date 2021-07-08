# Taxa de câmbio a partir do Valor Agregado em moeda local e USD
sea_setores[,"cambio",,which(lista_paises!="ROW")] <-
  m_io_fonte[,"TOT.VA",which(linhas$pais!="ROW")] / 
  as.numeric(sea_fonte[,"VA",lista_setores,])