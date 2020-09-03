if (versao == "Nov16") {
  sea$h_emp[which(pais_lins==paises[paises[,3]=="CHN",2])] <- sea$emp[which(pais_lins==paises[paises[,3]=="CHN",2])]*t(jornada_media_china[,as.character(ano)])[1,]*1000
  sea$h_emp[is.na(sea$h_emp)] <- 0
}
sea$empe[which(pais_lins==paises[paises[,3]=="CHN",2])] <- sea$emp[which(pais_lins==paises[paises[,3]=="CHN",2])]*as.numeric(was_w_china[as.character(ano)])/100
sea$h_empe[which(pais_lins==paises[paises[,3]=="CHN",2])] <- sea$h_emp[which(pais_lins==paises[paises[,3]=="CHN",2])]*as.numeric(was_w_china[as.character(ano)])/100
