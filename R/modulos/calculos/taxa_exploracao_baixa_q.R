# Taxa de exploração dos trabalhadores assalariados
sea_setores[,"taxa_exploracao_baixa_q",,] <- 
  ((sea_setores[,"horas_assalariadas",,] * 
     sea_setores[,"horas_taxa_baixa_q",,]) /
  (sea_setores[,"valor_forca_trabalho_total",,] *
     sea_setores[,"remuneracao_taxa_baixa_q",,])) -1


