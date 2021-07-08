# Calcula dados sea_setores
for (x in variaveis_sea$solucao_setor[which(variaveis_sea$ordem==3)]) {
  source(paste0("R/modulos/calculos/",x))
  sea_setores[is.nan(sea_setores)] <- 0
  sea_setores[is.infinite(sea_setores)] <- 0
}
