#K Depreciation - Depreciación de Capital

###Distribui o capital presente nas SEA em seus diversos tipos
#k_composicao <- matrix(rep(t(prop.table(m_wio[1:(tamanho),col_fbcf],2)),each=num_setores), ncol = tamanho, nrow = tamanho, byrow = TRUE)*matrix(k_usd,nrow=tamanho,ncol=tamanho, byrow= TRUE)
#^- essa versão faz a distribuição pela fbcf de cada ano

#v- esta versão faz a distribuiçã com os dados do euklems
ek_k <- readRDS(paste0("sourcedata/euklems/ekk_",ano,".rds"))
ek_tx_dep <- readRDS(paste0("sourcedata/euklems/ektxdep_",ano,".rds"))
tx_depreciacao = k_composicao <- matrix(1, nrow = tamanho, ncol = tamanho)

#levanta informações para desagragação dos setores
paises_setores <- data.frame(cbind(p_wiod=rep(paises$Legenda,each=num_setores),p_ek=rep(paises$euklems_paises,each=num_setores)))
paises_setores$p_wiod <- rep(paises$Legenda,each=num_setores)
paises_setores$s_wiod <- setores$WIOD
paises_setores$s_ek <- setores$euklems.setor
paises_setores$k_ek <- setores$euklems.capital

paises_setores$p_ek <- rep(paises$euklems.paises,each=num_setores)
paises_setores[!(paises_setores$p_ek %in% unique(ek_k$country)),"p_ek"] <- "MD" # Critério para aplicação geral
paises_setores$ps_ek <- paste0(paises_setores$p_ek, paises_setores$s_ek)
paises_setores$pwiod_sek <- paste0(paises_setores$p_wiod, paises_setores$s_ek)
ek_k$ps <- paste0(ek_k$country, ek_k$code)

#fator de desagragacao
agregados <- tapply(m_wio[lin_va,1:tamanho], paises_setores$pwiod_sek, sum, na.rm = FALSE)
k_composicao[,1:tamanho] <- rep(m_wio[lin_va,1:tamanho]/agregados[paises_setores$pwiod_sek], each = tamanho)

#desagregar
for (p in 1:tamanho) {
  k_composicao[p,] <- k_composicao[p,]*ek_k[match(paises_setores$ps_ek, ek_k$ps),as.character(paises_setores$k_ek[p])]
  tx_depreciacao[p,] <- ek_tx_dep[match(paises_setores$ps_ek, ek_k$ps),as.character(paises_setores$k_ek[p])]
}

##Aplicar

fbcf <- as.data.frame(m_wio[1:tamanho,col_fbcf]) # Cria uma matrix NxN com a fbcf de cada país
fbcf <- as.matrix(fbcf[rep(names(fbcf), each = num_setores)])
fbcf[fbcf<0] <- 0

k_composicao <- k_composicao * fbcf # primeiro, distribui a fbcf de cada país conforme a composição do capital euklems
k_composicao <- prop.table(k_composicao, margin = 2)*matrix(sea$k_usd,nrow=tamanho,ncol=tamanho, byrow= TRUE) #depois, distribui o estoque de capital pelas proporções da fbcf distribuida

#Aplica as taxas de depreciacao ao capital total
m_depreciacao <- k_composicao*tx_depreciacao

sea$k_dep <- array(colSums(m_depreciacao))
