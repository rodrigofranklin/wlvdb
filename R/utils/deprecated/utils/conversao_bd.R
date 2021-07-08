########################################################################
###
### Script padrão converter o BD em array multidimensional
###
########################################################################

###
### Variáveis de versão
###
# versao = versao_fonte  <- "July14"
# versao_resultado <- "July14_1011"
# anos <- 1995:2009
versao = versao_fonte <- "Nov16"
versao_resultado <- "Nov16_1010"
anos <- 2000:2014

# Carrega variáveis de controle
source('R/lib/variaveis_controle.R')
paises_setores <- data.frame(country=rep(paises$Legenda,each=num_setores))
paises_setores$description <- setores$Setor
paises_setores$code <- setores$Code
paises_demanda <- data.frame(country=rep(paises$Legenda,each=num_demanda))
paises_demanda$description <- demanda$Demanda
paises_demanda$code <- demanda$WIOD

lista_anos <- c(anos)

lista_filtros <- c("filtro.países",
                   "filtro.produtivos",
                   "filtro.comércio")

lista_variaveis_m_io <- c("k.composição",
                        "k.depreciação",
                        "valores",
                        "transferências.valores")

lista_input <- c(paste0(paises_setores$country,".",paises_setores$code),
                 "TOT.II_fob",
                 "TOT.TXSP",
                 "TOT.EXP_adj",
                 "TOT.PURR",
                 "TOT.PURNR",
                 "TOT.VA",
                 "TOT.IntTTM",
                 "TOT.GO")

lista_output <- c(paste0(paises_setores$country,".",paises_setores$code),
                  paste0(paises_demanda$country,".",paises_demanda$code),
                  "TOT.GO")

lista_variaveis_m_paises <- c("exportações.valores",
                              "exportações.pm",
                              "exportações_produtivas.pm",
                              "transferências_produtivas.valores",
                              "transferências.valores",
                              "transferências_produtivas.pd",
                              "transferências.pd")

lista_variaveis_sea_13 <- c("go","ii",
                            "va",
                            "comp",
                            "lab",
                            "cap",
                            "emp",
                            "empe",
                            "h_emp",
                            "h_empe",
                            "go_p",
                            "ii_p",
                            "va_p",
                            "gfcf_p",
                            "go_qi",
                            "ii_qi",
                            "va_qi",
                            "labhs",
                            "labms",
                            "labls",
                            "h_hs",
                            "h_ms",
                            "h_ls",
                            "k_gfcf",
                            "gfcf",
                            "cambio",
                            "cap_usd",
                            "lab_usd",
                            "comp_usd",
                            "comp_real",
                            "lab_real",
                            "k_usd",
                            "producao_bruta_precos_mercado",
                            "k_dep",
                            "trabalho",
                            "trabalho_assalariado",
                            "producao_bruta_valores",
                            "valor_forca_trabalho",
                            "taxa_exploracao",
                            "remuneracao_valor",
                            "taxa_exploracao_nao_assalariado",
                            "taxa_exploracao_total",
                            "taxa_exploracao_total_hs",
                            "taxa_exploracao_total_ms",
                            "taxa_exploracao_total_ls",
                            "producao_bruta_precos_diretos",
                            "producao_bruta_precos_diretos_nacionais",
                            "h_emp_hs",
                            "h_empe_hs",
                            "h_emp_ms",
                            "h_empe_ms",
                            "h_emp_ls",
                            "h_empe_ls",
                            "taxa_exploracao_hs",
                            "taxa_exploracao_ms",
                            "taxa_exploracao_ls")

lista_variaveis_sea_16 <- c("cap",
                            "comp",
                            "emp",
                            "empe",
                            "go",
                            "go_pi",
                            "go_qi",
                            "h_empe",
                            "ii",
                            "ii_pi",
                            "ii_qi",
                            "k",
                            "lab",
                            "va",
                            "va_pi",
                            "va_qi",
                            "cambio",
                            "cap_usd",
                            "lab_usd",
                            "comp_usd",
                            "comp_real",
                            "lab_real",
                            "k_usd",
                            "h_emp",
                            "producao_bruta_precos_mercado",
                            "k_dep",
                            "trabalho",
                            "trabalho_assalariado",
                            "producao_bruta_valores",
                            "valor_forca_trabalho",
                            "taxa_exploracao",
                            "remuneracao_valor",
                            "taxa_exploracao_nao_assalariado",
                            "taxa_exploracao_total",
                            "producao_bruta_precos_diretos",
                            "producao_bruta_precos_diretos_nacionais")

