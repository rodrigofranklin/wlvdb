#Download and import main EU KLEMS database on capital stocks

###R format available euklems data on capital stock by sector by country by year
library(magrittr)
library(dplyr)

### Instruções de download
#kkurl <- "http://euklems.eu/bulk/Statistical_Capital.rds"
#f <- tempfile()
#download.file(kkurl, f)
#euklems <- readRDS(f)
#saveRDS(euklems, file = paste0(getwd(),'/sourcedata/euklems.rds'))
#rm(f)

## Instruções para leitura de dados já baixados
euklems <- readRDS(paste0(getwd(),'/sourcedata/euklems.rds'))


#Converter dados - verificar se precisamos covnerter para setores

#euklems <- euklems %>% pivot_longer(-1:-6,names_to = "var", values_to = "value")

#estimar matrizes de depreciação de capital - K(t+1) = k - D + I   
# D = k -k(t+1) + I

#euklemsl <- euklems %>% pivot_wider(names_from = var, values_from = value) 

euklemsK <- euklems[grepl("K_",euklems$var),]

euklemsI <- euklems[grepl("I_",euklems$var),]

euklemsI$var <- gsub("^I","K",euklemsI$var)

euklemski <- left_join(euklemsK, euklemsI, by = names(euklemsK)[-length(names(euklemsK))])

euklemsK$year <- euklemsK$year -1
euklemsI$year <- euklemsI$year -1



euklemsd <- left_join(euklemski, euklemsK, by = names(euklemsK)[-length(names(euklemsK))])

euklemsd$depreciation <- (euklemsd$value.x+euklemsd$value.y -euklemsd$value)
euklemsd$tx.depreciation <- 1-((euklemsd$value-euklemsd$value.y)/euklemsd$value.x)

euklemsd <- left_join(euklemsd, euklemsI, by = names(euklemsI)[-length(names(euklemsI))])
euklemsd$tx.depreciation.2 <- 1-((euklemsd$value.x.x-euklemsd$value.y.y)/euklemsd$value.x)


matrizd <- euklemsd[,c(1,5,6,7,11)]

matrizd$paisetor <- paste(matrizd$country,matrizd$code)

paises.euklems <- unique(euklems[,1])
setores.euklems <- unique(euklems[,6])
paises.setores <- data.frame(cbind(country=rep(paises.euklems,each=length(setores.euklems)),code=setores.euklems))

ek.i.it[which(ek.k.it[,2]=="TOT"),3]
rep(ek.k.it[which(ek.k.it[,2]=="TOT"),4], each = length(setores.euklems))

