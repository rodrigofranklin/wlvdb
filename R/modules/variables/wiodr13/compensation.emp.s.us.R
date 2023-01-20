# labour_compensation
code <- "compensation.emp.s.us"

meta_indicators[code,"name"] <- "Labour compensation (USD)"
meta_indicators[code,"description"] <- 
  paste0("Labour compensation expressed in market prices represents ",
         "the income received all persons engaged as a result of their labour. ",
         "It includes wages, salaries, and income received by non-waged and ",
         "non-salaried workers (self-employed, etc.).")
meta_indicators[code,"observation"] <- 
  paste0("Converted from national currency using the exchange rate.")
meta_indicators[code,"type"] <- "usd"
meta_indicators[code,"group"] <- "Wages and value of labour force"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[,code,,] <-
  sea_source[,"LAB",lists$sectors,] *1000000 / 
  sea_sectors[,"exchange.r.us",,]
