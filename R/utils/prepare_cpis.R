source("R/lib/wb_wdi_function.R")
library(readODS)
countries <- read_fst_array("results/exiobase/m_countries.fst")
countries <- dimnames(countries)[[3]]

cpis <- "FP.CPI.TOTL.ZG"

cpis <- rel_wbdata(cpis,1995)

#Cyprus and India not available yet
#supposing 0 inflation for CY
cpis[cpis$iso2c == "CY" & cpis$year == 2021,3] <-0
#repeating 2020 inflation for india's 2021
cpis[cpis$iso2c == "IN" & cpis$year == 2021,3] <-cpis[cpis$iso2c == "IN" & cpis$year == 2020,3] 

cpis <- cpis[-2]%>%pivot_wider(names_from=iso2c,values_from = FP.CPI.TOTL.ZG)
cpis$year <- as.Date(paste0(cpis$year,"-12-31"))


acumula <- function(x) {
  x[,-1] <- (x[,-1]+100)/100
  
  x <- cbind(
    list(year = c(as.Date(paste0(year(x[[nrow(x),1]])-1,"-12-31")),
                  x$year)),
    rbind(rep(1,ncol(x)-1),x[,-1]))
  x <- x %>% arrange(year)
  for (i in nrow(x):2) {
    x[i,-1] <- apply(x[1:i,-1],2,function(x) prod(x))
  }
  x[,-1] <- x[,-1]*100
  x
}

indexcpis <- acumula(cpis)

##CHANGE BASE YEAR TO 2000
indexcpis[,-1] <- 100*indexcpis[,-1]/
  as.data.frame(lapply(indexcpis[year(indexcpis$year) == 2000,-1],rep,nrow(indexcpis)))


### Adding Taiwan's data
#ref https://eng.stat.gov.tw/lp.asp?ctNode=1558&CtUnit=712&BaseDSD=7
tw_cpil <- "https://eng.stat.gov.tw/public/data/dgbas03/bs3/english/cpiidx.ods"
download.file(tw_cpil,f)
twcpi <- read_ods(f, range = "A4:N67")
twcpi <- twcpi[twcpi$Year>1994,c("Year","Index")]
##rebase
twcpi[,-1] <- 100*twcpi[,-1]/as.data.frame(lapply(twcpi[twcpi$Year == 2000,-1],rep,nrow(twcpi)))
names(twcpi) <- c("year","TW")
indexcpis["TW"] <- twcpi$TW


write_csv2(indexcpis,"source_data/worldbank/cpis_countries.csv")
