# capital compensation
sea_sectors[,"profit.s.us",,] <-
  sea_source[,grep("Operating ", unlist(dimnames(sea_source)[2])),,] %>%
  apply(1, colSums, na.rm = TRUE) %>%
  aperm(c(2,1))