# Gross domestic product by value added in direct price
code <- "gdp.p.s.us"

meta_indicators[code,"name"] <- 
  "Gross domestic product of productive sectors (USD)"
meta_indicators[code,"description"] <- 
  paste0("Gross Domestic Product of productive sectors is the sum of the ",
  "traditional national accont calculated by value added approach represents ",
         "all value created by residents. ")
meta_indicators[code,"observation"] <-
  paste0("Obtained from the sum of GDP of productive sectors.")
meta_indicators[code,"type"] <- "usd"
meta_indicators[code,"group"] <- "Product"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[lists$years,code,,] <- 
  sea_sectors[lists$years,"gdp.s.us",,] * 
  rep(rows$productive, each = nums$years)
