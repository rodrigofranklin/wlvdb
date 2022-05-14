br <- list.files(path=getwd(),pattern = "started")
Sys.umask("002")
if(length(br) == 0) {
  cat("installing and loading required packages...")
  packages <-  c("ggplot2",
                 "dplyr",
                 "magrittr",
                 "R.matlab",
                 "writexl",
                 "readxl",
                 "doParallel",
                 "abind",
                 "REdaS",
                 "dineq",
                 "MLmetrics",
                 "foreach",
                 "lubridate",
                 "tidyverse",
                 "fst",
                 "countrycode")
  br <- "https://cloud.r-project.org"
  dipa <- setdiff(packages, rownames(utils::installed.packages())) 
  if (length(dipa)) utils::install.packages(dipa,repos = br)  
  br <- lapply(packages, require, character.only = T, quietly = T)
  if (sum(unlist(br))
      == length(packages)) {
    print("Packages loaded successfully")
  }
  
  print("Triggering code update from main linked source")
  system2("git",args = "pull")
  
  source("R/main.R")
  cat("\n\n\n\n\n\n
##################################################################
#                                                                #
#                                                                #
#   Bienvenidx a la Base de Datos de Valores-Trabajo Mundiales   #
#   Bem-vindx ao Banco de Dados de Valores-Trabalho Mundiais     #
#         Welcome to the World Labour Values Database            #
#                                                                #
##################################################################
\n"
      )
  cat(
"Función get_wlv (de R/main.R) cargada. Prueba get_wlv(\"alternative_1\")
Função get_wlv (de R / main.R) carregada. Teste get_wlv(\"alternative_1\")
get_wlv function(from R / main.R) loaded. Test get_wlv(\"alternative_1\")
  ")
  rm(packages)
  rm(dipa)
  rm(br)
}



