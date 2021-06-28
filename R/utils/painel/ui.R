ui <- fluidPage(
  fluidRow(
    tabsetPanel(
      tabPanel("Países",
               fluidRow(
                 wellPanel(),
                 wellPanel(selectInput(inputId = "pais",
                               label = "País:",
                               choices = lista_paises),
                           tableOutput("pais"))),
               fluidRow(
                 wellPanel(
                   selectInput(inputId = "indicador_pais",
                               label = "Indicador:",
                               choices = lista_variaveis_sea),
                   tableOutput("serie_pais")),
                 wellPanel(
                   column(3, tableOutput("setores_pais_13")),
                   column(1, tableOutput("setores_pais_16"))))),
      tabPanel("Indicadores",
          selectInput(inputId = "indicador", label = "Indicador:", choices = lista_variaveis_sea),
          tableOutput("indicadores"),

          checkboxGroupInput(inputId = "versao_indicadores",
                             choices = lista_versoes,
                             selected =  lista_versoes,
                             label = "Versão:"),
          selectInput(inputId = "paises_indicadores",
                      label = "Países:",
                      choices = lista_paises,
                      selected = lista_paises,
                      multiple = TRUE),
          tableOutput("serie")
        ),
      tabPanel("Transações Internacionais",
               navlistPanel(
                  tabPanel("Exportações",
                    tableOutput("exportacoes_monetarias"),
                    tableOutput("exportacoes_valores"),
                    tableOutput("exportacoes_transferencias"),
                  ),
                  tabPanel("Importações",
                    tableOutput("importacoes_monetarias"),
                    tableOutput("importacoes_valores"),
                    tableOutput("importacoes_transferencias"),
                  ),
                  tabPanel("Saldo",
                           tableOutput("saldo_monetarias"),
                           tableOutput("saldo_valores"),
                           tableOutput("saldo_transferencias"),
                  ),
                  tabPanel("Transferências",
                           tableOutput("td_envios_recebimentos"),
                           tableOutput("td_envios_recebimentos_saldo"),
                           tableOutput("improdutivos_envios_recebimentos"),
                           tableOutput("improdutivos_envios_recebimentos_saldo"),
                           textOutput("proporcao_td_transferencias"),
                           textOutput("proporcao_td_transferencias_saldo")
                  )
               ),
               selectInput(inputId = "pais_transacoes",
                           label = "País:",
                           choices = lista_paises),
               radioButtons(inputId = "transacoes_agregacao", choices = c("Agregado", "Por setor de origem", "Por setor de destino"), selected = "Agregado", label = ""),
               radioButtons(inputId = "transacoes_versao", choices = c("WIOD13", "WIOD16"), selected = "WIOD13", label = ""),
      ))),
  fluidRow(
    wellPanel(sliderInput(inputId = "ano", label = "", min = ano_min, max = ano_max, value = 2009, step = 1))
  )
)




         