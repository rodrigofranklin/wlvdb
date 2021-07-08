## Carrega todos os parâmetros que definem o modelo do resultado.

## _parametros.csv -  cada coluna é um parâmetro: versao e cesta_consumo
parametros <- 
  read.csv2(paste0("resultados/",versao_resultado,"/_parametros.csv"))

## -setores.csv - lista dos setores indicando quais são produtivos e 
## não produtivos; o tipo de capital que produz (EUKLEMS) e a correspondência
## com os setores do EUKLEMS
setores <-
  read.csv2(paste0("resultados/",versao_resultado,"/_setores.csv"))

## _variaveis_sea - lista de todas as variáveis presentes em sea_setores e 
## sea_paises, além dos métodos de cálculos.
variaveis_sea <-
  read.csv2(paste0("resultados/",versao_resultado,"/_variaveis_sea.csv"))

versao <- parametros$versao

  