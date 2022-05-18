# Hours worked by employed persons
sea_sectors[,"hours_worked.emp.s.hr",,] <-
  sea_source[,"H_EMPE",lists$sectors,] /
  sea_source[,"EMPE",lists$sectors,] * 
  sea_source[,"EMP",lists$sectors,] * 1000000

