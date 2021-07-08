###########################################.
## Aqui, é preciso copiar de sea_fontes para sea_setores todas as variáveis
## que serão complementadas (para ter todas as informações em um mesmo lugar).
## Além disso, calcula algumas variáveis
###########################################.

# Calcula variáveis preliminares indicadas nos parâmetros do modelo.
for (x in variaveis_sea$solucao_setor[which(variaveis_sea$ordem==1)]) {
  source(paste0("R/modulos/preliminar/",x))
}

# Copia variáveis de sea_fonte para sea_setores (indicadas nos parâmetros)
for (x in grep(".R", variaveis_sea$solucao_setor, invert = TRUE)) {
  temp <- unlist(strsplit(variaveis_sea$solucao_setor[x], "[*]"))
  sea_setores[, x, lista_setores, which(lista_paises!="ROW")] <- 
    sea_fonte[, temp[1], lista_setores, which(lista_paises!="ROW")]
}

# Muda escala das variáveis quando indicado nos parâmetros
for (x in grep("[*]", variaveis_sea$solucao_setor)) {
  temp <- unlist(strsplit(variaveis_sea$solucao_setor[x], "[*]"))
  sea_setores[,x,lista_setores,which(lista_paises!="ROW")] <- 
    sea_setores[,x,lista_setores,which(lista_paises!="ROW")] *
    as.numeric(temp[2])
}

# limpa os resultados
sea_setores[,,,][
  is.nan(sea_setores[,,,])] <- 0
sea_setores[,,,][
  is.infinite(sea_setores[,,,])] <- 0
rm(x, temp)