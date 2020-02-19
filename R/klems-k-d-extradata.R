#Baixa, explora e processa os dados de KLEMS disponíveis de capital
#Download, explore and process data on Capital from EU KLEMS 

#library tabulizer - IMPORTAR pdf
library(tabulizer)

#data tidying - limpiar datos
library(dplyr)
library(tidyr)

# Overall methodology of EUKLEMS
#http://www.euklems.net/data/overview_07i.pdf

#link to detailed last revision methodology with depreciation rates used as source to KLEMS - and WIOD
deprateurl <- "https://euklems.eu/wp-content/uploads/2019/10/Methodology.pdf"


#Download methodology to temporary file
klemsf <- tempfile()
download.file(deprateurl,klemsf)


#import k asset types nomenclature

#extract table of variables capital assets
#to help find areas
#tabulizer::locate_areas(klemsf, pages = 37)

kassets <- extract_tables(klemsf, guess = FALSE, pages = 37, area = list(c(229, 64, 387, 510)), 
                          method = "decide", output = "data.frame")[[1]]

kassets <- separate(kassets, "Capital.stock.net..curr.replac.costs..NAC.mn", into = c("Code","Variable"),
                    sep = " ", remove = T , extra = "merge")

#import depreciation rate table from the document above
#extract table from pdf
drate <- extract_tables(klemsf, pages = 52, output = "data.frame")[[1]]
drate <- separate(drate,"Appendix.Table.A.2...Depreciation.rates", 
                            into = c("Sort_ID","indnr","code","IT", "CT", "Soft_DB"),
                            sep = " ", remove = T, convert = T, extra = "merge")
colnames(drate) <- drate[1,]
drate <- drate[-1,]
drate[,4:length(drate)] <- sapply(drate[,4:length(drate)],as.numeric)



##### Import conversion tables from KLEMS

#Conversion table KLEMS 2017 - KLEMS 2019

conv1719 <- extract_tables(klemsf,pages = 51, output = "data.frame", guess = F,
                           area = list(c(214.57421,53.48661,748.45287,525.88860)))[[1]]

conv1719 <- separate(conv1719,"EU.KLEMS.2019..EU.KLEMS.2017.industries",
                     sep = " ", extra = "merge", remove = T, convert = T, 
                     into = c("EUKLEMS19","EUKLEMS17","INDUSTRY") )



#### Other references for future exploration

#Última versão
#https://euklems.eu/


###Maravilha já tem o arquivo no formato R!
#http://euklems.eu/bulk/Statistical_Capital.rds

#PENÚltima versão

#http://www.euklems.net/TCB/2018/ALL_capital_17i.txt

#Versão de 2007
#2007 atualizada 2009-2011
#http://www.euklems.net/data/09i/all_capital_09I.txt

#Inicial
#http://www.euklems.net/euk07I.shtml

#http://www.euklems.net/data/07i/all_countries_07I.txt
#http://www.euklems.net/data/07i/all_countries_alt_07I.txt

#Outras KLEMS - a futuro
#http://www.worldklems.net/data.htm
#Da América Latina
#http://laklems.net/

#metodologia de 'serviços de capital' na página 5
#http://www.euklems.net/data/overview_07i.pdf



