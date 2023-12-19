# select data to the paper on Health and Dependency
library(REdaS)
method_list <- c("wiodr13","wiodr16")
source("R/lib/functions.R")
#Uncomment if needed the call for gomarx
#get_wlv(method_list)

country_selection <- c("BRA","USA","JPN","MEX")

#Grouping EU
library(rvest)
eu_countries <- html_table(
  read_html("https://www23.statcan.gc.ca/imdb/p3VD.pl?Function=getVD&TVD=141329"))[[1]]


eur_na_wlvd <- eu_countries$`Alpha-3`[
  eu_countries$`Alpha-3` %in% dimnames(sea_countries)[[4]]]
tx_exploracao_saude <- sea_sectors[as.character(2000:2014),"surplus_value.emp.r.pc","Q",c("BRA","MEX","JPN","USA")]

tx_exploracao_europa <- sea_sectors[as.character(2000:2014),"surplus_value.emp.r.pc","Q",eur_na_wlvd]


horas_europa <- sea_sectors[as.character(2000:2014),"abstract_labour.emp.m.mv","Q",eur_na_wlvd]

tx_exploracao_mundo <- t(sea_countries[,,"surplus_value.emp.r.pc",
                           "WWW"])



tx_exp_europa_saude_pond <- rowSums(tx_exploracao_europa*horas_europa)/rowSums(horas_europa)

tx_exp_europa_saude_pond <- as.array(tx_exp_europa_saude_pond)

dim(tx_exp_europa_saude_pond) <- c(15,1)

dimnames(tx_exp_europa_saude_pond)[[1]] <- 2000:2014

dimnames(tx_exp_europa_saude_pond)[[2]] <- "EUR"

tx_exp_saude <- cbind(tx_exploracao_saude,tx_exp_europa_saude_pond,)

tx_x_saude <- as_tibble(tx_exp_saude,rownames="ano")%>%pivot_longer(-ano,names_to="país",values_to="taxa_exploracao")%>%
  mutate(país = as_factor(país))
ggplot(tx_x_saude,aes(x=ano,y=taxa_exploracao,group=`país`))+geom_line(aes(col=`país`))+
  theme_minimal()+ggthemes::theme_wsj()+
  ylab("Taxa de exploração\nTrabalhadores da saúde e serviço social")+
  labs(col="País/região",x="Ano")+
  scale_y_continuous(labels = scales::percent)



salarios_usd <- sea_sectors[,"compensation.emp.s.us","Q",c("BRA","MEX","USA","JPN")]/sea_sectors[,"emp.s.un","Q",c("BRA","MEX","USA","JPN")]/12

salarios_europa_usd <- 
  sea_sectors[,"compensation.empe.s.us","Q",eur_na_wlvd]/sea_sectors[,"empe.s.un","Q",]/12



varsc <- read_fst_array(paste0("results/wiodr16","/m_countries.fst"))
varsea <- read_fst_array("results/wiodr13/sea_sectors.fst")
varsea16 <- read_fst_array("results/wiodr16/sea_sectors.fst")
varsscea <- read_fst_array("results/wiodr16/sea_countries.fst")
year <- "2007"
nums <- data.frame(methods=2)
lists <- list(years=1995:2014)
lists$m_countries_variables <- dimnames(varsc)[[2]]
lists$sea_variables <- unique(c(dimnames(varsea)[[2]],dimnames(varsea16)[[2]]))
lists$countries <- unique(c(dimnames(varsc)[[4]],dimnames(varsea)[[4]]))
lists$sectors <- unique(c(dimnames(varsea)[[3]],dimnames(varsea16)[[3]]))
#lists$sectors <- dimnames(varsc)[[3]]

nums$methods <- length(method_list)
nums$years <- length(lists$years)
nums$m_countries_variables <- length(lists$m_countries_variables)
nums$sea_variables <- length(lists$sea_variables)
nums$countries <- length(lists$countries)
nums$sectors <- length(lists$sectors)



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
  mpais <- read_fst_array(paste0(method_path,"/m_countries.fst"))
  
  m_countries[mth_v,
              dimnames(mpais)[[1]],
              dimnames(mpais)[[2]],
              dimnames(mpais)[[3]],
              dimnames(mpais)[[4]]] <-mpais
  
  msetor <-   read_fst_array(paste0(method_path,"/sea_sectors.fst"))
 print(mth_v)
  print(dim(msetor))
  print(dim(sea_sectors))
  sea_sectors[mth_v,
              dimnames(msetor)[[1]],
              dimnames(msetor)[[2]],
              dimnames(msetor)[[3]],
              dimnames(msetor)[[4]]] <- msetor

  spais <- read_fst_array(paste0(method_path,"/sea_countries.fst"))
  sea_countries[mth_v,
                dimnames(spais)[[1]],
                dimnames(spais)[[2]],
                dimnames(spais)[[3]]] <-   spais
  rm(list=c("mpais","msetor","spais"))
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

