
## Este script salva as distribuições do capital e as taxas de
## depreciação para todos os anos

## This script saves sectoral capital distributions and
## depreciation rates for all needed years

# download euklems ----

if (!exists("wlv_download_verified", mode = "function", inherits = FALSE)) {
  sys.source("R/utils/preparation_downloads.R", envir = environment())
}
if (!exists(
  "wlv_add_synthetic_depreciation_component",
  mode = "function",
  inherits = FALSE
)) {
  sys.source("R/lib/functions.R", envir = environment())
}

dir.create("source_data", recursive = TRUE, showWarnings = FALSE)
dir.create("source_data/euklems", recursive = TRUE, showWarnings = FALSE)
if (!dir.exists("source_data/euklems")) {
  stop("Cannot create EU KLEMS source-data directory.", call. = FALSE)
}

euklems_download_manifest <- list(
  capital = list(
    url = "https://euklems.eu/bulk/Statistical_Capital.rds",
    destination = "source_data/euklems/Statistical_Capital.rds",
    size = 129637707,
    hash_algorithm = "sha256",
    hash = "77bf752a4c79c0e324e6be31164e8f27fdc100c89b08f68c3a227da7c7ab3b44"
  ),
  national_accounts = list(
    url = "https://euklems.eu/bulk/Statistical_National-Accounts.rds",
    destination = "source_data/euklems/Statistical_National-Accounts.rds",
    size = 44200266,
    hash_algorithm = "sha256",
    hash = "c6f7b65eb263839ea824fe223a8cf5fc13fad444db5b7a857b6aa01b29d0a4f2"
  )
)

capital_manifest <- euklems_download_manifest$capital
wlv_download_verified(
  url = capital_manifest$url,
  destination = capital_manifest$destination,
  expected_size = capital_manifest$size,
  expected_hash = capital_manifest$hash,
  hash_algorithm = capital_manifest$hash_algorithm
)

national_accounts_manifest <- euklems_download_manifest$national_accounts
wlv_download_verified(
  url = national_accounts_manifest$url,
  destination = national_accounts_manifest$destination,
  expected_size = national_accounts_manifest$size,
  expected_hash = national_accounts_manifest$hash,
  hash_algorithm = national_accounts_manifest$hash_algorithm
)

# prepare data ----
euklems <- readRDS(capital_manifest$destination)
euklems.na <- readRDS(national_accounts_manifest$destination)

