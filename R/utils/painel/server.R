source("requ.R")

server <- function(input, output, session) {

  output$pais <- renderTable(
    t(sea_paises[,as.character(input$ano),,input$pais])[1:10,],
    rownames = TRUE,
    spacing = "xs",
    striped = TRUE,
    hover = TRUE,
    width = "100%"
  )
  
  output$serie_pais <- renderPlot({
    dados <- sea_paises[,,input$indicador_pais,input$pais]
    lmax <- max(dados, na.rm = TRUE)
    lmin <- min(dados, na.rm = TRUE)
    plot(
      dados[1,],
      type = "l",
      ylim = c(lmin, lmax)
    )
    axis(side=1, 1:20, labels = as.character(lista_anos))
    lines(
      col = "red",
      dados[2,]
    )
  })
  
  output$setores_pais_13 <- renderTable(
    sea_setores_13[as.character(input$ano),
                   input$indicador_pais,
                   grep(input$pais, colnames(sea_setores_13[1,,]))],
    rownames = TRUE,
    spacing = "xs",
    striped = TRUE,
    hover = TRUE,
    width = "100%"
  )

  output$setores_pais_16 <- renderTable(
    sea_setores_16[as.character(input$ano),
                   input$indicador_pais,
                   grep(input$pais, colnames(sea_setores_16[1,,]))],
    rownames = TRUE,
    spacing = "xs",
    striped = TRUE,
    hover = TRUE,
    width = "100%"
  )
  
  output$indicadores1 <- 
    renderTable({
      t(sea_paises[,as.character(input$ano),input$indicador,])[1:(num_paises/2),]
    },
    rownames = TRUE,
    spacing = "xs",
    striped = TRUE,
    hover = TRUE,
    width = "100%"
    )

  output$indicadores2 <- 
    renderTable({
      t(sea_paises[,as.character(input$ano),input$indicador,])[((num_paises/2)+1):num_paises,]
    },
    rownames = TRUE,
    spacing = "xs",
    striped = TRUE,
    hover = TRUE,
    width = "100%"
    )

  output$serie <- renderPlot({
    dados <- sea_paises[input$versao_indicadores,,
                        input$indicador,
                        input$paises_indicadores]
    lmax <- max(dados, na.rm = TRUE)
    lmin <- min(dados, na.rm = TRUE)
    plot(
      dados[1,,],
      type = "l",
      ylim = c(lmin, lmax)
    )
    axis(side=1, 1:20, labels = as.character(lista_anos))
    # dim(dados)
    # for (x in 2:10) {
    #   lines( col = "red", dados[x,])
    # }
    
  })
  
  
### sobre esses outputs que se seguem: é preciso melhorar. Seria possível ter 
### uma única função que fosse chamada conforme a seleção de (exportação, 
### importação e saldo), e chamada 3 vezes (monetária, valor e transferência)?
  # Problema: os dados de exportações, importações e saldo são distintos.
  # Mas são os mesmos dados conforme o tipo de variável (monetário, valor transf)
  # No entanto, os gráficos conforme tipo de variábel são concomitantes.
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
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano),
                  "exportações.pm",
                  input$pais_transacoes,]
    } else if (selecao == 5) {
      rowSums(m_io_16[as.character(input$ano),
                      "exportações.pm",
                      grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),])
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano),
                      "exportações.pm",
                      grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
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
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano),
                  "exportações.valores",
                  input$pais_transacoes,]
    } else if (selecao == 5) {
      rowSums(m_io_16[as.character(input$ano),
                      "exportações.valores",
                      grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),])
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano),
                      "exportações.valores",
                      grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
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
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano),
                  "transferências.valores",
                  input$pais_transacoes,]
    } else if (selecao == 5) {
      rowSums(m_io_16[as.character(input$ano),
                      "transferências.valores",
                      grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),])
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano),
                      "transferências.valores",
                      grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    }},
    rownames = TRUE)
  
  output$importacoes_monetarias <- renderTable({
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
                  ,input$pais_transacoes]
    } else if (selecao == 2) {
      rowSums(m_io_13[as.character(input$ano),
                      "exportações.pm",
                      -grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                      grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 3) {
      colSums(m_io_13[as.character(input$ano),
                      "exportações.pm",
                      ,grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano),
                  "exportações.pm",
                  ,input$pais_transacoes]
    } else if (selecao == 5) {
      rowSums(m_io_16[as.character(input$ano),
                      "exportações.pm",
                      -grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                      grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano),
                      "exportações.pm",
                      ,grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    }},
    rownames = TRUE)
  
  output$importacoes_valores <- renderTable({
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
                  ,input$pais_transacoes]
    } else if (selecao == 2) {
      rowSums(m_io_13[as.character(input$ano),
                      "exportações.valores",
                      -grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                      grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))],
              na.rm = TRUE)
    } else if (selecao == 3) {
      colSums(m_io_13[as.character(input$ano),
                      "exportações.valores",
                      ,grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano),
                  "exportações.valores",
                  ,input$pais_transacoes]
    } else if (selecao == 5) {
      rowSums(m_io_16[as.character(input$ano),
                      "exportações.valores",
                      -grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                      grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano),
                      "exportações.valores",
                      ,grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    }},
    rownames = TRUE)
  
  output$importacoes_transferencias <- renderTable({
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
                  ,input$pais_transacoes]
    } else if (selecao == 2) {
      rowSums(m_io_13[as.character(input$ano),
                      "transferências.valores",
                      -grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                      grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 3) {
      colSums(m_io_13[as.character(input$ano),
                      "transferências.valores",
                      ,grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano),
                  "transferências.valores",
                  ,input$pais_transacoes]
    } else if (selecao == 5) {
      rowSums(m_io_16[as.character(input$ano),
                      "transferências.valores",
                      -grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                      grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano),
                      "transferências.valores",
                      ,grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    }},
    rownames = TRUE)
  
  output$saldo_monetarias <- renderTable({
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
                  input$pais_transacoes,] -
      m_paises_13[as.character(input$ano),
                  "exportações.pm",
                  ,input$pais_transacoes]
    } else if (selecao == 2) {
      - colSums(m_io_13[as.character(input$ano),
                        "exportações.pm",
                        ,grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))],
                na.rm = TRUE) +
      rowSums(m_io_13[as.character(input$ano),
                      "exportações.pm",
                      match(grep(input$pais_transacoes,colnames(m_io_13[1,1,,])),
                            grep(input$pais_transacoes,rownames(m_io_13[1,1,,]))),],
              na.rm = TRUE) 
    } else if (selecao == 3) {
      colSums(m_io_13[as.character(input$ano),
                      "exportações.pm",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))]) - 
      rowSums(m_io_13[as.character(input$ano),
                      "exportações.pm",
                      -grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                      grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano),
                  "exportações.pm",
                  input$pais_transacoes,] - 
      m_paises_16[as.character(input$ano),
                  "exportações.pm",
                  ,input$pais_transacoes]
    } else if (selecao == 5) {
      - colSums(m_io_16[as.character(input$ano),
                        "exportações.pm",
                        ,grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))],
                na.rm = TRUE) +
        rowSums(m_io_16[as.character(input$ano),
                        "exportações.pm",
                        match(grep(input$pais_transacoes,colnames(m_io_16[1,1,,])),
                              grep(input$pais_transacoes,rownames(m_io_16[1,1,,]))),],
                na.rm = TRUE) 
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano),
                      "exportações.pm",
                      grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))]) - 
        rowSums(m_io_16[as.character(input$ano),
                        "exportações.pm",
                        -grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                        grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    }},
    rownames = TRUE)
  
  output$saldo_valores <- renderTable({
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
                  input$pais_transacoes,] -
        m_paises_13[as.character(input$ano),
                    "exportações.valores",
                    ,input$pais_transacoes]
    } else if (selecao == 2) {
      - colSums(m_io_13[as.character(input$ano),
                        "exportações.valores",
                        ,grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))],
                na.rm = TRUE) +
        rowSums(m_io_13[as.character(input$ano),
                        "exportações.valores",
                        match(grep(input$pais_transacoes,colnames(m_io_13[1,1,,])),
                              grep(input$pais_transacoes,rownames(m_io_13[1,1,,]))),],
                na.rm = TRUE) 
    } else if (selecao == 3) {
      colSums(m_io_13[as.character(input$ano),
                      "exportações.valores",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))]) - 
        rowSums(m_io_13[as.character(input$ano),
                        "exportações.valores",
                        -grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                        grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano),
                  "exportações.valores",
                  input$pais_transacoes,] - 
        m_paises_16[as.character(input$ano),
                    "exportações.valores",
                    ,input$pais_transacoes]
    } else if (selecao == 5) {
      - colSums(m_io_16[as.character(input$ano),
                        "exportações.valores",
                        ,grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))],
                na.rm = TRUE) +
        rowSums(m_io_16[as.character(input$ano),
                        "exportações.valores",
                        match(grep(input$pais_transacoes,colnames(m_io_16[1,1,,])),
                              grep(input$pais_transacoes,rownames(m_io_16[1,1,,]))),],
                na.rm = TRUE) 
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano),
                      "exportações.valores",
                      grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))]) - 
        rowSums(m_io_16[as.character(input$ano),
                        "exportações.valores",
                        -grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                        grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    }},
    rownames = TRUE)
  
  output$saldo_transferencias <- renderTable({
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
                  input$pais_transacoes,] -
        m_paises_13[as.character(input$ano),
                    "transferências.valores",
                    ,input$pais_transacoes]
    } else if (selecao == 2) {
      - colSums(m_io_13[as.character(input$ano),
                        "transferências.valores",
                        ,grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))],
                na.rm = TRUE) +
        rowSums(m_io_13[as.character(input$ano),
                        "transferências.valores",
                        match(grep(input$pais_transacoes,colnames(m_io_13[1,1,,])),
                              grep(input$pais_transacoes,rownames(m_io_13[1,1,,]))),],
                na.rm = TRUE) 
    } else if (selecao == 3) {
      colSums(m_io_13[as.character(input$ano),
                      "transferências.valores",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))]) - 
        rowSums(m_io_13[as.character(input$ano),
                        "transferências.valores",
                        -grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                        grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano),
                  "transferências.valores",
                  input$pais_transacoes,] - 
        m_paises_16[as.character(input$ano),
                    "transferências.valores",
                    ,input$pais_transacoes]
    } else if (selecao == 5) {
      - colSums(m_io_16[as.character(input$ano),
                        "transferências.valores",
                        ,grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))],
                na.rm = TRUE) +
        rowSums(m_io_16[as.character(input$ano),
                        "transferências.valores",
                        match(grep(input$pais_transacoes,colnames(m_io_16[1,1,,])),
                              grep(input$pais_transacoes,rownames(m_io_16[1,1,,]))),],
                na.rm = TRUE) 
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano),
                      "transferências.valores",
                      grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))]) - 
        rowSums(m_io_16[as.character(input$ano),
                        "transferências.valores",
                        -grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                        grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    }},
    rownames = TRUE)
  
