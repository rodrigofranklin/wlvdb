##Weighted average by capital stock
yearxcountry <-expand.grid(dimnames(sea_sectors)[[1]],lists$countries)

mfunc <- function(x,y){
  k <- sea_sectors[x,"capital_stock.s.us",,y]
  k[is.na(k)] <- 0.01
  k[k<0.01] <- 0.01
  
  p <- sea_sectors[x,"appropriated_monetary_rate_of_profit.r.pc",,y]
  p[is.na(p)] <- 0
  a <- weighted.mean(p,
                     k)
  print(a)
  a
}
pr_pondered_k <- mapply(mfunc,yearxcountry[[1]],yearxcountry[[2]])
  
 
pr_pondered_k <- array(pr_pondered_k,c(nums$years,1,nums$countries),
                       dimnames = list(lists$years,
                                       "appropriated_monetary_rate_of_profit.r.pc",
                                       lists$countries))



sea_countries[, "appropriated_monetary_rate_of_profit.r.pc", lists$countries] <- pr_pondered_k
