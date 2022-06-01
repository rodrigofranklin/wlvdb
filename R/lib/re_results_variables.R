## assign results variables

## Define parameters ----
lists$m_io_variables <- matrices$names
lists$m_countries_variables <- reduced_matrices$names
lists$sea_variables <- sea_variables$names

nums$m_io_variables <- length(lists$m_io_variables)
nums$m_countries_variables <- length(lists$m_countries_variables)
nums$sea_variables <- length(lists$sea_variables)

# Recriates results variables in case of new variables
# sea_sectors -> vectors of results per sector
sea_sectors <- array(NA,
                     dim = c(nums$years,
                             nums$sea_variables,
                             nums$sectors,
                             nums$countries),
                     dimnames = list(lists$years,
                                     lists$sea_variables,
                                     lists$sectors,
                                     lists$countries))

# sea_countries -> vectors of results per country
# Obs: a 'Whole Wide World' (WWW) is added
sea_countries <- array(NA,
                       dim = c(nums$years,
                               nums$sea_variables,
                               nums$countries+1),
                       dimnames = list(lists$years,
                                       lists$sea_variables,
                                       c(lists$countries,"WWW")))

## load variables  ----

m_countries <- 
  read_fst_array(paste0(paste0("results/",method_version,"/m_countries.fst")))

# sea_sectors -> vectors of results per sector
sea_sectors_temp <- 
  read_fst_array(paste0(paste0("results/",method_version,"/sea_sectors.fst")))

# sea_countries -> vectors of results per country
sea_countries_temp <- 
  read_fst_array(paste0(paste0("results/",method_version,"/sea_countries.fst")))

sea_sectors[,names(sea_sectors_temp[1,,1,1]),,] <- sea_sectors_temp

sea_countries[,names(sea_countries_temp[1,,1]),] <- sea_countries_temp

rm(sea_sectors_temp, sea_countries_temp)
