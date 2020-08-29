#sea IMPORT
sea <- as.data.frame(read_xlsx(paste0(getwd(),"/sourcedata/",versao,"/WIOD_SEA_",versao,".xlsx"), sheet = "DATA", col_names = T, na = 'NA'))
sea[is.na(sea)] <- 0
colnames(sea) <- tolower(gsub("_","",colnames(sea)))
linhas.h.emp <- which(sea[,'variable'] == 'H_EMP')
linhas.h.empe <- which(sea[,'variable'] == 'H_EMPE')
linhas.emp <- which(sea[,'variable'] == 'EMP')
linhas.empe <- which(sea[,'variable'] == 'EMPE')
linhas.go <- which(sea[,'variable'] == 'GO')
linhas.va <- which(sea[,'variable'] == 'VA')
linhas.va.p <- which((sea[,'variable'] == 'VA_P')|(sea[,'variable'] == 'VA_PI'))
linhas.comp <- which(sea[,'variable'] == 'COMP')
linhas.lab <- which(sea[,'variable'] == 'LAB')
linhas.cap <- which(sea[,'variable'] == 'CAP')
linhas.k.gfcf <- which(sea[,'variable'] == 'K_GFCF')
linhas.gfcf <- which(sea[,'variable'] == 'GFCF')
linhas.gfcf.p <- which(sea[,'variable'] == 'GFCF_P')
linhas.k <- which(sea[,'variable'] == 'K')
linhas.h.hs <- which(sea[,'variable'] == 'H_HS')
linhas.h.ms <- which(sea[,'variable'] == 'H_MS')
linhas.h.ls <- which(sea[,'variable'] == 'H_LS')
linhas.lab.hs <- which(sea[,'variable'] == 'LABHS')
linhas.lab.ms <- which(sea[,'variable'] == 'LABMS')
linhas.lab.ls <- which(sea[,'variable'] == 'LABLS')
coluna.sea <- 5
anos <- as.numeric(colnames(sea)[5:dim(sea)[2]])



###vamos arreglar SEA para el formato tidy
sea.tidy <- sea %>% pivot_longer(5:ncol(sea),names_to = "year", values_to = "value")
sea.tidy$year <- as.numeric(sea.tidy$year)
