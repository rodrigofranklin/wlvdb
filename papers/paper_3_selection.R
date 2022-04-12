# select data to the paper on the reduction problem
method_list <- c("alternative_1","zerodep_1")

#Uncomment if needed the call for gomarx
gomarx(method_list)

#country_selection <- c("BRA","USA","JPN","MEX")
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

## lets predefine percentandresults for this paper
pc_cols <- (nums$methods+2):(nums$methods*2+1)
pc_res <- c(1,rbind(1:nums$methods+1,(nums$methods+2):(nums$methods*2+1)))
# load all results
for (mth_v in method_list) {
  method_path <- paste0("methods/", mth_v,"/results")

  m_countries[mth_v,,,,] <-
    readRDS(paste0(method_path,"/m_countries.rds"))
  
  sea_sectors[mth_v,,,,] <-
    readRDS(paste0(method_path,"/sea_sectors.rds"))
  
  sea_countries[mth_v,,,] <-
    readRDS(paste0(method_path,"/sea_countries.rds"))
}

# select results to show in the paper

# Table 1: prices deviations - VERSION FOR ALL YEARS AT ONCE
#Define aux Function to get each method's gross_output in dp and 
# (c)bind them
jbind <- function(m) {
  a <- sea_sectors[m,,"gross_output_dp",,]
  #redim as vector
  dim(a) <- prod(dim(a))
  a
}
temp1 <- sea_sectors[1,,"gross_output_mp",,]
dim(temp1) <- prod(dim(temp1))
temp2 <- do.call(cbind,lapply(method_list,jbind))


table_0b <- cbind(temp1, temp2)

colnames(table_0b) <- c("market_prices",method_list)

#Function to compute relevant deviation measure
get_deviations <- function(method = "ochoa_1",basetable = table_0b,conlog = T) {
  b <-  basetable[which(basetable[,2] !=0 & basetable[,1] !=0 ),1]
  #print(summary(b))
  c <- basetable[ which(basetable[,2] !=0 & basetable[,1]!=0) ,method]
  
  #Logs si definido
  if (conlog == T) {
  b <- log(b)
    c <- log(c)
  }
  #print(summary(c))
  x <- abs(c-b)
  x_perc <- x/b
  r <- cor(c,b)
  rsquared <- r^2
  MAWD <- weighted.mean(x_perc,b)
  MAD <- mean(x_perc)
  NVD <- norm(as.matrix(x),"F")/norm(as.matrix(b),"F")
  rmspe <- MLmetrics::RMSPE(c,b) #rmse
  cv <- sd(c/b)/mean(c/b)
  θ <- rad2deg(atan(cv))
  d <-  2*sin(atan(cv)/2)
  
  print(paste("market-direct price deviations calculated for method",method))
  a <- data.frame(cbind(r,rsquared,MAD,MAWD,NVD,rmspe,θ,cv,d))
  a$method <- method
  a
}

table_0 <- lapply(method_list,get_deviations)
table_0 <- do.call(rbind,table_0)

table_1 <- table_0%>%pivot_longer(-method,names_to="metric",values_to="value")%>%
  pivot_wider(names_from=method,values_from="value")


#Table 2 - VALUE VALUE DEVIATIONS FOR ALL YEARS AT ONCE
table_0b <- table_0b[,c(2,3)]

table_2 <- get_deviations("zerodep_1",conlog = F)



##Removing leftover table_0b
#rm(table_0b)  



# Figure 1: exploitation rate
table_3 <- t(sea_countries[,,"exploitation_rate",
                           "WWW"])

table_3[table_3<0] <- NA

table_3 <- table_3%>%as_tibble(rownames = "year")%>%pivot_longer(-1,names_to="method",values_to = "exploitation rate")%>%
  mutate(year=as.numeric(year), method = as.factor(method))


ggplot(table_3,aes(year,`exploitation rate`, colour = method))+
  geom_line()+
  hrbrthemes::theme_tinyhand()
