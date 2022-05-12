sea_sectors[,"empe.s.un",,] <- 
  sea_sectors[,"employed_persons",,] - 
  (sea_source[,"Employment: Vulnerable employment",,] * 1000)
