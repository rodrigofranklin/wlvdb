# Cálculo da composição da cesta de consumo

prop_demanda_familias <- as.data.frame(prop.table(m_wio[1:tamanho,col_demanda_final], margin = 2))
prop_demanda_familias <- as.matrix(prop_demanda_familias[rep(names(prop_demanda_familias), each = num_setores)])
cesta_consumo <- (matrix(sea$lab_usd, ncol = tamanho, nrow = tamanho, byrow = TRUE)*prop_demanda_familias)
cesta_consumo[is.infinite(cesta_consumo)] <- 0
cesta_consumo[is.nan(cesta_consumo)] <- 0

cesta_consumo_assalariados <- (matrix(sea$comp_usd, ncol = tamanho, nrow = tamanho, byrow = TRUE)*prop_demanda_familias)
cesta_consumo_assalariados[is.infinite(cesta_consumo_assalariados)] <- 0
cesta_consumo_assalariados[is.nan(cesta_consumo_assalariados)] <- 0
