
## Este script salva as distribuições do capital e as taxas de
## depreciação para todos os anos

## This script saves sectoral capital distributions and
## depreciation rates for all needed years

# download euklems ----

# capital stocks data
download.file(
  "http://euklems.eu/bulk/Statistical_Capital.rds",
  "source_data/euklems/euklems.rds")

# national accounts (only to use value added information, needed for
# disaggregation purposes)
download.file(
  "http://euklems.eu/bulk/Statistical_National-Accounts.rds",
  "source_data/euklems/euklems-na.rds")

# prepare data ----
euklems <- readRDS("source_data/euklems/euklems.rds")
euklems.na <- readRDS("source_data/euklems/euklems-na.rds")

# depreciation rate: obtained in EUKLEMS documentation
dep.rates <- 
  as.data.frame(read.csv2("source_data/euklems/dep_rates.csv", header = TRUE))

# load aggregation/harmonization data 
# needed to harmonize euklems and WIOD 
# capital goods and sectors 
agg <-
  read.csv2("source_data/euklems/aggregation.csv")

for (year in as.character(1995:2009)) {
  print(paste0("Obtaining capital composition data to the year ",year,"..."))

  # assign variables
  lists <- NULL
  lists$countries <- unique(euklems[,1])
  lists$sectors <- unique(euklems[,6])
  lists$ek_variables <- c("K_GFCF",
                          "K_IT",
                          "K_CT",
                          "K_Soft_DB",
                          "K_TraEq",
                          "K_OMach",
                          "K_OCon",
                          "K_RStruc",
                          "K_OIPP",
                          "K_Cult",
                          "K_RD")
  
  nums <- NULL
  nums$countries <- length(lists$countries)
  nums$sectors <- length(lists$sectors)
  nums$ek_variables <-length(lists$ek_variables)

  ek.k <- data.frame(country = 
                       (lists$countries %>%
                          rep(each = nums$sectors)))
  ek.k$sector <- lists$sectors
  ek.va = ek.dep.rate <- ek.k
  
  # select data ----
  # extract Value Added and depreciation rate information
  ek.va$va <- 
    left_join(
      ek.va,
      euklems.na[which(euklems.na[,3]=="VA" & euklems.na[,7]==year),c(1,6,8)],
      by = c("country", "sector" = "code")
    )[,3]
  
  ek.dep.rate <- 
    left_join(ek.dep.rate,
              dep.rates, 
              by = c("sector" = "code"))
  
  # select capital information from source
  for (x in lists$ek_variables) {
    ek.k$temp <- 
      left_join(
        ek.k,
        euklems[which(euklems$var==x & euklems$year==year),c(1,6,8)],
        by = c("country", "sector" = "code")
      )[,"value"]
    names(ek.k)[names(ek.k) == "temp"] <- x
  }
  ek.k$control <- ek.k$K_GFCF
  
  ### excluding countries without full information
  ek.k$sum <- rowSums(ek.k[,lists$ek_variables], na.rm = FALSE)
  countries_to_exclude <- (ek.k[ek.k$sector=="TOT_IND" & is.na(ek.k$sum),1])
  
  # These two countries don't have data about all sectors
  countries_to_exclude <- c(as.character(countries_to_exclude), "LU", "SE")
  
  # excluding...
  ek.k <- 
    ek.k[!(ek.k$country %in% countries_to_exclude),]
  
  ek.dep.rate <-  
    ek.dep.rate[!(ek.dep.rate$country %in% countries_to_exclude),]
  
  ek.va <-  
    ek.va[!(ek.va$country %in% countries_to_exclude),]
  
  # disaggregate ----
  
  # data that are available only in aggregated level are disaggregated 
  # by the proportion of value added. So, the first step is to obtain 
  # VA proportion of these sectors.
  # There are two levels of aggregation. "prop" is the broader one.
  ek.va$prop <- 0
  ek.va$prop2 <- 0

  for (x in unique(agg[agg$level=="prop",2])) {
    sectors <- unique(agg$disaggregated[agg$aggregated==x])
    ek.va$prop[ek.va$sector %in% sectors] <-
      ek.va$va[ek.va$sector %in% sectors] / 
      rep(ek.va$va[ek.va$sector==x], each = length(sectors))
  }
  
  for (x in unique(agg[agg$level=="prop2",2])) {
    sectors <- unique(agg$disaggregated[agg$aggregated==x])
    ek.va$prop2[ek.va$sector %in% sectors] <-
      ek.va$va[ek.va$sector %in% sectors] / 
      rep(ek.va$va[ek.va$sector==x], each = length(sectors))
  }
  
  ek.va.prop <- 
    do.call("cbind", replicate(nums$ek_variables, ek.va$prop, simplify=FALSE))
  ek.va.prop2 <- 
    do.call("cbind", replicate(nums$ek_variables, ek.va$prop2, simplify=FALSE))
  
  # second step: to disaggregate
  # first, from "prop2"
  for (x in which(agg[,3]=="prop2")) {
    filter1 <- 
      ek.k$sector==agg$disaggregated[x] &
      is.na(ek.k$sum)
    
    filter2 <- 
      ek.k$country %in% ek.k$country[filter1] &
      ek.k$sector == agg$aggregated[x]
    
    ek.k[filter1,lists$ek_variables] <-
      ek.k[filter2,lists$ek_variables] * ek.va.prop2[filter1,]
  }
  
  # (sum available data to indicates which sectors had change)
  # Altered sectors now have a sum different from NA
  # Non changed sectors will display a zero sum in this new column
  
  ek.k$sum <- rowSums(ek.k[,lists$ek_variables], na.rm = TRUE) 
  
  # second, from "prop"
  for (x in which(agg[,3]=="prop")) {
    filter1 <- 
      ek.k$sector==agg$disaggregated[x] &
      ek.k$sum==0
    
    filter2 <- 
      ek.k$country %in% ek.k$country[filter1] &
      ek.k$sector==agg$aggregated[x]
    ek.k[filter1,lists$ek_variables] <- 
      ek.k[filter2,lists$ek_variables] * ek.va.prop[filter1,]
  }

  # reaggregating ----

  ek.k[is.na(ek.k)] <- 0

  # agreggate data when "needed"
  # Some capital goods are products of the same unique
  # sector in WIOD - so this aggregation serves
  # harmonization purposes for combining relevant data
  for (x in which(agg[,3]=="needed")) {
    filter1 <-
      ek.k$sector == agg$aggregated[x] & 
      ek.k$control == 0
    
    filter2 <- 
      ek.k$country %in% ek.k$country[filter1] &
      ek.k[,2] == agg$disaggregated[x]
    
    ek.k[filter1, lists$ek_variables] <- 
      ek.k[filter1, lists$ek_variables] + 
      ek.k[filter2, lists$ek_variables]
  }
  
  ek.k <- ek.k[,c("country", "sector", lists$ek_variables)] #eliminate columns
  
  # create "new" aggregates
  for (x in unique(agg[agg[,3]=="new",2])) {
    ek.temp <- ek.k[ek.k$sector == "TOT",]
    ek.temp$sector <- x
    ek.temp[, lists$ek_variables] <- 0
    ek.k <- rbind(ek.k, ek.temp)

    ek.dep.temp <- ek.dep.rate[ek.dep.rate$sector == "TOT",]
    ek.dep.temp$sector <- x
    ek.dep.temp[, lists$ek_variables] <- 0
    ek.dep.rate <- rbind(ek.dep.rate, ek.dep.temp)
  }
  
  for (x in which(agg[,3]=="new")) {
    filter1 <- 
      which(ek.k$sector == agg$aggregated[x])
    filter2 <- 
      which(ek.k$sector == agg$disaggregated[x])
    
    ek.k[filter1, lists$ek_variables] <- 
      ek.k[filter1, lists$ek_variables] + 
      ek.k[filter2, lists$ek_variables]
  }
  
  # depreciation rate (weighted by capital stock goods' sectoral proportions)
  
  ek.dep.rate[is.na(ek.dep.rate)] <- 0
  
  for (x in which(agg[,3] %in% c("needed", "new"))) {
    filter1 <-
      ek.k$sector == agg$aggregated[x]
    
    filter2 <- 
      ek.k$country %in% ek.k$country[filter1] &
      ek.k[,2] == agg$disaggregated[x]
    
    ek.dep.rate[filter1, lists$ek_variables] <- 
      ek.dep.rate[filter1, lists$ek_variables] +
      (ek.dep.rate[filter2, lists$ek_variables] * 
         ek.k[filter2, lists$ek_variables] /
         ek.k[filter1, lists$ek_variables])
  }

  ek.dep.rate[is.na(ek.dep.rate)] <- 0
  
  # combine ----
  # combine capital categories for harmonization with WIOD
  
  # create new columns
  for (x in unique(agg[agg[,3]=="category",2])) {
    ek.k$temp <- 0
    names(ek.k)[names(ek.k) == "temp"] <- x

    ek.dep.rate$temp <- 0
    names(ek.dep.rate)[names(ek.dep.rate) == "temp"] <- x
  }
  lists$ek_variables <- 
    c(lists$ek_variables, unique(agg[agg[,3]=="category",2]))
  nums$ek_variables <- length(lists$ek_variables)
  
  # combine capita stock data
  for (x in which(agg$level == "category")) {
    ek.k[,agg$aggregated[x]] <- 
      ek.k[,agg$aggregated[x]] +
      ek.k[,agg$disaggregated[x]]
  }

  # combine depreciation rate data (weighted by capital stock)
  for (x in which(agg$level == "category")) {
    ek.dep.rate[,agg$aggregated[x]] <- 
      ek.dep.rate[,agg$aggregated[x]] +
      (ek.dep.rate[,agg$disaggregated[x]] *
         ek.k[,agg$disaggregated[x]] /
         ek.k[,agg$aggregated[x]])
  }
  ek.dep.rate[is.na(ek.dep.rate)] <- 0
  
  # calculate proportions ----
  for (x in lists$ek_variables) {
    totals <- ek.k[ek.k$sector=="TOT",c("country", x)]
    totals <- totals[match(ek.k$country,totals$country),x]
    ek.k[,x] <- ek.k[,x]/totals
  }
  
  ## include "mean country" ("MD")
  ## Started by copying any arbitrary country,
  ## Afterwards, it is recalculated by averaging all available
  ## countries  
  ek.k.md <- ek.k[ek.k$country=="AT",]
  ek.k.md$country <- "MD"
  ek.dep.rate.md <- ek.k.md
  
  for (x in lists$ek_variables) {
    ek.k.md[,x] <-
      tapply(ek.k[,x], match(ek.k[,2], ek.k.md[,2]), mean, na.rm = TRUE)
    ek.dep.rate.md[,x] <- 
      tapply(ek.dep.rate[,x], match(ek.dep.rate[,2], ek.dep.rate.md[,2]),
             mean, na.rm = TRUE)
  }
  
  ek.k <- rbind(ek.k, ek.k.md)
  ek.dep.rate <- rbind(ek.dep.rate, ek.dep.rate.md)
  
  saveRDS(ek.k, paste0("source_data/euklems/ekk_",year,".rds"))
  saveRDS(ek.dep.rate, paste0("source_data/euklems/ekdeprate_",year,".rds"))
}

# clear variables and data ----

file.remove(
  "source_data/euklems/euklems.rds",
  "source_data/euklems/euklems-na.rds")

rm(agg, dep.rates, ek.dep.rate, ek.dep.rate.md, ek.dep.temp, ek.k, ek.k.md,
   ek.va, ek.va.prop, ek.va.prop2, ek.temp, euklems, euklems.na, lists, nums,
   countries_to_exclude, filter1, filter2, sectors, totals, x)

gc()
