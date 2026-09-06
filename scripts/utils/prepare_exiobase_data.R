library(abind)
library(lubridate)
source("scripts/lib/functions.R")

# Alterado para a versão 3.9.5
# Download dos arquivos do exiobase, conforme versão disponível no zenodo

anos <- 1995:2022

versao_source <- "exiobase395"
options(timeout=1200)

dir.create(paste0("source_data/",versao_source), showWarnings = FALSE, recursive = TRUE)
dir.create("temp", showWarnings = FALSE, recursive = TRUE)

# Download dos arquivos IOT
pos_file <- "https://zenodo.org/record/14869924/files/IOT_"
pre_file <- "_ixi.zip?download=1"
for (ano in as.character(anos)) {
  download.file(paste0(pos_file,ano,pre_file),
                paste0("temp/",ano,".zip"),
                mode="wb")
}

# Extrai os arquivos Y, Z e F (employment e factor inputs)
for (ano in as.character(anos)) {
  myzipfile <- paste0("temp/",ano,".zip")
  myfiles <- c("Y.txt",
               "Z.txt", # Versão 3.7 não possui Z.txt
               "employment/F.txt",
               "factor_inputs/F.txt")
  myexdir <- paste0("temp/",ano)
  
  dir.create(myexdir, showWarnings = FALSE)
  
  unzip(myzipfile, files = myfiles, junkpaths = FALSE, exdir = myexdir)
}

# Primeira carga de leitura somente para buscar os parâmetros dessa base.
demand <- read.delim(file = "temp/1995/Y.txt", header = FALSE)
factors <- read.delim(file = "temp/1995/factor_inputs/F.txt", header = FALSE)
employment <- read.delim(file = "temp/1995/employment/F.txt", header = FALSE)
intermediate_inputs <- read.delim(file = "temp/1995/Z.txt", header = FALSE)



# leitura de parâmetros a partir dos dados carregados
nums <- NULL
nums$rows <- nrow(demand)
nums$col_demand <-  ncol(demand)
nums$cols_intermediate_inputs = ncol(intermediate_inputs)
nums$rows_factors <- nrow(factors)
nums$rows_employment <- nrow(employment)

lists <- NULL
lists$countries <- unique(demand[4:nums$rows,1])
lists$sectors <- unique(demand[4:nums$rows,2])
lists$demand <- unname(unique(t(demand[2,3:nums$col_demand]))[,1])

lists$inputs <- c(paste0(intermediate_inputs[4:nums$rows,1],
                        ".",
                        intermediate_inputs[4:nums$rows,2]))

lists$output <- c(paste0(intermediate_inputs[4:nums$rows,1],
                         ".",
                         intermediate_inputs[4:nums$rows,2]),
                  paste0(demand[1,3:nums$col_demand],
                         ".",
                         demand[2,3:nums$col_demand]))

lists$years <- as.character(anos)
lists$sea_variables <- 
  c(unique(factors[4:nums$rows_factors,1]),
    unique(employment[4:nums$rows_employment,1]))

nums$countries <- length(lists$countries)
nums$sectors <- length(lists$sectors)
nums$input <- length(lists$inputs)
nums$output <- length(lists$output)
nums$years <- length(lists$years)
nums$sea_variables <- length(lists$sea_variables)

# alocação da variável SEA
sea_source <- array(NA, dim = c(nums$years, 
                               nums$sea_variables,
                               nums$sectors,
                               nums$countries),
                   dimnames = list(lists$years,
                                   lists$sea_variables,
                                   lists$sectors,
                                   lists$countries))

# Preenche todos os dados da SEA de uma única vez
for (y in lists$years) {
  # lê o arquivo do ano específico
  print(paste0("loading  factors of year ",y,"..."))
  factors <- read.delim(file = paste0("temp/",y,"/factor_inputs/F.txt"),
                        header = FALSE)
  
  # adiciona seus dados à sea_source
  print(paste0("copying ",y,"..."))
  for (x in lists$sea_variables) {
    sea_source[y,x,,] <- 
      as.numeric(factors[factors[,1]==x,2:ncol(factors)])
  }
  
  print(paste0("loading  employment of year ",y,"..."))
  employment <- read.delim(file = paste0("temp/",y,"/employment/F.txt"),
                        header = FALSE)
  
  # adiciona seus dados à sea_source
  print(paste0("copying ",y,"..."))
  for (x in lists$sea_variables) {
    sea_source[y,x,,] <- 
      as.numeric(employment[employment[,1]==x,2:ncol(employment)])
  }
}

# create temporary sea variable to future append
sea_append <- array(NA, dim = c(nums$years, 
                                1,
                                nums$sectors,
                                nums$countries),
                    dimnames = list(lists$years,
                                    "gross_output_mp",
                                    lists$sectors,
                                    lists$countries))


rm(factors, employment, intermediate_inputs, demand)

# cria m_io para cada ano (ainda precisa automatizar para número variável
# de anos)
for (y in 1:nums$years) {
  temp_year <- as.character(1994 + y)
  m_io_source <- array(NA, dim = c(1,
                                   nums$input,
                                   nums$output),
                       dimnames = list(temp_year,
                                       lists$input,
                                       lists$output))

  gc(reset = TRUE)
  
  # lê o arquivo de intermediate input do ano específico
  print(paste0("loading  intermediate inputs of year ",temp_year,"..."))
  m_io_source[1,,1:nums$input] <-
    as.numeric(
      unlist(
        read.delim(
          file = paste0("temp/",temp_year,"/Z.txt"),
          header = FALSE)[4:nums$rows,3:nums$cols_intermediate_inputs]
      )
    )
  
  gc(reset = TRUE)

  # load demand file
  print(paste0("loading  demands of year ",temp_year,"..."))
  m_io_source[1,,(nums$input+1):nums$output] <- 
    as.numeric(
      unlist(
        read.delim(
          file = paste0("temp/",temp_year,"/Y.txt"),
          header = FALSE)[4:nums$rows, 3:nums$col_demand]
      )
    )
  
  gc(reset = TRUE)

  # copy gross_output to sea_append
  sea_append[temp_year,1,,] <- rowSums(m_io_source[1,,])

  print(paste0("writing ",temp_year,"..."))
  write_fst_array(m_io_source, 
          file = paste0("source_data/",versao_source,"/m_io_",temp_year,".fst"))
}

# append
sea_source <- abind(sea_source, sea_append, along = 2)


# Salva dados e parâmetros
write_fst_array(sea_source, 
        file = paste0("source_data/",versao_source,"/sea.fst"))

write.table(lists$demand, paste0("source_data/",versao_source,"/demand.csv"), 
           row.names = FALSE, col.names = "demand", sep = ";")

write.table(lists$countries, file = paste0("source_data/",versao_source,"/countries.csv"), 
           row.names = FALSE, col.names = "country.source", sep = ";")

write.table(lists$sectors, paste0("source_data/",versao_source,"/sectors.csv"), 
           row.names = FALSE, col.names = "sector.source", sep = ";")

# limpar variáveis e arquivos
