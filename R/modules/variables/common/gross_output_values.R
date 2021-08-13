sea_sectors[lists$years,"gross_output_values",,] <- 
  m_io[, "values", , ] %>%
  newDim(c(nums$years, nums$input, nums$output)) %>%
  apply(1, rowSums, na.rm = TRUE) %>%
  aperm(c(2,1))
