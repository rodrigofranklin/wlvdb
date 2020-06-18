#Genera vector de combinación de países y sectores según lo necesario para la asociación de la matriz de IO
#a los mismos

# Lista dos países
paises <- read.csv2(file = paste0(getwd(),"/sourcedata/",versao,"/paises.csv"), row.names = 1, check.names = F)
num.paises <- dim(paises)[1]

# Obtém a informação dos setores produtivos e prepara as variávels lin.prods, col.prods e pais.lins
setores<-read.csv2(paste0(getwd(),"/sourcedata/",versao,"/setores.csv"),check.names = F)
num.setores <- dim(setores)[1]
lin.prods <- NULL
pais.lins <- NULL
W=1
for (X in paises[,2]) {
  for (Y in 1:num.setores){
    pais.lins <- c(pais.lins, X)
    if (setores[Y,4]==1)  {lin.prods <- c(lin.prods,W)}
    W<-W+1
  }
}
lin.prods <- t(lin.prods)
col.prods <- lin.prods
lin.consumo.intermediario <- num.paises*num.setores + 1

