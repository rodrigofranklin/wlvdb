#create-cpis_gdps_exchange_rates array

##Add CPIS
indexcpis <- read_csv2("source_data/worldbank/cpis_countries.csv")
indexcpis$year <- as.numeric(indexcpis$year)
indexcpis <- indexcpis[indexcpis$year>1994,]

##Adding regional codes/ areas included in exiobase sea
for (i in dimnames(sea_source)[[4]][!(dimnames(sea_source)[[4]] %in% names(indexcpis)[-1])]) {
  indexcpis[i] <- 100
}

row.names(indexcpis) <- indexcpis$year
indexcpis <- indexcpis[,-1]
indexcpis <- indexcpis[dimnames(sea_source)[[4]]]
arraycpis <- array(as.matrix(indexcpis),dim(indexcpis),dimnames = list(row.names(indexcpis), names(indexcpis)))




##calculate GDPS from sea_source data
pibx <- function(pais,ano) {
  a <- data.frame(year = ano,
                  iso2c = pais,
                  gdp = sum(sea_source[as.character(ano),dimnames(sea_source)[[2]][1:9],,pais]))
  a
}

combs <- expand.grid(dimnames(sea_source)[[1]],dimnames(sea_source)[[4]])

pibsexiobase <- data.table::rbindlist(mapply(pibx,combs$Var2,combs$Var1, SIMPLIFY = F))

pibsexiobase <- pibsexiobase%>%pivot_wider(names_from=iso2c,values_from=gdp)

anospi <- pibsexiobase$year

pibsexiobase <- pibsexiobase[-1]
pibsexiobase <- pibsexiobase[dimnames(sea_source)[[4]]]
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

##ADD GDPS in local currency and calculate exchange rate
##except for euro area where gdp lcu is copied from "VATOTAL"



gdps <- read_csv2("source_data/worldbank/gdps_lcu.csv")

gdps <- gdps[-2]%>%pivot_wider(names_from = iso2c, values_from = NY.GDP.MKTP.CN)

for (i in dimnames(sea_source)[[4]][!(dimnames(sea_source)[[4]] %in% names(gdps)[-1])]) {
  gdps[i] <- NA
}

gdps <- gdps%>%arrange(year)

gdps[,-1] <- gdps[,-1]/1000000
#GET GDPS from sea_source based on entry date and country code from eutmembers
  for (i in eutmembers$iso2c) {
    srctable <- eutmembers[eutmembers$iso2c == i,]
    gdps[gdps$year>srctable$startyear-1,i] <- 
      cpi_gdp_er[as.character(srctable$startyear:2021),i,"VA"]
      }

anos <- as.character(gdps$year)
gdps <- gdps[,-1]


gdps <- gdps[dimnames(sea_source)[[4]]]
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
if(base_year == lists$years[1]) {
  lambdas <- as.numeric(sea_sectors[base_year,"value.m.mv",,])
  basi <- array(c(basebasket*replicate(nums$countries+1,lambdas),
                                 lambdas),c(nums$input,nums$countries+1),
                                 dimnames = list(
                                   dimnames(basebasket)[[1]],
                                   dimnames(basebasket)[[2]]
                                 )
                  )
  basi <- colSums(basi,na.rm=T)
  basi <- array(replicate(nrow(cpi_gdp_er),basi),c(nrow(cpi_gdp_er),1,dim(basi)[2]),
                dimnames = list(list(dimnames(sea_countries)[[1]],"reference basket value",dimnames(sea_countries)[[3]]))
  )

  sea_countries <- abind(sea_countries,basi,along = 2)  
} else {
  lambdas <- as.numeric(sea_sectors[,"value",,])
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