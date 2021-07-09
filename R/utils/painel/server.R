
server <- function(input, output, session) {
  ## Funções a reutilizar
  plotaserie <- function(dados,perc=F) {
    ##produz data.frame com cada versão para juntar
    
    if(length(dim(dados))>2){
      dados <- as.data.table(dados)
      ifelse(ncol(dados)==5,
      names(dados) <- c("bd","ano","indicador","pais","valor"),
      names(dados) <- c("bd","ano","pais","valor")
      )
      dados <- dados %>% mutate(ano = as.Date(paste0("01/01/",ano),
                                              tryFormats="%d/%m/%Y"),
                                across(c(-ano,-valor),as.factor))
    }else{
      bds <- names(dados[,1])
      anos <- names(dados[1,])
      dados <- as.data.table(t(dados))
      dados$ano <- as.Date(paste0("01/01/",anos),
                                 tryFormats="%d/%m/%Y")
      dados <- dados%>%pivot_longer(-ano,names_to = "bd",values_to="valor")%>%
        mutate(bd=as.factor(bd))
    }
    
    ifelse(ncol(dados)==3,
           p <- ggplot(dados,aes(x=ano,y=valor,col=bd)),
           p <- ggplot(dados,aes(x=ano,y=valor,col=pais,linetype=bd)))
      p+geom_line(size = 1) +
      scale_y_continuous(labels = comma_format(big.mark = ".", decimal.mark = ","))+
      theme_minimal()
    
    ggplotly()
    
  }
  milhares <- function(x){prettyNum(x,big.mark = ".",decimal.mark = ",")}
  tabmil <- function(x) {
    x <- as.data.table(x,keep.rownames="var")%>%mutate(across(where(is.numeric),milhares))
  }
  d <- reactive({ 
    d <- as.data.table(m_io_13[as.character(input$ano_transacoes),
                               "exportações.pm",
                               grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),],
                       keep.rownames = "paisect")
    d <- d%>%separate(paisect,c("pais_origen","sector_origen"),sep="\\.")%>%
      pivot_longer(-c(pais_origen,sector_origen),names_to="paisect_d",values_to="valor")%>%
      separate(paisect_d,c("pais_d","sect_d"),sep="\\.")
    
    print(d) # print from within
    return(d)
  })
  output$debuga <- renderTable({
    glimpse(d())
    })
  output$pais <- renderDataTable(
    tabmil(t(sea_paises[,as.character(input$ano_pais),,input$pais]))%>%
      left_join(varst)%>%
      select(var=pt,2:3),
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
                   grep(input$pais, colnames(sea_setores_13[1,,]))])%>%
      separate(var,c("Legenda","Code"),sep="\\.")%>%left_join(setorest)%>%left_join(paises)%>%
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
      separate(var,c("Legenda","Code"),sep="\\.")%>%left_join(setorest)%>%left_join(paises)%>%
      select(pais=`Países`,setor=pt,value = x),
    #rownames = TRUE,
#    spacing = "xs",
#    striped = TRUE,
    #hover = TRUE,
    #width = "100%",
