# Índice de valores da cesta de consumo

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

sea_sectors[lists$years,"basket_value.r.pc",,] <- 
  # Replica a distribuição da cesta do período Zero para todos os anos
  ((basket_zero %>%
      rep(times = nums$years) %>%
      newDim(c(nums$input, nums$input, nums$years)) %>% 
      aperm(c(3,1,2))) *
     
     # Aplica a inflação em moeda nacional
     (((sea_sectors[lists$years,"go_price.r.id",,]/100) / 
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
sea_sectors[lists$years,"basket_value.r.pc",,] <- 
  sea_sectors[lists$years,"basket_value.r.pc",,] /
  (basket_value_zero %>%
     rep(times = nums$years) %>%
     newDim(c(nums$sectors, nums$countries, nums$years)) %>%
     aperm(c(3,1,2)))

# Ano base = 2000
sea_sectors[,"basket_value.r.pc",,] <- 
  sea_sectors[,"basket_value.r.pc",,] /
  (sea_sectors["2000","basket_value.r.pc",,] %>%
     rep(times = nums$years) %>%
     newDim(c(nums$sectors, nums$countries, nums$years)) %>%
     aperm(c(3,1,2)))
