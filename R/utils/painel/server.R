
server <- function(input, output, session) {
  linhas_13 <- reactive({
    encontrar_pais(m_io_13, input$pais_transacoes, rownames)
  })
  
  colunas_13 <- reactive({
    encontrar_pais(m_io_13, input$pais_transacoes, colnames)
  })
  
  linhas_16 <- reactive({
    encontrar_pais(m_io_16, input$pais_transacoes, rownames)
  })
  
  colunas_16 <- reactive({
    encontrar_pais(m_io_16, input$pais_transacoes, colnames)
  })
  
  fazer_selecao <- reactive({
    switch(paste0(input$transacoes_versao,input$transacoes_agregacao),
             "WIOD13Agregado" = 1,
             "WIOD13Por setor de origem" = 2,
             "WIOD13Por setor de destino" = 3,
             "WIOD16Agregado" = 4,
             "WIOD16Por setor de origem" = 5,
             "WIOD16Por setor de destino" = 6)
  })
  
  dados <- reactive({ 
    m_io_13 %>% 
      agregado(input$ano_transacoes, "exportações.pm",  linhas_13()) %>% 
      as.data.table(keep.rownames = "paisect") %>%
      separate(paisect, c("pais_origen", "sector_origen"), sep="\\.") %>%
      pivot_longer(-c(pais_origen, sector_origen), names_to = "paisect_d", 
                   values_to = "valor")%>%
      separate(paisect_d, c("pais_d", "sect_d"), sep = "\\.")
  })
  
  output$debuga <- renderTable({
    glimpse(dados())
  })
  
  output$pais <- renderDataTable(
    tabmil(t(sea_paises[,as.character(input$ano_pais),,input$pais]))%>%
      left_join(varst)%>%
      select(var = pt, 2:3),
 #   rownames = TRUE,
#    spacing = "xs",
#    striped = TRUE,
 #   hover = TRUE,
#    width = "100%",
    options = list(pageLength = 10, info = FALSE, lengthMenu = list(c(10, -1), c("10", "All")) )
  )

  output$serie_pais <- renderPlotly({
    dados <- sea_paises[,,input$indicador_pais,input$pais]
    plotaserie(dados)
  })

  output$setores_pais_13 <- renderDataTable(
    tabmil(sea_setores_13[as.character(input$ano_pais),
                   input$indicador_pais,
                   grep(input$pais, colnames(sea_setores_13[1,,]))]) %>%
      separate(var,c("Legenda","Code"),sep="\\.") %>%
      left_join(setorest) %>% 
      left_join(paises) %>%
      select(pais=`Países`,setor=pt,value = x),
#    rownames = TRUE,
#    spacing = "xs",
#    striped = TRUE,
    #hover = TRUE,
    #width = "100%",
options = list(pageLength = 30, info = FALSE, lengthMenu = list(c(30, -1), c("30", "All")) )
  )

  output$setores_pais_16 <- renderDataTable(
    tabmil(sea_setores_16[as.character(input$ano_pais),
                   input$indicador_pais,
                   grep(input$pais, colnames(sea_setores_16[1,,]))])%>%
      separate(var,c("Legenda","Code"),sep="\\.") %>% 
      left_join(setorest) %>% 
      left_join(paises) %>%
      select(pais=`Países`,setor=pt,value = x),
    #rownames = TRUE,
#    spacing = "xs",
#    striped = TRUE,
    #hover = TRUE,
    #width = "100%",
options = list(pageLength = 30, info = FALSE, lengthMenu = list(c(30, -1), c("30", "All")) )

  )

  output$indicadores1 <- renderTable({
      t(sea_paises[,as.character(input$ano_indicador),input$indicador,])[1:(num_paises/2),]
    },
    rownames = TRUE,
    spacing = "xs",
    striped = TRUE,
    hover = TRUE,
    width = "100%"
    )

  output$indicadores2 <- renderTable({
      t(sea_paises[,as.character(input$ano_indicador),input$indicador,])[((num_paises/2)+1):num_paises,]
    },
    rownames = TRUE,
    spacing = "xs",
    striped = TRUE,
    hover = TRUE,
    width = "100%"
    )

  output$serie <- renderPlotly({
    dados <- sea_paises[input$versao_indicadores,,
                        input$indicador,
                        input$paises_indicadores]
  plotaserie(dados)
  })


### sobre esses outputs que se seguem: é preciso melhorar. Seria possível ter
### uma única função que fosse chamada conforme a seleção de (exportação,
### importação e saldo), e chamada 3 vezes (monetária, valor e transferência)?
  # Problema: os dados de exportações, importações e saldo são distintos.
  # Mas são os mesmos dados conforme o tipo de variável (monetário, valor transf)
  # No entanto, os gráficos conforme tipo de variábel são concomitantes.

### Sim certamente possível
  output$exportacoes_monetarias <- renderD3tree2({
    selecao <- fazer_selecao()
    
    ##Preparación del filtro del treemap interactivo
    agrupamento <- c("pais_origen","pais_d","sect_d")
    if (selecao %in% c(2,5) ){
      agrupamento <- c("pais_origen","sect_origen","pais_d")
    } else  if (selecao %in% c(3,6)){
      agrupamento <- c("pais_origen","sect_d","pais_d")
    }
    
    if (selecao < 4) {
      #Prepara versão do BD
      dados <- m_io_13 %>% 
        agregado(input$ano_transacoes, "exportações.pm", linhas_13()) %>% 
        as.data.table(keep.rownames = "paisect")%>%
        separate(paisect,c("pais_origen","sector_origen"),sep="\\.")%>%
        pivot_longer(-c(pais_origen,sector_origen),names_to="paisect_d",values_to="valor")%>%
        separate(paisect_d,c("pais_d","sect_d"),sep="\\.")
    } else {
      dados <- m_io_16 %>% 
        agregado(input$ano_transacoes, "exportações.pm", linhas_16()) %>% 
        as.data.table(keep.rownames = "paisect")%>%
        separate(paisect,c("pais_origen","sector_origen"),sep="\\.")%>%
        pivot_longer(-c(pais_origen,sector_origen),names_to="paisect_d",values_to="valor")%>%
        separate(paisect_d,c("pais_d","sect_d"),sep="\\.")
    }
    #genera el resultado interactivo
    d3tree2(treemap(dados, index = agrupamento, vSize = "valor", 
                    type = "value", palette = "Set1"))
    }
    )

  output$exportacoes_valores <- renderPlot({
    selecao <- fazer_selecao()
    
    if (selecao < 4) {
      dados <- m_io_13 %>% 
        agregado(input$ano_transacoes,"exportações.pm", linhas_13()) %>% 
        as.data.table()
      
    } else if (selecao > 3) {
      m_paises_16 %>% 
        agregado(input$ano_transacoes, "exportações.valores", input$pais_transacoes)
      
    } else if (selecao == 5) {
      m_io_16 %>% 
        agregado(input$ano_transacoes, "exportações.valores", linhas_16()) %>% 
        rowSums()
    } else if (selecao == 6) {
      m_io_16 %>% 
        agregado(input$ano_transacoes, "exportações.valores", linhas_16()) %>% 
        limitar_colunas(-colunas_16()) %>% 
        colSums()
    }})

  output$exportacoes_transferencias <- renderPlot({
    selecao <- fazer_selecao()
    
    if (selecao == 1) {
      temp <- m_paises_13 %>% 
        agregado(input$ano_transacoes,
                 "transferências.valores",
                  input$pais_transacoes)
      dados <- data.frame(valor = temp, pais = names(temp))
      treemap(dados, index="pais", vSize = "valor", type = "value")
    } else if (selecao == 2) {
      m_io_13 %>% 
        agregado(input$ano_transacoes,
                 "transferências.valores",
                 linhas_13()) %>% 
        rowSums()
    } else if (selecao == 3) {
      m_io_13 %>% 
        agregado(input$ano_transacoes, "transferências.valores", linhas_13()) %>% 
        limitar_colunas(-colunas_16()) %>% 
        colSums()
    } else if (selecao == 4) {
      m_paises_16 %>% 
        agregado(input$ano_transacoes, "transferências.valores", input$pais_transacoes)
      
    } else if (selecao == 5) {
      m_io_16 %>% 
        agregado(input$ano_transacoes, "transferências.valores", linhas_16()) %>% 
        rowSums()
    } else if (selecao == 6) {
      m_io_16 %>% 
        agregado(input$ano_transacoes, "transferências.valores", linhas_16()) %>% 
        limitar_colunas(-colunas_16()) %>% 
        colSums()
    }},
    rownames = TRUE)
  
  output$importacoes_monetarias <- renderTable({
    selecao <- fazer_selecao()
    if (selecao == 1) {
      m_paises_13 %>% 
        agregado(input$ano_transacoes,
                 "exportações.pm",
                 TRUE) %>% 
        limitar_colunas(input$pais_transacoes)
    } else if (selecao == 2) {
      m_io_13 %>% 
        agregado(input$ano_transacoes,
                 "exportações.pm",
                 -linhas_13()) %>% 
        limitar_colunas(colunas_13()) %>% 
        rowSums()
    } else if (selecao == 3) {
      m_io_13 %>% 
        agregado(input$ano_transacoes,
                 "exportações.pm",
                 TRUE) %>% 
        limitar_colunas(colunas_13()) %>% 
        colSums()
    } else if (selecao == 4) {
      m_paises_16 %>% 
        agregado(input$ano_transacoes,
                 "exportações.pm",
                 TRUE) %>% 
        limitar_colunas(input$pais_transacoes)
    } else if (selecao == 5) {
      m_io_16 %>% 
        agregado(input$ano_transacoes,
                 "exportações.pm",
                 -linhas_16()) %>% 
        limitar_colunas(colunas_16()) %>% 
        rowSums()
    } else if (selecao == 6) {
      m_io_16 %>% 
        agregado(input$ano_transacoes,
                 "exportações.pm",
                 TRUE) %>% 
        limitar_colunas(colunas_16()) %>% 
        colSums()
    }},
    rownames = TRUE)
  
  output$importacoes_valores <- renderTable({
    selecao <- fazer_selecao()
    
    if (selecao == 1) {
      m_paises_13 %>% 
        agregado(input$ano_transacoes, "exportações.valores", TRUE) %>% 
          limitar_colunas(input$pais_transacoes)
    } else if (selecao == 2) {
      m_io_13 %>% 
        agregado(input$ano_transacoes, "exportações.valores", -linhas_13()) %>% 
        limitar_colunas(colunas_13()) %>% 
        rowSums(na.rm = TRUE)
    } else if (selecao == 3) {
      m_io_13 %>% 
        agregado(input$ano_transacoes, "exportações.valores", TRUE) %>% 
        limitar_colunas(colunas_13()) %>% 
        colSums()
    } else if (selecao == 4) {
      m_paises_16 %>% 
        agregado(input$ano_transacoes, "exportações.valores", TRUE) %>% 
        limitar_colunas(input$pais_transacoes)
    } else if (selecao == 5) {
      m_io_16 %>% 
        agregado(input$ano_transacoes, "exportações.valores", -linhas_16()) %>% 
        limitar_colunas(colunas_16()) %>% 
        rowSums(na.rm = TRUE)
    } else if (selecao == 6) {
      m_io_16 %>% 
        agregado(input$ano_transacoes, "exportações.valores", TRUE) %>% 
        limitar_colunas(colunas_16()) %>% 
        colSums()
    }},
    rownames = TRUE)

  output$importacoes_transferencias <- renderTable({
    selecao <- fazer_selecao()
    
    if (selecao == 1) {
      m_paises_13 %>% 
        agregado(input$ano_transacoes, "transferências.valores", TRUE) %>% 
        limitar_colunas(input$pais_transacoes)
    } else if (selecao == 2) {
      m_io_13 %>% 
        agregado(input$ano_transacoes, "transferências.valores", -linhas_13()) %>% 
        limitar_colunas(colunas_13()) %>% 
        rowSums(na.rm = TRUE)
    } else if (selecao == 3) {
      m_io_13 %>% 
        agregado(input$ano_transacoes, "transferências.valores", TRUE) %>% 
        limitar_colunas(colunas_13()) %>% 
        colSums()
    } else if (selecao == 4) {
      m_paises_16 %>% 
        agregado(input$ano_transacoes, "transferências.valores", TRUE) %>% 
        limitar_colunas(input$pais_transacoes)
    } else if (selecao == 5) {
      m_io_16 %>% 
        agregado(input$ano_transacoes, "transferências.valores", -linhas_16()) %>% 
        limitar_colunas(colunas_16()) %>% 
        rowSums(na.rm = TRUE)
    } else if (selecao == 6) {
      m_io_16 %>% 
        agregado(input$ano_transacoes, "transferências.valores", TRUE) %>% 
        limitar_colunas(colunas_16()) %>% 
        colSums()
    }},
    rownames = TRUE)
  
  output$saldo_monetarias <- renderTable({
    selecao <- fazer_selecao()
    
    if (selecao == 1) {
      m_paises_13 %>% 
        agregado(input$ano_transacoes, "exportações.pm", input$pais_transacoes) %>% 
        magrittr::subtract(
          m_paises_13 %>% 
            agregado(input$ano_transacoes, "exportações.pm", TRUE) %>% 
            limitar_colunas(input$pais_transacoes)
        )
    } else if (selecao == 2) {
      linhas <- match(colunas_13(), linhas_13())
      
      m_io_13 %>% 
        agregado(input$ano_transacoes, "exportações.pm", TRUE) %>% 
        limitar_colunas(colunas_13()) %>% 
        colSums(na.rm = TRUE) %>%
        magrittr::multiply_by(-1) %>% 
        magrittr::add(
          m_io_13 %>% 
            agregado(input$ano_transacoes, "exportações.pm", linhas) %>% 
            rowSums(na.rm = TRUE)
        )
    } else if (selecao == 3) {
      m_io_13 %>% 
        agregado(input$ano_transacoes, "exportações.pm", linhas_13()) %>% 
        limitar_colunas(-colunas_13()) %>% 
        colSums() %>% 
        magrittr::subtract(
          m_io_13 %>% 
            agregado(input$ano_transacoes, "exportações.pm", -linhas_13()) %>% 
            limitar_colunas(colunas_13()) %>% 
            rowSums()
        )
    } else if (selecao == 4) {
      m_paises_16 %>% 
        agregado(input$ano_transacoes, "exportações.pm", input$pais_transacoes) %>% 
        magrittr::subtract(
          m_paises_16 %>% 
            agregado(input$ano_transacoes, "exportações.pm", TRUE) %>% 
            limitar_colunas(input$pais_transacoes)
        )
    } else if (selecao == 5) {
      linhas <- match(colunas_16(), linhas_16())
      
      m_io_16 %>% 
        agregado(input$ano_transacoes, "exportações.pm", TRUE) %>% 
        limitar_colunas(colunas_16()) %>% 
        colSums(na.rm = TRUE) %>%
        magrittr::multiply_by(-1) %>% 
        magrittr::add(
          m_io_16 %>% 
            agregado(input$ano_transacoes, "exportações.pm", linhas) %>% 
            rowSums(na.rm = TRUE)
        )
    } else if (selecao == 6) {
      m_io_16 %>% 
        agregado(input$ano_transacoes, "exportações.pm", paises) %>% 
        limitar_colunas(-colunas_16()) %>% 
        colSums() %>% 
        magrittr::subtract(
          m_io_16 %>% 
            agregado(input$ano_transacoes, "exportações.pm", -linhas_16()) %>% 
            limitar_colunas(colunas_16()) %>% 
            rowSums()
        )
    }},
    rownames = TRUE)
  
  
  output$saldo_valores <- renderTable({
    selecao <- fazer_selecao()
    if (selecao == 1) {
      m_paises_13 %>% 
        agregado(input$ano_transacoes, "exportações.valores", input$pais_transacoes) %>% 
        magrittr::subtract(
          m_paises_13 %>% 
            agregado(input$ano_transacoes, "exportações.valores", TRUE) %>% 
            limitar_colunas(input$pais_transacoes)
        )
    } else if (selecao == 2) {
      linhas <- match(colunas_13(), linhas_13())
      
      m_io_13 %>% 
        agregado(input$ano_transacoes, "exportações.valores", TRUE) %>% 
        limitar_colunas(colunas_13()) %>% 
        colSums(na.rm = TRUE) %>%
        magrittr::multiply_by(-1) %>% 
        magrittr::add(
          m_io_13 %>% 
            agregado(input$ano_transacoes, "exportações.valores", linhas) %>% 
            rowSums(na.rm = TRUE)
        )
    } else if (selecao == 3) {
      m_io_13 %>% 
        agregado(input$ano_transacoes,
                 "exportações.valores",
                 linhas_13()) %>% 
        limitar_colunas(-colunas_13()) %>% 
        colSums() %>% 
        magrittr::subtract(
          m_io_13 %>% 
            agregado(input$ano_transacoes,
                     "exportações.valores",
                     -linhas_13()) %>% 
            limitar_colunas(colunas_13()) %>% 
            rowSums()
        )
    } else if (selecao == 4) {
      m_paises_16 %>% 
        agregado(input$ano_transacoes, "exportações.valores", input$pais_transacoes) %>% 
        magrittr::subtract(
            m_paises_16 %>% 
              agregado(input$ano_transacoes, "exportações.valores", TRUE) %>% 
              limitar_colunas(input$pais_transacoes)
          )
    } else if (selecao == 5) {
      linhas <- match(colunas_16(), linhas_16())
      
        m_io_16 %>% 
          agregado(input$ano_transacoes, "exportações.valores", TRUE) %>% 
          limitar_colunas(colunas_16()) %>% 
          colSums(na.rm = TRUE) %>%
          magrittr::multiply_by(-1) %>% 
          magrittr::add(
            m_io_16 %>% 
              agregado(input$ano_transacoes, "exportações.valores", linhas) %>% 
              rowSums(na.rm = TRUE)
          )
    } else if (selecao == 6) {
      m_io_16 %>% 
        agregado(input$ano_transacoes,
                 "exportações.valores",
                 linhas_16()) %>% 
        limitar_colunas(-colunas_16()) %>% 
        colSums() %>% 
        magrittr::subtract(
          m_io_16 %>% 
            agregado(input$ano_transacoes,
                     "exportações.valores",
                     -linhas_16()) %>% 
            limitar_colunas(colunas_16()) %>% 
            rowSums()
        )
    }},
    rownames = TRUE)
  
  output$saldo_transferencias <- renderTable({
    selecao <- fazer_selecao()
    if (selecao == 1) {
      m_paises_13 %>% 
        agregado(input$ano_transacoes,
                 "transferências.valores",
                 input$pais_transacoes) %>% 
        magrittr::subtract(
          m_paises_13 %>% 
            agregado(input$ano_transacoes,
                     "transferências.valores",
                     TRUE) %>% 
            limitar_colunas(input$pais_transacoes)
        )
    } else if (selecao == 2) {
      linhas <- match(colunas_13(), linhas_13())
      
      m_io_13 %>% 
        agregado(input$ano_transacoes,
                 "transferências.valores",
                 TRUE) %>% 
        limitar_colunas(colunas_13()) %>% 
        colSums(na.rm = TRUE) %>%
        magrittr::multiply_by(-1) %>% 
        magrittr::add(
          m_io_13 %>% 
            agregado(input$ano_transacoes,
                     "transferências.valores",
                     linhas) %>% 
            rowSums(na.rm = TRUE)
        )
    } else if (selecao == 3) {
      m_io_13 %>% 
        agregado(input$ano_transacoes,
                 "transferências.valores",
                 linhas_13()) %>% 
        limitar_colunas(-colunas_13()) %>% 
        colSums() %>% 
        magrittr::subtract(
          m_io_13 %>% 
            agregado(input$ano_transacoes,
                     "transferências.valores",
                     -linhas_13()) %>% 
            limitar_colunas(colunas_13()) %>% 
            rowSums()
        )
      
    } else if (selecao == 4) {
      m_paises_16 %>% 
        agregado(input$ano_transacoes,
                 "transferências.valores",
                 input$pais_transacoes) %>% 
        magrittr::subtract(
          m_paises_16 %>% 
            agregado(input$ano_transacoes,
                     "transferências.valores",
                     TRUE) %>% 
            limitar_colunas(input$pais_transacoes))
    } else if (selecao == 5) {
      linhas <- match(colunas_16(), linhas_16())
      
      m_io_16 %>% 
        agregado(input$ano_transacoes,
                 "transferências.valores",
                 TRUE) %>% 
        limitar_colunas(colunas_16()) %>% 
        colSums(na.rm = TRUE) %>%
        magrittr::multiply_by(-1) %>% 
        magrittr::add(
          m_io_16 %>% 
            agregado(input$ano_transacoes,
                     "transferências.valores",
                     linhas) %>% 
            rowSums(na.rm = TRUE))
    } else if (selecao == 6) {
      m_io_16 %>% 
        agregado(input$ano_transacoes,
                 "transferências.valores",
                 linhas_16()) %>% 
        limitar_colunas(-colunas_16()) %>% 
        colSums() %>% 
        magrittr::subtract(
          m_io_16 %>% 
            agregado(input$ano_transacoes,
                     "transferências.valores",
                     -linhas_16) %>% 
            limitar_colunas(colunas_16()) %>% 
            rowSums()
        )
    }},
    rownames = TRUE)

### Análise das transferências: tabelas sobre troca desigual e trocas nos setores
### improdutivos

  ## Juntar tanto as exportações quanto as importações
  output$td_envios_recebimentos <- renderTable({
    selecao <- fazer_selecao()
    if (selecao == 1) {
      temp1 <- m_paises_13[as.character(input$ano_transacoes),
                           "transferências_produtivas.valores",
                           input$pais_transacoes,
                           ]
      temp2 <-  -m_paises_13[as.character(input$ano_transacoes),
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
    selecao <- fazer_selecao()
    if (selecao == 1){
      m_paises_13[as.character(input$ano_transacoes),
                           "transferências_produtivas.valores",
                           input$pais_transacoes,] -
      m_paises_13[as.character(input$ano_transacoes),
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
    selecao <- fazer_selecao()
    if (selecao == 1){
      temp1 <- m_paises_13[as.character(input$ano_transacoes),
                           "transferencias_valores",
                           input$pais_transacoes,] -
        m_paises_13[as.character(input$ano_transacoes),
                           "transferências_produtivas.valores",
                           input$pais_transacoes,]
      temp2 <-  -(m_paises_13[as.character(input$ano_transacoes),
                            "transferencias_valores",
                            ,input$pais_transacoes] -
        m_paises_13[as.character(input$ano_transacoes),
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
    selecao <- fazer_selecao()
    if (selecao == 1){
      temp1 <- m_paises_13[as.character(input$ano_transacoes),
                           "transferencias_valores",
                           input$pais_transacoes,] -
        m_paises_13[as.character(input$ano_transacoes),
                    "transferências_produtivas.valores",
                    input$pais_transacoes,] -
        (m_paises_13[as.character(input$ano_transacoes),
                              "transferencias_valores",
                              ,input$pais_transacoes] -
           m_paises_13[as.character(input$ano_transacoes),
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
    as.character(sum(m_paises_13[as.character(input$ano_transacoes),
                                 "transferências_produtivas.valores",
                                 input$pais_transacoes,] +
                       m_paises_13[as.character(input$ano_transacoes),
                                   "transferências_produtivas.valores",
                                   ,input$pais_transacoes])/
                   sum(m_paises_13[as.character(input$ano_transacoes),
                                   "transferencias_valores",
                                   input$pais_transacoes,] +
                         m_paises_13[as.character(input$ano_transacoes),
                                     "transferencias_valores",
                                     ,input$pais_transacoes]))
  })
  textOutput("proporcao_td_transferencias_saldo")

}


