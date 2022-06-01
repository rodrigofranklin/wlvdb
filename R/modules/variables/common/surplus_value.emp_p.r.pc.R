# "Exploitation rate" of employed persons
sea_sectors[,"surplus_value.emp_p.r.pc",,] <- 
  sea_sectors[,"surplus_value.emp.r.pc",,] *
  rows$productive %>% rep(each = nums$years)

