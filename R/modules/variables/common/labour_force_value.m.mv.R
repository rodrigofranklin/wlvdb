# Sum of labour force value of each sector

sea_sectors[lists$years,"labour_force_value.m.mv",,] <- 
  sea_sectors[lists$years,"labour_force_value.s.mv",,] /
  sea_sectors[lists$years,"empe.s.un",,]