# Sum of labour force value of each sector

sea_countries[lists$years,"labour_force_value.m.mv",] <- 
  sea_countries[lists$years,"labour_force_value.s.mv",] /
  sea_countries[lists$years,"empe.s.un",]
