require("devtools")
install_github("bquast/wiod")
library("wiod")
library(readxl)
library(dplyr)

sf <- "WIOD_SEA_Nov16.xlsx"
datadir <- "sourcedata/"
dfdir <- paste0(datadir,sf)
seaurl <- paste0("http://www.wiod.org/protected3/data16/SEA/",dfdir)
download.file(seaurl,sf)

sea2016 <- read_xlsx(dfdir,"DATA")

sea2016 %>% filter (variable == "K", grepl("CHL",country))
