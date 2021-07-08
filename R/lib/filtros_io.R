## Cria filtros para matriz input-ouput

## Define parâmetros ----
lista_filtros <- c("paises",
                   "setores_produtivos",
                   "comercio")

## Aloca variável ----
m_io_filtros <- array(0,
                      dim = c(num_filtros,
                              num_input,
                              num_output),
                      dimnames = list(lista_filtros,
                                      lista_input,
                                      lista_output))

## Filtro de países ----
# Essa matriz é para ser usada como índice de funções tapply. Cria uma matriz
# na qual cada célula é um número no formato X,Y. Sendo X o número índice do
# país da coluna, e Y (a parte decimal) o número índice do país da linha
pais_cols_matriz <- t(rep(colunas$num_pais, each = num_paises_setores))
dim(pais_cols_matriz) <- c(num_paises_setores, num_output-1)

pais_lins_matriz <- rep(linhas$num_pais, times = num_output-1)
dim(pais_lins_matriz) <- c(num_paises_setores, num_output-1)

m_io_filtros["paises",1:num_paises_setores,1:(num_output-1)] <- 
  pais_cols_matriz+(pais_lins_matriz/100)

## Filtro de setores produtivos ----
# Filtro de multiplicação: ao se multiplicar esse filtro por uma matriz
# contendo os dados de todos os setores, será obtido como resultado uma
# matriz contendo apenas os dados dos setores produtivos
m_io_filtros["setores_produtivos",linhas$produtivo==1,] <- 1

## Filtro de comércio internacional ----
# Filtro de multiplicação para eliminar o comércio interno
m_io_filtros["comercio",1:num_paises_setores,1:(num_output-1)
             ][(pais_cols_matriz - pais_lins_matriz)!=0] <- 1

rm(pais_cols_matriz, pais_lins_matriz)
