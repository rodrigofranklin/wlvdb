#sea_completo IMPORT

sea_completo <- readRDS(file = paste0("sourcedata/",versao,"/sea.rds"))
anos <- names(sea_completo[,1,1,1])

# sea_completo$pais_setor <- paste0(sea_completo$country, sea_completo$code)

# ###vamos arreglar sea_completo para el formato tidy
# sea_completo.tidy <- sea_completo %>% pivot_longer(5:ncol(sea_completo),names_to = "year", values_to = "value")
# sea_completo.tidy$year <- as.numeric(sea_completo.tidy$year)
