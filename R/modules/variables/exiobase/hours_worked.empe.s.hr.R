sea_sectors[,"hours_worked.empe.s.hr",,] <- 
  sea_sectors[,"hours_worked.emp.s.hr",,] - 
  (sea_source[,"Employment hours: Vulnerable employment",,] * 1000000)
