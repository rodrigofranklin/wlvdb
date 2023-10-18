# select data to the paper on Health and Dependency
library(REdaS)
method_list <- c("wiodr13","wiodr16")

#Uncomment if needed the call for gomarx
get_wlv(method_list)

#country_selection <- c("BRA","USA","JPN","MEX")

#Grouping EU
library(rvest)
eu_countries <- html_table(
  read_html("https://www23.statcan.gc.ca/imdb/p3VD.pl?Function=getVD&TVD=141329"))[[1]]


eur_na_wlvd <- eu_countries$`Alpha-3`[
  eu_countries$`Alpha-3` %in% dimnames(sea_sectors)[[4]]]
tx_exploracao_saude <- sea_sectors[as.character(2000:2014),"surplus_value.empe.r.pc","Q",c("BRA","MEX","JPN","USA")]

tx_exploracao_europa <- sea_sectors[as.character(2000:2014),"surplus_value.empe.r.pc","Q",eur_na_wlvd]


horas_europa <- sea_sectors[as.character(2000:2014),"abstract_labour.empe.m.mv","Q",eur_na_wlvd]


tx_exp_europa_saude_pond <- rowSums(tx_exploracao_europa*horas_europa)/rowSums(horas_europa)

tx_exp_europa_saude_pond <- as.array(tx_exp_europa_saude_pond)

dim(tx_exp_europa_saude_pond) <- c(15,1)

dimnames(tx_exp_europa_saude_pond)[[1]] <- 2000:2014

dimnames(tx_exp_europa_saude_pond)[[2]] <- "EUR"

tx_exp_saude <- cbind(tx_exploracao_saude,tx_exp_europa_saude_pond)

tx_x_saude <- as_tibble(tx_exp_saude,rownames="ano")%>%pivot_longer(-ano,names_to="país",values_to="taxa_exploracao")%>%
  mutate(país = as_factor(país))
ggplot(tx_x_saude,aes(x=ano,y=taxa_exploracao,group=`país`))+geom_line(aes(col=`país`))+
  theme_minimal()+
  ylab("Taxa de exploração\nTrabalhadores da saúde e serviço social")+
  scale_y_continuous(labels = scales::percent)



salarios_usd <- sea_sectors[,"compensation.emp.s.us","Q",c("BRA","MEX","USA","JPN")]/sea_sectors[,"emp.s.un","Q",c("BRA","MEX","USA","JPN")]/12

salarios_europa_usd <- 
  sea_sectors[,"compensation.empe.s.us","Q",eur_na_wlvd]/sea_sectors[,"empe.s.un","Q",]/12


year <- "2007"
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
  method_path <- paste0("results/",mth_v)
  
  m_countries[mth_v,,,,] <-
    read_fst_array(paste0(method_path,"/m_countries.fst"))
  
  sea_sectors[mth_v,,,,] <-
    read_fst_array(paste0(method_path,"/sea_sectors.fst"))
  
  sea_countries[mth_v,,,] <-
    read_fst_array(paste0(method_path,"/sea_countries.fst"))
}

# select results to show in the paper

# Table 1: prices deviations - VERSION FOR ALL YEARS AT ONCE
#Define aux Function to get each method's gross_output in dp and 
# (c)bind them
jbind <- function(m) {
  a <- sea_sectors[m,,"gross_output.s.du",,]
  #redim as vector
  dim(a) <- prod(dim(a))
  a
}
temp1 <- sea_sectors[1,,"gross_output.s.us",,]
dim(temp1) <- prod(dim(temp1))
temp2 <- do.call(cbind,lapply(method_list,jbind))


table_0b <- cbind(temp1, temp2)

colnames(table_0b) <- c("market_prices",method_list)

#Function to compute relevant deviation measure
get_deviations <- function(method = "alternative_1",basetable = table_0b,conlog = T) {
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

table_0 <- lapply(method_list,get_deviations,conlog=F)
table_0 <- do.call(rbind,table_0)

table_1 <- table_0%>%pivot_longer(-method,names_to="metric",values_to="value")%>%
  pivot_wider(names_from=method,values_from="value")


#Table 2 - VALUE VALUE DEVIATIONS FOR ALL YEARS AT ONCE
table_0b <- table_0b[,c(2,3)]

table_2 <- get_deviations("zerodep_1",conlog = F)



##Removing leftover table_0b
#rm(table_0b)  



# Figure 1: exploitation rate
table_3 <- t(sea_countries[,,"surplus_value.empe.r.pc",
                           "WWW"])

table_3[table_3<0] <- NA

table_3 <- table_3%>%as_tibble(rownames = "year")%>%pivot_longer(-1,names_to="method",values_to = "exploitation rate")%>%
  mutate(year=as.numeric(year), method = as.factor(method))

table_4 <- t(sea_countries[,,"gross_output_dp",
                           "WWW"])

ggplot(table_3,aes(year,`exploitation rate`, colour = method))+
  geom_line()+
  hrbrthemes::theme_tinyhand()