pm <- c(country_selection,"WWW")
tx_exp_p <- 
  cbind(year = 1995:2014,
        as_tibble(
          sea_countries["wiodr13",,"surplus_value.emp.r.pc" ,pm]))%>%pivot_longer(-1,names_to="country",values_to='surplus_rate')|> 
  dplyr::filter(!is.na('surplus_rate'))

tx_exp_p2 <- 
  cbind(year = 1995:2014,
        as_tibble(
          sea_countries["wiodr16",,"surplus_value.emp.r.pc" ,pm]))|>
  pivot_longer(-1,names_to="country",values_to='surplus_rate')|> dplyr::filter(!is.na('surplus_rate'))

tx_exp_junto <- tx_exp_p|>left_join(tx_exp_p2, by = c("year","country"))
names(tx_exp_junto)[3:4] <- c("wiod13","wiod16")

#tx_exp_junto <-tx_exp_junto|> pivot_longer(-1:-2,names_to="version",values_to="surplus_rate")

#tx_exp_junto <- tx_exp_junto|> dplyr::filter(!is.na(surplus_rate))


txexp_eur <- cbind(year = 1995:2014,
                   as_tibble(
                     sea_countries["wiodr13",,"surplus_value.emp.r.pc" ,eur_na_wlvd]))|>
  pivot_longer(-1,names_to="country",values_to='surplus_rate')|> dplyr::filter(!is.na('surplus_rate'))

txexp_eur2 <- cbind(year = 1995:2014,
                   as_tibble(
                     sea_countries["wiodr16",,"surplus_value.emp.r.pc" ,eur_na_wlvd]))|>
  pivot_longer(-1,names_to="country",values_to='surplus_rate')|> 
  dplyr::filter(!is.na('surplus_rate'))

txepeurj <- txexp_eur|>left_join(txexp_eur2, by = c("year","country"))

horaseur <- 
  cbind(year=1995:2014,
        as_tibble(
        sea_countries["wiodr13",,"abstract_labour.emp.m.mv",eur_na_wlvd]
        ))|>  pivot_longer(-1,names_to="country",values_to='abstract_labourtime')
  
horaseur2 <- 
  cbind(year=1995:2014,
        as_tibble(
          sea_countries["wiodr16",,"abstract_labour.emp.m.mv",eur_na_wlvd]
        ))|>  pivot_longer(-1,names_to="country",values_to='abstract_labourtime')


heurj <- horaseur|>left_join(horaseur2, by = c("year","country"))

eurj <- txepeurj|>left_join(heurj) 

eurj <- eurj|>group_by(year)|>
  summarize(regional_surplus_rate_wiod13 = weighted.mean(surplus_rate.x,abstract_labourtime.x,na.rm=T),
            regional_surplus_rate_wiod16 = weighted.mean(surplus_rate.y,abstract_labourtime.y,na.rm=T))
  
names(eurj)[2:3] <- c("wiod13","wiod16")

eurj$country <- "EUROPE"

tx_conjunto <- tx_exp_junto|>bind_rows(eurj)
ggplot(tx_conjunto,aes(x=year,y=wiod13,col=country))+scale_y_continuous(labels=scales::label_percent())+
  geom_smooth(linetype="dashed",se=F)+geom_smooth(aes(y=wiod16),se=F)+theme_minimal()+
  labs(x="Ano",y="taxa de exploração",col="País")


####Setor de Saúde
tx_exp_ps <- 
  cbind(year = 1995:2014,
        as_tibble(
          sea_sectors["wiodr13",,"surplus_value.emp.r.pc","N",country_selection]))%>%pivot_longer(-1,names_to="country",values_to='surplus_rate')|> 
  dplyr::filter(!is.na('surplus_rate'))

