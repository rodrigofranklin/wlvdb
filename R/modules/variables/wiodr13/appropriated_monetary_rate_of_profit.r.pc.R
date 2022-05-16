if(!(exists("sea_sectors"))) {
a <-   read_fst_array(paste("results",method_version,"sea_sectors.fst",sep = "/"))
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
