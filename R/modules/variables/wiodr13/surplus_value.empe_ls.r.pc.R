# exploitation rate of high skilled employees
sea_sectors[,"surplus_value.empe_ls.r.pc",,] <- 
  ((sea_sectors[,"abstract_labour.empe.s.mv",,] * 
      sea_sectors[,"hours_worked.empe_ls.r.pc",,]) /
     (sea_sectors[,"labour_force_value.s.mv",,] *
        sea_sectors[,"compensation.empe_ls.r.pc",,])) -1


