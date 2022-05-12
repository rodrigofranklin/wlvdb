# exploitation rate high skilled employee
sea_countries[,"surplus_value.empe_hs.r.pc", lists$countries] <- 
  aperm(
    apply(
      (sea_sectors[,"abstract_labour.empe.s.mv",,] * 
        sea_sectors[,"hours_worked.empe_hs.r.pc",,]), 1,
      tapply, rows$num_country, sum, na.rm = TRUE),
    c(2,1)
  ) / aperm(
    apply(
      sea_sectors[,"labour_force_value.s.mv",,] * 
        sea_sectors[,"compensation.empe_hs.r.pc",,], 1,
      tapply, rows$num_country, sum, na.rm = TRUE),
    c(2,1)
  ) -1

sea_countries[, "surplus_value.empe_hs.r.pc", "WWW"] <- 
  apply(
    (sea_sectors[,"abstract_labour.empe.s.mv",,] * 
       sea_sectors[,"hours_worked.empe_hs.r.pc",,]), 1,
    sum, na.rm = TRUE) /
  apply(
    sea_sectors[,"labour_force_value.s.mv",,] * 
      sea_sectors[,"compensation.empe_hs.r.pc",,], 1,
    sum, na.rm = TRUE) -1
