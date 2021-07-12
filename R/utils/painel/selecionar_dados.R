########################################################################
##
## Seleciona os dados que serão exibidos no painel (para reduzir uso da
## memória). Todos os dados serão salvos na pasta "dados".
##
## Esse script precisa ser automatizado para facilitar a troca das versões
## presentes no painel (com o intuito de fazermos comparações).
##
########################################################################

## Seleciona versões
#####
versao_13  <- "July14"
versao_resultado_13 <- "oficial_WIOD13"
versao_16  <- "Nov16"
versao_resultado_16 <- "oficial_WIOD16"


## Carrega os dados
#####
paises <- read.csv2(file = "R/utils/painel/dados/paises.csv", 
                    row.names = 1, check.names = F)
num_paises <- dim(paises)[1]

sea_paises_13 <- readRDS(file = paste0("resultados/",versao_resultado_13,"/sea_paises.rds"))
sea_paises_16 <- readRDS(file = paste0("resultados/",versao_resultado_16,"/sea_paises.rds"))

## Cria as listas das dimensões (que serão utilizadas como inputs)
#####
lista_versoes <- c("WIOD13", "WIOD16")
lista_anos <- unique(c(rownames(sea_paises_13[,1,]), rownames(sea_paises_16[,1,])))
lista_variaveis_sea <- unique(c(rownames(sea_paises_13[1,,]), rownames(sea_paises_16[1,,])))
lista_paises <- unique(c(names(sea_paises_13[1,1,]), names(sea_paises_16[1,1,])))
names(lista_paises) <- paises[match(paises[,3], lista_paises),1]

## Mescla os bancos de dados das duas versões em um único arquivo.

## Mescla o arquivo sea_paises
#####
sea_paises <- array(data = NA, dim = c(length(lista_versoes),
                                       length(lista_anos),
                                       length(lista_variaveis_sea),
                                       length(lista_paises)),
                    dimnames = list(lista_versoes,
                                    lista_anos,
                                    lista_variaveis_sea,
                                    lista_paises))

sea_paises["WIOD13",
           match(names(sea_paises_13[,1,1]), lista_anos),
           match(names(sea_paises_13[1,,1]), lista_variaveis_sea),
           match(names(sea_paises_13[1,1,]), lista_paises)] <- sea_paises_13[,,]
sea_paises["WIOD16",
           match(names(sea_paises_16[,1,1]), lista_anos),
           match(names(sea_paises_16[1,,1]), lista_variaveis_sea),
           match(names(sea_paises_16[1,1,]), lista_paises)] <- sea_paises_16[,,]

### Seleciona os dados das matrizes insumo-produtos
## m_io_13
m_io_resultados_13 <- 
  readRDS(file = paste0("resultados/",versao_resultado_13,"/m_io.rds"))
m_io_fonte_13 <- 
  readRDS(file = paste0("sourcedata/",versao_13,"/m_io.rds"))
m_io_filtros_13 <- 
  readRDS(file = paste0("resultados/",versao_resultado_13,"/m_io_filtros.rds"))

lista_anos <- names(m_io_resultados_13[,1,1,1])
lista_variaveis_io <- c("exportacoes_pm", "exportacoes_valores", 
                     "transferencias_valores")
lista_input <- names(m_io_resultados_13[1,1,,1])
lista_output <- names(m_io_resultados_13[1,1,1,])

num_anos <- length(lista_anos)
num_variaveis_io <- length(lista_variaveis_io)
num_input <- length(lista_input)
num_output <- length(lista_output)

m_io_13 <- array(data = NA, dim = c(num_anos,
                                    num_variaveis_io,
                                    num_input,
                                    num_output),
                 dimnames = list(lista_anos,
                                 lista_variaveis_io,
                                 lista_input,
                                 lista_output))

m_io_13[,"exportacoes_pm",,] <- m_io_fonte_13[lista_anos,,] * 
  rep(m_io_filtros_13["comercio",,], each = num_anos)

m_io_13[,"exportacoes_valores",,] <- 
  m_io_resultados_13[lista_anos,"valores",,] * 
  rep(m_io_filtros_13["comercio",,], each = num_anos)

m_io_13[,"transferencias_valores",,] <- 
  m_io_resultados_13[lista_anos,"transferencias_valores",,]

## m_io_16
m_io_resultados_16 <- 
  readRDS(file = paste0("resultados/",versao_resultado_16,"/m_io.rds"))
m_io_fonte_16 <- 
  readRDS(file = paste0("sourcedata/",versao_16,"/m_io.rds"))
m_io_filtros_16 <- 
  readRDS(file = paste0("resultados/",versao_resultado_16,"/m_io_filtros.rds"))

lista_anos <- names(m_io_resultados_16[,1,1,1])
lista_input <- names(m_io_resultados_16[1,1,,1])
lista_output <- names(m_io_resultados_16[1,1,1,])

num_anos <- length(lista_anos)
num_input <- length(lista_input)
num_output <- length(lista_output)

m_io_16 <- array(data = NA, dim = c(num_anos,
                                    num_variaveis_io,
                                    num_input,
                                    num_output),
                 dimnames = list(lista_anos,
                                 lista_variaveis_io,
                                 lista_input,
                                 lista_output))

m_io_16[,"exportacoes_pm",,] <- m_io_fonte_16[lista_anos,,] * 
  rep(m_io_filtros_16["comercio",,], each = num_anos)

m_io_16[,"exportacoes_valores",,] <- 
  m_io_resultados_16[lista_anos,"valores",,] * 
  rep(m_io_filtros_16["comercio",,], each = num_anos)

m_io_16[,"transferencias_valores",,] <- 
  m_io_resultados_16[lista_anos,"transferencias_valores",,]


## Salva informações na pasta do painel
#####

saveRDS(sea_paises, file = "R/utils/painel/dados/sea_paises.rds")
saveRDS(m_io_13, file = "R/utils/painel/dados/m_io_13.rds")
saveRDS(m_io_16, file = "R/utils/painel/dados/m_io_16.rds")

## Copiando demais arquivos

current.folder <- "C:/Where my files currently live"
new.folder <- "H:/Where I want my files to be copied to"
# find the files that you want
lista_arquivos <- 
  c(paste0("resultados/", versao_resultado_13,"/m_paises.rds"),
    paste0("resultados/", versao_resultado_13,"/sea_setores.rds"),
    paste0("resultados/", versao_resultado_16,"/m_paises.rds"),
    paste0("resultados/", versao_resultado_16,"/sea_setores.rds"))
lista_destino <- 
  c("R/utils/painel/dados/m_paises_13.rds",
    "R/utils/painel/dados/sea_setores_13.rds",
    "R/utils/painel/dados/m_paises_16.rds",
    "R/utils/painel/dados/sea_setores_16.rds")
# copy the files to the new folder
file.copy(lista_arquivos, lista_destino, overwrite = TRUE)
