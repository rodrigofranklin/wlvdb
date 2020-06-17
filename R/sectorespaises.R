#Genera vector de combinación de países ysectores según lo necesario para la asociación de la matriz de IO
#a los mismos

# Lista dos países
paises <- read.csv2(file = paste0(getwd(),"/sourcedata/",versao,"/paises.csv"), row.names = 1)
num_paises <- dim(paises)[1]

# Obtém a informação dos setores produtivos e prepara as variávels linprods, colprods e paislins
setores<-read.csv2(paste0(getwd(),"/sourcedata/",versao,"/setores.csv"))
num_setores <- dim(setores)[1]
linprods <- NULL
paislins <- NULL
w=1
for (x in paises[,2]) {
  for (y in 1:num_setores){
    paislins <- c(paislins, X)
    if (setores[Y,4]==1)  {linprods <- c(linprods,w)}
    w<-w+1
  }
}
linprods <- t(linprods)
colprods <- linprods
linconsumoIntermediario <- num_paises*num_setores + 1