options = list(pageLength = 30, info = FALSE, lengthMenu = list(c(30, -1), c("30", "All")) )

  )

  output$indicadores1 <-
    renderTable({
      t(sea_paises[,as.character(input$ano_indicador),input$indicador,])[1:(num_paises/2),]
    },
    rownames = TRUE,
    spacing = "xs",
    striped = TRUE,
    hover = TRUE,
    width = "100%"
    )

  output$indicadores2 <-
    renderTable({
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
    selecao <- fazer_selecao(input$transacoes_versao,input$transacoes_agregacao)
    
    ##Preparación del filtro del treemap interactivo
    agrupamento <- c("pais_origen","pais_d","sect_d")
    if (selecao %in% c(2,5) ){
      agrupamento <- c("pais_origen","sect_origen","pais_d")
    } else  if (selecao %in% c(3,6)){
      agrupamento <- c("pais_origen","sect_d","pais_d")
    }
    
    if (selecao < 4) {
      #Prepara versão do BD
      dados <- as.data.table(m_io_13[as.character(input$ano_transacoes),
                                     "exportações.pm",
                                     grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),],
                             keep.rownames = "paisect")%>%
        separate(paisect,c("pais_origen","sector_origen"),sep="\\.")%>%
        pivot_longer(-c(pais_origen,sector_origen),names_to="paisect_d",values_to="valor")%>%
        separate(paisect_d,c("pais_d","sect_d"),sep="\\.")
      
    } else {
      dados <- as.data.table(m_io_16[as.character(input$ano_transacoes),
                                     "exportações.pm",
                                     grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),],
                             keep.rownames = "paisect")%>%
        separate(paisect,c("pais_origen","sector_origen"),sep="\\.")%>%
        pivot_longer(-c(pais_origen,sector_origen),names_to="paisect_d",values_to="valor")%>%
        separate(paisect_d,c("pais_d","sect_d"),sep="\\.")
    }
    #genera el resultado interactivo
    d3tree2(treemap(dados, index=agrupamento, vSize = "valor", type = "value",
                    palette = "Set1"))
    }
    )

  output$exportacoes_valores <- renderPlot({
    selecao <- fazer_selecao(input$transacoes_versao,input$transacoes_agregacao)
    if (selecao < 4) {
      dados <- as.data.table(m_io_13[as.character(input$ano_transacoes),
                                     "exportações.pm",
                                     grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),])
    } else if (selecao > 3) {
      m_paises_16[as.character(input$ano_transacoes),
                  "exportações.valores",
                  input$pais_transacoes,]
    } else if (selecao == 5) {
      rowSums(m_io_16[as.character(input$ano_transacoes),
                      "exportações.valores",
                      grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),])
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano_transacoes),
                      "exportações.valores",
                      grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    }})

  output$exportacoes_transferencias <- renderPlot({
    selecao <- fazer_selecao(input$transacoes_versao,input$transacoes_agregacao)
    if (selecao == 1) {
      temp <- m_paises_13[as.character(input$ano_transacoes),
                          "transferências.valores",
                          input$pais_transacoes,]
      dados <- data.frame(valor = temp, pais = names(temp))
      treemap(dados, index="pais", vSize = "valor", type = "value")
    } else if (selecao == 2) {
      rowSums(m_io_13[as.character(input$ano_transacoes),
                      "transferências.valores",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),])
    } else if (selecao == 3) {
      colSums(m_io_13[as.character(input$ano_transacoes),
                      "transferências.valores",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano_transacoes),
                  "transferências.valores",
                  input$pais_transacoes,]
    } else if (selecao == 5) {
      rowSums(m_io_16[as.character(input$ano_transacoes),
                      "transferências.valores",
                      grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),])
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano_transacoes),
                      "transferências.valores",
                      grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    }},
    rownames = TRUE)

  output$importacoes_monetarias <- renderTable({
    selecao <- fazer_selecao(input$transacoes_versao,input$transacoes_agregacao)
    if (selecao == 1) {
      m_paises_13[as.character(input$ano_transacoes),
                  "exportações.pm",
                  ,input$pais_transacoes]
    } else if (selecao == 2) {
      rowSums(m_io_13[as.character(input$ano_transacoes),
                      "exportações.pm",
                      -grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                      grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 3) {
      colSums(m_io_13[as.character(input$ano_transacoes),
                      "exportações.pm",
                      ,grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano_transacoes),
                  "exportações.pm",
                  ,input$pais_transacoes]
    } else if (selecao == 5) {
      rowSums(m_io_16[as.character(input$ano_transacoes),
                      "exportações.pm",
                      -grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                      grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano_transacoes),
                      "exportações.pm",
                      ,grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    }},
    rownames = TRUE)

  output$importacoes_valores <- renderTable({
    selecao <- fazer_selecao(input$transacoes_versao,input$transacoes_agregacao)
    if (selecao == 1) {
      m_paises_13[as.character(input$ano_transacoes),
                  "exportações.valores",
                  ,input$pais_transacoes]
    } else if (selecao == 2) {
      rowSums(m_io_13[as.character(input$ano_transacoes),
                      "exportações.valores",
                      -grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                      grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))],
              na.rm = TRUE)
    } else if (selecao == 3) {
      colSums(m_io_13[as.character(input$ano_transacoes),
                      "exportações.valores",
                      ,grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano_transacoes),
                  "exportações.valores",
                  ,input$pais_transacoes]
    } else if (selecao == 5) {
      rowSums(m_io_16[as.character(input$ano_transacoes),
                      "exportações.valores",
                      -grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                      grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano_transacoes),
                      "exportações.valores",
                      ,grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    }},
    rownames = TRUE)

  output$importacoes_transferencias <- renderTable({
    selecao <- fazer_selecao(input$transacoes_versao,input$transacoes_agregacao)
    if (selecao == 1) {
      m_paises_13[as.character(input$ano_transacoes),
                  "transferências.valores",
                  ,input$pais_transacoes]
    } else if (selecao == 2) {
      rowSums(m_io_13[as.character(input$ano_transacoes),
                      "transferências.valores",
                      -grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                      grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 3) {
      colSums(m_io_13[as.character(input$ano_transacoes),
                      "transferências.valores",
                      ,grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano_transacoes),
                  "transferências.valores",
                  ,input$pais_transacoes]
    } else if (selecao == 5) {
      rowSums(m_io_16[as.character(input$ano_transacoes),
                      "transferências.valores",
                      -grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                      grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano_transacoes),
                      "transferências.valores",
                      ,grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    }},
    rownames = TRUE)

  output$saldo_monetarias <- renderTable({
    selecao <- fazer_selecao(input$transacoes_versao,input$transacoes_agregacao)
    if (selecao == 1) {
      m_paises_13[as.character(input$ano_transacoes),
                  "exportações.pm",
                  input$pais_transacoes,] -
      m_paises_13[as.character(input$ano_transacoes),
                  "exportações.pm",
                  ,input$pais_transacoes]
    } else if (selecao == 2) {
      - colSums(m_io_13[as.character(input$ano_transacoes),
                        "exportações.pm",
                        ,grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))],
                na.rm = TRUE) +
      rowSums(m_io_13[as.character(input$ano_transacoes),
                      "exportações.pm",
                      match(grep(input$pais_transacoes,colnames(m_io_13[1,1,,])),
                            grep(input$pais_transacoes,rownames(m_io_13[1,1,,]))),],
              na.rm = TRUE)
    } else if (selecao == 3) {
      colSums(m_io_13[as.character(input$ano_transacoes),
                      "exportações.pm",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))]) -
      rowSums(m_io_13[as.character(input$ano_transacoes),
                      "exportações.pm",
                      -grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                      grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano_transacoes),
                  "exportações.pm",
                  input$pais_transacoes,] -
      m_paises_16[as.character(input$ano_transacoes),
                  "exportações.pm",
                  ,input$pais_transacoes]
    } else if (selecao == 5) {
      - colSums(m_io_16[as.character(input$ano_transacoes),
                        "exportações.pm",
                        ,grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))],
                na.rm = TRUE) +
        rowSums(m_io_16[as.character(input$ano_transacoes),
                        "exportações.pm",
                        match(grep(input$pais_transacoes,colnames(m_io_16[1,1,,])),
                              grep(input$pais_transacoes,rownames(m_io_16[1,1,,]))),],
                na.rm = TRUE)
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano_transacoes),
                      "exportações.pm",
                      grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))]) -
        rowSums(m_io_16[as.character(input$ano_transacoes),
                        "exportações.pm",
                        -grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                        grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    }},
    rownames = TRUE)

  output$saldo_valores <- renderTable({
    selecao <- fazer_selecao(input$transacoes_versao,input$transacoes_agregacao)
    if (selecao == 1) {
      m_paises_13[as.character(input$ano_transacoes),
                  "exportações.valores",
                  input$pais_transacoes,] -
        m_paises_13[as.character(input$ano_transacoes),
                    "exportações.valores",
                    ,input$pais_transacoes]
    } else if (selecao == 2) {
      - colSums(m_io_13[as.character(input$ano_transacoes),
                        "exportações.valores",
                        ,grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))],
                na.rm = TRUE) +
        rowSums(m_io_13[as.character(input$ano_transacoes),
                        "exportações.valores",
                        match(grep(input$pais_transacoes,colnames(m_io_13[1,1,,])),
                              grep(input$pais_transacoes,rownames(m_io_13[1,1,,]))),],
                na.rm = TRUE)
    } else if (selecao == 3) {
      colSums(m_io_13[as.character(input$ano_transacoes),
                      "exportações.valores",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))]) -
        rowSums(m_io_13[as.character(input$ano_transacoes),
                        "exportações.valores",
                        -grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                        grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano_transacoes),
                  "exportações.valores",
                  input$pais_transacoes,] -
        m_paises_16[as.character(input$ano_transacoes),
                    "exportações.valores",
                    ,input$pais_transacoes]
    } else if (selecao == 5) {
      - colSums(m_io_16[as.character(input$ano_transacoes),
                        "exportações.valores",
                        ,grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))],
                na.rm = TRUE) +
        rowSums(m_io_16[as.character(input$ano_transacoes),
                        "exportações.valores",
                        match(grep(input$pais_transacoes,colnames(m_io_16[1,1,,])),
                              grep(input$pais_transacoes,rownames(m_io_16[1,1,,]))),],
                na.rm = TRUE)
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano_transacoes),
                      "exportações.valores",
                      grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))]) -
        rowSums(m_io_16[as.character(input$ano_transacoes),
                        "exportações.valores",
                        -grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                        grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    }},
    rownames = TRUE)

  output$saldo_transferencias <- renderTable({
    selecao <- fazer_selecao(input$transacoes_versao,input$transacoes_agregacao)
    if (selecao == 1) {
      m_paises_13[as.character(input$ano_transacoes),
                  "transferências.valores",
                  input$pais_transacoes,] -
        m_paises_13[as.character(input$ano_transacoes),
                    "transferências.valores",
                    ,input$pais_transacoes]
    } else if (selecao == 2) {
      - colSums(m_io_13[as.character(input$ano_transacoes),
                        "transferências.valores",
                        ,grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))],
                na.rm = TRUE) +
        rowSums(m_io_13[as.character(input$ano_transacoes),
                        "transferências.valores",
                        match(grep(input$pais_transacoes,colnames(m_io_13[1,1,,])),
                              grep(input$pais_transacoes,rownames(m_io_13[1,1,,]))),],
                na.rm = TRUE)
    } else if (selecao == 3) {
      colSums(m_io_13[as.character(input$ano_transacoes),
                      "transferências.valores",
                      grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))]) -
        rowSums(m_io_13[as.character(input$ano_transacoes),
                        "transferências.valores",
                        -grep(input$pais_transacoes,rownames(m_io_13[1,1,,])),
                        grep(input$pais_transacoes,colnames(m_io_13[1,1,,]))])
    } else if (selecao == 4) {
      m_paises_16[as.character(input$ano_transacoes),
                  "transferências.valores",
                  input$pais_transacoes,] -
        m_paises_16[as.character(input$ano_transacoes),
                    "transferências.valores",
                    ,input$pais_transacoes]
    } else if (selecao == 5) {
      - colSums(m_io_16[as.character(input$ano_transacoes),
                        "transferências.valores",
                        ,grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))],
                na.rm = TRUE) +
        rowSums(m_io_16[as.character(input$ano_transacoes),
                        "transferências.valores",
                        match(grep(input$pais_transacoes,colnames(m_io_16[1,1,,])),
                              grep(input$pais_transacoes,rownames(m_io_16[1,1,,]))),],
                na.rm = TRUE)
    } else if (selecao == 6) {
      colSums(m_io_16[as.character(input$ano_transacoes),
                      "transferências.valores",
                      grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                      -grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))]) -
        rowSums(m_io_16[as.character(input$ano_transacoes),
                        "transferências.valores",
                        -grep(input$pais_transacoes,rownames(m_io_16[1,1,,])),
                        grep(input$pais_transacoes,colnames(m_io_16[1,1,,]))])
    }},
    rownames = TRUE)

