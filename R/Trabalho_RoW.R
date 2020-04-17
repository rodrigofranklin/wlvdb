#######################################################################
#
# Cálculo do emprego mundial
#

EMP_ROW_TOTAL <- ROW_EMP[which(ROW_EMP==VERSAO),as.character(Z)]
was_w_row <- as.numeric(ROW_EMP[which(ROW_EMP=='was_w'),as.character(Z)])/100
EMP_WIOD <- sum(EMP)

posROW <- (Num_Paises-1)*Num_Setores
tamanho <- dim(EMP)

PONDERACAO <- EMP

for (Setor in 1:Num_Setores) {
  posicao <- Setor+posROW
  EMP_Setor_WIOD <- sum(EMP[seq(Setor,tamanho,Num_Setores)])
  H_EMP_Setor_WIOD <- sum(H_EMP[seq(Setor,tamanho,Num_Setores)])
  VA_Setor_WIOD <- sum(M[LinVA,seq(Setor,tamanho-Num_Setores,Num_Setores)])
  PONDERACAO[posicao] <- M[LinVA,posicao]*EMP_Setor_WIOD/VA_Setor_WIOD
}

posicao <- which(PaisLins==Paises[Paises[,3]=="ROW",2])


TOTAL_PONDERACAO <- sum(PONDERACAO[posicao])
PONDERACAO[posicao] <- PONDERACAO[posicao]/TOTAL_PONDERACAO
EMP[posicao] <- PONDERACAO[posicao]*EMP_ROW_TOTAL
H_EMP[posicao] <- EMP[posicao]*(H_EMP_Setor_WIOD/EMP_Setor_WIOD)
EMPE[posicao] <- EMP[posicao]*was_w_row
H_EMPE[posicao] <- H_EMP[posicao]*was_w_row

EMP[is.na(EMP)] <- 0
H_EMP[is.na(H_EMP)] <- 0
EMPE[is.na(EMPE)] <- 0
H_EMPE[is.na(H_EMPE)] <- 0
