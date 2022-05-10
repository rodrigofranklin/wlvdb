br <- list.files(path=getwd(),pattern = "started")

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
                 "MLmetrics")
  br <- "https://cloud.r-project.org"
  dipa <- setdiff(packages, rownames(utils::installed.packages())) 
  if (length(dipa)) utils::install.packages(dipa,repos = br)  
  br <- lapply(packages, require, character.only = T, quietly = T)
  if (sum(unlist(br))
      == length(packages)) {
    print("Packages loaded successfully")
  }
  source("R/main.R")
  cat("\n
##################################################################
#                                                                #
#                                                                #
#   Bienvenidx a la Base de Datos Mundial de Valores-Trabajo     #
#   Bem-vindx ao Banco de Dados Mundial de Valores-Trabalho      #
#         Welcome to the World Labour Values Database            #
#                                                                #
##################################################################
"
      )
  cat(
"Función get_wlv (de R/main.R) cargada. Prueba get_wlv(\"alternative_1\")
Função get_wlv (de R / main.R) carregada. Teste get_wlv(\"alternative_1\")
get_wlv function(from R / main.R) loaded. Test get_wlv(\"alternative_1\")
  ")
  rm(packages)
  rm(dipa)

}


rm(br)
