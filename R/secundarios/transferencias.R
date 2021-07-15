########################################################################
###
### Script para cálculo das transferências médias
###
########################################################################

###
### Variáveis de versão
###
versao = versao_fonte  <- "July14"
versao_resultado <- "July14_1011"
anos <- 1995:2009
# versao = versao_fonte <- "Nov16"
# versao_resultado <- "Nov16_1016"
# anos <- 2000:2014

# Carrega variáveis de controle
source('R/lib/variaveis_controle.R')

###
### Área para inicialização das variáveis de resultado
###

trans_paises <- data.frame(country=paises$Legenda)
pib_prod_paises <- data.frame(country=paises$Legenda)
jornada_paises <- data.frame(country=paises$Legenda)
valorft_paises <- data.frame(country=paises$Legenda)


BR_UE <-data.frame(temp=0)
BR_EUA <-data.frame(temp=0)


# paises_setores <- data.frame(country=rep(paises$Legenda,each=num_setores))
# paises_setores$description <- setores$Setor
# paises_setores$code <- setores$Code
# resultado_temp <- paises_setores
# resultado_temp$variable <- 'EXEMPLO1'
# resultado <- resultado_temp
# resultado_temp$variable <- 'EXEMPLO2'
#resultado <- rbind(resultado, resultado_temp)

for (ano in anos) {
  
  #Carrega os dados brutos da versão especificada
  source("R/lib/dados_brutos.R")

  #Carrega os dados pré-calculados da versão especificada
  source("R/lib/dados_pre_calculados.R")
  
  ###
  ### Área para os cálculos desejados
  ###
  
  BR_EUA$temp <- transferencias[40,5]
  BR_UE$temp <- sum(transferencias[c(2, 3, 4, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 21, 22, 25, 26, 27, 29, 30, 31, 32, 33, 35, 36, 37),5])
  names(BR_EUA)[names(BR_EUA) == "temp"] <- ano
  names(BR_UE)[names(BR_UE) == "temp"] <- ano
  
  trans_paises$temp <- -rowSums(transferencias[,1:40])
  names(trans_paises)[names(trans_paises) == "temp"] <- ano
  
  pib_prod_paises$temp <- tapply(sea$h_emp*filtro_produtivo, pais_lins, sum, na.rm = TRUE)
  names(pib_prod_paises)[names(pib_prod_paises) == "temp"] <- ano
  # resultado$temp <- t(cbind(sea$EXEMPLO1, sea$EXEMPLO2))
  # names(resultado)[names(resultado) == "temp"] <- ano
  
  

}


resultado <- data.frame(country=paises$Países)
resultado$trans_medias <- rowSums(trans_paises[,2:16])/15
resultado$prod_medias <- rowSums(pib_prod_paises[,2:16])/15
resultado$ab <- resultado$trans_medias/resultado$prod_medias


filtro_tech <- rep(setores$Lall, times = num_paises)

pais_lins[(pais_lins != 28) & (pais_lins != 40)] <- 0
pais_cols[(pais_cols != 28) & (pais_cols != 40)] <- 0

pais_lins[pais_lins == 28] <- 100
pais_cols[pais_cols == 28] <- 100

pais_lins[pais_lins == 40] <- 1000
pais_cols[pais_cols == 40] <- 1000

pais_lins[filtro_produtivo==0 & pais_lins==0] <- 1

filtro_tech <- filtro_tech*pais_lins
pais_cols <- pais_cols-5000


m_wio_inter <- matrix(0, nrow = 17, ncol = (tamanho_completo-1))
m_t_inter <- matrix(0, nrow = 17, ncol = (tamanho_completo-1))

for (x in 1:(tamanho_completo-1)) {
  m_wio_inter[,x] <- tapply(m_wio[1:tamanho,x], filtro_tech, sum, na.rm = TRUE)
  m_t_inter[,x] <- tapply(m_t[1:tamanho,x], filtro_tech, sum, na.rm = TRUE)
}

filtro_tech_demanda <- c(filtro_tech,pais_cols[(tamanho+1):(tamanho_completo-1)])
m_wio_simples <- matrix(0, nrow = 17, ncol = 20)
m_t_simples <- matrix(0, nrow = 17, ncol = 20)

for (x in 1:17) {
  m_wio_simples[x,] <- tapply(m_wio_inter[x,1:(tamanho_completo-1)], filtro_tech_demanda, sum, na.rm = TRUE)
  m_t_simples[x,] <- tapply(m_t_inter[x,1:(tamanho_completo-1)], filtro_tech_demanda, sum, na.rm = TRUE)
}



###
### Área para registro das informações
###

va_simples <- tapply(m_wio[lin_va,1:tamanho],filtro_tech, sum, na.rm=TRUE)
trabalho_simples <- tapply(sea$trabalho*filtro_produtivo,filtro_tech, sum, na.rm=TRUE)
#dep_simples <- tapply(sea$k_dep*filtro_produtivo,filtro_tech, sum, na.rm=TRUE)

write.csv2(BR_EUA, file = paste0("eua_",versao_resultado,".csv"))
write.csv2(BR_UE, file = paste0("ue_",versao_resultado,".csv"))

write.csv2(va_simples, file = paste0("va_",versao_resultado,".csv"))
write.csv2(trabalho_simples[c(4:17,1:3)]/1000000, file = paste0("trab_",versao_resultado,".csv"))
write.csv2(m_wio_simples[c(4:17,1:3),c(7:20,2,3,4,1,5,6)], file = paste0("m_wio_",versao_resultado,".csv"))
write.csv2(m_t_simples[c(4:17,1:3),c(7:20,2,3,4,1,5,6)]/1000000, file = paste0("m_t_",versao_resultado,".csv"))

write.csv2(resultado, file = paste0("Transfs_",versao_resultado,".csv"))

