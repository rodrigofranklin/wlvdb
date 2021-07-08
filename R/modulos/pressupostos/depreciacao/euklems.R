####
#
# Calcula a matriz de depreciação do capital.
# - Distribui o estoque de capital
# - Aplica taxas de depreciação
#
####

## Distribui o estoque de capital a partir dos dados do EUKLEMS

# matrizes temporárias para taxa de depreciação e composição do capital
tx_depreciacao = k_composicao <- matrix(1, nrow = num_paises_setores, 
                                        ncol = num_paises_setores)
# Cria as variáveis de controle para compatibilidade entre WIOD e EUKLEMS
# Informações obtidas no arquivo _setores.csv
linhas$s_ek <- setores$euklems.setor
linhas$k_ek <- setores$euklems.capital
linhas$p_ek <- rep(paises$euklems.paises,each=num_setores)
linhas$pwiod_sek <- paste0(linhas$pais, linhas$s_ek)

for (ano in lista_anos) {
  print(paste0("Distribuicao do capital. Ano: ", ano, "..."))
  # Carrega dados ----
  # ek_k -> taxa de distribuição de cada tipo de capital por todos os setores
  # ek_tx_dep -> taxa de depreciação de cada tipo de capital em cada setor
  ek_k <- readRDS(paste0("sourcedata/euklems/ekk_",ano,".rds"))
  ek_tx_dep <- readRDS(paste0("sourcedata/euklems/ektxdep_",
                              as.character(as.numeric(ano)),".rds"))
  ## ATENÇÃO: ACRESCENTAR +1 AO ANO DAS TAXAS DE DEPRECIAÇÃO
  
  # Países que não possuem dados na base do EUKLEMS serão calculados pela média
  linhas[!(linhas$p_ek %in% unique(ek_k$country)),"p_ek"] <- "MD" 
  linhas$ps_ek <- paste0(linhas$p_ek, linhas$s_ek)
  ek_k$ps <- paste0(ek_k$country, ek_k$code)
  
  # fator de desagragacao: desagrega os capitais da base EUKLEMS pelo valor 
  # agregado da base WIOD.
  # agregados -> soma dos VA do WIOD que representam um único setor em EUKLEMS
  agregados <- tapply(m_io_fonte[ano,"TOT.VA", 1:num_paises_setores], 
                      linhas$pwiod_sek, sum, na.rm = FALSE)
  k_composicao[,1:num_paises_setores] <- 
    rep(m_io_fonte[ano,"TOT.VA", 1:num_paises_setores]/agregados[linhas$pwiod_sek], 
        each = num_paises_setores)
  
  # desagregar a taxa de distribuição dos tipos de k pelos setores conforme o VA
  for (x in 1:num_paises_setores) {
    k_composicao[x,] <- k_composicao[x,]*ek_k[match(linhas$ps_ek, ek_k$ps),as.character(linhas$k_ek[x])]
    tx_depreciacao[x,] <- ek_tx_dep[match(linhas$ps_ek, ek_k$ps),as.character(linhas$k_ek[x])]
  }
  
  
  ##Aplicar
  # Cria uma matrix NxN com a fbcf de cada país
  fbcf <- as.data.frame(m_io_fonte[ano,1:num_paises_setores,colunas$setor=="c41"])
  fbcf <- as.matrix(fbcf[rep(names(fbcf), each = num_setores)])
  fbcf[fbcf<0] <- 0
  
  # primeiro, distribui a fbcf de cada país conforme a composição do capital no 
  # euklems
  k_composicao <- k_composicao * fbcf 
  
  #depois, distribui o estoque de capital pelas proporções da fbcf distribuida
  k_composicao <- prop.table(k_composicao, margin = 2) * 
    matrix(sea_setores[ano,"estoque_capital",,], 
           nrow=num_paises_setores, ncol=num_paises_setores, byrow= TRUE)
  
  m_io[ano,"k_composicao",1:num_paises_setores,1:num_paises_setores] <- 
    k_composicao
  
  #Aplica as taxas de depreciacao ao capital total
  m_io[ano,"k_depreciacao",1:num_paises_setores,1:num_paises_setores] <- 
    k_composicao*tx_depreciacao
  
  # Calcula as informações setoriais, por país e para o mundo
  sea_setores[ano,"depreciacao",,] <-
    colSums(m_io[ano,"k_depreciacao",,1:num_paises_setores], na.rm = TRUE)
}

print("Fim da distribuicao do capital.")
#limpar variáveis
rm (tx_depreciacao, k_composicao, ek_k, ek_tx_dep, agregados, fbcf)



