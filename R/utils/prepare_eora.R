source("R/lib/functions.R")

anos <- 1990:2016
versao_source <- "Eora26"
dir.create(paste0("source_data/",versao_source), showWarnings = FALSE)


# Parâmetros dessa base.
labels_Q <- 
  read.delim("temp/labels_Q.txt", 
             row.names = NULL, 
             header = FALSE)

labels_T <- 
  read.delim("temp/labels_T.txt", 
             row.names = NULL, 
             header = FALSE)

labels_FD <- 
  read.delim("temp/labels_FD.txt", 
             row.names = NULL, 
             header = FALSE)

lins_sea <- c(grep("Empl", labels_Q[,1]),
              grep("added", labels_Q[,1]))

# leitura de parâmetros a partir dos dados carregados
nums <- NULL
nums$rows <- nrow(labels_T[labels_T$V2!="ROW",])
nums$col_demand <-  nrow(labels_FD[labels_FD$V2!="ROW",])
nums$cols_intermediate_inputs = nrow(labels_T)-1
nums$rows_factors <- length(lins_sea)

lists <- NULL
lists$countries <- unique(labels_T[1:nums$rows,2])
lists$sectors <- unique(labels_T[1:nums$rows,4])
lists$demand <- unique(labels_FD[,4])

lists$inputs <- c(paste0(labels_T[1:nums$rows,2],
                         ".",
                         labels_T[1:nums$rows,4]))

lists$output <- c(paste0(labels_T[1:nums$rows,2],
                         ".",
                         labels_T[1:nums$rows,4]),
                  paste0(labels_FD[labels_FD$V2!="ROW",2],
                         ".",
                         labels_FD[labels_FD$V2!="ROW",4]))

lists$years <- as.character(anos)
lists$sea_variables <- paste0(labels_Q[lins_sea,1],".",labels_Q[lins_sea,2])

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
  sea_source[y,,,] <- 
    read.delim(file = paste0("temp/Eora26_",y,"_bp_Q.txt"),
               header = FALSE, row.names = NULL)[lins_sea,1:nums$input] %>%
    unlist() %>%
    as.numeric()
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

# cria m_io para cada ano (ainda precisa automatizar para número variável
# de anos)
y <- 1
for (y in 1:nums$years) {
  temp_year <- as.character(1989 + y)
  m_io_source <- array(NA, dim = c(1,
                                   nums$input,
                                   nums$output),
                       dimnames = list(temp_year,
                                       lists$input,
                                       lists$output))
  
  gc(reset = TRUE)
  
  # lê o arquivo de intermediate input do ano específico
  print(paste0("loading  intermediate inputs of year ",temp_year,"..."))
  m_io_source[1,1:nums$input,1:nums$input] <- 
    read.delim(file = paste0("temp/Eora26_",temp_year,"_bp_T.txt"),
               header = FALSE, row.names = NULL)[1:nums$input,1:nums$input] %>%
    unlist() %>%
    as.numeric() / 1000

  gc(reset = TRUE)

  # load demand file
  print(paste0("loading  demands of year ",temp_year,"..."))
  m_io_source[1,1:nums$input,(nums$input+1):nums$output]  <- 
    read.delim(file = paste0("temp/Eora26_",temp_year,"_bp_FD.txt"),
               header = FALSE, row.names = NULL)[1:nums$input,1:nums$col_demand] %>%
    unlist() %>%
    as.numeric() / 1000
  
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
