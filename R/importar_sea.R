#sea IMPORT
SEA <- as.data.frame(read_xlsx(paste0(getwd(),"/sourcedata/",VERSAO,"/WIOD_SEA_",VERSAO,".xlsx"), sheet = "DATA", col_names = T, na = 'NA'))
SEA[is.na(SEA)] <- 0
colnames(SEA) <- tolower(gsub("_","",colnames(SEA)))
Linhas_H_EMP <- which(SEA[,'variable'] == 'H_EMP')
Linhas_H_EMPE <- which(SEA[,'variable'] == 'H_EMPE')
Linhas_EMP <- which(SEA[,'variable'] == 'EMP')
Linhas_EMPE <- which(SEA[,'variable'] == 'EMPE')
Linhas_GO <- which(SEA[,'variable'] == 'GO')
Linhas_VA <- which(SEA[,'variable'] == 'VA')
Linhas_VA_P <- which((SEA[,'variable'] == 'VA_P')|(SEA[,'variable'] == 'VA_PI'))
Linhas_COMP <- which(SEA[,'variable'] == 'COMP')
Linhas_LAB <- which(SEA[,'variable'] == 'LAB')
Linhas_CAP <- which(SEA[,'variable'] == 'CAP')
Linhas_K_GFCF <- which(SEA[,'variable'] == 'K_GFCF')
Linhas_GFCF_P <- which(SEA[,'variable'] == 'GFCF_P')
Linhas_K <- which(SEA[,'variable'] == 'K')
ColunaSEA <- 5
Anos <- as.numeric(colnames(SEA)[5:dim(SEA)[2]])