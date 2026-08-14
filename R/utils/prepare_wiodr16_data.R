# download and prepare wiod data



wiotsf <- "source_data/wiodr16/WIOTS_in_R.zip"
soceaf <- "source_data/wiodr16/Socio_Economic_Accounts.xlsx"
# download wiod data ----
# download wiots
download.file(
#  "http://www.wiod.org/protected3/data13/update_sep12/wiot/wiot_matlab_sep12.zip",
  "https://dataverse.nl/api/access/datafile/199101",
  wiotsf,
  mode="wb")

# download sea
download.file(
  "https://dataverse.nl/api/access/datafile/199095",
  soceaf,
  mode="wb")

print("converting WIOD files...")

# converting sea ----
sea <- as.data.frame(
  read_excel(soceaf,
            sheet = "DATA", col_names = T, na = 'NA'))
sea[is.na(sea)] <- 0
colnames(sea) <- tolower(gsub("_","",colnames(sea)))

lists <- NULL

lists$years <- as.character(2000:2014)
lists$countries <- unique(sea[,1])
lists$sea_variables <- unique(sea[,2])
lists$sectors <- unique(sea[,4])

# includind sea variables obtained from WIOTs
lists$sea_variables <- c(lists$sea_variables,"VA_USD", "GO_USD")

# including RoW
lists$countries <- c(lists$countries,"ROW")

nums <- NULL
nums$years <- length(lists$years)
nums$sea_variables <- length(lists$sea_variables)
nums$countries <- length(lists$countries)
nums$sectors <- length(lists$sectors)

sea_source <- array(NA,
                    dim = c(nums$years,
                            nums$sea_variables,
                            nums$sectors,
                            nums$countries),
                    dimnames = list(lists$years,
                                    lists$sea_variables,
                                    lists$sectors,
                                    lists$countries))

x <- 1:nums$years
for (y in (1:(length(sea$country)))) {
  sea_source[
    x,
    sea[y,2],
    sea[y,4],
    sea[y,1]] <- as.matrix(sea[y,(x+4)])
}

sea_source <- sea_source[,,lists$sectors,]

# converting wiots ----
unzip(
  wiotsf,
  exdir = "source_data/wiod")




#function to load WIOT data and convert to matrix along
#our naming pattern definitions for dimnames
loren <- function(ano) {
  patwiot <- "_October16_ROW.RData"
  load(paste0("source_data/wiodr16/WIOT",ano,patwiot))
  withpoint <- paste(wiot$Country,wiot$IndustryCode,sep = ".")
  wiot <- wiot %>% select(-IndustryDescription,-IndustryCode,-Country,-RNr,-Year)
  wiot <- data.matrix(wiot[,-ncol(wiot)])
  findemcntry <- paste(rep(lists$countries,each=5),paste0("c",c(57,58,59,60,61)),sep = ".")
  puntocols <- c(paste(rep(lists$countries, each = 56),lists$sectors,sep="."),findemcntry)
  dimnames(wiot)[[1]] <- withpoint
  dimnames(wiot)[[2]] <- puntocols
  assign(paste0("wiot_", ano), wiot, envir = environment(loren))
  rm(wiot)
}

lapply(2000:2014,loren)
wiots <- ls(pattern="wiot_")

m_io <- abind(mget(wiots, envir = environment(), inherits = FALSE), along = 3)
dimnames(m_io)[[3]] <- 2000:2014

m_io <- aperm(m_io,c(3,1,2))
rm(list=wiots)
gc()

# creating lists of final demand, inputs and outputs
lists$demand <- paste0("c",c(57:61))
nums$demand <- length(lists$demand)

lists$input <-dimnames(m_io)[[2]][1:(nums$countries*nums$sectors)]
  
nums$input <- length(lists$input)

lists$output <- dimnames(m_io)[[3]]
  
nums$output <- length(lists$output)

#saves gross_output and value_added to SEA
sea_source[,"VA_USD",,] <- m_io[,"TOT.VA",1:nums$input]
sea_source[,"GO_USD",,] <- m_io[,"TOT.GO",1:nums$input]

# adjust m_io
m_io <- m_io[,1:nums$input, 1:nums$output]
# dimnames(m_io) <- list(lists$years,
#                        lists$input,
#                        lists$output)

# save all data
write_fst_array(m_io,"source_data/wiodr16/m_io.fst")
write_fst_array(sea_source,"source_data/wiodr16/sea.fst")

# write.table(lists$demand, "source_data/wiodr13/demand.csv", 
#             row.names = FALSE, col.names = "demand", sep = ";")
# 
# write.table(lists$countries, file = "source_data/wiodr13/countries.csv", 
#             row.names = FALSE, col.names = "country.source", sep = ";")
# 
# write.table(lists$sectors, "source_data/wiodr13/sectors.csv", 
#             row.names = FALSE, col.names = "sector.source", sep = ";")




# clear variables and data ----

#file.remove(...)

rm(lists, nums, sea, sea_source, m_io, x, y)
gc()
