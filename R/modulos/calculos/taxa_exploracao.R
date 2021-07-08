# Taxa de exploração dos trabalhadores assalariados
sea_setores[,"taxa_exploracao",,] <- 
  (sea_setores[,"jornada_trabalho_media",,] /
  sea_setores[,"valor_forca_trabalho_media",,]) -1