tx_exp_ps2 <- 
  cbind(year = 1995:2014,
        as_tibble(
          sea_sectors["wiodr16",,"surplus_value.emp.r.pc","Q",country_selection]))%>%pivot_longer(-1,names_to="country",values_to='surplus_rate')|> 
  dplyr::filter(!is.na('surplus_rate'))

tx_exp_juntos <- tx_exp_ps|>left_join(tx_exp_ps2, by = c("year","country"))
names(tx_exp_juntos)[3:4] <- c("wiod13","wiod16")



txexp_eurs <- cbind(year = 1995:2014,
                   as_tibble(
                     sea_sectors["wiodr13",,"surplus_value.emp.r.pc","N" ,eur_na_wlvd]))|>
  pivot_longer(-1,names_to="country",values_to='surplus_rate')|> dplyr::filter(!is.na('surplus_rate'))

txexp_eurs2 <- cbind(year = 1995:2014,
                    as_tibble(
                      sea_sectors["wiodr16",,"surplus_value.emp.r.pc" ,"Q",eur_na_wlvd]))|>
  pivot_longer(-1,names_to="country",values_to='surplus_rate')|> 
  dplyr::filter(!is.na('surplus_rate'))

txepeurjs <- txexp_eurs|>left_join(txexp_eurs2, by = c("year","country"))

horaseurs <- 
  cbind(year=1995:2014,
        as_tibble(
          sea_sectors["wiodr13",,"abstract_labour.emp.m.mv","N",eur_na_wlvd]
        ))|>  pivot_longer(-1,names_to="country",values_to='abstract_labourtime')

horaseur2s <- 
  cbind(year=1995:2014,
        as_tibble(
          sea_sectors["wiodr16",,"abstract_labour.emp.m.mv","Q",eur_na_wlvd]
        ))|>  pivot_longer(-1,names_to="country",values_to='abstract_labourtime')


heurjs <- horaseurs|>left_join(horaseur2s, by = c("year","country"))

eurjs <- txepeurjs|>left_join(heurjs) 

eurjs <- eurjs|>group_by(year)|>
  summarize(regional_surplus_rate_wiod13 = weighted.mean(surplus_rate.x,abstract_labourtime.x,na.rm=T),
            regional_surplus_rate_wiod16 = weighted.mean(surplus_rate.y,abstract_labourtime.y,na.rm=T))

names(eurjs)[2:3] <- c("wiod13","wiod16")

eurjs$country <- "EUROPE"

tx_conjuntos <- tx_exp_juntos|>bind_rows(eurjs)
ggplot(tx_conjuntos,aes(x=year,y=wiod13,col=country))+scale_y_continuous(labels=scales::label_percent())+
  geom_smooth(linetype="dashed",se=F)+geom_smooth(aes(y=wiod16),se=F)+theme_minimal()+
  labs(x="Ano",y="taxa de exploração",col="País")+
  theme(legend.position="bottom")

###Transferëncia de valor
# transferëncias % PIB em valor
# indtr <- "trade_transfers.p.m.pc"
# transferencia em horas de trab abstrato só setores produtivos
#indtr <- "trade_transfers.p.s.mv"
# Transferencia em horas de trabalho abstrato todos
indtr <- "trade_transfers.s.mv"

tr_exp_p <- 
  cbind(year = 1995:2014,
        as_tibble(
          sea_countries["wiodr13",,indtr ,pm]))%>%pivot_longer(-1,names_to="country",values_to='trade_transfers')|> 
  dplyr::filter(!is.na('trade_transfers'))

tr_exp_p2 <- 
  cbind(year = 1995:2014,
        as_tibble(
          sea_countries["wiodr16",,indtr,pm]))|>
  pivot_longer(-1,names_to="country",values_to='trade_transfers')|> dplyr::filter(!is.na('trade_transfers'))

tr_exp_junto <- tr_exp_p|>left_join(tr_exp_p2, by = c("year","country"))
names(tr_exp_junto)[3:4] <- c("wiod13","wiod16")



transf_eurs <- cbind(year = 1995:2014,
                     as_tibble(
                       sea_sectors["wiodr13",,indtr,"N" ,eur_na_wlvd]))|>
  pivot_longer(-1,names_to="country",values_to='trade_transfers')|> dplyr::filter(!is.na(trade_transfers))

transf_eurs2 <- cbind(year = 1995:2014,
                      as_tibble(
                        sea_sectors["wiodr16",,indtr ,"Q",eur_na_wlvd]))|>
  pivot_longer(-1,names_to="country",values_to="trade_transfers")|> 
  dplyr::filter(!is.na(trade_transfers))

