# Variáveis de controle

print("carregando variaveis de controle...")

# Carrega a lista de países
paises <- read.csv2(file = paste0(getwd(),"/sourcedata/",versao,"/paises.csv"),
                    row.names = 1, check.names = F)
lista_paises <- paises$Legenda
num_paises <- length(lista_paises)

# Carrega a lista de setores
lista_setores <- setores$Code
num_setores <- length(lista_setores)

# Identifica as linhas
linhas <- data.frame(pais = rep(lista_paises, each = num_setores))
linhas$setor <- lista_setores
linhas$produtivo <- setores$produtivo
linhas$num_pais <- match(linhas$pais, paises$Legenda)
linhas$num_setores <- match(linhas$setor, setores$Code)

lista_paises_setores <- paste0(linhas$pais,".",linhas$setor)
num_paises_setores <- num_setores*num_paises

# Obtém informações sobre as colunas de demanda das famílias
demanda<-read.csv2(paste0(getwd(),"/sourcedata/",versao,"/demanda.csv"))
num_demanda <- dim(demanda)[1]

#identifica as colunas
colunas <- data.frame(pais = c(linhas$pais, 
                               rep(lista_paises, each = num_demanda)))
colunas$setor <- c(linhas$setor, rep(demanda$WIOD, times = num_paises))
colunas$num_pais <- match(colunas$pais, paises$Legenda)

# Define listas dos parâmetros
lista_anos <- names(sea_fonte[,1,1,1])
lista_input <- names(m_io_fonte[1,,1])
lista_output <- names(m_io_fonte[1,1,])
num_anos <- length(lista_anos)
num_input <- length(lista_input)
num_output <- length(lista_output)