if (versao_fonte=="July14"){
  lista_variaveis_sea <- lista_variaveis_sea_13
} else{
  lista_variaveis_sea <- lista_variaveis_sea_16
}

num_variaveis_sea <- length(lista_variaveis_sea)
num_anos <- length(lista_anos)

###
### Área para inicialização das variáveis de resultado
###


m_io_filtros <- array(NA,
                      dim = c(length(lista_filtros),
                              length(lista_input),
                              length(lista_output)),
                      dimnames = list(lista_filtros,
                                      lista_input,
                                      lista_output))
m_io <- array(NA,
              dim = c(num_anos,
                      length(lista_variaveis_m_io),
                      length(lista_input),
                      length(lista_output)),
              dimnames = list(lista_anos,
                              lista_variaveis_m_io,
                              lista_input,
                              lista_output))
m_paises <- array(NA,
                  dim = c(num_anos,
                          length(lista_variaveis_m_paises),
                          num_paises,
                          num_paises),
                  dimnames = list(lista_anos,
                                  lista_variaveis_m_paises,
                                  paises$Legenda,
                                  paises$Legenda))
sea_setores <- array(NA,
                     dim = c(num_anos,
                             num_variaveis_sea,
                             tamanho),
                     dimnames = list(lista_anos,
                                     lista_variaveis_sea,
                                     paste0(paises_setores$country,".",paises_setores$code)))
sea_paises <- array(NA,
                    dim = c(num_anos,
                            num_variaveis_sea,
                            num_paises+1),
                    dimnames = list(lista_anos,
                                    lista_variaveis_sea,
                                    c(paises$Legenda,"WLD")))

## Preenche os filtros
tamanho_completo <- length(pais_cols)+1
pais_cols_matriz <- matrix(rep(pais_cols, times = tamanho), ncol = tamanho_completo-1, nrow = tamanho, byrow = TRUE)
pais_lins_matriz <- matrix(rep(pais_lins, times = tamanho_completo-1), ncol = tamanho_completo-1, nrow = tamanho, byrow = FALSE)
m_io_filtros[1,1:tamanho,1:(tamanho_completo-1)] <- pais_cols_matriz+(pais_lins_matriz/100)
m_io_filtros[2,1:tamanho,1:(tamanho_completo-1)] <- matrix(rep(filtro_produtivo, times = tamanho_completo-1), ncol = tamanho_completo-1, nrow = tamanho, byrow = FALSE)
m_io_filtros[3,1:tamanho,1:(tamanho_completo-1)] <- matrix(1,nrow = tamanho, ncol = tamanho_completo-1)
for (x in 1:num_paises) {
  m_io_filtros[3,pais_lins==x, pais_cols==x] <- 0
}

filtro_sea_paises <- matrix(rep(pais_lins, times = num_variaveis_sea), ncol = tamanho, nrow = num_variaveis_sea, byrow = TRUE)
filtro_sea_paises <- filtro_sea_paises*matrix(rep(1000^(1:num_variaveis_sea), times = tamanho), ncol = tamanho, nrow = num_variaveis_sea, byrow = FALSE)

