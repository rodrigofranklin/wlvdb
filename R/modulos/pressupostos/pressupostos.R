# Calcula variáveis de pressupostos
for (x in variaveis_sea$solucao_setor[which(variaveis_sea$ordem==2)]) {
  source(paste0("R/modulos/pressupostos/",x))
}
