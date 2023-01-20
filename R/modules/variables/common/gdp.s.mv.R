# Gross domestic product by value added in magnitude of value
code <- "gdp.s.mv"

meta_indicators[code,"name"] <- "Gross Domestic Product (magnitude of value)"
meta_indicators[code,"description"] <- 
  paste0("Gross Domestic Product calculated by value added approach represents ",
         "all value created by residents. Data are in magnitude of value, thus ",
         "it enconpass productive sectors only.")
meta_indicators[code,"observation"] <- 
  paste0("Obtained from the sum of abstract labour performed in productive ",
         "sectors.")
meta_indicators[code,"type"] <- "value"
meta_indicators[code,"group"] <- "Product"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[lists$years,code,,] <- 
  sea_sectors[lists$years,"abstract_labour.emp.s.mv",,] * 
  rep(rows$productive, each = nums$years)