for (ano in anos) {
  i_ano <- as.character(ano)
  #Carrega os dados brutos da versão especificada
  source("R/lib/dados_brutos.R")

  #Carrega os dados pré-calculados da versão especificada
  source("R/lib/dados_pre_calculados.R")
  
  ###
  ### Área para os cálculos desejados
  ###
  
  ## m_io
  m_io[i_ano,"valores",,] <- m_t[1:dim(m_io)[3],1:dim(m_io)[4]]
  m_io[i_ano,"k.composição",1:tamanho,1:tamanho] <- k_composicao
  m_io[i_ano,"k.depreciação",1:tamanho,1:tamanho] <- m_depreciacao

  ## esse fator saldo é o fator para a conversão dos valores em preços diretos 
  ## (somente para as exportações). Cálculo: soma (transações internacionais de
  ## valores) dividido pela soma (transações internacionais preços dos setores
  ## produtivos)
  fator_saldo <- (sum(m_io[i_ano,"valores",1:tamanho,1:(tamanho_completo-1)]*
                         m_io_filtros[3,1:tamanho,1:(tamanho_completo-1)], na.rm = TRUE)/
                     sum(m_wio[1:tamanho,1:(tamanho_completo-1)]*
                           m_io_filtros[3,1:tamanho,1:(tamanho_completo-1)]*
                           m_io_filtros[2,1:tamanho,1:(tamanho_completo-1)], na.rm = TRUE))
  
  ## as transferências setorias brutas são calculadas deduzindo as transações
  ## internacionais em valores do quanto que as transações internacionais em 
  ## preços representam em termos de valores (ie. em preços diretos)
  m_io[i_ano,"transferências.valores",1:tamanho,1:(tamanho_completo-1)] <- (
    (m_wio[1:tamanho,1:(tamanho_completo-1)]*
       m_io_filtros[3,1:tamanho,1:(tamanho_completo-1)]*
       fator_saldo) - 
    (m_io[i_ano,"valores",1:tamanho,1:(tamanho_completo-1)]*
       m_io_filtros[3,1:tamanho,1:(tamanho_completo-1)])
  )
    
  

  ## m_paises
  m_paises[i_ano,"exportações.valores",,] <- matrix(tapply(m_t[1:tamanho,1:(tamanho_completo-1)],m_io_filtros["filtro.países",1:tamanho,1:(tamanho_completo-1)],sum,na.rm = TRUE), ncol = num_paises, nrow = num_paises)*(1-diag(num_paises))
  m_paises[i_ano,"exportações.pm",,] <- matrix(tapply(m_wio[1:tamanho,1:(tamanho_completo-1)],m_io_filtros["filtro.países",1:tamanho,1:(tamanho_completo-1)],sum,na.rm = TRUE), ncol = num_paises, nrow = num_paises)*(1-diag(num_paises))
  m_paises[i_ano,"exportações_produtivas.pm",,] <- matrix(tapply(m_wio[1:tamanho,1:(tamanho_completo-1)]*m_io_filtros["filtro.produtivos",1:tamanho,1:(tamanho_completo-1)],m_io_filtros["filtro.países",1:tamanho,1:(tamanho_completo-1)],sum,na.rm = TRUE), ncol = num_paises, nrow = num_paises)*(1-diag(num_paises))
  m_paises[i_ano,"transferências.valores",,] <- matrix(
    tapply(m_io[i_ano,"transferências.valores",1:tamanho,1:(tamanho_completo-1)],
           m_io_filtros["filtro.países",1:tamanho,1:(tamanho_completo-1)],
           sum,na.rm = TRUE),
    ncol = num_paises,
    nrow = num_paises)*(1-diag(num_paises))
  m_paises[i_ano,"transferências_produtivas.valores",,] <- matrix(
    tapply(m_io[i_ano,"transferências.valores",1:tamanho,1:(tamanho_completo-1)]*
             m_io_filtros["filtro.produtivos",1:tamanho,1:(tamanho_completo-1)],
           m_io_filtros["filtro.países",1:tamanho,1:(tamanho_completo-1)],
           sum,na.rm = TRUE), 
    ncol = num_paises, 
    nrow = num_paises)*(1-diag(num_paises))
  m_paises[i_ano,"transferências_produtivas.pd",,] <- m_paises[i_ano,"transferências_produtivas.valores",,]/fator_saldo
  m_paises[i_ano,"transferências.pd",,] <- m_paises[i_ano,"transferências.valores",,]/fator_saldo

  
    
  ## sea_setores
  sea_setores[i_ano,,] <- t(sea[,4:(num_variaveis_sea+3)])
  
  ## sea_paises (+ mundo todo)
  sea_paises[i_ano,,1:num_paises] <- matrix(tapply(sea_setores[i_ano,,],filtro_sea_paises,sum,na.rm = TRUE), ncol = num_paises, nrow = num_variaveis_sea, byrow = TRUE)
  sea_paises[i_ano,,num_paises+1] <- rowSums(sea_paises[i_ano,,1:num_paises])

}

###
### Área para registro das informações
###
caminho <- paste0("resultados/", versao_resultado)

saveRDS(m_io_filtros,paste0(caminho,"/m_io_filtros.RDS"))
saveRDS(m_io,paste0(caminho,"/m_io.RDS"))
saveRDS(m_paises,paste0(caminho,"/m_paises.RDS"))
saveRDS(sea_setores,paste0(caminho,"/sea_setores.RDS"))
saveRDS(sea_paises,paste0(caminho,"/sea_paises.RDS"))