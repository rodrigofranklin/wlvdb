# Taxa de exploração da população ocupada dos países e do mundo

sea_paises[,"taxa_exploracao_ocupados",lista_paises] <-  aperm(
  apply(
    apply(
      (cesta_consumo * rep(fator_t, times = num_paises_setores)),
      1,
      colSums
    ),
    2,
    tapply,
    linhas$pais,
    sum,
    na_rm = TRUE
  ),
  c(2,1)
)

sea_paises[,"taxa_exploracao_ocupados","WWW"] <- 
  sum(sea_paises[,"taxa_exploracao_ocupados",lista_paises], na.rm = TRUE)

sea_paises[,"taxa_exploracao_ocupados",] <- 
  (sea_paises[,"trabalho_abstrato",] /
     sea_paises[,"taxa_exploracao_ocupados",]) -1