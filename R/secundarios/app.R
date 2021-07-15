library(shiny) 
library(shinydashboard) 
library(shinydashboardPlus) 
ui <- fluidPage(
  reactive(navbarPage(title = "Abas principais", windowTitle ="World Labour Values App", id="tabactive", 
             tabPanel("Exploitation conscience",icon = icon("table"),
                      tags$body(class="skin-blue sidebar-mini control-sidebar-open", 
                                p("ola mundo"),
                                dashboardPage(
                                              dashboardHeader(disable = T, controlbarIcon  = "gears" ),
                                              dashboardSidebar(),
                                              dashboardBody(
                                                ),
                                              # dashboardControlbar( background = "dark", 
                                              #                              controlbarItem( id = 1, 
                                              #                                                      title = "Controllers", 
                                              #                                                    icon = "desktop", 
                                              #                                                     active = TRUE )) 
                                              )
                      )
             ),
             tabPanel("Holdings Analysis",icon = icon("line-chart"))
             )
           )
)

server <- function(input, output, session) {output$teste <- paste0(input$tabactive)} 

shinyApp(ui = ui, server = server) 
