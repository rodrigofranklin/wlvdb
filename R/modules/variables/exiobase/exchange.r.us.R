# Exchange rate of euro in US dollars


euro_data <- 
  read.csv("source_data/eurostat/ert_bil_eur_a__custom_2789526_page_linear.csv")

euro <- euro_data$OBS_VALUE
names(euro) <- euro_data$TIME_PERIOD

sea_sectors[lists$years,"exchange.r.us",,] <- 
  rep(euro[lists$years], each = nums$countries_sectors)
  
rm(euro, euro_data)