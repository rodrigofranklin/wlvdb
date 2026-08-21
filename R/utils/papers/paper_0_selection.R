# select data to the paper on the reduction problem
country_selection <- c("BRA","USA","JPN","MEX")
year <- "2009"
nums$methods <- length(methods)

m_countries <- array(NA,
                     dim = c(nums$methods,
                             nums$years,
                             nums$m_countries_variables,
                             nums$countries,
                             nums$countries),
                     dimnames = list(methods,
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
                     dimnames = list(methods,
                                     lists$years,
                                     lists$sea_variables,
                                     lists$sectors,
                                     lists$countries))

sea_countries <- array(NA,
                       dim = c(nums$methods,
                               nums$years,
                               nums$sea_variables,
                               nums$countries+1),
                       dimnames = list(methods,
                                       lists$years,
                                       lists$sea_variables,
                                       c(lists$countries,"WWW")))

## lets predefine percentandresults for this paper
pc_cols <- (nums$methods+2):(nums$methods*2+1)
pc_res <- c(1,rbind(1:nums$methods+1,(nums$methods+2):(nums$methods*2+1)))
# load all results
for (mth_v in methods) {
  method_path <- wlv_current_result_dir(mth_v)
  
  m_countries[mth_v,,,,] <-
    read_fst_array(paste0(method_path,"/m_countries.fst"))
  
  sea_sectors[mth_v,,,,] <-
    read_fst_array(paste0(method_path,"/sea_sectors.fst"))
  
  sea_countries[mth_v,,,] <-
    read_fst_array(paste0(method_path,"/sea_countries.fst"))
}

# select results to show in the paper

# Table 0: prices deviations
temp1 <- sea_sectors[1,year,"gross_output.s.us",,]
dim(temp1) <- nums$countries_sectors
temp2 <- sea_sectors[,year,"gross_output.s.du",,]
dim(temp2) <- c(nums$methods,nums$countries_sectors)
table_0 <- cbind(temp1, t(temp2))

colnames(table_0) <- c("market_prices",methods)

# Table 1: gross output in market prices and direct prices
mp <- sea_countries[1,year,"gross_output.s.us",country_selection]/1000000
table_1 <- 
  cbind(mp,t(sea_countries[,year,"gross_output.s.du",country_selection])/1000000)
table_1 <- 
  cbind(table_1,
        t(sea_countries[,year,"gross_output.s.du",country_selection] /
            sea_countries[,year,"gross_output.s.us",country_selection]))

colnames(table_1)[pc_cols] <- "%"
table_1 <- table_1[,pc_res]

# Table 2: value added in mp and dp

mp <- sea_countries[1,year,"gdp.s.us",country_selection]/1000000

table_2 <- 
  cbind(mp,t(sea_countries[,year,"gdp.s.du",country_selection])/1000000)

table_2 <- 
  cbind(table_2,
        t(sea_countries[,year,"gdp.s.du",country_selection] /
            sea_countries[,year,"gdp.s.us",country_selection]))

colnames(table_2)[pc_cols] <- "%"
table_2 <- table_2[,pc_res]

# Table 3: exploitation rate
table_3 <- t(sea_countries[,year,"surplus_value.empe.r.pc",
                           c(country_selection,"WWW")])

# Table 4: exploitation rate per skill level
if(sum(!grepl("ochoa",dimnames(sea_countries)[[1]])) > 0) {
  pseq <- (1:dim(sea_countries)[1])[!grepl("ochoa",dimnames(sea_countries)[[1]])]
  table_4 <- sea_countries[pseq,
                           year,
                           grep("surplus_value.empe_",lists$sea_variables),
                           c(country_selection,"WWW")]
  
  if (pseq>1) {
    table_4 <- aperm(table_4, c(3,2,1))
    dim(table_4) <- c(dim(table_4)[1],dim(table_4)[2]*dim(table_4)[3])
  } else {
    table_4 <- aperm(table_4, c(2,1))
  }
  
} else {table_4 <- "only if methods other than ochoa's selected"}
# Figure 1: exploitation rate - series
f1_bra_exploitation_rate <- 
  sea_countries[,,"surplus_value.empe.r.pc","BRA"]
f1_usa_exploitation_rate <- 
  sea_countries[,,"surplus_value.empe.r.pc","USA"]
f1_world_exploitation_rate <- 
  sea_countries[,,"surplus_value.empe.r.pc","WWW"]

# Table 5: unequal exchange
table_5 <- 
  ((m_countries[,year,"transfers_productive_values",country_selection,] -
      aperm(
        m_countries[,year,"transfers_productive_values",,country_selection],
        c(1,3,2))) %>%
     apply(1, rowSums)) /
  t(sea_countries[,year,"gdp.s.mv",country_selection])

# Figure 2: unequal exchange - series
f2_bra_usa_unequal <- 
  (m_countries[,,"transfers_productive_values","BRA","USA"] -
     m_countries[,,"transfers_productive_values","USA","BRA"])/
  sea_countries[,,"gdp.s.mv","BRA"]

f2_mex_usa_unequal <- 
  (m_countries[,,"transfers_productive_values","MEX","USA"] -
     m_countries[,,"transfers_productive_values","USA","MEX"])/
  sea_countries[,,"gdp.s.mv","MEX"]

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

write_xlsx(mydata, path = "results/reduction_problem.xlsx")
