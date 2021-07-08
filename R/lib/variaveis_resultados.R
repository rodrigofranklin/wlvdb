## Alocação das variáveis de resultados

## Define parâmetros ----
lista_filtros <- c("paises",
                   "setores_produtivos",
                   "comercio")
lista_variaveis_m_io <- c("k_composicao",
                          "k_depreciacao",
                          "valores",
                          "transferencias_valores")
lista_variaveis_m_paises <- c("exportacoes_valores",
                              "exportacoes_pm",
                              "exportacoes_produtivas_pm",
                              "transferencias_produtivas_valores",
                              "transferencias_valores",
                              "transferencias_produtivas_pd",
                              "transferencias_pd")
lista_variaveis_sea <- variaveis_sea$lista_variaveis_sea

num_filtros <- length(lista_filtros)
num_variaveis_m_io <- length(lista_variaveis_m_io)
num_variaveis_m_paises <- length(lista_variaveis_m_paises)
num_variaveis_sea <- length(lista_variaveis_sea)

## Aloca variáveis ----
# m_io -> matrizes input-output de resultados
m_io <- array(NA,
              dim = c(num_anos,
                      num_variaveis_m_io,
                      num_input,
                      num_output),
              dimnames = list(lista_anos,
                              lista_variaveis_m_io,
                              lista_input,
                              lista_output))
# m_paises -> matrizes país x país
m_paises <- array(NA,
                  dim = c(num_anos,
                          num_variaveis_m_paises,
                          num_paises,
                          num_paises),
                  dimnames = list(lista_anos,
                                  lista_variaveis_m_paises,
                                  lista_paises,
                                  lista_paises))
# sea_setores -> vetores de resultados por setor
sea_setores <- array(NA,
                     dim = c(num_anos,
                             num_variaveis_sea,
                             num_setores,
                             num_paises),
                     dimnames = list(lista_anos,
                                     lista_variaveis_sea,
                                     lista_setores,
                                     lista_paises))
# sea_paises -> vetores de resultados por país
# Obs: em sea_paises, adiciona 'Whole Wide World' (WWW)
sea_paises <- array(NA,
                    dim = c(num_anos,
                            num_variaveis_sea,
                            num_paises+1),
                    dimnames = list(lista_anos,
                                    lista_variaveis_sea,
                                    c(lista_paises,"WWW")))
