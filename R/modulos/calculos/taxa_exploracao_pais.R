# Taxa de exploração dos trabalhadores assalariados de cada país e do mundo
sea_paises[,"taxa_exploracao",] <- 
  (sea_paises[,"jornada_trabalho_media",] /
  sea_paises[,"valor_forca_trabalho_media",]) -1