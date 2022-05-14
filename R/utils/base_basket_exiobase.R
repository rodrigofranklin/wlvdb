##create base_basket
base_year <- (dimnames(sea_source)[[1]])[1]

#at this point, corresponding m_io and sea_sectors was already saved, recover it


fchnames <- dimnames(m_io)[[4]]
basebasket <- 
  m_io[base_year,"consumption_basket",,(0:(nums$countries-1))*nums$sectors+1]

shc <- substr(dimnames(basebasket)[[2]],1,2)
if (source_version %in% c("wiodr13","wiodr16")) {
  shc <- substr(dimnames(basebasket)[[2]],1,3)
  shc <- countrycode::countrycode(shc,"iso3c","iso2c",nomatch="ROW")
}
basebasket <- array(cbind(basebasket,apply(basebasket,1,mean)),
                             c(nums$input,nums$countries+1,1),
                             dimnames = list(dimnames(basebasket)[[1]],
                                             c(shc,"WWW"),
                                             base_year))
write_fst_array(basebasket,paste0("results/",method_version,"/base_basket.fst"))

