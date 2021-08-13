# l' = l x z
sea_sectors[,"abstract_labour",,] <- 
  sea_sectors[,"hours_employed",,] * sea_sectors[,"z",,]
