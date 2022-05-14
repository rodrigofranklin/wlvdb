##create base_basket
base_year <- (dimnames(sea_source)[[1]])[1]

#at this point, corresponding m_io and sea_sectors was already saved, recover it


fchnames <- dimnames(m_io)[[4]]
basebasket <- 
  m_io[base_year,"consumption_basket",,(0:nums$countries)*nums$sectors+1]

shc <- substr(dimnames(basebasket)[[2]],1,2)
basebasket <- array(basebasket,
                             c(dim(basebasket),1),
                             dimnames = list(dimnames(basebasket)[[1]],
                                             shc,
                                             base_year))
write_fst_array(basebasket,paste0("results/",method_version,"/base_basket.fst"))