### Análise das transferências: tabelas sobre troca desigual e trocas nos setores
### improdutivos

  ## Juntar tanto as exportações quanto as importações
  output$td_envios_recebimentos <- renderTable({
    selecao <- fazer_selecao(input$transacoes_versao,input$transacoes_agregacao)
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
    selecao <- fazer_selecao(input$transacoes_versao,input$transacoes_agregacao)
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
    selecao <- fazer_selecao(input$transacoes_versao,input$transacoes_agregacao)
    if (selecao == 1){
      temp1 <- m_paises_13[as.character(input$ano_transacoes),
                           "transferências.valores",
                           input$pais_transacoes,] -
        m_paises_13[as.character(input$ano_transacoes),
                           "transferências_produtivas.valores",
                           input$pais_transacoes,]
      temp2 <-  -(m_paises_13[as.character(input$ano_transacoes),
                            "transferências.valores",
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
    selecao <- fazer_selecao(input$transacoes_versao,input$transacoes_agregacao)
    if (selecao == 1){
      temp1 <- m_paises_13[as.character(input$ano_transacoes),
                           "transferências.valores",
                           input$pais_transacoes,] -
        m_paises_13[as.character(input$ano_transacoes),
                    "transferências_produtivas.valores",
                    input$pais_transacoes,] -
        (m_paises_13[as.character(input$ano_transacoes),
                              "transferências.valores",
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
                                   "transferências.valores",
                                   input$pais_transacoes,] +
                         m_paises_13[as.character(input$ano_transacoes),
                                     "transferências.valores",
                                     ,input$pais_transacoes]))
  })
  textOutput("proporcao_td_transferencias_saldo")

}


