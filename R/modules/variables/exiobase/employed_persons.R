sea_sectors[,"employed_persons",,] <- 
  (sea_source[,"Employment: Low-skilled male",,] +
  sea_source[,"Employment: Low-skilled female",,] +
  sea_source[,"Employment: Medium-skilled male",,] +
  sea_source[,"Employment: Medium-skilled female",,] +
  sea_source[,"Employment: High-skilled male",,] +
  sea_source[,"Employment: High-skilled female",,]) *
  1000
  
  