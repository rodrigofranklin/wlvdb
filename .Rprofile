  pacotes <-  c("ggplot2","zoo","readxl","tidyverse","dplyr","tidyr","plotly","lubridate","readODS",
                "shiny","shinydashboard","dashboardthemes","treemap","rnaturalearth","plotly")
pacotesnovos <- pacotes[ !( pacotes %in% utils::installed.packages()[ , "Package" ] ) ]
if( length( pacotesnovos ) ) utils::install.packages( pacotesnovos )
 

 sapply(pacotes, function (x) {
   suppressPackageStartupMessages(require(x[[1]],character.only = T))}) 
rm(pacotes)
cat("Bienvenido a World Labour Values Database")
