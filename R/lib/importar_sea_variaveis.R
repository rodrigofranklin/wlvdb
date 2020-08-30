#sea_completo IMPORT
sea_completo <- as.data.frame(read_xlsx(paste0(getwd(),"/sourcedata/",versao,"/WIOD_sea_",versao,".xlsx"), sheet = "DATA", col_names = T, na = 'NA'))
sea_completo[is.na(sea_completo)] <- 0
colnames(sea_completo) <- tolower(gsub("_","",colnames(sea_completo)))

anos <- as.numeric(colnames(sea_completo)[5:dim(sea_completo)[2]])
sea_completo$pais_setor <- paste0(sea_completo$country, sea_completo$code)

# ###vamos arreglar sea_completo para el formato tidy
# sea_completo.tidy <- sea_completo %>% pivot_longer(5:ncol(sea_completo),names_to = "year", values_to = "value")
# sea_completo.tidy$year <- as.numeric(sea_completo.tidy$year)