wlv_assert_euklems_table <- function(value, label) {
  required_columns <- c("country", "code", "var", "year", "value")
  if (!is.data.frame(value) || !nrow(value)) {
    stop(sprintf("%s is not a non-empty data frame.", label), call. = FALSE)
  }
  missing <- setdiff(required_columns, names(value))
  if (length(missing)) {
    stop(
      sprintf("%s lacks columns: %s", label, paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
  invisible(TRUE)
}
wlv_assert_euklems_table(euklems, "EU KLEMS capital data")
wlv_assert_euklems_table(euklems.na, "EU KLEMS national-accounts data")

wlv_normalize_euklems_years <- function(value) {
  if (
    !(is.character(value) || is.numeric(value)) ||
    !length(value) ||
    anyNA(value)
  ) {
    stop(
      "`wlv_euklems_years` must be a non-empty vector of integer years.",
      call. = FALSE
    )
  }
  character_years <- as.character(value)
  numeric_years <- suppressWarnings(as.integer(character_years))
  if (
    anyNA(numeric_years) ||
    any(as.character(numeric_years) != character_years) ||
    anyDuplicated(numeric_years)
  ) {
    stop(
      "`wlv_euklems_years` must contain unique integer years in canonical form.",
      call. = FALSE
    )
  }
  as.character(numeric_years)
}

requested_euklems_years <- if (
    exists("wlv_euklems_years", inherits = FALSE)
  ) {
  get("wlv_euklems_years", inherits = FALSE)
} else {
  1995:2010
}
requested_euklems_years <- wlv_normalize_euklems_years(
  requested_euklems_years
)

capital_years <- unique(as.character(euklems$year))
national_accounts_years <- unique(as.character(euklems.na$year))
missing_capital_years <- setdiff(requested_euklems_years, capital_years)
missing_national_accounts_years <- setdiff(
  requested_euklems_years,
  national_accounts_years
)
if (length(missing_capital_years) || length(missing_national_accounts_years)) {
  stop(
    sprintf(
      paste0(
        "EU KLEMS does not cover every requested year; capital missing: %s; ",
        "national accounts missing: %s."
      ),
      if (length(missing_capital_years)) {
        paste(missing_capital_years, collapse = ", ")
      } else {
        "none"
      },
      if (length(missing_national_accounts_years)) {
        paste(missing_national_accounts_years, collapse = ", ")
      } else {
        "none"
      }
    ),
    call. = FALSE
  )
}

# depreciation rate: obtained in EUKLEMS documentation
dep.rates <- 
  as.data.frame(read.csv2("complementar/euklems/dep_rates.csv", header = TRUE))

# load aggregation/harmonization data 
# needed to harmonize euklems and WIOD 
# capital goods and sectors 
agg <-
  read.csv2("complementar/euklems/aggregation.csv")

for (year in requested_euklems_years) {
  print(paste0("Obtaining capital composition data to the year ",year,"..."))
  
  # assign variables
  lists <- NULL
  lists$countries <- as.character(unlist(unique(euklems$country)))
  lists$sectors <- as.character(unlist(unique(euklems$code)))
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
  
  ek.k <- data.frame(country = rep(lists$countries, each = nums$sectors))
  ek.k$sector <- lists$sectors
  ek.va = ek.dep.rate <- ek.k
  
  # select data ----
  # extract Value Added and depreciation rate information
  filter.na <- (euklems.na$var=="VA") & (euklems.na$year==as.numeric(year))
  ek.va$va <- dplyr::left_join(
    ek.va,
    euklems.na[filter.na,],
    by = c("country", "sector" = "code")
  )$value
  
  ek.dep.rate <- 
    dplyr::left_join(
      ek.dep.rate,
      dep.rates,
      by = c("sector" = "code")
    )
  
  # select capital information from source
  for (x in lists$ek_variables) {
    filter.ek <- euklems$var == x & euklems$year == as.numeric(year)
    ek.k$temp <- 
      dplyr::left_join(
        ek.k,
        euklems[filter.ek,],
        by = c("country", "sector" = "code")
      )$value
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
    # `NA` records that this aggregate has no direct depreciation rate. It is
    # synthesized from its components below; an explicit direct rate must win.
    ek.dep.temp[, lists$ek_variables] <- NA_real_
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

  direct_dep_rate_provided <- !is.na(as.matrix(
    ek.dep.rate[, lists$ek_variables, drop = FALSE]
  ))
  ek.dep.rate[is.na(ek.dep.rate)] <- 0
  
  for (x in which(agg[,3] %in% c("needed", "new"))) {
    filter1 <-
      ek.k$sector == agg$aggregated[x]
    
    filter2 <- 
      ek.k$country %in% ek.k$country[filter1] &
      ek.k[,2] == agg$disaggregated[x]
    
    ek.dep.rate[filter1, lists$ek_variables] <-
      wlv_add_synthetic_depreciation_component(
        aggregate_rate = as.matrix(
          ek.dep.rate[filter1, lists$ek_variables, drop = FALSE]
        ),
        component_rate = as.matrix(
          ek.dep.rate[filter2, lists$ek_variables, drop = FALSE]
        ),
        component_stock = as.matrix(
          ek.k[filter2, lists$ek_variables, drop = FALSE]
        ),
        aggregate_stock = as.matrix(
          ek.k[filter1, lists$ek_variables, drop = FALSE]
        ),
        direct_rate_provided = direct_dep_rate_provided[
          filter1,
          ,
          drop = FALSE
        ]
      )
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
  
  wlv_write_fst_atomic(
    ek.k,
    paste0("source_data/euklems/ekk_", year, ".fst"),
    writer = fst::write_fst
  )
  wlv_write_fst_atomic(
    ek.dep.rate,
    paste0("source_data/euklems/ekdeprate_", year, ".fst"),
    writer = fst::write_fst
  )
}

# clear variables and data ----

# file.remove(
#   "source_data/euklems/Statistical_Capital.rds",
#   "source_data/euklems/Statistical_National-Accounts.rds")

rm(agg, dep.rates, ek.dep.rate, ek.dep.rate.md, ek.dep.temp, ek.k, ek.k.md,
   ek.va, ek.va.prop, ek.va.prop2, ek.temp, euklems, euklems.na, lists, nums,
   countries_to_exclude, filter1, filter2, sectors, totals, x, filter.na, 
   filter.ek, capital_manifest, national_accounts_manifest,
   euklems_download_manifest, wlv_assert_euklems_table,
   wlv_normalize_euklems_years, requested_euklems_years,
   capital_years, national_accounts_years, missing_capital_years,
   missing_national_accounts_years, direct_dep_rate_provided)

gc()
