##########################################################.
#                                                         #
# Script para cálculo das matrizes IO em valor trabalho   #
#                                                         #
##########################################################.

# Bibliotecas e definições de sistema
library(readxl)
library(doParallel)
my.cluster <- parallel::makeCluster(
  parallel::detectCores() - 1, 
  type = "PSOCK"
)

#######################.
# Parâmetros dos cálculos ----
#######################.

# Define a versão que será calculada. O nome da versão é o mesmo nome da pasta
# onde estão gravadas as informações de inicialização.
versao_resultado <- "oficial_WIOD16"

# Lê os parâmetros presentes na pasta da versão.
source("R/lib/parametros_versao.R")

# Carrega dados das fontes (dados brutos)
source("R/lib/dados_brutos.R")

# Carrega variáveis de controle
source("R/lib/variaveis_controle.R")

# Alocação de variáveis de resultados
source("R/lib/variaveis_resultados.R")

# Cria filtros para leitura das matrizes IO
source("R/lib/filtros_io.R")

# Realiza alguns cálculos preliminares
source("R/modulos/preliminar/preliminar.R")

#######################.
# Pressupostos ----
#######################.

# China
source("R/modulos/pressupostos/china/suposicoes_china.R")

# RoW
source("R/modulos/pressupostos/row/suposicoes_row.R")

# Demais pressupostos
# (ex.: depreciação e problema da redução)
source("R/modulos/pressupostos/pressupostos.R")

#######################.
# Cálculos ----
#######################.

# Transformar
## Transforma os dados monetários em dados em termos de valor.
source("R/modulos/transformar.R")

# Transferências
## Calcula as transferências de valor entre países.
## Reduz as matrizes IO em matrizes País x País.
source("R/modulos/transferencias.R")

# Cestas de consumo
## Calcula as cestas de consumo da população ocupada e assalariada
if (is.null(parametros$cesta_consumo)) {
  source("R/modulos/cesta_de_consumo.R")
} else {
  source(paste0("R/modulos/",parametros$cesta_consumo))
}

# Preços diretos
# source("R/modulos/calculos/precos/precos_diretos.R")

# Preços de produção
# rotacao <- 1
# source("R/modulos/calculos/precos/precos_producao.R")

#######################.
# Dados de resultados
#######################.

# Resultados setoriais
source("R/modulos/calculos/sea_setores.R")

# Resultados nacionais
source("R/modulos/calculos/sea_paises.R")

stopCluster(cl = my.cluster)
closeAllConnections()

#######################.
# Gravação ----
#######################.

caminho <- paste0("resultados/", versao_resultado)

print("Granvando...")
saveRDS(m_io_filtros,paste0(caminho,"/m_io_filtros.RDS"))
saveRDS(m_io,paste0(caminho,"/m_io.RDS"))
saveRDS(m_paises,paste0(caminho,"/m_paises.RDS"))
saveRDS(sea_setores,paste0(caminho,"/sea_setores.RDS"))
saveRDS(sea_paises,paste0(caminho,"/sea_paises.RDS"))
