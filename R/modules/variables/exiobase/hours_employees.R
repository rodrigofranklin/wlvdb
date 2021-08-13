sea_sectors[,"hours_employees",,] <- 
  sea_sectors[,"hours_employed",,] - 
  (sea_source[,"Employment hours: Vulnerable employment",,] * 1000000)
