if (!exists("sea_sectors")) {
  if (!exists("wlv_existing_result_dir", inherits = FALSE)) {
    stop("A staged result snapshot is required to load `sea_sectors`.", call. = FALSE)
  }
  sea_sectors <- read_fst_array(
    file.path(wlv_existing_result_dir, "sea_sectors.fst")
  )
}
varname <- "appropriated_monetary_rate_of_profit.r.pc"
datanm <- c("gdp.s.us","capital_depreciation.s.us","compensation.emp.s.us","capital_stock.s.us")
basedata <- sea_sectors[,datanm,,]

#Get Appropriated monetary rate of profit
ampr.r.pc <- (basedata[,datanm[1],,]-basedata[,datanm[2],,]-basedata[,datanm[3],,])/
  basedata[,datanm[4],,]


ampr.r.pc <- 
  array(ampr.r.pc,
        c(dim(ampr.r.pc)[1],
        1,
        dim(ampr.r.pc)[2:3]),
        dimnames = 
          list(
            dimnames(ampr.r.pc)[[1]],
            varname,
            dimnames(ampr.r.pc)[[2]],
            dimnames(ampr.r.pc)[[3]]
          ))

dim(ampr.r.pc)

sea_sectors[,varname,,] <- ampr.r.pc
