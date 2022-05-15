#create-cpis_gdps_exchange_rates array
if(!exists("base_year")){
  base_year <- dimnames(sea_source)[[1]]
}
##Add CPIS
indexcpis <- read_csv2("source_data/worldbank/cpis_countries.csv")
lastyear <- dimnames(sea_source)[[1]][length(dimnames(sea_source)[[1]])]

indexcpis$year <- as.numeric(indexcpis$year)
indexcpis <- indexcpis[indexcpis$year> as.numeric(base_year)-1 & indexcpis$year<(as.numeric(lastyear)+1),]

##Adding regional codes/ areas included in exiobase sea
al <- indexcpis$year
allyears <- dimnames(sea_countries)[[1]]
    ciso2c <- lists$countries
  for (i in ciso2c[(!ciso2c %in% names(indexcpis))]) {
    indexcpis[i] <- 100
  }
    row.names(indexcpis) <- al
    indexcpis <- indexcpis[,-1]
    
    




arraycpis <- array(as.matrix(indexcpis),dim(indexcpis),dimnames = list(row.names(indexcpis), names(indexcpis)))



##calculate GDPS from sea_source data
pibx <- function(pais,ano) {
  a <- data.frame(year = ano,
                  iso2c = pais,
                  gdp = sum(sea_source[as.character(ano),dimnames(sea_source)[[2]][1:9],,pais]))
  a
}

combs <- expand.grid(dimnames(sea_source)[[1]],lists$countries)

pibsexiobase <- data.table::rbindlist(mapply(pibx,combs$Var2,combs$Var1, SIMPLIFY = F))


pibsexiobase <- pibsexiobase%>%pivot_wider(names_from=iso2c,values_from=gdp)

anospi <- pibsexiobase$year

pibsexiobase <- pibsexiobase[-1]
pibsexiobase <- pibsexiobase[lists$countries !="ROW"]
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
##ADD GDPS in local currency and calculate exchange rate
##except for euro area where gdp lcu is copied from "VATOTAL"



gdps <- read_csv2("source_data/worldbank/gdps_lcu.csv")

gdps <- gdps[-2]%>%pivot_wider(names_from = iso2c, values_from = NY.GDP.MKTP.CN)

  for (i in ciso2c[!(lists$countries %in% names(gdps))]) {
    gdps[i] <- 100
  }
  


gdps <- gdps%>%arrange(year)

gdps[,-1] <- gdps[,-1]/1000000

#GET GDPS from sea_source based on entry date and country code from eutmembers

   for (i in eutmembers$iso2c) {
    srctable <- eutmembers[eutmembers$iso2c == i,]
    gdps[gdps$year>srctable$startyear-1,unique(srctable$iso2c)] <- 
      cpi_gdp_er[as.character(srctable$startyear:as.numeric(lastyear)),i,"VA"]
   }
rm(srctable)
anos <- as.character(gdps$year)
gdps <- gdps[,ciso2c]


row.names(gdps) <- al

arraygdps <- array(as.matrix(gdps),c(dim(gdps),1),dimnames = list(row.names(gdps),names(gdps),"VATOTAL"))

cpi_gdp_er <- abind(cpi_gdp_er,arraygdps,along = 3)



exrate <- array(cpi_gdp_er[,,"VATOTAL"]/cpi_gdp_er[,,"VA"],c(dim(cpi_gdp_er)[-3],1),
      dimnames = list(dimnames(cpi_gdp_er)[[1]],dimnames(cpi_gdp_er)[[2]],"exchange_rate"))

cpi_gdp_er <- abind(cpi_gdp_er,exrate, along = 3)

write_fst_array(cpi_gdp_er,paste0("results/",method_version,"/cpis_gdps_er.fst"))


#Check if there is a base basket file already in results, otherwise sets first year as base year

a <- list.files(paste0("results/",method_version),pattern = "base_basket.fst$",full.names = T)

if(length(a)>0) {
  basebasket <- read_fst_array(a)
  base_year <- dimnames(basebasket)[[3]]
  basebasket <- basebasket[,,1]
} else {
  source("R/utils/base_basket_exiobase.R")
}
basebasket <- basebasket[,ciso2c[ciso2c!= "ROW"]]
cpis_gdps_er <- read_fst_array("results/exiobase/cpis_gdps_er.fst")
lambdas <- as.numeric(lambda)

if(base_year == lists$years[1]) {
    basi <- array(abind(basebasket,
                        rowMeans(basebasket),along = 2),
                        c(nums$input,nums$countries+1),
                  dimnames = list(
                    dimnames(basebasket)[[1]],
                    c(dimnames(basebasket)[[2]],"WWW")
                  )
    )
  
  allyears <- dimnames(sea_countries)[[1]]
#  basi <- colSums(basi,na.rm=T)
  
  
    basi <- array(replicate(length(allyears),basi),dim = c(dim(basi),length(allyears),1),
                  dimnames = list(lists$input,dimnames(sea_countries)[[3]],allyears,"reference basket value"))%>%
      aperm(c(3,4,1,2))
    
    basi[1,1,,] <- basi[1,1,,]*replicate(nums$countries+1,lambdas)
  
  write_fst_array(basi,paste0("results/",method_version,"base_monetary_structure_of_cbasket.fst"))
} 
  er <- cpi_gdp_er[lists$years,,"exchange_rate"]
  fkwww <- 1
  names(fkwww) <- "WWW"
  er <- c(er,fkwww)
  erbase <- cpi_gdp_er[base_year,,"exchange_rate"]
  erbase <- c(erbase,fkwww)
  
  consprice <- cpi_gdp_er[lists$years,,"CPI"]
  fkwww <- 105
  consprice <- c(consprice,fkwww)
  
  baseconsprice <- cpi_gdp_er[base_year,,"CPI"]
  baseconsprice <- c(baseconsprice,fkwww)
  
  curba <-     basi[base_year,1,,]*replicate(nums$countries+1,lambdas)*
    t(replicate(nums$input,erbase))*100*
    t(replicate(nums$input,consprice))/
    t(replicate(nums$input,er))
                     
  names(curba) <- names(er)
  
curba <- colSums(curba,na.rm=T)
  sea_countries[lists$years,"reference_basket_value",] <- curba


  
write_fst_array(sea_countries,paste0("results/",method_version,"/sea_countries.fst"))
