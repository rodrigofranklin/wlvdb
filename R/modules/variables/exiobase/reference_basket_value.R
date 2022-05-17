#create-cpis_gdps_exchange_rates array
cat("Obtaining value of reference basket...\n\n")
if(!exists("base_year")){
  base_year <- dimnames(sea_countries)[[1]][1]
}
allyears <- dimnames(sea_countries)[[1]]
##Add CPIS
indexcpis <- read_csv2("source_data/worldbank/cpis_countries.csv")

lastyear <- dimnames(sea_countries)[[1]][length(dimnames(sea_countries)[[1]])]

indexcpis$year <- as.numeric(indexcpis$year)
indexcpis <- indexcpis[indexcpis$year> as.numeric(allyears[1])-1 & indexcpis$year<(as.numeric(lastyear)+1),]

#Change base to first year in source_version
indexcpis[,-1] <- mapply('/',indexcpis[,-1],indexcpis[1,-1])
indexcpis[,-1] <- 100*indexcpis[,-1]
##Adding regional codes/ areas included in exiobase sea
al <- indexcpis$year
allyears <- dimnames(sea_countries)[[1]]
    ciso2c <- lists$countries
  for (i in ciso2c[(!ciso2c %in% names(indexcpis))]) {
    indexcpis[i] <- 100
  }
    row.names(indexcpis) <- al
    indexcpis <- indexcpis[,-1]
    indexcpis <- indexcpis[,ciso2c]




arraycpis <- array(as.matrix(indexcpis),dim(indexcpis),dimnames = list(row.names(indexcpis), names(indexcpis)))



##calculate GDPS from sea_source data


pibsexiobase <- as.data.frame(sea_countries[,"gdp.s.us",])

pibsexiobase$year <- as.numeric(row.names(pibsexiobase))


anospi <- pibsexiobase$year

pibsexiobase <- pibsexiobase[1:nums$countries]
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



exrate <- array(mapply("/",cpi_gdp_er[,,"VATOTAL"],cpi_gdp_er[,,"VA"]),c(dim(cpi_gdp_er)[-3],1),
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
lambdas <- sea_sectors[lists$years,"value.m.mv",,]

    basi <- array(basebasket,
                        c(nums$input,nums$countries),
                  dimnames = list(
                    dimnames(basebasket)[[1]],
                    dimnames(basebasket)[[2]]
                  )
    )
  

#  basi <- colSums(basi,na.rm=T)
  expbasi <- as.matrix(data.frame("WWW" = apply(basi,1,mean,na.rm = T)))
  cseac <- length(dimnames(sea_countries)[[3]])
  
    basi <- array(replicate(length(allyears),abind(basi,expbasi,along = 2)),
                  dim = c(dim(basi)[[1]],
                          cseac,
                          length(allyears),
                          1),
                  dimnames = list(lists$input,
                                  dimnames(sea_countries)[[3]],
                                  allyears,
                                  "reference_basket_value.hr.mv"))%>%
      aperm(c(3,4,1,2))
    
    
  
  write_fst_array(basi,paste0("results/",method_version,"/base_monetary_structure_of_cbasket.fst"))
  er <- cpi_gdp_er[lists$year,,"exchange_rate"]
  fkwww <- data.frame(WWW = rep(105,27))
  er <- cbind(er,fkwww)
  erm <- (replicate(nums$input,as.matrix(er)) %>%aperm(c(1,3,2)))
  erbase <- cpi_gdp_er[base_year,,"exchange_rate"]
  erbase <- c(erbase,1)
  
  consprice <- cpi_gdp_er[lists$years,,"CPI"]
  fkwww <- data.frame(WWW = rep(105,27))
  consprice <- cbind(consprice,fkwww)
  
  baseconsprice <- cpi_gdp_er[base_year,,"CPI"]
  fkwww<- 1
  baseconsprice <- c(baseconsprice,fkwww)
#  curba <-     basi[base_year,1,,]*replicate(nums$countries+1,as.numeric(lambdas[base_year,,]))
  

  
#  curba <- colSums(curba,na.rm=T)
  
  #names(curba) <- names(er)
  
  #sea_countries[base_year,"reference_basket_value.c.hr",] <- curba
  
  curba <-     basi[lists$years,1,,]*array(replicate(nums$countries+1,as.numeric(lambdas[lists$years,,])),c(nums$years,nums$input,nums$countries+1))*
  (array(replicate(nums$years,replicate(nums$input,erbase)),dim = c(nums$years,nums$input,nums$countries+1)))*
    array(rep(100,nums$years*nums$input*(nums$countries+1)),c(nums$years,nums$input,nums$countries+1))*
    array(rep(100,nums$years,nums$input*(nums$countries+1)),c(nums$years,nums$input,nums$countries+1))/
    ((replicate(nums$input,as.matrix(consprice)) %>%aperm(c(1,3,2)))*er)
                    
  
  vlavla <- sapply(1:nums$years,function(i){colSums(curba[i,,],na.rm= T)} )%>%aperm(c(2,1))
    

curba <- sapply(1:nums$years,function(x){curba[x,,] <- colSums(curba[x,,],na.rm = T)})
dimnames(curba)[] <- dimnames(er)

  sea_countries[lists$years,"reference_basket_value.c.hr",] <- curba


  
write_fst_array(sea_countries,paste0("results/",method_version,"/sea_countries.fst"))
