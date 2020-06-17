
# ano <- 1995
# source("R/euklems/klems-k.R")
# ek.dep2 = ek.dep1 = ek1.k <- ek.k
# ek1.k <- ek.k
# ano <- 1996
# for (ano in 1996:2015) {
#   source("R/euklems/klems-kpyp.R")
#   source("R/euklems/klems-i.R")
#   saveRDS(ek.k, file = paste0("sourcedata/euklems/ekk_",ano,".RDS"))
#   ek.dep2[,3:16] <- (ek1.k[,3:16] + ek.i[,3:16] - ek.k[, 3:16])
# 
#   saveRDS(ek.dep, file = paste0("sourcedata/euklems/ek.dep.",ano,".RDS"))
# }
# 
# delta.dep[,3:16] <- (ek.k[,3:16]+ek1.k[,3:16])/2


ano <- 1995

for (ano in 1995:2015) {
  source("R/euklems/k-prop.R")
  saveRDS(ek.k, file = paste0("sourcedata/euklems/ekk_",ano,".RDS"))
}
