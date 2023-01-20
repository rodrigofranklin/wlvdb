#create-cpis_gdps_exchange_rates array
# code <- ""
# 
# meta_indicators[code,"name"] <- ""
# meta_indicators[code,"description"] <- 
#   paste0("")
# meta_indicators[code,"observation"] <- NA
# meta_indicators[code,"type"] <- ""
# meta_indicators[code,"group"] <- ""
# meta_indicators[code,"reverted"] <- FALSE

if(!exists("base_year")){
  base_year <- lists$years
}
##Add CPIS
indexcpis <- read_csv2("source_data/worldbank/cpis_countries.csv")
lastyear <- lists$years[length(lists$years)]

indexcpis$year <- as.numeric(indexcpis$year)
indexcpis <- indexcpis[indexcpis$year> as.numeric(base_year)-1 & indexcpis$year<(as.numeric(lastyear)+1),]

##Adding regional codes/ areas included in exiobase sea
al <- indexcpis$year
  ciso2c <- countrycode(lists$countries,"iso3c","iso2c", nomatch = "ROW")
  for (i in names(indexcpis)[!(countrycode::countrycode(lists$countries,"iso3c","iso2c",nomatch = "ROW") %in% names(indexcpis))][-1]) {
    indexcpis[i] <- 100
    indexcpis <- indexcpis[,-1]
    indexcpis <- indexcpis[,ciso2c[ciso2c != "ROW"]]
    row.names(indexcpis) <- al
    indexcpis[,ciso2c[ciso2c != "ROW"]]
  }

  ciso2c <- lists$countries
  ciso2c2 <- countrycode(ciso2c,"iso3c","iso2c",nomatch = "ROW")
  n <- 1
  for (i in dimnames(sea_countries)[[3]][!(dimnames(sea_countries)[[3]] %in% names(indexcpis)[-1])]) {
    indexcpis[i] <- 105*n
    n <- n+1
    row.names(indexcpis) <- al
    indexcpis <- indexcpis[lists$years,ciso2c2[ciso2c2!="ROW"]]
    
  }




arraycpis <- array(as.matrix(indexcpis),dim(indexcpis),dimnames = list(row.names(indexcpis), names(indexcpis)))



##retrieve GDPS from sea_countries data

  pibsexiobase <- as.data.frame(sea_countries[,"gdp.s.us",])
  pibsexiobase$year <- row.names(pibsexiobase)


   anospi <- pibsexiobase$year

pibsexiobase <- pibsexiobase[!(names(pibsexiobase) =="year")]
pibsexiobase <- pibsexiobase[ciso2c[ciso2c!="ROW"]]
row.names(pibsexiobase) <- anospi

pibsexiobase <- array(as.matrix(pibsexiobase),dim(pibsexiobase),dimnames = list(anospi,names(pibsexiobase)))




cpi_gdp_er <- abind(list(CPI = arraycpis, VA = pibsexiobase),along =3)


#get list of eurozone members and entry dates
eu_m <- "https://en.wikipedia.org/wiki/Eurozone"
eu <- tempfile()
download.file(eu_m,eu)
eutmembers <- rvest::html_element(xml2::read_html(eu),xpath = "/html/body/div[3]/div[3]/div[5]/div[1]/table[3]")
eutmembers <- rvest::html_table(eutmembers)
eutmembers <- eutmembers%>%transmute(iso2c = ISOcode, startyear = year(as.Date(substr(Adopted,1,10))))
eutmembers <- eutmembers[-nrow(eutmembers),]
eutmembers <- eutmembers[eutmembers$startyear< as.numeric(lastyear)+1,]

eutmembers <- eutmembers[eutmembers$startyear < (as.numeric(lastyear)+1),]
eutmembers$iso3c <- countrycode(eutmembers$iso2c,"iso2c","iso3c",nomatch ="ROW")
##ADD GDPS in local currency and calculate exchange rate
##except for euro area where gdp lcu is copied from "VATOTAL"



gdps <- read_csv2("source_data/worldbank/gdps_lcu.csv")

gdps <- gdps[-2]%>%pivot_wider(names_from = iso2c, values_from = NY.GDP.MKTP.CN)

gdps <- gdps%>%arrange(year)

  gdps <- gdps[gdps$year<as.numeric(lastyear)+1,]
  for (i in names(ciso2c2)[!(ciso2c2[ciso2c2 != "ROW"] %in% names(gdps))]) {
    gdps[i] <- 0

  }



gdps[,-1] <- gdps[,-1]/1000000

#GET GDPS from sea_source based on entry date and country code from eutmembers

