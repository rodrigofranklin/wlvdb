#####
## global.R:
## Painel para exibição dos dados do Banco de Dados Valor Trabalho Mundial
## - Leitura dos dados
## - Preparação das variáveis para exibição
#####

## Carrega pacotes
source("requ.R")

## Carrega os dados
#####
paises <- read.csv2(file = "dados/paises.csv", row.names = 1, check.names = F)
num_paises <- dim(paises)[1]

sea_paises <- readRDS(file = "dados/sea_paises.rds")
m_paises_13 <- readRDS(file = "dados/m_paises_13.rds")
m_paises_16 <- readRDS(file = "dados/m_paises_16.rds")

sea_setores_13 <- readRDS(file = "dados/sea_setores_13.rds")
sea_setores_16 <- readRDS(file = "dados/sea_setores_16.rds")

m_io_13 <- readRDS(file = "dados/m_io_13.rds")
m_io_16 <- readRDS(file = "dados/m_io_16.rds")

varst <- read_csv2("dados/vars.csv")
setorest <- read_csv2("dados/setores_t.csv")
## Cria demais variáveis

lista_versoes <- names(sea_paises[,1,1,1])
lista_anos <- names(sea_paises[1,,1,1])
lista_variaveis_sea <- names(sea_paises[1,1,,1])
lista_paises <- paises[,3]
names(lista_paises) <- paises[match(paises[,3], lista_paises),1]

names(lista_variaveis_sea) <- (tibble(var=lista_variaveis_sea)%>%left_join(varst)%>%select(pt))[[1]]

ano_min <- as.numeric(lista_anos[1])
ano_max <- as.numeric(last(lista_anos))
