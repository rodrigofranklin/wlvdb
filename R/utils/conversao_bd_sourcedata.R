########################################################################
###
### Script padrão converter o BD em array multidimensional para os 
### dados originais
###
########################################################################

###
### Variáveis de versão
###
 versao = versao_fonte  <- "July14"
#versao = versao_fonte <- "Nov16"

# Carrega variáveis de controle
source('R/lib/variaveis_controle.R')
paises_setores <- data.frame(country=rep(paises$Legenda,each=num_setores))
paises_setores$description <- setores$Setor
paises_setores$code <- setores$Code
paises_demanda <- data.frame(country=rep(paises$Legenda,each=num_demanda))
paises_demanda$description <- demanda$Demanda
paises_demanda$code <- demanda$WIOD



#### Conversão das contas socioeconômicas
# Carrega as informações das contas socioeconômicas
source("R/lib/importar_sea_variaveis.R")

# Inicializa array
lista_anos <- as.character(anos)
lista_paises <- unique(sea_completo[,1])
lista_variaveis_sea <- unique(sea_completo[,2])
lista_setores <- unique(sea_completo[,4])

num_anos <- length(lista_anos)
num_variaveis_sea <- length(lista_variaveis_sea)
num_paises <- length(lista_paises)
num_setores <- length(lista_setores)

sea_bd <- array(NA,
                    dim = c(num_anos,
                            num_variaveis_sea,
                            num_paises,
                            num_setores),
                    dimnames = list(lista_anos,
                                    lista_variaveis_sea,
                                    lista_paises,
                                    lista_setores))

# Salva as informações no novo formato
x <- 1:num_anos
for (y in (1:(num_paises*num_setores*num_variaveis_sea))) {
  sea_bd[x,sea_completo[y,2],sea_completo[y,1],sea_completo[y,4]] <- as.matrix(sea_completo[y,(x+4)])
}

# Salva novo formato no disco
saveRDS(sea_bd,paste0(getwd(),"/sourcedata/",versao,"/sea.rds"))


#### Conversão das IOT

# Iniciaçiza array
lista_input <- c(paste0(paises_setores$country,".",paises_setores$code),
                 "TOT.II_fob",
                 "TOT.TXSP",
                 "TOT.EXP_adj",
                 "TOT.PURR",
                 "TOT.PURNR",
                 "TOT.VA",
                 "TOT.IntTTM",
                 "TOT.GO")

lista_output <- c(paste0(paises_setores$country,".",paises_setores$code),
                  paste0(paises_demanda$country,".",paises_demanda$code),
                  "TOT.GO")

m_io <- array(NA,
              dim = c(num_anos,
                      length(lista_input),
                      length(lista_output)),
              dimnames = list(lista_anos,
                              lista_input,
                              lista_output))

# Salva as informações no novo formato
for (ano in lista_anos) {
  #Carrega os dados brutos da versão especificada
  source("R/lib/dados_brutos.R")

  ###
  ### Área para os cálculos desejados
  ###
  m_io[ano,,] <- m_wio
}

# Salva novo formato no disco
saveRDS(m_io,paste0(getwd(),"/sourcedata/",versao,"/m_io.rds"))