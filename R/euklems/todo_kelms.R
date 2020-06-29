## Este script salva as distribuições do capital para todos os anos

for (ano in 1995:2015) {
  source("R/euklems/k-prop.R")
  saveRDS(ek.k, file = paste0("sourcedata/euklems/ekk_",ano,".RDS"))
}
