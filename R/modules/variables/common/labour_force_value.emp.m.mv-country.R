# Sum of labour force value of each sector

sea_countries[lists$years,"labour_force_value.emp.m.mv",] <- 
  sea_countries[lists$years,"labour_force_value.emp.s.mv",] /
  sea_countries[lists$years,"emp.s.un",]
