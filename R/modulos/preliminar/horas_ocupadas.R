# Total de horas de trabalho das pessoas ocupadas - necessário para Nov16
sea_setores[,"horas_ocupadas",,which(lista_paises!="ROW")] <-
  sea_fonte[,"H_EMPE",lista_setores,] /
  sea_fonte[,"EMPE",lista_setores,] * 
  sea_fonte[,"EMP",lista_setores,]