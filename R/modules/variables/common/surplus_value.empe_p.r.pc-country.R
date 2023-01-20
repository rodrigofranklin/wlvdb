# exploitation rate of employee of productive sectors of each country and 
# of the whole world
sea_countries[,"surplus_value.empe_p.r.pc",lists$countries] <- 
  (sea_sectors[,"abstract_labour.empe.s.mv",,] *
     rows$productive %>% rep(each = nums$years)) %>%
  apply(1,tapply, rows$num_country, sum, na.rm = TRUE) %>%
  aperm(c(2,1)) /
  (sea_sectors[,"labour_force_value.s.mv",,] *
     rows$productive %>% rep(each = nums$years)) %>%
  apply(1,tapply, rows$num_country, sum, na.rm = TRUE) %>%
  aperm(c(2,1))
