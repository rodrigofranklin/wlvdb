# Jornada de trabalho média - trabalhadores assalariados - em magnitude de valor

sea_sectors[lists$years,"abstract_labour.emp.m.mv",,] <- 
  sea_sectors[lists$years,"abstract_labour.emp.s.mv",,] /
  sea_sectors[lists$years,"emp.s.un",,]
