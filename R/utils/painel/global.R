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

sea_paises <- readRDS(file = "dados/sea_paises.RDS")
m_paises_13 <- readRDS(file = "dados/m_paises_13.RDS")
m_paises_16 <- readRDS(file = "dados/m_paises_16.RDS")

sea_setores_13 <- readRDS(file = "dados/sea_setores_13.RDS")
sea_setores_16 <- readRDS(file = "dados/sea_setores_16.RDS")

m_io_13 <- readRDS(file = "dados/m_io_13.RDS")
m_io_16 <- readRDS(file = "dados/m_io_16.RDS")

## Cria demais variáveis

lista_versoes <- rownames(sea_paises[,,1,1])
lista_anos <- rownames(sea_paises[1,,,1])
lista_variaveis_sea <- rownames(sea_paises[1,1,,])
lista_paises <- paises[,3]
names(lista_paises) <- paises[match(paises[,3], lista_paises),1]

ano_min <- as.numeric(lista_anos[1])
ano_max <- as.numeric(last(lista_anos))



## Funções a reutilizar
plotaserie <- function(dados,bdlim=F,perc=F) {
  ##produz data.frame com cada versão para juntar
  verte <- function(x, dt=dados,nome="wiod13"){
    b <- dt[x,]
    a <- data.frame(valor = b,
                    ano = as.Date(paste0("30/06/",as.numeric(names(b))),tryFormats="%d/%m/%Y"),
                    bd = nome)
  }
  
  dwiod <- bind_rows(verte(1),verte(2,nome="wiod16"))
  dwiod$bd <- as.factor(dwiod$bd)
  if(bdlim == T) {
    dwiod <- dwiod[dwiod$bd==input$versao_indicadores,]
  }
  ggplot(dwiod,aes(x=ano,y=valor,col=ifelse(bdlim=F,bd,pais)))+
    geom_line(size = 1) +
    scale_y_continuous(labels = comma_format(big.mark = ".", decimal.mark = ","))+
    theme_minimal()
  
  ggplotly()
  
}