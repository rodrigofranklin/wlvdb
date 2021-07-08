# Soma do valor da força de trabalho de cada setor
sea_setores[,"valor_forca_trabalho_total",,] <- 
  aperm(
    apply(
      (cesta_consumo_assalariados * rep(fator_t, times = num_paises_setores)),
      1,
      colSums
    ),
    c(2,1)
  )