traneurjs <- transf_eurs|>left_join(transf_eurs2, by = c("year","country"))



eurtjs <- traneurjs|>left_join(heurjs) 

eurtjs <- eurtjs|>group_by(year)|>
  summarize(sectoral_transfer_wiod13 = weighted.mean(trade_transfers.x,abstract_labourtime.x,na.rm=T),
            sectoral_transfer_regional_surplus_rate_wiod16 = weighted.mean(trade_transfers.y,abstract_labourtime.y,na.rm=T))

names(eurtjs)[2:3] <- c("wiod13","wiod16")

eurtjs$country <- "EUROPE"


tr_conjuntos <- tr_exp_junto|>bind_rows(eurtjs)
tr_conjuntos <- tr_conjuntos|> mutate(across(contains("wiod"),\(x){x/(2*1e9)}))

##Tira JPN e USA separado
tr_conjuntos<- tr_conjuntos|>mutate(graf=ifelse(country %in% c("JPN","USA"),"Japão/EUA","Demais"))

ggplot(tr_conjuntos,aes(x=year,y=wiod13,col=country))+
#  scale_y_continuous(labels=scales::label_percent())+
  geom_smooth(linetype="dashed",se=F)+geom_smooth(aes(y=wiod16),se=F)+theme_minimal()+
  labs(x="Ano",y="transferência de valor \n(Milhões de trabalhadores/ano*)",col="País")+
  theme(legend.position="bottom")+
  facet_wrap(vars(graf),ncol=2,scales="free_y")

###Transferências de valor setor
#SETORES DO CEIS
# ceis <- c("C20","C21","C26", "C28")
ceis16 <- c("C20","C21","C25","C26", "C28")
ceis13 <- c("24","29","30t33")
ceis <- c(ceis13,ceis16)

trss <- as_tibble(apply(sea_sectors["wiodr13",,indtr,ceis,country_selection],3,\(x){rowSums(x,na.rm=T)/(2*1e9)}))
trss$ano <- 1995:2014
trss <- trss|>
  pivot_longer(-5, names_to="país",values_to="transferencias_totais")

trss2 <- as_tibble(apply(sea_sectors["wiodr16",,indtr,ceis,country_selection],3,\(x){rowSums(x,na.rm=T)/(2*1e9)}))
trss2$ano <- 1995:2014
trss2 <- trss2|>
  pivot_longer(-5, names_to="país",values_to="transferencias_totais")


trssj <- trss|>left_join(trss2,by=c("ano","país"))

names(trssj)[3:4] <- c("W13","W16")


##CEIS EUROPA
trsseur <- as_tibble(apply(sea_sectors["wiodr13",,indtr,ceis,eur_na_wlvd],3,\(x){rowSums(x,na.rm=T)/(2*1e9)}))
trsseur <- rowSums(trsseur,na.rm=T)
trsseur <- data.frame(ano = 1995:2014,europa = trsseur)

trsseur2 <- as_tibble(apply(sea_sectors["wiodr16",,indtr,ceis,eur_na_wlvd],3,\(x){rowSums(x,na.rm=T)/(2*1e9)}))
trsseur2 <- rowSums(trsseur2,na.rm=T)
trsseur2 <- data.frame(ano = 1995:2014,europa = trsseur2)


trsseurj <- trsseur|>left_join(trsseur2,by=c("ano"))

names(trsseurj)[2:3] <- c("W13","W16")

trsseurj <- trsseurj |>
  mutate(país="EUROPE")

trssceis <- bind_rows(trssj,trsseurj)

trssceis <- arrange(trssceis,ano,país)

trssceis <- trssceis|> mutate(graf=ifelse(país %in% c("BRA","MEX"),"Dependentes","Imperialistas"))

trssceis[trssceis==0] <- NA
ggplot(trssceis,aes(x=ano,y=W13,col=país))+
  #  scale_y_continuous(labels=scales::label_percent())+
  geom_smooth(linetype="dashed",se=F)+geom_smooth(aes(y=W16),se=F)+theme_minimal()+
  labs(x="Ano",y="transferência de valor \n(Milhões de trabalhadores/ano*)",col="País")+
  theme(legend.position="bottom")+
  facet_wrap(vars(graf),ncol=2,scales="free_y")





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

