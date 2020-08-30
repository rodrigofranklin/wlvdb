#Elimina taiwan das variáveis de controle

twn_demanda <- col_demanda_final[paises[paises[,3]=="TWN",2]]
twn_cols <- which(pais_cols==paises[paises[,3]=="TWN",2])
twn_lins <- which(pais_lins==paises[paises[,3]=="TWN",2])
twn_n_cols <- which(pais_cols %in% paises[paises[,3]!="TWN",2])
twn_n_lins <- which(pais_lins %in% paises[paises[,3]!="TWN",2])
row_demanda <- col_demanda_final[num_paises]
row_cols <- which(pais_cols==num_paises)
row_lins <- which(pais_lins==num_paises)

num_paises <- num_paises -1
paises <- paises[which(paises[,3]!="TWN"),]
tamanho <- num_paises*num_setores
col_demanda_final <- col_demanda_final[1:num_paises]-num_setores
pais_cols = pais_lins <- pais_cols[1:tamanho]
