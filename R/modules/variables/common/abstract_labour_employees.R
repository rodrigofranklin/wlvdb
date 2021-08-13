# l' = l x z
sea_sectors[,"abstract_labour_employees",,] <- 
  sea_sectors[,"hours_employees",,] * sea_sectors[,"z_employees",,]
