#Genera vector de combinación de países y sectores según lo necesario para la 
#asociación de la matriz de IO a los mismos

# Lista dos países
paises <- read.csv2(file = paste0(getwd(),"/sourcedata/",versao,"/paises.csv"),
                    row.names = 1, check.names = F)
lista_paises <- paises$Legenda
num_paises <- length(lista_paises)

# Obtém a informação dos setores produtivos e prepara as variávels 
# lins_prods, col_prods e linhas
lista_setores <- setores$Code
num_setores <- length(lista_setores)

linhas <- data.frame(pais = rep(lista_paises, each = num_setores))
linhas$setor <- lista_setores
linhas$produtivo <- setores$produtivo

lista_paises_setores <- paste0(linhas$pais,".",linhas$setor)
num_paises_setores <- num_setores*num_paises

