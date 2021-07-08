# Calcula os valores nacionais das variáveis da SEA com sum e mean
for (x in grep(".R", variaveis_sea$solucao_pais, invert = TRUE)) {
  sea_paises[, x, lista_paises] <- 
    aperm(
      apply(sea_setores[,x,,], 1,
            tapply, linhas$num_pais, variaveis_sea$solucao_pais[x], 
            na.rm = TRUE),
      c(2,1)
    )
  
  sea_paises[, x, "WWW"] <- 
    sea_paises[, x, lista_paises] %>%
    apply(1, variaveis_sea$solucao_pais[x], na.rm = TRUE)
}

# Calcula demais variáveis da SEA para os países
for (x in grep(".R", variaveis_sea$solucao_pais)) {
  source(paste0("R/modulos/calculos/",variaveis_sea$solucao_pais[x]))
  sea_paises[is.nan(sea_paises)] <- 0
  sea_paises[is.infinite(sea_paises)] <- 0
}
