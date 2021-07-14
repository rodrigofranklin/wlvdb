
ui <- navbarPage(
    theme="painel.css",
    lang="es",
    footer=tags$div(tags$i(class="fa fa-copyright fa-flip-horizontal"),
                    tags$a(href="https://gitlab.com/rodrigoesborges/worldlabourvalues",
                           icon("creative-commons")),
                    "Por: World Labour Values Task Force - ",
                    tags$a(href="https://worldlabourvalues.org",
                           "Grupo de Estudos Concretos sobre Teoria do Valor")),
    header="",
    id="mainpanel",
    title=tags$div(style="margin-bottom: 0px !important;",
                   tags$a(href="#", class="sidebar-toggle",
                          `data-toggle`="offcanvas",role="button",
                          tags$span(class="sr-only","Toggle navigation") ,
                          style='color: #ffffff;',
                          icon("bars",class = )),
                   "World Labour Values Database"),
    windowTitle ="World Labour Values App",
    selected = "País",

    
        
### Painel "País" -------------------    
    
    tabPanel(
      "País",
      icon = icon("globe-americas"),
      column(
        width = 4,
        wellPanel(
          fluidRow(
            column(
              width = 5,
              selectInput(inputId = "pais", 
                          label = "País:", 
                          width = "100%",
                          choices = lista_paises)          
            ),
            column(
              width = 7,
              selectInput(inputId = "indicador_pais",
                          label = "Indicador:",
                          width = "100%",
                          choices = lista_variaveis_sea)          
            )
          ),
          fluidRow(
            align = "center",
            sliderInput(inputId = "ano_pais",
                        label = NULL,
                        min = ano_min,
                        max = ano_max,
                        value = 2009,
                        ticks = FALSE,
                        width = "95%",
                        sep = "")
          )
        ),
        wellPanel(
          tabsetPanel(
            tabPanel(
              "WIOD.13",
              dataTableOutput("setores_pais_13")
            ),
            tabPanel(
              "WIOD.16",
              dataTableOutput("setores_pais_16")
            )
          )
        )
      ),
      column(
        width = 8,
        wellPanel(
          
          plotlyOutput("serie_pais")
        ),
        wellPanel(
          dataTableOutput("pais"),          
        )
      )
    ),
    
    
    
  
    
### Painel "Indicador --------------    
    
  tabPanel("Indicador",icon = icon("chart-line"),
#                      tags$body(class="skin-yellow sidebar-mini control-sidebar-closed",
                                dashboardPage(
                                  dashboardHeader(disable = T),
                                  dashboardSidebar(
                                    sliderInput(inputId = "ano_indicador",
                                                label = NULL,
                                                min = ano_min,
                                                max = ano_max,
                                                value = 2009,
                                                ticks = FALSE,
                                                width = "95%",
                                                sep = ""),
                                    selectInput(inputId = "indicador", 
                                                label = NULL, 
                                                choices = lista_variaveis_sea),
                                    checkboxGroupInput(inputId = "versao_indicadores",
                                                       choices = lista_versoes,
                                                       selected =  lista_versoes,
                                                       label = "Versão:"),
                                    selectInput(inputId = "paises_indicadores",
                                                label = "Países:",
                                                choices = lista_paises,
                                                selected = lista_paises,
                                                multiple = TRUE)
                                  ),
                                  dashboardBody(
                                    # ### changing theme
                                    # shinyDashboardThemes(
                                    #   theme = "grey_light"
                                    # ),
                                   
                                    shinydashboard::box(
                                      tableOutput("indicadores1")
                                      ),
                                     shinydashboard::box(
                                        tableOutput("indicadores2")
                                    ),
                                    shinydashboard::box(width=12,
                                      plotlyOutput("serie")
                                    )
                                  )
                                )
 #                     )
             ),
             tabPanel("Unequal Exchange",icon = icon("globe"),
  #                    tags$body(class="skin-blue sidebar-mini control-sidebar-closed",
                                dashboardPage(
                                  dashboardHeader(disable = T),
                                  dashboardSidebar(
                                    sliderInput(inputId = "ano_transacoes", label = NULL, min = ano_min, max = ano_max, value = 2009, ticks = FALSE, width = "95%", sep = ""),
                                    selectInput(inputId = "pais_transacoes", label = "País:", choices = lista_paises),
                                    radioButtons(inputId = "transacoes_agregacao", choices = c("Agregado", "Por setor de origem", "Por setor de destino"), selected = "Agregado", label = ""), 
                                    radioButtons(inputId = "transacoes_versao", choices = c("WIOD13", "WIOD16"), selected = "WIOD13", label = ""),
                                    sidebarMenu("",
                                    menuItem("Export",
                                             menuSubItem(selectInput(inputId = "par_transacoes", label = "Parceiro/Partner:", choices = lista_paises)),
                                             tabName = "transf"
                                    ),
                                    menuItem("Import",
                                             menuSubItem(selectInput(inputId = "par_transacoes", label = "Parceiro/Partner:", choices = lista_paises)),
                                             tabName = "transf"

                                    ),
                                    menuItem("Saldo/Position",
                                             tabName = "transf"
                                  ),
                                    menuItem("Unequal Transfers",
                                             tabName = "transf"
                                   )
                                    )
                                  ),
                                  dashboardBody(
                                    shinydashboard::box(
                                      #plotOutput("exportacoes_monetarias")
                                      d3tree2Output("exportacoes_monetarias")
                                      
                                    ),
                                    # 
                                    # shinydashboard::box(
                                    #   plotOutput("exportacoes_valores")
                                    # ),
                                    # shinydashboard::box(
                                    #   plotOutput("exportacoes_transferencias")
                                    # ),
                                    # shinydashboard::box(
                                    #   tableOutput("importacoes_monetarias"),
                                    #   tableOutput("importacoes_valores"),
                                    #   tableOutput("importacoes_transferencias"),
                                    # ),
                                    # shinydashboard::box(
                                    #   tableOutput("saldo_monetarias"),
                                    #   tableOutput("saldo_valores"),
                                    #   tableOutput("saldo_transferencias"),
                                    # ),
                                    # shinydashboard::box(
                                    #   tableOutput("td_envios_recebimentos"),
                                    #   tableOutput("td_envios_recebimentos_saldo"),
                                    #   tableOutput("improdutivos_envios_recebimentos"),
                                    #   tableOutput("improdutivos_envios_recebimentos_saldo"),
                                    #   textOutput("proporcao_td_transferencias"),
                                    #   textOutput("proporcao_td_transferencias_saldo")
                                    # )
                                    # 
 #                                   shinydashboard::box(tableOutput("debuga"))
                                  )
                                )
                      )
#             )             
             
  )



