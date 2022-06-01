# Sum of labour force value of each sector

sea_sectors[lists$years,"labour_force_value.emp.m.mv",,] <- 
  sea_sectors[lists$years,"labour_force_value.emp.s.mv",,] /
  sea_sectors[lists$years,"emp.s.un",,]