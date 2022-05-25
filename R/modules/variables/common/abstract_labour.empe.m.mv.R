# Jornada de trabalho média - trabalhadores assalariados - em magnitude de valor

sea_sectors[lists$years,"abstract_labour.empe.m.mv",,] <- 
  sea_sectors[lists$years,"abstract_labour.empe.s.mv",,] /
  sea_sectors[lists$years,"empe.s.un",,]
