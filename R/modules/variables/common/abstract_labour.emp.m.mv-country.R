# Sum of labour force value of each sector

sea_countries[lists$years,"abstract_labour.emp.m.mv",] <- 
  sea_countries[lists$years,"abstract_labour.emp.s.mv",] /
  sea_countries[lists$years,"emp.s.un",]