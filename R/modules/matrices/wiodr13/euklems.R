####
#
# Calculates the capital depreciation matrix.
# - Distributes the capital stock
# - Apply depreciation rates
#
####

## Distribute capital stock from EUKLEMS data

# temporary matrices for depreciation rate and capital composition
dep_ratio = k_composition <- matrix(1, nrow = nums$input, 
                                    ncol = nums$input)

for (year in lists$years) {
  print(paste0("Distributing capital stock. Year: ", year, "..."))
  
  # Create control variables for WIOD and EUKLEMS compatibility
  # Information obtained from the _sectors.csv file
  rows$s_ek <- sectors$euklems.sector
  rows$k_ek <- sectors$euklems.capital
  rows$p_ek <- 
    rep(ISO_3166_1$Alpha_2[match(lists$countries, ISO_3166_1$Alpha_3)],
        each=nums$sectors)
  rows$pwiod_sek <- paste0(rows$country, rows$s_ek)
  
  # Load data ----
  # ek_k -> distribution rate of each type of capital across all sectors
  # ek_dep_rate -> depreciation rate of each type of capital in each sector
  ek_k <- read_fst_array(paste0("source_data/euklems/ekk_",year,".fst"))
  ek_dep_rate <- read_fst_array(paste0("source_data/euklems/ekdeprate_",
                                       as.character(as.numeric(year)+1),".fst"))
  
  # Countries that do not have data in the EUKLEMS database will be averaged
  rows[!(rows$p_ek %in% unique(ek_k$country)),"p_ek"] <- "MD" 
  rows$ps_ek <- paste0(rows$p_ek, rows$s_ek)
  ek_k$ps <- paste0(ek_k$country, ek_k$sector)
  
  # disaggregation factor: disaggregates EUKLEMS capitals data by value
  # added from WIOD.
  # aggregates -> sum of WIOD VA representing a single sector in EUKLEMS
  aggregates <- tapply(as.numeric(sea_sectors[year,"gdp.s.us", ,]), 
                       rows$pwiod_sek, sum, na.rm = FALSE)
  k_composition[,1:nums$input] <- 
    rep(as.numeric(sea_sectors[year,"gdp.s.us", ,]) / 
          aggregates[rows$pwiod_sek], 
        each = nums$input)
  
  # disaggregate the rate of distribution of types of k by sectors according 
  # to value added
  for (x in 1:nums$input) {
    k_composition[x,] <- 
      k_composition[x,] * 
      ek_k[match(rows$ps_ek, ek_k$ps),as.character(rows$k_ek[x])]
    
    dep_ratio[x,] <- 
      ek_dep_rate[match(rows$ps_ek, ek_k$ps),as.character(rows$k_ek[x])]
  }
  
  
  ## Apply
  # creates an NxN matrix with the gfcf of each country (column "c41")
  gfcf <- 
    as.data.frame(
      m_io_source[year,1:nums$input,
                  grep("c41", columns$sector)])
  gfcf <- as.matrix(gfcf[rep(names(gfcf), each = nums$sectors)])
  gfcf[gfcf<0] <- 0
  
  # First, it distributes the gfcf of each country according to 
  # the composition of capital in the euklems 
  k_composition <- k_composition * gfcf 
  
  # then distributes the capital stock by the proportions of 
  # the distributed gfcf
  k_composition <- prop.table(k_composition, margin = 2) * 
    matrix(sea_sectors[year,"capital_stock.s.us",,], 
           nrow=nums$input, ncol=nums$input,
           byrow= TRUE)
  
  m_io[year,"k_composition",
       1:nums$input,1:nums$input] <- 
    k_composition
  
  # Apply depreciation rate to stock of capital
  m_io[year,"k_depreciation",
       1:nums$input,1:nums$input] <- 
    k_composition * dep_ratio
}

# clear temporary variables
rm (dep_ratio, k_composition, ek_k, ek_dep_rate, aggregates, gfcf)