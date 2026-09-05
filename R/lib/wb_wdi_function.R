library(WDI)
library(lubridate)
if (!exists("wlv_current_result_dir", mode = "function", inherits = TRUE)) {
  source("R/lib/publication_manifest.R")
  source("R/lib/publication.R")
}
exiobase_result_dir <- wlv_current_result_dir(
  "exiobase",
  root = ".",
  channel = getOption("wlv.channel", "stable")
)
countries <- read_fst_array(file.path(exiobase_result_dir, "m_countries.fst"))
countries <- dimnames(countries)[[3]]
rel_wbdata <- function(indicator, sy , cl = countries) {
  data <- WDI(indicator = indicator)
  data <- data[data$year> (sy-1) & data$iso2c %in% cl,]
}
