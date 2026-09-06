source("scripts/lib/wb_wdi_function.R")
gdpsi <- "NY.GDP.MKTP.CN"
gdps <- rel_wbdata(gdpsi,1995)

#2021 not available
if(sum(is.na(gdps[gdps$year == 2021,]$NY.GDP.MKTP.CN))>0){
  gdps <- gdps[gdps$year != 2021,]
}

#include taiwan GDP in LCU (NT dollar)
#ref https://eng.stat.gov.tw/point.asp?index=1
#2022-02-estimates
twlink <- "https://eng.stat.gov.tw/public/data/dgbas03/bs4/ninews_e/11102/t1-1e.ods"
twlink <- "https://eng.stat.gov.tw/public/data/dgbas03/bs4/Statistical%20Tables/table_eng(042a).ods"
f <- tempfile()
download.file(twlink,f)
tw_gdp <- readODS::read_ods(f, skip = 4,col_names = F)

tw_gdp <- tw_gdp[,c(1,5)]


##Formatting compatible with worldbank gdps
names(tw_gdp) <-c("year",gdpsi)

#removing quarters
tw_gdp$year <- as.numeric(tw_gdp$year)

tw_gdp <- tw_gdp[!is.na(tw_gdp$year),]  

tw_gdp$iso2c <- "TW"
tw_gdp$country <- "Taiwan"

tw_gdp <- tw_gdp%>%filter(year > 1994, year < 2022)
gdps <- gdps%>%bind_rows(tw_gdp)

# ##Checking if compatible with exiobase base estimations
# exiobase <- read_fs _array("source_data/exiobase/sea.fst")
# 
# pibx <- function(pais,ano) {
#   a <- data.frame(year = ano, 
#                   iso2c = pais, 
#                   gdp = sum(exiobase[as.character(ano),dimnames(exiobase)[[2]][1:9],,pais]))
#   a
# }
# 
# combs <- expand.grid(dimnames(exiobase)[[1]],dimnames(exiobase)[[4]])
# 
# pibsexiobase <- data.table::rbindlist(mapply(pibx,combs$Var2,combs$Var1, SIMPLIFY = F))
# 
# pibsexiobase$year <- as.numeric(levels(pibsexiobase$year))[pibsexiobase$year]
# 
# ##Get EURO Area Countries, year 2010 ahead
# eurocoun <- c("Belgium"," Germany"," Ireland"," Spain"," France"," Italy"," Luxembourg"," the Netherlands"," Austria"," Portugal"," Finland"," Greece"," Slovenia"," Cyprus"," Malta"," Slovakia"," Estonia"," Latvia"," Lithuania")
# gdpsc <- gdps%>%left_join(pibsexiobase)%>%filter(country %in% eurocoun, year > 2009)
# 
# gdpsc$cpib <- gdpsc$NY.GDP.MKTP.CN/gdpsc$gdp/1000000
# summary(gdpsc[gdpsc,]$cpib)

write_csv2(gdps,"source_data/worldbank/gdps_lcu.csv",)
