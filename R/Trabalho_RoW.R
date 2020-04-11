#######################################################################
#
# Cálculo do emprego mundial
#

EMP_WIOD <- sum(EMP)

VA_ROW <- sum(M[LinVA,which(PaisLins == Num_Paises)])
VA_WIOD <- sum(M[LinVA,])-VA_ROW

posROW <- (Num_Paises-1)*Num_Setores
tamanho <- dim(EMP)

PONDERACAO <- EMP

for (Setor in 1:Num_Setores) {
  posicao <- Setor+posROW
  EMP_Setor_WIOD <- sum(EMP[seq(Setor,tamanho,Num_Setores)])
  H_EMP_Setor_WIOD <- sum(H_EMP[seq(Setor,tamanho,Num_Setores)])
  VA_Setor_WIOD <- sum(M[LinVA,seq(Setor,tamanho-Num_Setores,Num_Setores)])
  PONDERACAO[posicao] <- (M[LinVA,posicao]/VA_ROW)*((EMP_Setor_WIOD/EMP_WIOD)/(VA_Setor_WIOD/VA_WIOD))
}

TOTAL_PONDERACAO <- sum(PONDERACAO[which(PaisLins == Num_Paises)])

for (Setor in 1:Num_Setores) {
  posicao <- Setor+posROW
  PONDERACAO[posicao] <- PONDERACAO[posicao]/TOTAL_PONDERACAO
  H_EMP[posicao] <- EMP[posicao]*(H_EMP_Setor_WIOD/EMP_Setor_WIOD)
  EMP[posicao] <- EMP_ROW_TOTAL*PONDERACAO[posicao]
}
EMP[is.na(EMP)] <- 0

H_EMP[is.na(H_EMP)] <- 0
EMP