### Análise das transferências: tabelas sobre troca desigual e trocas nos setores
### improdutivos

  ## Juntar tanto as exportações quanto as importações
  output$td_envios_recebimentos <- renderTable({
    selecao <- switch(paste0(input$transacoes_versao,input$transacoes_agregacao),
                      "WIOD13Agregado" = 1,
                      "WIOD13Por setor de origem" = 2,
                      "WIOD13Por setor de destino" = 3,
                      "WIOD16Agregado" = 4,
                      "WIOD16Por setor de origem" = 5,
                      "WIOD16Por setor de destino" = 6)
    if (selecao == 1) {
      temp1 <- m_paises_13[as.character(input$ano),
                           "transferências_produtivas.valores",
                           input$pais_transacoes,
                           ]
      temp2 <-  -m_paises_13[as.character(input$ano),
                            "transferências_produtivas.valores",
                            ,
                            input$pais_transacoes]
      names(temp1) <- paste0("X.",names(temp1))
      names(temp2) <- paste0("M.",names(temp2))
      c(temp1, temp2)
    } else if (selecao == 2) {
    } else if (selecao == 3) {
    } else if (selecao == 4) {
    } else if (selecao == 5) {
    } else if (selecao == 6) {
    }
  }, rownames = TRUE)
  
  output$td_envios_recebimentos_saldo <- renderTable({
    selecao <- switch(paste0(input$transacoes_versao,input$transacoes_agregacao),
                      "WIOD13Agregado" = 1,
                      "WIOD13Por setor de origem" = 2,
                      "WIOD13Por setor de destino" = 3,
                      "WIOD16Agregado" = 4,
                      "WIOD16Por setor de origem" = 5,
                      "WIOD16Por setor de destino" = 6)
    if (selecao == 1){
      m_paises_13[as.character(input$ano),
                           "transferências_produtivas.valores",
                           input$pais_transacoes,] -
      m_paises_13[as.character(input$ano),
                          "transferências_produtivas.valores",
                          ,input$pais_transacoes]
    } else if (selecao == 2) {
    } else if (selecao == 3) {
    } else if (selecao == 4) {
    } else if (selecao == 5) {
    } else if (selecao == 6) {
    }
  }, rownames = TRUE)


  output$improdutivos_envios_recebimentos <- renderTable({
    selecao <- switch(paste0(input$transacoes_versao,input$transacoes_agregacao),
                      "WIOD13Agregado" = 1,
                      "WIOD13Por setor de origem" = 2,
                      "WIOD13Por setor de destino" = 3,
                      "WIOD16Agregado" = 4,
                      "WIOD16Por setor de origem" = 5,
                      "WIOD16Por setor de destino" = 6)
    if (selecao == 1){
      temp1 <- m_paises_13[as.character(input$ano),
                           "transferências.valores",
                           input$pais_transacoes,] - 
        m_paises_13[as.character(input$ano),
                           "transferências_produtivas.valores",
                           input$pais_transacoes,]
      temp2 <-  -(m_paises_13[as.character(input$ano),
                            "transferências.valores",
                            ,input$pais_transacoes] - 
        m_paises_13[as.character(input$ano),
                    "transferências_produtivas.valores",
                    ,input$pais_transacoes])
      names(temp1) <- paste0("X.",names(temp1))
      names(temp2) <- paste0("M.",names(temp2))
      c(temp1, temp2)
    } else if (selecao == 2) {
    } else if (selecao == 3) {
    } else if (selecao == 4) {
    } else if (selecao == 5) {
    } else if (selecao == 6) {
    }
  }, rownames = TRUE)


  output$improdutivos_envios_recebimentos_saldo <- renderTable({
    selecao <- switch(paste0(input$transacoes_versao,input$transacoes_agregacao),
                      "WIOD13Agregado" = 1,
                      "WIOD13Por setor de origem" = 2,
                      "WIOD13Por setor de destino" = 3,
                      "WIOD16Agregado" = 4,
                      "WIOD16Por setor de origem" = 5,
                      "WIOD16Por setor de destino" = 6)
    if (selecao == 1){
      temp1 <- m_paises_13[as.character(input$ano),
                           "transferências.valores",
                           input$pais_transacoes,] - 
        m_paises_13[as.character(input$ano),
                    "transferências_produtivas.valores",
                    input$pais_transacoes,] - 
        (m_paises_13[as.character(input$ano),
                              "transferências.valores",
                              ,input$pais_transacoes] - 
           m_paises_13[as.character(input$ano),
                                "transferências_produtivas.valores",
                                ,input$pais_transacoes])
    } else if (selecao == 2) {
    } else if (selecao == 3) {
    } else if (selecao == 4) {
    } else if (selecao == 5) {
    } else if (selecao == 6) {
    }
  }, rownames = TRUE)

  output$proporcao_td_transferencias <- renderText({
    as.character(sum(m_paises_13[as.character(input$ano),
                                 "transferências_produtivas.valores",
                                 input$pais_transacoes,] +
                       m_paises_13[as.character(input$ano),
                                   "transferências_produtivas.valores",
                                   ,input$pais_transacoes])/
                   sum(m_paises_13[as.character(input$ano),
                                   "transferências.valores",
                                   input$pais_transacoes,] +
                         m_paises_13[as.character(input$ano),
                                     "transferências.valores",
                                     ,input$pais_transacoes]))
  })
  textOutput("proporcao_td_transferencias_saldo")
  
}


