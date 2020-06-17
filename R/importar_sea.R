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
coluna.sea <- 5
anos <- as.numeric(colnames(sea)[5:dim(sea)[2]])

for (x in 1:(num.paises-1)) {
  linhas.pais.h.emp <- linhas.h.emp[which(sea[linhas.h.emp,'country'] == as.character(paises[x,3]))]
  linhas.pais.h.empe <- linhas.h.empe[which(sea[linhas.h.empe,'country'] == as.character(paises[x,3]))]
  linhas.pais.emp <- linhas.emp[which(sea[linhas.emp,'country'] == as.character(paises[x,3]))]
  linhas.pais.empe <- linhas.empe[which(sea[linhas.empe,'country'] == as.character(paises[x,3]))]
  linhas.pais.go <- linhas.go[which(sea[linhas.go,'country'] == as.character(paises[x,3]))]
  linhas.pais.va <- linhas.va[which(sea[linhas.va,'country'] == as.character(paises[x,3]))]
  linhas.pais.va.p <- linhas.va.p[which(sea[linhas.va.p,'country'] == as.character(paises[x,3]))]
  linhas.pais.comp <- linhas.comp[which(sea[linhas.comp,'country'] == as.character(paises[x,3]))]
  linhas.pais.lab <- linhas.lab[which(sea[linhas.lab,'country'] == as.character(paises[x,3]))]
  linhas.pais.cap <- linhas.cap[which(sea[linhas.cap,'country'] == as.character(paises[x,3]))]
  linhas.pais.k.gfcf <- linhas.k.gfcf[which(sea[linhas.k.gfcf,'country'] == as.character(paises[x,3]))]
  linhas.pais.gfcf <- linhas.gfcf[which(sea[linhas.gfcf,'country'] == as.character(paises[x,3]))]
  linhas.pais.gfcf.p <- linhas.gfcf.p[which(sea[linhas.gfcf.p,'country'] == as.character(paises[x,3]))]
  linhas.pais.k <- linhas.k[which(sea[linhas.k,'country'] == as.character(paises[x,3]))]
  
  
  for (y in 1:num.setores) {
    linhas.setor.pais.h.emp <- linhas.pais.h.emp[which(sea[linhas.pais.h.emp,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.h.empe <- linhas.pais.h.empe[which(sea[linhas.pais.h.empe,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.emp <- linhas.pais.emp[which(sea[linhas.pais.emp,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.empe <- linhas.pais.empe[which(sea[linhas.pais.empe,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.go <- linhas.pais.go[which(sea[linhas.pais.go,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.va <- linhas.pais.va[which(sea[linhas.pais.va,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.va.p <- linhas.pais.va.p[which(sea[linhas.pais.va.p,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.comp <- linhas.pais.comp[which(sea[linhas.pais.comp,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.lab <- linhas.pais.lab[which(sea[linhas.pais.lab,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.cap <- linhas.pais.cap[which(sea[linhas.pais.cap,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.k.gfcf <- linhas.pais.k.gfcf[which(sea[linhas.pais.k.gfcf,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.gfcf <- linhas.pais.gfcf[which(sea[linhas.pais.gfcf,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.gfcf.p <- linhas.pais.gfcf.p[which(sea[linhas.pais.gfcf.p,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.k <- linhas.pais.k[which(sea[linhas.pais.k,'code'] == as.character(setores[y,1]))]
  }
}
