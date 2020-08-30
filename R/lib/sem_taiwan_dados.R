#Junta os dados de Taiwan com os do resto do mundo

#m_wio[,row_demanda] <- m_wio[,row_demanda] + m_wio[,twn_demanda]
m_wio[,row_cols] <- m_wio[,row_cols] + m_wio[,twn_cols]
m_wio[row_lins,] <- m_wio[row_lins,] + m_wio[twn_lins,]
m_wio <- m_wio[c(twn_n_lins,(last(twn_n_lins)+1):nrow(m_wio)),c(twn_n_cols,(last(twn_n_cols)+1):ncol(m_wio))]

m_t[,row_cols] <- m_t[,row_cols] + m_t[,twn_cols]
m_t[row_lins,] <- m_t[row_lins,] + m_t[twn_lins,]
m_t <- m_t[c(twn_n_lins,(last(twn_n_lins)+1):nrow(m_t)),c(twn_n_cols,(last(twn_n_cols)+1):ncol(m_t))]

k_composicao[,row_lins] <- k_composicao[,row_lins] + k_composicao[,twn_lins]
k_composicao[row_lins,] <- k_composicao[row_lins,] + k_composicao[twn_lins,]
k_composicao <- k_composicao[twn_n_lins,twn_n_lins]

m_depreciacao[,row_lins] <- m_depreciacao[,row_lins] + m_depreciacao[,twn_lins]
m_depreciacao[row_lins,] <- m_depreciacao[row_lins,] + m_depreciacao[twn_lins,]
m_depreciacao <- m_depreciacao[twn_n_lins,twn_n_lins]

sea[row_lins,4:ncol(sea)] <- sea[row_lins,4:ncol(sea)] + sea[twn_lins,4:ncol(sea)]

sea <- sea[twn_n_lins,]

lin_produto_total <- lin_produto_total - num_setores
producao_bruta_pm_matriz <- matrix(sea$producao_bruta_precos_mercado, nrow = tamanho, ncol=tamanho, byrow = TRUE)
