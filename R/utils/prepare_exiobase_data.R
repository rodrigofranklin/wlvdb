library(abind)
library(lubridate)
# Primeira carga de leitura somente para buscar os parâmetros dessa base.
demand <- read.delim(file = "temp/1995/Y.txt", header = FALSE)
factors <- read.delim(file = "temp/1995/F.txt", header = FALSE, nrows = 26)
intermediate_inputs <- read.delim(file = "temp/1995/Z.txt", header = FALSE)

# leitura de parâmetros a partir dos dados carregados
nums <- NULL
nums$rows <- nrow(demand)
nums$col_demand <-  ncol(demand)
nums$cols_intermediate_inputs = ncol(intermediate_inputs)
nums$rows_factors <- nrow(factors)

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

lists$years <- as.character(1995:2021)
lists$sea_variables <- 
  c(unique(factors[4:nums$rows_factors,1]))

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
  factors <- read.delim(file = paste0("temp/",y,"/F.txt"),
                        header = FALSE,
                        nrows = 26)
  
  # adiciona seus dados à sea_source
  print(paste0("copying ",y,"..."))
  for (x in lists$sea_variables) {
    sea_source[y,x,,] <- 
      as.numeric(factors[factors[,1]==x,2:ncol(factors)])
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

# preenche as m_io de z em z.
# z <- 1
# for (y in 1:9) {
#   temp_year <- as.character(1994 + (1:z) + (z*(y-1)))
#   m_io_source <- array(NA, dim = c(z,
#                                    nums$input,
#                                    nums$output),
#                        dimnames = list(temp_year,
#                                        lists$input,
#                                        lists$output))
# 
#   for (x in 1:3) {
#     # lê o arquivo de intermediate input do ano específico
#     print(paste0("loading  intermediate inputs of year ",temp_year[x],"..."))
#     intermediate_inputs <- 
#       read.delim(file = paste0("temp/",temp_year[x],"/Z.txt"),
#                  header = FALSE)
#     
#     # load demand file
#     print(paste0("loading  demands of year ",temp_year[x],"..."))
#     demand <- 
#       read.delim(file = paste0("temp/",temp_year[x],"/Y.txt"),
#                  header = FALSE)
#     
#     # copy intermediate and demand data to m_io
#     print(paste0("copying ",temp_year[x],"..."))
#     temp <- 
#       as.numeric(
#         cbind(
#           intermediate_inputs[4:nums$rows,3:nums$cols_intermediate_inputs],
#           demand[4:nums$rows, 3:nums$col_demand]))
#     # m_io_source[x,,1:nums$input] <- 
#     #   
#     # m_io_source[x,,(nums$input+1):nums$output] <- 
#       
#     
#     # copy gross_output to sea_append
#     sea_append[temp_year[x],1,,] <- rowSums(m_io_source[x,,])
#   }
#   print(paste0("writing ",temp_year[x],"..."))
#   saveRDS(m_io_source, 
#           file = paste0("source_data/exiobase/m_io_",y,".RDS"))
# }

rm(factors, intermediate_inputs, demand)

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
  saveRDS(m_io_source, 
          file = paste0("source_data/exiobase/m_io_",temp_year,".rds"))
}

# append
sea_source <- abind(sea_source, sea_append, along = 2)


# Salda dados e parâmetros
saveRDS(sea_source, 
        file = paste0("source_data/exiobase/sea.rds"))

write.table(lists$demand, "source_data/exiobase/demand.csv", 
           row.names = FALSE, col.names = "demand", sep = ";")

write.table(lists$countries, file = "source_data/exiobase/countries.csv", 
           row.names = FALSE, col.names = "country.source", sep = ";")

write.table(lists$sectors, "source_data/exiobase/sectors.csv", 
           row.names = FALSE, col.names = "sector.source", sep = ";")

# limpar variáveis e arquivos
