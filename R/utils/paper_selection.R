# select data to the paper on the reduction problem
country_selection <- c("BRA","USA","JPN","MEX")
year <- "2009"
nums$methods <- length(method_list)

m_countries <- array(NA,
                     dim = c(nums$methods,
                             nums$years,
                             nums$m_countries_variables,
                             nums$countries,
                             nums$countries),
                     dimnames = list(method_list,
                                     lists$years,
                                     lists$m_countries_variables,
                                     lists$countries,
                                     lists$countries))

sea_sectors <- array(NA,
                     dim = c(nums$methods,
                             nums$years,
                             nums$sea_variables,
                             nums$sectors,
                             nums$countries),
                     dimnames = list(method_list,
                                     lists$years,
                                     lists$sea_variables,
                                     lists$sectors,
                                     lists$countries))

sea_countries <- array(NA,
                       dim = c(nums$methods,
                               nums$years,
                               nums$sea_variables,
                               nums$countries+1),
                       dimnames = list(method_list,
                                       lists$years,
                                       lists$sea_variables,
                                       c(lists$countries,"WWW")))

# load all results
for (method_version in method_list) {
  method_path <- paste0("results/", method_version)

  m_countries[method_version,,,,] <-
    readRDS(paste0(method_path,"/m_countries.rds"))
  
  sea_sectors[method_version,,,,] <-
    readRDS(paste0(method_path,"/sea_sectors.rds"))
  
  sea_countries[method_version,,,] <-
    readRDS(paste0(method_path,"/sea_countries.rds"))
}

# select results to show in the paper

# Table 0: prices deviations
temp1 <- sea_sectors[1,year,"gross_output_mp",,]
dim(temp1) <- nums$countries_sectors
temp2 <- sea_sectors[,year,"gross_output_dp",,]
dim(temp2) <- c(nums$methods,nums$countries_sectors)
table_0 <- cbind(temp1, t(temp2))
colnames(table_0) <- c("market_prices",method_list)
  
# Table 1: gross output in mp and dp
mp <- sea_countries[1,year,"gross_output_mp",country_selection]/1000000
table_1 <- 
  cbind(mp,t(sea_countries[,year,"gross_output_dp",country_selection])/1000000)
table_1 <- 
  cbind(table_1,
        t(sea_countries[,year,"gross_output_dp",country_selection] /
            sea_countries[,year,"gross_output_mp",country_selection]))
colnames(table_1)[7:11] <- "%"
table_1 <- table_1[,c(1,2,7,3,8,4,9,5,11)]

# Table 2: value added in mp and dp
mp <- sea_countries[1,year,"value_added_mp",country_selection]/1000000
table_2 <- 
  cbind(mp,t(sea_countries[,year,"value_added_dp",country_selection])/1000000)
table_2 <- 
  cbind(table_2,
        t(sea_countries[,year,"value_added_dp",country_selection] /
            sea_countries[,year,"value_added_mp",country_selection]))
colnames(table_2)[7:11] <- "%"
table_2 <- table_2[,c(1,2,7,3,8,4,9,5,11)]

# Table 3: exploitation rate
table_3 <- t(sea_countries[,year,"exploitation_rate",
                           c(country_selection,"WWW")])

# Table 4: exploitation rate per skill level
table_4 <- sea_countries[3:5,
                         year,
                         grep("exploitation_rate_",lists$sea_variables),
                         c(country_selection,"WWW")]
table_4 <- aperm(table_4, c(3,2,1))
dim(table_4) <- c(5,9)

# Figure 1: exploitation rate - series
f1_bra_exploitation_rate <- 
  sea_countries[,,"exploitation_rate","BRA"]
f1_usa_exploitation_rate <- 
  sea_countries[,,"exploitation_rate","USA"]
f1_world_exploitation_rate <- 
  sea_countries[,,"exploitation_rate","WWW"]

# Table 5: unequal exchange
table_5 <- 
  ((m_countries[,year,"transfers_productive_values",country_selection,] -
  aperm(
    m_countries[,year,"transfers_productive_values",,country_selection],
    c(1,3,2))) %>%
  apply(1, rowSums)) /
  t(sea_countries[,year,"value_added_values",country_selection])

# Figure 2: unequal exchange - series
f2_bra_usa_unequal <- 
  (m_countries[,,"transfers_productive_values","BRA","USA"] -
     m_countries[,,"transfers_productive_values","USA","BRA"])/
  sea_countries[,,"value_added_values","BRA"]

f2_mex_usa_unequal <- 
  (m_countries[,,"transfers_productive_values","MEX","USA"] -
    m_countries[,,"transfers_productive_values","USA","MEX"])/
  sea_countries[,,"value_added_values","MEX"]

# Save to xlsx
mydata <- list(
  data.frame(table_0),
  data.frame(table_1),
  data.frame(table_2),
  data.frame(table_3),
  data.frame(table_4),
  data.frame(f1_bra_exploitation_rate),
  data.frame(f1_usa_exploitation_rate),
  data.frame(f1_world_exploitation_rate),
  data.frame(table_5),
  data.frame(f2_bra_usa_unequal),
  data.frame(f2_mex_usa_unequal))

myfile <- paste0("results/reduction_problem.xlsx")
write_xlsx(mydata, path = myfile)
