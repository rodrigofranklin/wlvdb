#create-cpis_gdps_exchange_rates array
if(!exists(base_year)){
  base_year <- dimnames(sea_source)[[1]]
}
##Add CPIS
indexcpis <- read_csv2("source_data/worldbank/cpis_countries.csv")
lastyear <- dimnames(sea_source)[[1]][length(dimnames(sea_source)[[1]])]

indexcpis$year <- as.numeric(indexcpis$year)
indexcpis <- indexcpis[indexcpis$year> as.numeric(base_year) & indexcpis$year<(as.numeric(lastyear)+1),]

##Adding regional codes/ areas included in exiobase sea
al <- indexcpis$year
if (source_version %in% c("wiodr13","wiodr16")) {
  ciso2c <- countrycode(lists$countries,"iso3c","iso2c", nomatch = "ROW")
for (i in names(indexcpis)[!(countrycode::countrycode(lists$countries,"iso3c","iso2c",nomatch = "ROW") %in% names(indexcpis))][-1]) {
  indexcpis[i] <- 100
  indexcpis <- indexcpis[,-1]
  indexcpis <- indexcpis[,ciso2c[ciso2c != "ROW"]]
  row.names(indexcpis) <- al
  indexcpis[,ciso2c[ciso2c != "ROW"]]
}
  } else {
    ciso2c <- lists$countries
  for (i in dimnames(sea_source)[[4]][!(dimnames(sea_source)[[4]] %in% names(indexcpis)[-1])]) {
    indexcpis[i] <- 100
    row.names(indexcpis) <- indexcpis$year
    indexcpis <- indexcpis[,-1]
    indexcpis <- indexcpis[dimnames(m_io)[[1]],dimnames(sea_source)[[4]]]
    
  }
}



arraycpis <- array(as.matrix(indexcpis),dim(indexcpis),dimnames = list(row.names(indexcpis), names(indexcpis)))
arraycpis <- arraycpis[,ciso2c[ciso2c != "ROW"]]


##calculate GDPS from sea_source data
pibx <- function(pais,ano) {
  a <- data.frame(year = ano,
                  iso2c = pais,
                  gdp = ifelse(source_version %in% c("wiodr13","wiodr16"),
                               sum(sea_source[as.character(ano),"VA_USD",,pais]),
                               sum(sea_source[as.character(ano),dimnames(sea_source)[[2]][1:9],,pais])))
  a
}

combs <- expand.grid(dimnames(sea_source)[[1]],lists$countries)

pibsexiobase <- data.table::rbindlist(mapply(pibx,combs$Var2,combs$Var1, SIMPLIFY = F))

if(source_version %in% c("wiodr13","wiodr16")){
  levels(pibsexiobase$iso2c) <- ciso2c
}

pibsexiobase <- pibsexiobase%>%pivot_wider(names_from=iso2c,values_from=gdp)

anospi <- pibsexiobase$year

pibsexiobase <- pibsexiobase[-1]
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
##ADD GDPS in local currency and calculate exchange rate
##except for euro area where gdp lcu is copied from "VATOTAL"



gdps <- read_csv2("source_data/worldbank/gdps_lcu.csv")

gdps <- gdps[-2]%>%pivot_wider(names_from = iso2c, values_from = NY.GDP.MKTP.CN)

if(source_version %in% c("wiodr13","wiodr16")){
  gdps <- gdps[gdps$year<as.numeric(lastyear)+1,]
for (i in names(gdps)[!(ciso2c[ciso2c != "ROW"] %in% names(gdps))]) {
  gdps[i] <- NA
}} else {
  for (i in lists$countries[!(ciso2c[c2iso2c != "ROW"] %in% names(gdps))][-1]) {
    gdps[i] <- 100
  }
  
}

gdps <- gdps%>%arrange(year)

gdps[,-1] <- gdps[,-1]/1000000

#GET GDPS from sea_source based on entry date and country code from eutmembers

   for (i in eutmembers$iso2c) {
    srctable <- eutmembers[eutmembers$iso2c == i,]
    gdps[gdps$year>srctable$startyear-1,unique(srctable$iso2c)] <- 
      cpi_gdp_er[as.character(srctable$startyear:as.numeric(lastyear)),i,"VA"]
   }
      
anos <- as.character(gdps$year)
gdps <- gdps[,ciso2c[ciso2c!= "ROW"]]


gdps <- gdps[ciso2c[ciso2c != "ROW"]]
row.names(gdps) <- as.character(anos)

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
cpis_gdps_er <- read_fst_array("results/exiobase/cpis_gdps_er.fst")
lambdas <- as.numeric(lambda)
if(base_year == lists$years[1]) {
  basi <- array(c(basebasket*replicate(nums$countries+1,lambdas),
                                 lambdas),c(nums$input,nums$countries+1),
                                 dimnames = list(
                                   dimnames(basebasket)[[1]],
                                   dimnames(basebasket)[[2]]
                                 )
                  )
  
  allyears <- dimnames(sea_countries)[[1]]
  basi <- colSums(basi,na.rm=T)
  
  basi <- array(replicate(length(allyears),basi),dim = c(length(basi),length(allyears),1),
                dimnames = list(dimnames(sea_countries)[[3]],allyears,"reference basket value"))%>%
    aperm(c(2,3,1))
  
  
  sea_countries <- abind(sea_countries,basi,along = 2)  
} else {
  er <- cpi_gdp_er[lists$years,,"exchange_rate"]
  erbase <- cpi_gdp_er[base_year,,"exchange_rate"]
  consprice <- cpi_gdp_er[lists$years,,"CPI"]
  baseconsprice <- cpi_gdp_er[base_year,,"CPI"]
  curba <-     array(c(replicate(nums$countries,lambdas)*basebasket*replicate(nums$inputs,erbase)*
                         replicate(nums$inputs,consprice)/replicate(nums$inputs,er),
                       lambdas),c(nums$input,nums$countries+1),
                     dimnames = list(
                       dimnames(basebasket)[[1]],
                       c(dimnames(basebasket)[[2]],"WWW")
                     )
  )
  curba <- colSums(curba,na.rm=T)
  sea_countries[lists$years,"reference basket value",] <- curba
}
  
write_fst_array(sea_countries,paste0("results/",method_version,"/sea_countries.fst"))
