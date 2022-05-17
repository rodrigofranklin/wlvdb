sea_sectors[,"gdp.s.us",,] <- 
  array(sea_source[,grep("Compensation ", dimnames(sea_source)[[2]]),,] %>%
  apply(1, colSums, na.rm = TRUE) %>%
  aperm(c(2,1)) +
  sea_source[,grep("surplus ", dimnames(sea_source)[[2]]),,] %>%
  apply(1, colSums, na.rm = TRUE) %>%
  aperm(c(2,1))+
  sea_source[,grep("axes ", dimnames(sea_source)[[2]]),,] %>%
  apply(1, colSums, na.rm = TRUE)%>%aperm(c(2,1)),c(nums$years,nums$sectors,nums$countries))
