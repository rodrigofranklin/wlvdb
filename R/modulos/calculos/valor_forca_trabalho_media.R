# Valor médio da força de trabalho de cada setor
sea_setores[,"valor_forca_trabalho_media",,] <- 
  sea_setores[,"valor_forca_trabalho_total",,] /
  sea_setores[,"assalariados",,]
