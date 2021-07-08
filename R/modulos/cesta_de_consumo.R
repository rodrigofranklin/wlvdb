# Estrutura da cesta de consumo e valor da força de trabalho
# Suposição: a demanda das famílias representa a estrutura da cesta de consumo 
# de todos os trabalhadores de todos os setores

# Cria um array de matrizes contendo a distribuição da cesta de consumo de cada
# setor para cada país. De acordo com nossa suposição, todos os setores de um
# mesmo paíse possuem a mesma estrutura de cesta de consumo (= demanda das
# famílias).
cesta_consumo <- apply(m_io_fonte[,1:num_paises_setores,colunas$setor=="c37"],
               MARGIN = 1, prop.table, margin = 2)
cesta_consumo <- rep(cesta_consumo, each = num_setores)
dim(cesta_consumo) <- c(num_setores, num_setores, num_paises, num_paises, num_anos)
cesta_consumo <- aperm(cesta_consumo, c(5,2,3,1,4))
dim(cesta_consumo) <- c(num_anos, num_paises_setores, num_paises_setores)

# distribui a renda de cada setor conforme a estrutura da cesta de consumo
# (tanto para assalariados quanto para pessoas ocupadas)

remuneracao <- rep(sea_setores[,"salarios",,],
                   times = num_paises_setores)
dim(remuneracao) <- c(num_anos, num_paises_setores, num_paises_setores)
remuneracao <- aperm(remuneracao, c(1,3,2))
remuneracao[is.na(remuneracao)] <- 0

cesta_consumo_assalariados <- remuneracao*cesta_consumo

remuneracao <- rep(sea_setores[,"renda_trabalho",,],
                     times = num_paises_setores)
dim(remuneracao) <- c(num_anos, num_paises_setores, num_paises_setores)
remuneracao <- aperm(remuneracao, c(1,3,2))
remuneracao[is.na(remuneracao)] <- 0

cesta_consumo <- remuneracao*cesta_consumo

rm(remuneracao)
gc()