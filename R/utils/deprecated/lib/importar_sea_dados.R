print("Separando dados das contas socioeconomicas...")

# Inicia variável das contas socioeconômicas
sea <- data.frame(pais=rep(paises$Legenda,each=num_setores))
sea$setor <- setores$Setor
sea$codigo <- setores$Code

# Separa todas as variáveis da tabela de contas socioeconômicas
sea$pais_setor <- paste0(sea$pais, sea$codigo)
for (var_sea in unique(sea_completo[,2])) {
  sea_temp <- sea_completo[sea_completo[,2] == var_sea, c(ano, 'pais_setor')]
  sea$temp <- sea_temp[match(sea$pais_setor, sea_temp[, 'pais_setor']),1]
  names(sea)[names(sea) == "temp"] <- tolower(var_sea)
}
sea$pais_setor <- NULL

# Ajusta variáveis e calculo dados de interesse
sea$cambio <- m_wio[lin_va,1:tamanho]/as.numeric(sea$va)
sea$h_empe <- sea$h_empe*1000000
sea$emp <- sea$emp*1000
sea$empe <- sea$empe*1000
sea$cap_usd <- sea$cap*sea$cambio
sea$lab_usd <- sea$lab*sea$cambio
sea$comp_usd <- sea$comp*sea$cambio

if (versao == 'July14') {
  sea$h_emp <- sea$h_emp*1000000
  sea$comp_real <- sea$comp/sea$va_p*100
  sea$lab_real <- sea$lab/sea$va_p*100
  sea$k_usd <- sea$k_gfcf*sea$gfcf_p/100*sea$cambio
} else {
  sea$comp_real <- sea$comp/sea$va_pi*100
  sea$lab_real <- sea$lab/sea$va_pi*100
  sea$k_usd <- sea$k*sea$cambio
  sea$h_emp <- sea$h_empe/sea$empe*sea$emp
  sea$h_emp[is.na(sea$h_emp)] <- 0
  sea$h_emp[is.infinite(sea$h_emp)] <- 0
}

sea[is.na(sea)] <- 0

print("fim da separacao de dados")

sea$producao_bruta_precos_mercado <- m_wio[lin_produto_total,1:tamanho]
producao_bruta_pm_matriz <- matrix(sea$producao_bruta_precos_mercado, nrow = tamanho, ncol=tamanho, byrow = TRUE)