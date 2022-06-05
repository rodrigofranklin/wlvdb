# download and prepare wiod data

dir.create("source_data", showWarnings = FALSE)

# download wiod data ----
# download wiots
download.file(
#  "http://www.wiod.org/protected3/data13/update_sep12/wiot/wiot_matlab_sep12.zip",
  "https://dataverse.nl/api/access/datafile/199125",
  "source_data/wiodr13/wiot_matlab_sep12.zip",
  mode = "wb")

# download sea
download.file(
#  "http://www.wiod.org/protected3/data13/SEA/WIOD_SEA_July14.xlsx",
  "https://dataverse.nl/api/access/datafile/199111",
  "source_data/wiodr13/WIOD_SEA_July14.xlsx",
  mode="wb")

print("converting WIOD files...")

# converting sea ----
sea <- as.data.frame(
  read_excel("source_data/wiodr13/WIOD_SEA_July14.xlsx",
            sheet = "DATA", col_names = T, na = 'NA'))
sea[is.na(sea)] <- 0
colnames(sea) <- tolower(gsub("_","",colnames(sea)))

lists <- NULL

lists$years <- as.character(1995:2009)
lists$countries <- unique(sea[,1])
lists$sea_variables <- unique(sea[,2])
lists$sectors <- unique(sea[,4])

# including sea variables obtained from WIOTs
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

# excluding "TOT" sector
lists$sectors <- lists$sectors[2:nums$sectors]
nums$sectors <- nums$sectors-1
sea_source <- sea_source[,,lists$sectors,]

# converting wiots ----
unzip(
  "source_data/wiodr13/wiot_matlab_sep12.zip",
  files = c("WIOT95_00.mat",
            "WIOT01_05.mat",
            "WIOT06_09.mat",
            "WIOT08_11.mat"),
  exdir = "source_data/wiodr13")

wiot_1 <- as.matrix(readMat("source_data/wiodr13/WIOT95_00.mat")$WIOT95.00)
wiot_2 <- as.matrix(readMat("source_data/wiodr13/WIOT01_05.mat")$WIOT01.05)
wiot_3 <- as.matrix(readMat("source_data/wiodr13/WIOT06_09.mat")$WIOT06.09)
wiot_4 <- as.matrix(readMat("source_data/wiodr13/WIOT08_11.mat")$WIOT08.11)

# concatenates WIOTS
m_io <- cbind(wiot_1, wiot_2, wiot_3)
# adjusts dimensions
dim(m_io) <- c(1443, 1641, 15)
# update 2008 and 2009
m_io[,,14:15] <- wiot_4[1:1443, 1:(1641*2)]
# transpose
m_io <- aperm(m_io, c(3,1,2))

# creating lists of final demand, inputs and outputs
lists$demand <- paste0("c",c(37,38,39,41,42))
nums$demand <- length(lists$demand)

lists$input <- c(
  paste0(
    rep(lists$countries, each = nums$sectors),
    ".",
    rep(lists$sectors, times = nums$countries)))
nums$input <- length(lists$input)

lists$output <- c(
  paste0(
    rep(lists$countries, each = nums$sectors),
    ".",
    rep(lists$sectors, times = nums$countries)),
  paste0(
    rep(lists$countries, each = nums$demand),
    ".",
    rep(lists$demand, times = nums$countries)))
nums$output <- length(lists$output)

#saves gross_output and value_added to SEA
sea_source[,"VA_USD",,] <- m_io[,1441,1:nums$input]
sea_source[,"GO_USD",,] <- m_io[,1443,1:nums$input]

# adjust m_io
m_io <- m_io[,1:nums$input, 1:nums$output]
dimnames(m_io) <- list(lists$years,
                       lists$input,
                       lists$output)

# save all data
write_fst_array(m_io,"source_data/wiodr13/m_io.fst")
write_fst_array(sea_source,"source_data/wiodr13/sea.fst")

# write.table(lists$demand, "source_data/wiodr13/demand.csv", 
#             row.names = FALSE, col.names = "demand", sep = ";")
# 
# write.table(lists$countries, file = "source_data/wiodr13/countries.csv", 
#             row.names = FALSE, col.names = "country.source", sep = ";")
# 
# write.table(lists$sectors, "source_data/wiodr13/sectors.csv", 
#             row.names = FALSE, col.names = "sector.source", sep = ";")




# clear variables and data ----

file.remove("source_data/wiodr13/WIOD_SEA_July14.xlsx",
            "source_data/wiodr13/wiot_matlab_sep12.zip",
            "source_data/wiodr13/WIOT95_00.mat",
            "source_data/wiodr13/WIOT01_05.mat",
            "source_data/wiodr13/WIOT06_09.mat",
            "source_data/wiodr13/WIOT08_11.mat")

rm(lists, nums, sea, sea_source, wiot_1, wiot_2, wiot_3, wiot_4, m_io, x, y)
gc()

source("R/utils/prepare_euklems_data.R")
