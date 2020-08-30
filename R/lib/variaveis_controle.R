# Variáveis de controle

print("carregando variaveis de controle...")

source('R/lib/paises_e_setores.R')
pais_cols <- pais_lins

# Obtém informações sobre as colunas de demanda das famílias
demanda<-read.csv2(paste0(getwd(),"/sourcedata/",versao,"/demanda.csv"))
num_demanda <- dim(demanda)[1]
col_fbcf <- tamanho + demanda[demanda == 'Gross fixed capital formation',3] + ((paises[,2]-1)*num_demanda)
col_demanda_final <- tamanho + demanda[demanda == 'Final consumption expenditure by households',3] + ((paises[,2]-1)*num_demanda)
pais_cols <- c(pais_cols, rep(paises[,2], each = num_demanda))