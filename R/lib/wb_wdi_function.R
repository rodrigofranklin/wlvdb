library(WDI)
library(lubridate)
countries <- read_fst_array("results/exiobase/m_countries.fst")
countries <- dimnames(countries)[[3]]
rel_wbdata <- function(indicator, sy , cl = countries) {
  data <- WDI(indicator = indicator)
  data <- data[data$year> (sy-1) & data$iso2c %in% cl,]
}