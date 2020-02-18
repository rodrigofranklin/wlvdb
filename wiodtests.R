require("devtools")
install_github("bquast/wiod")
install.packages("gvc")
library("wiod")
library("gvc")
library(readxl)
library(dplyr)
library(decompr)

#Tabela com taxas de depreciação
# http://www.wiod.org/publications/source_docs/SEA_Sources.pdf

wiod.list <- list()
for(this.year in 2000:2014) {
  wiod.list[[as.character(this.year)]] <- getWIOT(period = this.year,
                                                     format = "list")
}

wiod.wide <- list()
for(this.year in 2000:2014) {
  wiod.wide[[as.character(this.year)]] <- getWIOT(period = this.year,
                                                  format = "wide")
}

wiod1995 <- wiot_1995

sf <- "WIOD_SEA_Nov16.xlsx"
datadir <- "sourcedata/"
dfdir <- paste0(datadir,sf)
seaurl <- paste0("http://www.wiod.org/protected3/data16/SEA/",dfdir)
download.file(seaurl,sf)

sea2016 <- read_xlsx(dfdir,"DATA")

chinak <- sea2016 %>% filter (variable == "K", grepl("CHN",country))

chinak <- chinak[,5:length(chinak)] %>% rowSums()

str(wiod.list$`2014`$F)

View(wiod1995$final)
