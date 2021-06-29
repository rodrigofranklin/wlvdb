require(tidyverse)

ui <- fillPage(
  # theme = "bootstrap.css",
  tabsetPanel(
    tabPanel(
      "Países",
      fluidRow(
        HTML("<center>"),
        sliderInput(inputId = "ano",
                    label = NULL,
                    min = ano_min,
                    max = ano_max,
                    value = 2009,
                    ticks = FALSE,
                    width = "95%",
                    sep = ""),
        HTML("</center>")
      ),
      column(
        width = 8,
        fluidRow(
          column(
            width = 6,
            selectInput(
              inputId = "pais",
              label = NULL,
              choices = lista_paises
            )
          ),
          column(
            width = 6,
            selectInput(
              inputId = "indicador_pais",
              label = NULL,
              choices = lista_variaveis_sea
            )
          )
        ),
        fluidRow(tableOutput("pais")),
        fluidRow(plotOutput("serie_pais"))
      ),
      column(
        width = 4,
        tabsetPanel(
          tabPanel("WIOD.13",
                   tableOutput("setores_pais_13")
          ),
          tabPanel("WIOD.16",
                   tableOutput("setores_pais_16")
          )
        )
      )
    ),
    tabPanel(
      "Indicadores",
      fluidRow(
        HTML("<center>"),
        sliderInput(inputId = "ano",
                    label = NULL,
                    min = ano_min,
                    max = ano_max,
                    value = 2009,
                    ticks = FALSE,
                    width = "95%",
                    sep = ""),
        HTML("</center>")
      ),
      column(
        width = 3,
        fluidRow(
          selectInput(inputId = "indicador", label = NULL, choices = lista_variaveis_sea)
        ),
        fluidRow(
          checkboxGroupInput(inputId = "versao_indicadores",
                             choices = lista_versoes,
                             selected =  lista_versoes,
                             label = "Versão:")
        ),
        fluidRow(
          selectInput(inputId = "paises_indicadores",
                      label = "Países:",
                      choices = lista_paises,
                      selected = lista_paises,
                      multiple = TRUE),
        )
      ),
      column(
        width = 9,
        fluidRow(
          column(
            width = 6,
            tableOutput("indicadores1")
          ),
          column(
            width = 6,
            tableOutput("indicadores2")
          )
        ),
        fluidRow(
          plotOutput("serie")
        )
      )
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
    ))
)




         