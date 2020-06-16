library(shiny)
library(tidyverse)

ler_transf <- function(path) {
  transf <- read_csv2(path, locale = locale(encoding = "latin1"))
  
  
  transf %>% 
    set_names(c("origem", transf$X1)) %>% 
    pivot_longer(-origem, names_to = "destino", values_to = "valor") %>% 
    mutate(ano = as.integer(str_extract(path, "\\d{4}")))
}

iso3 <- tribble(
  ~pais, ~iso,
  "Austrália", "AUS",
  "Áustria", "AZE",
  "Bélgica", "BEL",
  "Bulgária", "BGR",
  "Brasil", "BRA",
  "Canadá", "CAN",
  "China", "CHN",
  "Chipre", "CYP",
  "Tchéquia", "CZE",
  "Alemanha", "DEU",
  "Dinamarca", "DNK",
  "Espanha", "ESP",
  "Estônia", "EST",
  "Finlândia", "FIN",
  "França", "FRA",
  "Reino Unido", "GBR",
  "Grécia", "GRC",
  "Hungria", "HUN",
  "Indonésia", "IDN",
  "Índia", "IND",
  "Irlanda", "IRL",
  "Itália", "ITA",
  "Japão", "JPN",
  "Coreia do Sul", "KOR",
  "Lituânia","LTU", 
  "Luxemburgo", "LUX", 
  "Letônia", "LVA",
  "México", "MEX",
  "Malta", "MLT",
  "Países Baixos", "NLD",
  "Polônia", "POL",
  "Portugal", "PRT",
  "Romênia", "ROU",
  "Federação Russa", "RUS",
  "Eslováquia", "SVK",
  "Eslovênia", "SVN",
  "Suécia", "SWE",
  "Turquia", "TUR",
  "Taiwan", "TWN",
  "Estados Unidos", "USA"
)

shapes <- rnaturalearth::ne_countries(returnclass = "sf") %>% 
  as_tibble() %>% 
  select(iso = iso_a3, geometry) %>% 
  left_join(iso3, c("iso"))


transf_long <- dir("Resultados", "Trans", full.names = TRUE) %>% 
  map_df(ler_transf) %>% 
  full_join(shapes, c("destino" = "pais"))

anos <- range(transf_long$ano, na.rm = TRUE)

ui <- fluidPage(
  column(
    4,
    wellPanel(
      helpText("Para o Mapa:"),
      selectInput("origem", "Selectione um país:", unique(transf_long$origem)),
      sliderInput("ano", "Selectione um ano", anos[1], anos[2], 
                  value = mean(anos), step = 1),
      hr(),
      helpText("Para análise das relações bilaterais:"),
      selectInput("destino", "Selectione outro país:", 
                  unique(transf_long$origem), unique(transf_long$origem)[2])
    )
  ),
  column(
    8,
    mainPanel(
      tabsetPanel(
        tabPanel(
          title = "mapa",
          fluidRow(plotOutput("mapa", width = "100%"))
        ),
        tabPanel(
          title = "gráfico",
          fluidRow(plotOutput("grafico_paises"))  
        ),
        tabPanel(
          title = "Relações bilaterais",
          fluidRow(plotOutput("grafico_tempo"))
        )
      )
    )
  )
)

server <- function(input, output, session) {
  output$mapa <- renderPlot({
    dados_mapa <- transf_long %>% 
      filter(origem == input$origem, ano == input$ano)
    
    ggplot(dados_mapa, aes(geometry = geometry)) +
      geom_sf(aes(fill = valor)) + 
      geom_sf(data = filter(dados_mapa, origem == input$origem, destino == input$origem, ano == input$ano),
              fill = "darkgreen") + 
      scale_fill_gradient2(low = "#2166AC", high = "#B2182B", na.value = "transparent", 
                           labels = function(x) scales::number(x/1e6)) + 
      theme_void() + 
      theme(legend.position = "bottom") +
      labs(title = glue::glue("Transferência do {input$origem} - {input$ano}"), fill = "Em milhões")
  })
  
  output$grafico_paises <- renderPlot({
    transf_long %>% 
      filter(origem == input$origem, ano == input$ano) %>% 
      mutate(ganho = ifelse(valor > 0, "Perda", "Ganho")) %>% 
      ggplot(aes(reorder(destino, valor), abs(valor))) + 
      geom_point(aes(col = ganho)) +
      coord_flip() + 
      scale_y_log10() +
      theme_classic() +
      scale_color_manual(values = c("Perda" = "red", "Ganho" = "darkblue")) +
      theme(legend.position = c(0.9, 0.5)) +
      labs(x = "", y = "Valor (escala logaritmica)", col = "")
  })
  
  output$grafico_tempo <- renderPlot({
    transf_long %>% 
      filter(origem == input$origem, destino == input$destino) %>% 
      ggplot(aes(ano, valor)) + 
      geom_line() + 
      annotate("text", x = 1998, y = 0, vjust = c(-1, 1.5),
               label = c("Perde", "Ganha"), col = c("red", "darkblue")) + 
      geom_hline(yintercept = 0) + 
      theme_classic() +
      labs(title = glue::glue("Histórico {input$origem}-{input$destino}"))
  })
}

shinyApp(ui, server)
