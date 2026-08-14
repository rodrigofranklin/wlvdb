## assign results variables

## Define parameters ----
lists$m_io_variables <- matrices$names
lists$m_countries_variables <- reduced_matrices$names
lists$sea_variables <- sea_variables$names

nums$m_io_variables <- length(lists$m_io_variables)
nums$m_countries_variables <- length(lists$m_countries_variables)
nums$sea_variables <- length(lists$sea_variables)

# Reuse the indicator metadata written by the original calculation. If an old
# result predates that file, create the same structure used by a full run.
meta_indicators_path <- paste0("results/", method_version, "/meta_indicators.RDS")
if (file.exists(meta_indicators_path)) {
  meta_indicators <- readRDS(meta_indicators_path)
} else {
  meta_indicators <- data.frame(
    code = lists$sea_variables,
    name = NA_character_,
    description = NA_character_,
    observation = NA_character_,
    group = NA_character_,
    type = NA_character_,
    reverted = NA,
    stringsAsFactors = FALSE,
    row.names = lists$sea_variables
  )
}

missing_indicators <- setdiff(lists$sea_variables, meta_indicators$code)
if (length(missing_indicators)) {
  additions <- data.frame(
    code = missing_indicators,
    name = NA_character_,
    description = NA_character_,
    observation = NA_character_,
    group = NA_character_,
    type = NA_character_,
    reverted = NA,
    stringsAsFactors = FALSE,
    row.names = missing_indicators
  )
  meta_indicators <- rbind(meta_indicators, additions)
}
row.names(meta_indicators) <- meta_indicators$code

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
  read_fst_array(paste0("results/",method_version,"/m_countries.fst"))

# sea_sectors -> vectors of results per sector
sea_sectors_temp <- 
  read_fst_array(paste0("results/",method_version,"/sea_sectors.fst"))
sea_sectors[,names(sea_sectors_temp[1,,1,1]),,] <- sea_sectors_temp

# sea_countries -> vectors of results per country
if (file.exists(paste0("results/",method_version,"/sea_countries.fst"))) {
  sea_countries_temp <- 
    read_fst_array(paste0("results/",method_version,"/sea_countries.fst"))
  sea_countries[,names(sea_countries_temp[1,,1]),] <- sea_countries_temp
}

rm(sea_sectors_temp)
if (exists("sea_countries_temp", inherits = FALSE)) {
  rm(sea_countries_temp)
}
rm(list = intersect(
  c("meta_indicators_path", "missing_indicators", "additions"),
  ls(envir = environment(), all.names = TRUE)
), envir = environment())
