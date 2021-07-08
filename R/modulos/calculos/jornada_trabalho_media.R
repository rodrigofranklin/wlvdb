# Jornada de trabalho média de cada setor
sea_setores[,"jornada_trabalho_media",,] <- 
  sea_setores[,"horas_assalariadas",,] /
  sea_setores[,"assalariados",,]