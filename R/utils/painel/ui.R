
ui <- fluidPage(
  navbarPage(theme="painel.css", lang="es",footer=tags$div(tags$i(class="fa fa-copyright fa-flip-horizontal"),
                                                         tags$a(href="https://gitlab.com/rodrigoesborges/worldlabourvalues",icon("creative-commons")),"Por: World Labour Values Task Force - ",
                                                                  tags$a(href="https://worldlabourvalues.org","Grupo de Estudos Concretos sobre Teoria do Valor")),
             header="",id="mainpanel",
             title=tags$div(style="margin-bottom: 0px !important;",tags$a(href="#", class="sidebar-toggle",
                                   `data-toggle`="offcanvas",role="button",
                                   tags$span(class="sr-only","Toggle navigation") , 
                                   style='color: #ffffff;',
                                  icon("bars",class = )
             ),"World Labour Values Database"), windowTitle ="World Labour Values App", selected = "Pais/Country",
             tabPanel("Pais/Country",icon = icon("globe-americas"),
                                dashboardPage(skin="red",
                                  dashboardHeader(disable = T),
                                  dashboardSidebar(disable = T
                                  ),
                                  dashboardBody(
                                     ### changing theme
                                     shinyDashboardThemes(
                                       theme = "grey_light"
                                     ),
                                     tags$head(tags$style(HTML('

                                /* main sidebar */
                                .skin-red .main-sidebar {
                                background-color: indianred;
                                }
                                /* body */
                                .content-wrapper, .right-side {
                                background-color: idianred;
                                }

                                '))),
                                    fluidRow(shinydashboard::box(width=1,
                                      selectInput(inputId = "pais",
                                                  label = NULL,
                                                  choices = lista_paises
                                      )),
                                      shinydashboard::box(width=5,selectInput(inputId = "indicador_pais",
                                                  label = NULL,
                                                  choices = lista_variaveis_sea
                                      )),
                                      shinydashboard::box(width=6,sliderInput(inputId = "ano_pais",
                                                  label = NULL,
                                                  min = ano_min,
                                                  max = ano_max,
                                                  value = 2009,
                                                  ticks = FALSE,
                                                  width = "95%",
                                                  sep = ""
                                      )
                                    )
                                    ),
                                    shinydashboard::box(dataTableOutput("pais"),
                                                        plotlyOutput("serie_pais")),
                                    shinydashboard::box(
                                      tabsetPanel(
                                        tabPanel("WIOD.13",
                                                 dataTableOutput("setores_pais_13")
                                        ),
                                        tabPanel("WIOD.16",
                                                 dataTableOutput("setores_pais_16")
                                        )
                                      )
                                    ),

                                  )
                                )
             ),
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
                                      plotOutput("exportacoes_monetarias")
                                      
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
#                                    shinydashboard::box(tableOutput("debuga"))
                                  )
                                )
                      )
#             )             
             
  )
  )



