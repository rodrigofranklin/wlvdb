##create base_basket
base_year <- (dimnames(sea_source)[[1]])[1]

#at this point, corresponding m_io and sea_sectors was already saved, recover it


fchnames <- dimnames(m_io)[[3]]
basebasket <- 
  m_io[base_year,"consumption_basket",,seq(from = 1, to = nums$input, by = nums$sectors)]

shc <- substr(dimnames(basebasket)[[2]],1,2)
if (source_version %in% c("wiodr13","wiodr16")) {
  shc <- substr(dimnames(basebasket)[[2]],1,3)
  shc <- countrycode::countrycode(shc,"iso3c","iso2c",nomatch="ROW")
}
basbsktm <- apply(basebasket,1,mean,na.rm = T)

expbbskt <- cbind(as.data.frame(basebasket),data.frame( "ROW" = basbsktm,"WWW" =  basbsktm))

basebasket <- array(as.matrix(expbbskt),
                             c(nums$input,nums$countries+2,1),
                             dimnames = list(dimnames(basebasket)[[1]],
                                             c(shc,"ROW","WWW"),
                                             base_year))
if (!exists("wlv_result_dir", inherits = FALSE)) {
  stop(
    "`base_basket_exiobase.R` must run inside a staged WLV calculation.",
    call. = FALSE
  )
}
write_fst_array(basebasket, file.path(wlv_result_dir, "base_basket.fst"))

