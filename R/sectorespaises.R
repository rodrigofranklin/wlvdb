#Genera vector de combinación de países y sectores según lo necesario para la asociación de la matriz de IO
#a los mismos

# Lista dos países
Paises <- read.csv2(file = paste0(getwd(),"/sourcedata/",VERSAO,"/Paises.csv"), row.names = 1)
Num_Paises <- dim(Paises)[1]

# Obtém a informação dos setores produtivos e prepara as variávels LinProds, ColProds e PaisLins
Setores<-read.csv2(paste0(getwd(),"/sourcedata/",VERSAO,"/setores.csv"))
Num_Setores <- dim(Setores)[1]
LinProds <- NULL
PaisLins <- NULL
W=1
for (X in Paises[,2]) {
  for (Y in 1:Num_Setores){
    PaisLins <- c(PaisLins, X)
    if (Setores[Y,4]==1)  {LinProds <- c(LinProds,W)}
    W<-W+1
  }
}
LinProds <- t(LinProds)
ColProds <- LinProds
LinConsumoIntermediario <- Num_Paises*Num_Setores + 1

