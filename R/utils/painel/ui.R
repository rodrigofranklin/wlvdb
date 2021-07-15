ui <- dashboardPage(
  
  # footer = 
  #   tags$div(tags$i(class="fa fa-copyright fa-flip-horizontal"),
  #            tags$a(href="https://gitlab.com/rodrigoesborges/worldlabourvalues",
  #                   icon("creative-commons")),
  #            "Por: World Labour Values Task Force - ",
  #            tags$a(href="https://worldlabourvalues.org",
  #                   "Grupo de Estudos Concretos sobre Teoria do Valor")),
  skin = "red",
  title = "Banco de Dados Valor Trabalho Mundial",
  header = dashboardHeader (
    title = "Valor Trabalho Mundial",
    titleWidth = 250
  ),
  sidebar = dashboardSidebar(
    width = 250,
    sidebarMenu(
      id = "menu",
      menuItem(
        "País",
        tabName = "País",
        icon = icon("globe-americas")
        
        
      ),
      menuItem(
        "Indicador",
        tabName = "Indicador",
        icon = icon("chart-line")
        
        
      ),
      menuItem(
        "Comércio Internacional",
        icon = icon("sync-alt"),
        menuSubItem(
          "Exportações",
          tabName = "Exportações"
        ),
        menuSubItem(
          "Importações",
          tabName = "Importações"
        ),
        menuSubItem(
          "Saldos",
          tabName = "Saldos"
        ),
        menuSubItem(
          "Transferências",
          tabName = "Transferências"
        )
        
        
        
      )
    ),
    hr(width = "80%"),
    
    conditionalPanel(
      'input.menu == "País" |
      input.menu == "Exportações" |
      input.menu == "Importações" |
      input.menu == "Saldos" |
      input.menu == "Transferências"',
      selectInput(inputId = "pais",
                  label = "País:",
                  choices = lista_paises,
                  selected = "BRA")
    ),
    
    selectInput(inputId = "indicador",
                label = "Indicador:",
                width = "100%",
                choices = lista_variaveis_sea,
                selected = "taxa_exploracao"),

    sliderInput(inputId = "ano",
                label = NULL,
                min = ano_min,
                max = ano_max,
                value = 2009,
                ticks = FALSE,
                width = "100%",
                sep = ""),

    conditionalPanel(
      'input.menu == "Indicador"',
      
      checkboxGroupInput(inputId = "versao",
                         choices = lista_versoes,
                         selected =  lista_versoes,
                         label = "Base de dados:"),
      
      selectInput(inputId = "paises",
                  label = "Países:",
                  choices = lista_paises,
                  selected = lista_paises,
                  multiple = TRUE)      
    ),
    
    conditionalPanel(
      'input.menu == "Exportações" |
      input.menu == "Importações" |
      input.menu == "Saldos" |
      input.menu == "Transferências"',
      radioButtons(inputId = "transacoes_agregacao", choices = c("Agregado", "Por setor de origem", "Por setor de destino"), selected = "Agregado", label = ""),
      radioButtons(inputId = "transacoes_versao", choices = c("WIOD13", "WIOD16"), selected = "WIOD13", label = "Base de dados:"),
    )

    
        
  ),
  body = dashboardBody(
    tabItems(

### País -------------------------------
      tabItem(
        tabName = "País",
        column(
          width = 8,
          shinydashboard::box(
            width = "100%",
            title = textOutput("titulo_painel"),
            status = "danger",
            solidHeader = TRUE,
            dataTableOutput("pais")
          ),
          shinydashboard::box(
            width = "100%",
            title = "Série Temporal",
            status = "danger",
            solidHeader = TRUE,
            div(textOutput("titulo_serie_pais"), align = "center" , 
                style = "font-size:20px; font-weight: bold"),
            div(textOutput("subtitulo_serie_pais"), align = "center"),
            plotlyOutput("serie_pais")
          )
        ),
        column(
          width = 4,
          shinydashboard::box(
            width = "100%",
            title = "Detalhamento Setorial",
            status = "danger",
            solidHeader = TRUE,
            div(textOutput("titulo_detalhamento_pais"), align = "center",
                style = "font-size:20px; font-weight: bold"),
            div(textOutput("subtitulo_detalhamento_pais"), align = "center"),
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
        )
      ),

### Indicador -------------------------------
      tabItem(
        tabName = "Indicador",
        shinydashboard::box(
          width = "100%",
          # title = "",
          # solidHeader = TRUE,
          status = "danger",
          column(
            width = 6,
            dataTableOutput("indicadores1")
          ),
          column(
            width = 6,
            dataTableOutput("indicadores2")
          )
        ),
        shinydashboard::box(
          width = "100%",
          title = "Série Temporal",
          status = "danger",
          solidHeader = TRUE,
          plotlyOutput("serie")
        )
      ),

### Exportações -------------------------------
      tabItem(
        tabName = "Exportações"
        
      ),      

### Importações -------------------------------
      tabItem(
        tabName = "Importações"
        
      ),      

### Saldo -------------------------------
      tabItem(
        tabName = "Saldo"
        
      ),      

### Transferências -------------------------------
      tabItem(
        tabName = "Transferências"
        
      )      
    )
    
  )
)
    
        
# ### Painel "Indicador --------------    
#     
#   tabPanel(
#     "Indicador",
#     #                      tags$body(class="skin-yellow sidebar-mini control-sidebar-closed",
#     icon = icon("chart-line"),
#     dashboardPage(
#       dashboardHeader(disable = T),
#       dashboardSidebar(
#         sliderInput(inputId = "ano_indicador",
#                     label = NULL,
#                     min = ano_min,
#                     max = ano_max,
#                     value = 2009,
#                     ticks = FALSE,
#                     width = "95%",
#                     sep = ""),
#         selectInput(inputId = "indicador",
#                     label = NULL,
#                     choices = lista_variaveis_sea),
#         selectInput(inputId = "paises_indicadores",
#                     label = "Países:",
#                     choices = lista_paises,
#                     selected = lista_paises,
#                     multiple = TRUE)
#       ),
#       dashboardBody(
#         shinyDashboardThemes(
#           theme = "grey_light"
#         ),
#         
#       )
#     )
#   ),
#             tabPanel("Unequal Exchange",icon = icon("globe"),
#  #                    tags$body(class="skin-blue sidebar-mini control-sidebar-closed",
#                                dashboardPage(
#                                  dashboardHeader(disable = T),
#                                  dashboardSidebar(
#                                    sliderInput(inputId = "ano_transacoes", label = NULL, min = ano_min, max = ano_max, value = 2009, ticks = FALSE, width = "95%", sep = ""),
#                                    selectInput(inputId = "pais_transacoes", label = "País:", choices = lista_paises),
#                                    radioButtons(inputId = "transacoes_agregacao", choices = c("Agregado", "Por setor de origem", "Por setor de destino"), selected = "Agregado", label = ""),
#                                    radioButtons(inputId = "transacoes_versao", choices = c("WIOD13", "WIOD16"), selected = "WIOD13", label = ""),
#                                    sidebarMenu("",
#                                    menuItem("Export",
#                                             menuSubItem(selectInput(inputId = "par_transacoes", label = "Parceiro/Partner:", choices = lista_paises)),
#                                             tabName = "transf"
#                                    ),
#                                    menuItem("Import",
#                                             menuSubItem(selectInput(inputId = "par_transacoes", label = "Parceiro/Partner:", choices = lista_paises)),
#                                             tabName = "transf"
# 
#                                    ),
#                                    menuItem("Saldo/Position",
#                                             tabName = "transf"
#                                  ),
#                                    menuItem("Unequal Transfers",
#                                             tabName = "transf"
#                                   )
#                                    )
#                                  ),
#                                  dashboardBody(
#                                    shinydashboard::box(
#                                      #plotOutput("exportacoes_monetarias")
#                                      d3tree2Output("exportacoes_monetarias")
# 
#                                    )
#                                    #
#                                    # shinydashboard::box(
#                                    #   plotOutput("exportacoes_valores")
#                                    # ),
#                                    # shinydashboard::box(
#                                    #   plotOutput("exportacoes_transferencias")
#                                    # ),
#                                    # shinydashboard::box(
#                                    #   tableOutput("importacoes_monetarias"),
#                                    #   tableOutput("importacoes_valores"),
#                                    #   tableOutput("importacoes_transferencias"),
#                                    # ),
#                                    # shinydashboard::box(
#                                    #   tableOutput("saldo_monetarias"),
#                                    #   tableOutput("saldo_valores"),
#                                    #   tableOutput("saldo_transferencias"),
#                                    # ),
#                                    # shinydashboard::box(
#                                    #   tableOutput("td_envios_recebimentos"),
#                                    #   tableOutput("td_envios_recebimentos_saldo"),
#                                    #   tableOutput("improdutivos_envios_recebimentos"),
#                                    #   tableOutput("improdutivos_envios_recebimentos_saldo"),
#                                    #   textOutput("proporcao_td_transferencias"),
#                                    #   textOutput("proporcao_td_transferencias_saldo")
#                                    # )
#                                    #
# #                                   shinydashboard::box(tableOutput("debuga"))
#                                  )
#                                )
#                       )
# #             )
# 
#   )



