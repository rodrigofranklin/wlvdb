
ui <- fluidPage(
  navbarPage(theme=shinytheme("united"), lang="es",footer="Venceremos!",
             header="",id="mainpanel",
             title=tags$div(tags$a(href="#", class="sidebar-toggle",
                                   `data-toggle`="offcanvas",role="button",
                                   tags$span(class="sr-only","Toggle navigation") , 
                                   style='color: #ffffff;',
                                  icon("bars",class = )
             ),"World Labour Values Database"), windowTitle ="World Labour Values App", selected = "Pais/Country",
             tabPanel("Pais/Country",icon = icon("globe-americas"),
                      tags$body(class="skin-red sidebar-mini control-sidebar-closed",
                                dashboardPage(skin="red",
                                  dashboardHeader(disable = T),
                                  dashboardSidebar(
                                    sliderInput(inputId = "ano_pais",
                                                label = NULL,
                                                min = ano_min,
                                                max = ano_max,
                                                value = 2009,
                                                ticks = FALSE,
                                                width = "95%",
                                                sep = ""
                                    ),
                                    selectInput(inputId = "pais",
                                                label = NULL,
                                                choices = lista_paises
                                    ),
                                    selectInput(inputId = "indicador_pais",
                                                label = NULL,
                                                choices = lista_variaveis_sea
                                    )
                                  ),
                                  dashboardBody(
                                    ### changing theme
                                    shinyDashboardThemes(
                                      theme = "flat_red"
                                    ),
                                    box(tableOutput("pais")),
                                    box(plotlyOutput("serie_pais"),width=12,collapsible = T),
                                    box(
                                      tabsetPanel(
                                        tabPanel("WIOD.13",
                                                 tableOutput("setores_pais_13")
                                        ),
                                        tabPanel("WIOD.16",
                                                 tableOutput("setores_pais_16")
                                        )
                                      )
                                    ),
                                    box(tableOutput("debuga"))
                                  )
                                )
                      )
             ),
             tabPanel("Indicador",icon = icon("chart-line"),
                      tags$body(class="skin-yellow sidebar-mini control-sidebar-closed",
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
                                    ### changing theme
                                    shinyDashboardThemes(
                                      theme = "grey_light"
                                    ),
                                   
                                    box(
                                      tableOutput("indicadores1")
                                      ),
                                     box(
                                        tableOutput("indicadores2")
                                    ),
                                    box(
                                      plotlyOutput("serie")
                                    )
                                  )
                                )
                      )
             ),
             tabPanel("Unequal Exchange",icon = icon("globe"),
                      tags$body(class="skin-blue sidebar-mini control-sidebar-closed",
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
                                    box(
                                      plotOutput("exportacoes_monetarias")
                                      
                                    ),
                                    # 
                                    # box(
                                    #   plotOutput("exportacoes_valores")
                                    # ),
                                    # box(
                                    #   plotOutput("exportacoes_transferencias")
                                    # ),
                                    # box(
                                    #   tableOutput("importacoes_monetarias"),
                                    #   tableOutput("importacoes_valores"),
                                    #   tableOutput("importacoes_transferencias"),
                                    # ),
                                    # box(
                                    #   tableOutput("saldo_monetarias"),
                                    #   tableOutput("saldo_valores"),
                                    #   tableOutput("saldo_transferencias"),
                                    # ),
                                    # box(
                                    #   tableOutput("td_envios_recebimentos"),
                                    #   tableOutput("td_envios_recebimentos_saldo"),
                                    #   tableOutput("improdutivos_envios_recebimentos"),
                                    #   tableOutput("improdutivos_envios_recebimentos_saldo"),
                                    #   textOutput("proporcao_td_transferencias"),
                                    #   textOutput("proporcao_td_transferencias_saldo")
                                    # )
                                    # 
                                  )
                                )
                      )
             )             
             
  )
  )



