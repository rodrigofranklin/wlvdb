sea_sectors[,"wages",,] <- 
  sea_source[,grep("Compensation ", unlist(dimnames(sea_source)[2])),,] %>%
  apply(1, colSums, na.rm = TRUE) %>%
  aperm(c(2,1))