ek.k.it <- left_join(paises.setores,euklems[which(euklems[,3]=="K_IT" & euklems[,7]=="1995"),c(1,5,6,8)])
ek.k.it$prop <- ek.k.it$value/rep(ek.k.it[which(ek.k.it[,2]=="TOT"),4], each = length(setores.euklems))
ek.k.it$media <- rep(tapply(ek.k.it$prop, ek.k.it$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.k.it$prop, ek.k.it$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.k.it$prop[is.na(ek.k.it$prop)] <- ek.k.it$media[is.na(ek.k.it$prop)]
ek.i.it <- left_join(paises.setores,euklems[which(euklems[,3]=="I_IT" & euklems[,7]=="1995"),c(1,6,8)])
ek.i.it$prop <- ek.i.it$value/rep(tapply(ek.i.it$value, ek.i.it$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.i.it$media <- rep(tapply(ek.i.it$prop, ek.i.it$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.i.it$prop, ek.i.it$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.i.it$prop[is.na(ek.i.it$prop)] <- ek.i.it$media[is.na(ek.i.it$prop)]

ek.k.ct <- left_join(paises.setores,euklems[which(euklems[,3]=="K_CT" & euklems[,5]!="Agg" & euklems[,5]!="*Agg" & euklems[,7]=="1995"),c(1,6,8)])
ek.k.ct$prop <- ek.k.ct$value/rep(tapply(ek.k.ct$value, ek.k.ct$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.k.ct$media <- rep(tapply(ek.k.ct$prop, ek.k.ct$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.k.ct$prop, ek.k.ct$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.k.ct$prop[is.na(ek.k.ct$prop)] <- ek.k.ct$media[is.na(ek.k.ct$prop)]
ek.i.ct <- left_join(paises.setores,euklems[which(euklems[,3]=="I_CT" & euklems[,5]!="Agg" & euklems[,5]!="*Agg" & euklems[,7]=="1995"),c(1,6,8)])
ek.i.ct$prop <- ek.i.ct$value/rep(tapply(ek.i.ct$value, ek.i.ct$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.i.ct$media <- rep(tapply(ek.i.ct$prop, ek.i.ct$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.i.ct$prop, ek.i.ct$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.i.ct$prop[is.na(ek.i.ct$prop)] <- ek.i.ct$media[is.na(ek.i.ct$prop)]

ek.k.soft <- left_join(paises.setores,euklems[which(euklems[,3]=="K_Soft_DB" & euklems[,5]!="Agg" & euklems[,5]!="*Agg" & euklems[,7]=="1995"),c(1,6,8)])
ek.k.soft$prop <- ek.k.soft$value/rep(tapply(ek.k.soft$value, ek.k.soft$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.k.soft$media <- rep(tapply(ek.k.soft$prop, ek.k.soft$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.k.soft$prop, ek.k.soft$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.k.soft$prop[is.na(ek.k.soft$prop)] <- ek.k.soft$media[is.na(ek.k.soft$prop)]
ek.i.soft <- left_join(paises.setores,euklems[which(euklems[,3]=="I_Soft_DB" & euklems[,5]!="Agg" & euklems[,5]!="*Agg" & euklems[,7]=="1995"),c(1,6,8)])
ek.i.soft$prop <- ek.i.soft$value/rep(tapply(ek.i.soft$value, ek.i.soft$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.i.soft$media <- rep(tapply(ek.i.soft$prop, ek.i.soft$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.i.soft$prop, ek.i.soft$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.i.soft$prop[is.na(ek.i.soft$prop)] <- ek.i.soft$media[is.na(ek.i.soft$prop)]

ek.k.traeq <- left_join(paises.setores,euklems[which(euklems[,3]=="K_TraEq" & euklems[,5]!="Agg" & euklems[,5]!="*Agg" & euklems[,7]=="1995"),c(1,6,8)])
ek.k.traeq$prop <- ek.k.traeq$value/rep(tapply(ek.k.traeq$value, ek.k.traeq$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.k.traeq$media <- rep(tapply(ek.k.traeq$prop, ek.k.traeq$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.k.traeq$prop, ek.k.traeq$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.k.traeq$prop[is.na(ek.k.traeq$prop)] <- ek.k.traeq$media[is.na(ek.k.traeq$prop)]
ek.i.traeq <- left_join(paises.setores,euklems[which(euklems[,3]=="I_TraEq" & euklems[,5]!="Agg" & euklems[,5]!="*Agg" & euklems[,7]=="1995"),c(1,6,8)])
ek.i.traeq$prop <- ek.i.traeq$value/rep(tapply(ek.i.traeq$value, ek.i.traeq$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.i.traeq$media <- rep(tapply(ek.i.traeq$prop, ek.i.traeq$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.i.traeq$prop, ek.i.traeq$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.i.traeq$prop[is.na(ek.i.traeq$prop)] <- ek.i.traeq$media[is.na(ek.i.traeq$prop)]

ek.k.omach <- left_join(paises.setores,euklems[which(euklems[,3]=="K_OMach" & euklems[,5]!="Agg" & euklems[,5]!="*Agg" & euklems[,7]=="1995"),c(1,6,8)])
ek.k.omach$prop <- ek.k.omach$value/rep(tapply(ek.k.omach$value, ek.k.omach$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.k.omach$media <- rep(tapply(ek.k.omach$prop, ek.k.omach$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.k.omach$prop, ek.k.omach$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.k.omach$prop[is.na(ek.k.omach$prop)] <- ek.k.omach$media[is.na(ek.k.omach$prop)]
ek.i.omach <- left_join(paises.setores,euklems[which(euklems[,3]=="I_OMach" & euklems[,5]!="Agg" & euklems[,5]!="*Agg" & euklems[,7]=="1995"),c(1,6,8)])
ek.i.omach$prop <- ek.i.omach$value/rep(tapply(ek.i.omach$value, ek.i.omach$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.i.omach$media <- rep(tapply(ek.i.omach$prop, ek.i.omach$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.i.omach$prop, ek.i.omach$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.i.omach$prop[is.na(ek.i.omach$prop)] <- ek.i.omach$media[is.na(ek.i.omach$prop)]

ek.k.ocon <- left_join(paises.setores,euklems[which(euklems[,3]=="K_OCon" & euklems[,5]!="Agg" & euklems[,5]!="*Agg" & euklems[,7]=="1995"),c(1,6,8)])
ek.k.ocon$prop <- ek.k.ocon$value/rep(tapply(ek.k.ocon$value, ek.k.ocon$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.k.ocon$media <- rep(tapply(ek.k.ocon$prop, ek.k.ocon$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.k.ocon$prop, ek.k.ocon$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.k.ocon$prop[is.na(ek.k.ocon$prop)] <- ek.k.ocon$media[is.na(ek.k.ocon$prop)]
ek.i.ocon <- left_join(paises.setores,euklems[which(euklems[,3]=="I_OCon" & euklems[,5]!="Agg" & euklems[,5]!="*Agg" & euklems[,7]=="1995"),c(1,6,8)])
ek.i.ocon$prop <- ek.i.ocon$value/rep(tapply(ek.i.ocon$value, ek.i.ocon$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.i.ocon$media <- rep(tapply(ek.i.ocon$prop, ek.i.ocon$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.i.ocon$prop, ek.i.ocon$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.i.ocon$prop[is.na(ek.i.ocon$prop)] <- ek.i.ocon$media[is.na(ek.i.ocon$prop)]

ek.k.rstruc <- left_join(paises.setores,euklems[which(euklems[,3]=="K_RStruc" & euklems[,5]!="Agg" & euklems[,5]!="*Agg" & euklems[,7]=="1995"),c(1,6,8)])
ek.k.rstruc$prop <- ek.k.rstruc$value/rep(tapply(ek.k.rstruc$value, ek.k.rstruc$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.k.rstruc$media <- rep(tapply(ek.k.rstruc$prop, ek.k.rstruc$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.k.rstruc$prop, ek.k.rstruc$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.k.rstruc$prop[is.na(ek.k.rstruc$prop)] <- ek.k.rstruc$media[is.na(ek.k.rstruc$prop)]
ek.i.rstruc <- left_join(paises.setores,euklems[which(euklems[,3]=="I_RStruc" & euklems[,5]!="Agg" & euklems[,5]!="*Agg" & euklems[,7]=="1995"),c(1,6,8)])
ek.i.rstruc$prop <- ek.i.rstruc$value/rep(tapply(ek.i.rstruc$value, ek.i.rstruc$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.i.rstruc$media <- rep(tapply(ek.i.rstruc$prop, ek.i.rstruc$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.i.rstruc$prop, ek.i.rstruc$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.i.rstruc$prop[is.na(ek.i.rstruc$prop)] <- ek.i.rstruc$media[is.na(ek.i.rstruc$prop)]

ek.k.oipp <- left_join(paises.setores,euklems[which(euklems[,3]=="K_OIPP" & euklems[,5]!="Agg" & euklems[,5]!="*Agg" & euklems[,7]=="1995"),c(1,6,8)])
ek.k.oipp$prop <- ek.k.oipp$value/rep(tapply(ek.k.oipp$value, ek.k.oipp$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.k.oipp$media <- rep(tapply(ek.k.oipp$prop, ek.k.oipp$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.k.oipp$prop, ek.k.oipp$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.k.oipp$prop[is.na(ek.k.oipp$prop)] <- ek.k.oipp$media[is.na(ek.k.oipp$prop)]
ek.i.oipp <- left_join(paises.setores,euklems[which(euklems[,3]=="I_OIPP" & euklems[,5]!="Agg" & euklems[,5]!="*Agg" & euklems[,7]=="1995"),c(1,6,8)])
ek.i.oipp$prop <- ek.i.oipp$value/rep(tapply(ek.i.oipp$value, ek.i.oipp$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.i.oipp$media <- rep(tapply(ek.i.oipp$prop, ek.i.oipp$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.i.oipp$prop, ek.i.oipp$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.i.oipp$prop[is.na(ek.i.oipp$prop)] <- ek.i.oipp$media[is.na(ek.i.oipp$prop)]

ek.k.rd <- left_join(paises.setores,euklems[which(euklems[,3]=="K_RD" & euklems[,5]!="Agg" & euklems[,5]!="*Agg" & euklems[,7]=="1995"),c(1,6,8)])
ek.k.rd$prop <- ek.k.rd$value/rep(tapply(ek.k.rd$value, ek.k.rd$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.k.rd$media <- rep(tapply(ek.k.rd$prop, ek.k.rd$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.k.rd$prop, ek.k.rd$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.k.rd$prop[is.na(ek.k.rd$prop)] <- ek.k.rd$media[is.na(ek.k.rd$prop)]
ek.i.rd <- left_join(paises.setores,euklems[which(euklems[,3]=="I_RD" & euklems[,5]!="Agg" & euklems[,5]!="*Agg" & euklems[,7]=="1995"),c(1,6,8)])
ek.i.rd$prop <- ek.i.rd$value/rep(tapply(ek.i.rd$value, ek.i.rd$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.i.rd$media <- rep(tapply(ek.i.rd$prop, ek.i.rd$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.i.rd$prop, ek.i.rd$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.i.rd$prop[is.na(ek.i.rd$prop)] <- ek.i.rd$media[is.na(ek.i.rd$prop)]

ek.k.cult <- left_join(paises.setores,euklems[which(euklems[,3]=="K_Cult" & euklems[,5]!="Agg" & euklems[,5]!="*Agg" & euklems[,7]=="1995"),c(1,6,8)])
ek.k.cult$prop <- ek.k.cult$value/rep(tapply(ek.k.cult$value, ek.k.cult$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.k.cult$media <- rep(tapply(ek.k.cult$prop, ek.k.cult$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.k.cult$prop, ek.k.cult$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.k.cult$prop[is.na(ek.k.cult$prop)] <- ek.k.cult$media[is.na(ek.k.cult$prop)]
ek.i.cult <- left_join(paises.setores,euklems[which(euklems[,3]=="I_Cult" & euklems[,5]!="Agg" & euklems[,5]!="*Agg" & euklems[,7]=="1995"),c(1,6,8)])
ek.i.cult$prop <- ek.i.cult$value/rep(tapply(ek.i.cult$value, ek.i.cult$country, sum, na.rm = TRUE), each = length(setores.euklems))
ek.i.cult$media <- rep(tapply(ek.i.cult$prop, ek.i.cult$code, mean, na.rm = TRUE), times = length(paises.euklems))*rep(1-tapply(ek.i.cult$prop, ek.i.cult$country, sum, na.rm = TRUE), each =  length(setores.euklems))
ek.i.cult$prop[is.na(ek.i.cult$prop)] <- ek.i.cult$media[is.na(ek.i.cult$prop)]

#exportar isso como RDS