#Genera vector de combinación de países y sectores según lo necesario para la asociación de la matriz de IO
#a los mismos

# Lista dos países
paises <- read.csv2(file = paste0(getwd(),"/sourcedata/",versao,"/paises.csv"), row.names = 1, check.names = F)
num_paises <- dim(paises)[1]

# Obtém a informação dos setores produtivos e prepara as variávels lins_prods, col.prods e pais_lins
setores<-read.csv2(paste0(getwd(),"/sourcedata/",versao,"/setores.csv"),check.names = F)
num_setores <- dim(setores)[1]
pais_lins <- rep(paises[,2], each = num_setores)

tamanho <- num_setores*num_paises

linha_consumo_intermediario <- tamanho + 1

filtro_produtivo <- rep(setores$produtivo, times = num_paises)
filtro_produtivo_matriz <- matrix(filtro_produtivo, nrow = tamanho, ncol = tamanho, byrow = TRUE ) * filtro_produtivo
lins_prods <- (1:tamanho)[which(filtro_produtivo==1)]
cols_prods <- lins_prods
