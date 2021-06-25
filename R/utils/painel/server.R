server <- function(input, output, session) {

  output$pais <- renderTable(t(sea_paises[,as.character(input$ano),,
                                            input$pais]), rownames = TRUE)
  
  output$serie_pais <- renderTable(sea_paises[,,input$indicador_pais,
                                                input$pais],rownames = TRUE)
  
  output$setores_pais_13 <- renderTable(sea_setores_13[as.character(input$ano),
                                                         input$indicador_pais,
                                                         grep(input$pais,
                                                              colnames(sea_setores_13[1,,]))]
                                          ,rownames = TRUE)

  output$setores_pais_16 <- renderTable(sea_setores_16[as.character(input$ano),
                                                       input$indicador_pais,
                                                       grep(input$pais,
                                                            colnames(sea_setores_16[1,,]))]
                                        ,rownames = TRUE)
  
  output$indicadores <- renderTable(t(sea_paises[,as.character(input$ano),
                                               input$indicador,]),
                                    rownames = TRUE)

  output$serie <- renderTable(sea_paises[input$versao_indicadores,,
                                         input$indicador,
                                         input$paises_indicadores],
                              rownames = TRUE)
  
  output$exportacoes_monetarias <- renderTable({
    selecao <- switch(paste0(input$transacoes_versao,input$transacoes_agregacao),
                      "WIOD13Agregado" = 1,
                      "WIOD13Por setor de origem" = 2,
                      "WIOD13Por setor de destino" = 3,
                      "WIOD16Agregado" = 4,
                      "WIOD16Por setor de origem" = 5,
                      "WIOD16Por setor de destino" = 6)
    if (selecao == 1) {
      m_paises_13[as.character(input$ano),
                  "exportações.pm",
                  input$pais_transacoes,]
    } else if (selecao == 2) {
      rowSums(m_io_13[as.character(input$ano),
                      "exportações.pm",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),])
    } else if (selecao == 3) {
      colSums(m_io_13[as.character(input$ano),
                      "exportações.pm",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano),
                  "exportações.pm",
                  input$pais_transacoes,]
    } else if (selecao == 5) {
      rowSums(m_io_16[as.character(input$ano),
                      "exportações.pm",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),])
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano),
                      "exportações.pm",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),])
    }},
    rownames = TRUE)
  
  output$exportacoes_valores <- renderTable({
    selecao <- switch(paste0(input$transacoes_versao,input$transacoes_agregacao),
                      "WIOD13Agregado" = 1,
                      "WIOD13Por setor de origem" = 2,
                      "WIOD13Por setor de destino" = 3,
                      "WIOD16Agregado" = 4,
                      "WIOD16Por setor de origem" = 5,
                      "WIOD16Por setor de destino" = 6)
    if (selecao == 1) {
      m_paises_13[as.character(input$ano),
                  "exportações.valores",
                  input$pais_transacoes,]
    } else if (selecao == 2) {
      rowSums(m_io_13[as.character(input$ano),
                      "exportações.valores",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),],
              na.rm = TRUE)
    } else if (selecao == 3) {
      colSums(m_io_13[as.character(input$ano),
                      "exportações.valores",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano),
                  "exportações.valores",
                  input$pais_transacoes,]
    } else if (selecao == 5) {
      rowSums(m_io_16[as.character(input$ano),
                      "exportações.valores",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),])
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano),
                      "exportações.valores",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),])
    }},
    rownames = TRUE)
  
  output$exportacoes_transferencias <- renderTable({
    selecao <- switch(paste0(input$transacoes_versao,input$transacoes_agregacao),
                      "WIOD13Agregado" = 1,
                      "WIOD13Por setor de origem" = 2,
                      "WIOD13Por setor de destino" = 3,
                      "WIOD16Agregado" = 4,
                      "WIOD16Por setor de origem" = 5,
                      "WIOD16Por setor de destino" = 6)
    if (selecao == 1) {
      m_paises_13[as.character(input$ano),
                  "transferências.valores",
                  input$pais_transacoes,]
    } else if (selecao == 2) {
      rowSums(m_io_13[as.character(input$ano),
                      "transferências.valores",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),])
    } else if (selecao == 3) {
      colSums(m_io_13[as.character(input$ano),
                      "transferências.valores",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano),
                  "transferências.valores",
                  input$pais_transacoes,]
    } else if (selecao == 5) {
      rowSums(m_io_16[as.character(input$ano),
                      "transferências.valores",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),])
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano),
                      "transferências.valores",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),])
    }},
    rownames = TRUE)
  
  output$importacoes_monetarias <- renderTable(m_paises_13[as.character(input$ano),
                                                           "exportações.pm",
                                                           ,input$pais_transacoes]
                                               ,rownames = TRUE)
  
  output$importacoes_valores <- renderTable(m_paises_13[as.character(input$ano),
                                                        "exportações.valores",
                                                        ,input$pais_transacoes]
                                            ,rownames = TRUE)
  
  output$importacoes_transferencias <- renderTable(m_paises_13[as.character(input$ano),
                                                               "transferências.valores",
                                                               ,input$pais_transacoes]
                                                   ,rownames = TRUE)
  
  output$saldo_monetarias <- renderTable((m_paises_13[as.character(input$ano),
                                                      "exportações.pm",
                                                      input$pais_transacoes,] - 
                                            m_paises_13[as.character(input$ano),
                                                        "exportações.pm",
                                                        ,input$pais_transacoes])
                                         ,rownames = TRUE)
  
  output$saldo_valores <- renderTable((m_paises_13[as.character(input$ano),
                                                   "exportações.valores",
                                                   input$pais_transacoes,] - 
                                         m_paises_13[as.character(input$ano),
                                                     "exportações.valores",
                                                     ,input$pais_transacoes])
                                      ,rownames = TRUE)
  
  output$saldo_transferencias <- renderTable((m_paises_13[as.character(input$ano),
                                                          "transferências.valores",
                                                          input$pais_transacoes,] - 
                                                m_paises_13[as.character(input$ano),
                                                            "transferências.valores",
                                                            ,input$pais_transacoes])
                                             ,rownames = TRUE)
  
  
  # 
  # 
  # output$exportacoes_monetarias <- renderTable({
  #   balanca_comercial_pm <- read.csv2(paste0("dados/balanca_comercial_pm13_,", input$ano,".csv"), 
  #             row.names = 1, 
  #             check.names = F)
  #   balanca_comercial_produtivos_pm <- read.csv2(paste0("dados/balanca_comercial_produtivos_pm13_,", input$ano,".csv"), 
  #                                     row.names = 1, 
  #                                     check.names = F)
  # })
  
}


