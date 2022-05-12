# l' = l x z
sea_sectors[,"abstract_labour.empe.s.mv",,] <- 
  sea_sectors[,"hours_worked.empe.s.hr",,] * 
  sea_sectors[,"complex_labour_multiplier.empe.r.un",,]
