sea_sectors[,"compensation_ratio_hs",,] <- 
  sea_source[,grep("Compensation ", unlist(dimnames(sea_source)[2])),,] %>%
  apply(1, colSums, na.rm = TRUE) %>%
  aperm(c(2,1))
