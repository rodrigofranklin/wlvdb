  pacotes <-  c("ggplot2","zoo","readxl","tidyverse","dplyr","tidyr","plotly","lubridate","readODS")
pacotesnovos <- pacotes[ !( pacotes %in% installed.packages()[ , "Package" ] ) ]
if( length( pacotesnovos ) ) install.packages( pacotesnovos )
 

 sapply(pacotes, function (x) {
   suppressPackageStartupMessages(require(x[[1]],character.only = T))}) 
rm(pacotes)
cat("Bienvenido a World Labour Values Database")
