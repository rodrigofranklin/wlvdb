###Distribui o capital presente nas SEA em seus diversos tipos

k_composicao <- matrix(rep(t(prop.table(m_wio[1:(tamanho),col_fbcf],2)),each=num_setores), ncol = tamanho, nrow = tamanho, byrow = TRUE)*matrix(k_usd,nrow=tamanho,ncol=tamanho, byrow= TRUE)

#^- essa versão faz a distribuição pela fbcf de cada ano
# VERSÃO ABANDONADA. Matinda aqui apenas para preservar o histórico.