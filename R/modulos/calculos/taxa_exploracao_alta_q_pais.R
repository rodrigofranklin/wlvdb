# Taxa de exploração dos trabalhadores assalariados
sea_paises[,"taxa_exploracao_alta_q", lista_paises] <- 
  aperm(
    apply(
      (sea_setores[,"horas_assalariadas",,] * 
        sea_setores[,"horas_taxa_alta_q",,]), 1,
      tapply, linhas$num_pais, sum, na.rm = TRUE),
    c(2,1)
  ) / aperm(
    apply(
      sea_setores[,"valor_forca_trabalho_total",,] * 
        sea_setores[,"remuneracao_taxa_alta_q",,], 1,
      tapply, linhas$num_pais, sum, na.rm = TRUE),
    c(2,1)
  ) -1

sea_paises[, "taxa_exploracao_alta_q", "WWW"] <- 
  apply(
    (sea_setores[,"horas_assalariadas",,] * 
       sea_setores[,"horas_taxa_alta_q",,]), 1,
    sum, na.rm = TRUE) /
  apply(
    sea_setores[,"valor_forca_trabalho_total",,] * 
      sea_setores[,"remuneracao_taxa_alta_q",,], 1,
    sum, na.rm = TRUE)
