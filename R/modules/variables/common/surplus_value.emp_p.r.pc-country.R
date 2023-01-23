# exploitation rate of employed persons of each country
sea_countries[,"surplus_value.emp_p.r.pc",lists$countries] <- 
  (sea_sectors[,"abstract_labour.emp.s.mv",,] *
     rows$productive %>% rep(each = nums$years)) %>%
  apply(1,tapply, rows$num_country, sum, na.rm = TRUE) %>%
  aperm(c(2,1)) /
  (sea_sectors[,"labour_force_value.emp.s.mv",,] *
     rows$productive %>% rep(each = nums$years)) %>%
  apply(1,tapply, rows$num_country, sum, na.rm = TRUE) %>%
  aperm(c(2,1)) -1
