#Download and import main EU KLEMS database on capital stocks

###R format available euklems data on capital stock by sector by country by year

kkurl <- "http://euklems.eu/bulk/Statistical_Capital.rds"
f <- tempfile()
download.file(kkurl, klemsk)

euklems <- readRDS(f)
#rm(f)


#Converter dados - verificar se precisamos covnerter para setores

#euklems <- euklems %>% pivot_longer(-1:-6,names_to = "var", values_to = "value")

#estimar matrizes de depreciação de capital - K(t+1) = k - D + I   
# D = k -k(t+1) + I

#euklemsl <- euklems %>% pivot_wider(names_from = var, values_from = value) 

euklemsK <- euklems[grepl("K_",euklems$var),]

euklemsI <- euklems[grepl("I_",euklems$var),]

euklemsI$var <- gsub("^I","K",euklemsI$var)

euklemski <- euklemsK %>% left_join(euklemsI, by = names(euklemsK)[-length(names(euklemsK))])

euklemsK$year <- euklemsK$year -1

euklemsd <- euklemski %>% left_join(euklemsK, by = names(euklemsK)[-length(names(euklemsK))])

euklemsd$depreciation <- euklemsd$value.x+euklemsd$value.y -euklemsd$value


matrizd <- euklemsd[,c(1,5,6,7,11)]

matrizd$paisetor <- paste(matrizd$country,matrizd$code)



#exportar isso como RDS