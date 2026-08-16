# Índice de valores da cesta de consumo
code <- "basket_value.r.pc"

meta_indicators[code,"name"] <- "Consumption basket value index (2000 = 1)"
meta_indicators[code,"description"] <- 
  paste0("Consumption basket value index reflects changes in the socially ",
         "necessary labour-time to produce a fixed consumption basket ",
         "necessary for reproduction of an avarage worker. The Laspeyres ",
         "formula is used.")
meta_indicators[code,"observation"] <-
  "Calculated and published on the canonical base-one scale."
meta_indicators[code,"type"] <- "index"
meta_indicators[code,"group"] <- "Others"
meta_indicators[code,"reverted"] <- FALSE

if (!exists("basket_value_zero")) {
  # Define a distribuição monetária (USD) da cesta do período Zero
  basket_zero <-  
    m_io[1, "consumption_basket", 1:nums$input, 1:nums$input]

  # Define o valor da cesta de consumo do período zero
  basket_value_zero <-  
    (basket_zero *
    # transform monetary data into values
    (lambda[1,] %>% 
       rep(times = nums$input))) %>%
    # Soma todas as colunas
    colSums(na.rm = TRUE)
}

sea_sectors[lists$years,code,,] <- 
  # Replica a distribuição da cesta do período Zero para todos os anos
  ((basket_zero %>%
      rep(times = nums$years) %>%
      newDim(c(nums$input, nums$input, nums$years)) %>% 
      aperm(c(3,1,2))) *
     
     # Aplica a inflação em moeda nacional
     ((sea_sectors[lists$years,"go_price.r.id",,] /
         # Dividido pelo índice de variação cambial
         sea_sectors[lists$years,"exchange.r.id",,]) %>%
        rep(times = nums$input) %>%
        newDim(c(nums$years, nums$input, nums$input))) *

  # transform monetary data into values
  rep(lambda, times = nums$input)) %>%
  
  # Soma todas as colunas
  apply(1, colSums, na.rm = TRUE) %>%
  aperm(c(2,1))

# Divide todos os anos pelo valor da cesta do ano zero (para criar um índice)
sea_sectors[lists$years,code,,] <- 
  sea_sectors[lists$years,code,,] /
  (basket_value_zero %>%
     rep(times = nums$years) %>%
     newDim(c(nums$sectors, nums$countries, nums$years)) %>%
     aperm(c(3,1,2)))

# Ano base = 2000
sea_sectors[,code,,] <-
  sea_sectors[,code,,] /
  (sea_sectors["2000",code,,] %>%
     rep(times = nums$years) %>%
     newDim(c(nums$sectors, nums$countries, nums$years)) %>%
     aperm(c(3,1,2)))
