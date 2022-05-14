sea_sectors[,"empe.s.un",,] <- 
  sea_sectors[,"emp.s.un",,] - 
  (sea_source[,"Employment: Vulnerable employment",,] * 1000)