for (i in eutmembers$iso3c) {
  srctable <- eutmembers[eutmembers$iso3c == i,]
  gdps[gdps$year>srctable$startyear-1,srctable$iso2c] <- 
    cpi_gdp_er[as.character(srctable$startyear:as.numeric(lastyear)),i,"VA"]
}

anos <- as.character(gdps$year)


gdps <- gdps[ciso2c2[ciso2c2 != "ROW"]]
row.names(gdps) <- as.character(anos)

arraygdps <- array(as.matrix(gdps),c(dim(gdps),1),dimnames = list(row.names(gdps),names(gdps),"VATOTAL"))

cpi_gdp_er <- abind(cpi_gdp_er,arraygdps,along = 3)



exrate <- array(cpi_gdp_er[,,"VATOTAL"]/cpi_gdp_er[,,"VA"],c(dim(cpi_gdp_er)[-3],1),
                dimnames = list(dimnames(cpi_gdp_er)[[1]],dimnames(cpi_gdp_er)[[2]],"exchange_rate"))

cpi_gdp_er <- abind(cpi_gdp_er,exrate, along = 3)

write_fst_array(cpi_gdp_er,paste0("results/",method_version,"/cpis_gdps_er.fst"))


#Check if there is a base basket file already in results, otherwise sets first year as base year

a <- list.files(paste0("results/",method_version),pattern = "base_basket.fst$",full.names = T)

if(length(a)>0 ) {
  basebasket <- read_fst_array(a)
  base_year <- dimnames(basebasket)[[3]]
  basebasket <- basebasket[,,1]
} else {
  source("R/utils/base_basket_exiobase.R")
}
basebasket <- basebasket[,c(ciso2c2,"WWW")]
cpi_gdp_er <- read_fst_array(paste0("results/",method_version,"/cpis_gdps_er.fst"))
lambdas <- array(as.numeric(lambda),c(nums$years,nums$countries_sectors,nums$countries),
                 dimnames = list(lists$years,lists$input,lists$countries))

##############  lambdas <- lambdas[1:nums$input] 
wwwlambda <- array(rep(0,length(lambda)),c(nums$years,nums$input,1),
      dimnames = list(lists$years,lists$input,
                      "WWW" ))
bbskt <- array(replicate(nums$years,basebasket),c(dim(basebasket),nums$years),
               dimnames = list(lists$input,c(ciso2c,"WWW"),lists$years))%>%
  aperm(c(3,1,2))
basi <- array(bbskt*abind(lambdas,wwwlambda),c(nums$years,nums$input,nums$countries+1),
dimnames = list(
                    lists$years,
                    dimnames(basebasket)[[1]],
                    dimnames(basebasket)[[2]]
                  )
    )
    


  basi <- sapply(lists$years,function(x) {a <- colSums(basi[x,,],na.rm = T)})
  dimnames(basi)[[1]] <- c(lists$countries,"WWW")
  dimnames(basi)[[2]] <- lists$years
  

  
    
    basi <- array(basi,c(nums$years,1,nums$countries+1),
                  dimnames = list(lists$years,"reference basket structure",c(lists$countries,"WWW")))

  sea_countries <- abind(sea_countries,basi,along = 2)  

  er <- as.data.frame(cpi_gdp_er[lists$years,,"exchange_rate"])
  fakealeatory <- er[,1:2]
  names(fakealeatory) <- c("ROW","WWW")
  er <- cbind(er,fakealeatory)
  er <- as.matrix(er)
dim(er) <- c(nums$years,1,nums$countries+1)
  
  erbase <- cpi_gdp_er[base_year,,"exchange_rate"]
  fakebased <- c(100,100)
  names(fakebased) <- c("ROW","WWW")
  erbase[41:42] <- fakebased
  erbase <- t(replicate(nums$years,erbase))
  dim(erbase) <- c(nums$years,1,nums$countries+1)
  
  consprice <- as.data.frame(cpi_gdp_er[lists$years,,"CPI"])
  consprice <- cbind(consprice,fakealeatory)
  consprice <- t(consprice)
  dim(consprice) <- c(nums$years,1,nums$countries+1)
  
  variname <- "reference_basket_value.c.hr"
#  baseconsprice <- cpi_gdp_er[base_year,,"CPI"]
  curba <-     array(basi*erbase*consprice/er,
                     c(nums$years,1,nums$countries+1))
  dimnames(curba)[[2]] <- variname
  sea_countries[,variname,] <- curba



write_fst_array(sea_countries,paste0("results/",method_version,"/sea_countries.fst"))
