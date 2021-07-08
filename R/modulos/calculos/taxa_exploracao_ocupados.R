# Taxa de exploração da população ocupada
sea_setores[,"taxa_exploracao_ocupados",,] <- 
  aperm(
    apply(
      (cesta_consumo * rep(fator_t, times = num_paises_setores)),
      1,
      colSums
    ),
    c(2,1)
  )

sea_setores[,"taxa_exploracao_ocupados",,] <- 
  (sea_setores[,"trabalho_abstrato",,] /
  sea_setores[,"taxa_exploracao_ocupados",,]) -1
