#Elimina taiwan das variáveis de controle

twn_pais <- paises[paises[,3]=="TWN",2]
twn_n_pais <- paises[paises[,3]!="TWN",2]
row_pais <- num_paises

twn_cols <- which(pais_cols==twn_pais)
twn_lins <- which(pais_lins==twn_pais)
twn_n_cols <- which(pais_cols %in% twn_n_pais)
twn_n_lins <- which(pais_lins %in% twn_n_pais)

row_cols <- which(pais_cols==row_pais)
row_lins <- which(pais_lins==row_pais)

num_paises <- num_paises -1
paises <- paises[which(paises[,3]!="TWN"),]
tamanho <- num_paises*num_setores
col_demanda_final <- col_demanda_final[1:num_paises]-num_setores
pais_cols = pais_lins <- pais_cols[1:tamanho]
