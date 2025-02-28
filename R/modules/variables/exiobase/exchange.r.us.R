# Exchange rate of euro in US dollars


euro_data <- 
  read.csv("source_data/eurostat/estat_ert_bil_eur_a_en.csv") |>
  dplyr::filter(currency == "US dollar" & statinfo == "Value at the end of the period")

euro <- euro_data$OBS_VALUE
names(euro) <- euro_data$TIME_PERIOD

sea_sectors[lists$years,"exchange.r.us",,] <- 
  rep(euro[lists$years], each = nums$countries_sectors)
  
rm(euro, euro_data)