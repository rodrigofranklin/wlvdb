# Taxa de exploração dos trabalhadores assalariados
sea_setores[,"taxa_exploracao_alta_q",,] <- 
  ((sea_setores[,"horas_assalariadas",,] * 
     sea_setores[,"horas_taxa_alta_q",,]) /
  (sea_setores[,"valor_forca_trabalho_total",,] *
     sea_setores[,"remuneracao_taxa_alta_q",,])) -1


