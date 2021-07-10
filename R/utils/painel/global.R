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

varst <- read_csv2("dados/vars.csv")
setorest <- read_csv2("dados/setores_t.csv")
## Cria demais variáveis

lista_versoes <- rownames(sea_paises[,,1,1])
lista_anos <- rownames(sea_paises[1,,,1])
lista_variaveis_sea <- rownames(sea_paises[1,1,,])
lista_paises <- paises[,3]
names(lista_paises) <- paises[match(paises[,3], lista_paises),1]

names(lista_variaveis_sea) <- (tibble(var=lista_variaveis_sea)%>%left_join(varst)%>%select(pt))[[1]]

ano_min <- as.numeric(lista_anos[1])
ano_max <- as.numeric(last(lista_anos))

agregado <- function(matriz, ano, var, pais) {
  matriz[as.character(ano), var, pais, ]
}

limitar_colunas <- function(matriz, colunas) {
  matriz[, colunas]
}

encontrar_pais <- function(matriz, pais, fun) {
  matriz[1,1, , ] %>% 
    fun() %>% 
    str_which(pais)
}

## Funções a reutilizar
plotaserie <- function(dados,perc=F) {
  ##produz data.frame com cada versão para juntar
  
  if(length(dim(dados))>2){
    dados <- as.data.table(dados)
    ifelse(ncol(dados)==5,
           names(dados) <- c("bd","ano","indicador","pais","valor"),
           names(dados) <- c("bd","ano","pais","valor")
    )
    dados <- dados %>% mutate(ano = as.Date(paste0("01/01/",ano),
                                            tryFormats="%d/%m/%Y"),
                              across(c(-ano,-valor),as.factor))
  }else{
    bds <- names(dados[,1])
    anos <- names(dados[1,])
    dados <- as.data.table(t(dados))
    dados$ano <- as.Date(paste0("01/01/",anos),
                         tryFormats="%d/%m/%Y")
    dados <- dados%>%pivot_longer(-ano,names_to = "bd",values_to="valor")%>%
      mutate(bd=as.factor(bd))
  }
  
  ifelse(ncol(dados)==3,
         p <- ggplot(dados,aes(x=ano,y=valor,col=bd)),
         p <- ggplot(dados,aes(x=ano,y=valor,col=pais,linetype=bd)))
  p+geom_line(size = 1) +
    scale_y_continuous(labels = comma_format(big.mark = ".", decimal.mark = ","))+
    theme_minimal()
  
  ggplotly()
  
}
milhares <- function(x){prettyNum(x,big.mark = ".",decimal.mark = ",")}
tabmil <- function(x) {
  x <- as.data.table(x,keep.rownames="var")%>%mutate(across(where(is.numeric),milhares))
}