sea_sectors[,"emp.s.un",,] <- 
  (sea_source[,"Employment people: Medium-skilled male",,] +
  sea_source[,"Employment people: Medium-skilled female",,] +
  sea_source[,"Employment people: Low-skilled male",,] +
  sea_source[,"Employment people: Low-skilled female",,] +
  sea_source[,"Employment people: High-skilled male",,] +
  sea_source[,"Employment people: High-skilled female",,]) *
  1000
  
  