## Este script salva as distribuições do capital e as taxas de
## depreciação para todos os anos

for (ano in 1995:2015) {
  source("R/euklems/k-prop.R")
  saveRDS(ek.k, file = paste0("sourcedata/euklems/ekk_",ano,".rds"))
  saveRDS(ek.tx.dep, file = paste0("sourcedata/euklems/ektxdep_",ano,".rds"))
}
