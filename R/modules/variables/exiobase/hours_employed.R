sea_sectors[,"hours_employed",,] <- 
  (sea_source[,"Employment hours: Low-skilled male",,] +
     sea_source[,"Employment hours: Low-skilled female",,] +
     sea_source[,"Employment hours: Medium-skilled male",,] +
     sea_source[,"Employment hours: Medium-skilled female",,] +
     sea_source[,"Employment hours: High-skilled male",,] +
     sea_source[,"Employment hours: High-skilled female",,]) *
  1000000
