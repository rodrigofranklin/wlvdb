####
#
# Calculates the capital depreciation matrix.
# - Distributes the capital stock
# - Apply depreciation rates
#
####

if (!exists("wlv_wiodr16_allocate_capital", mode = "function")) {
  source("R/lib/wiodr16_allocation.R")
}

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
    rep(
      wlv_wiodr16_euklems_country_codes(lists$countries),
      each = nums$sectors
    )
  rows$pwiod_sek <- paste0(rows$country, rows$s_ek)

  # Load data ----
  # ek_k -> distribution ratio of each type of capital across all sectors
  # ek_dep_rate -> depreciation ratio of each type of capital in each sector
  ek_k <- read_fst_array(paste0("source_data/euklems/ekk_",year,".fst"))
  ek_dep_rate <- read_fst_array(paste0("source_data/euklems/ekdeprate_",
                              as.character(as.numeric(year)+1),".fst"))
  ek_k <- wlv_wiodr16_sanitize_euklems_weights(ek_k, year)

  # Countries that do not have data in the EUKLEMS database will be averaged
  rows[!(rows$p_ek %in% unique(ek_k$country)),"p_ek"] <- "MD" 
  rows$ps_ek <- paste0(rows$p_ek, rows$s_ek)
  ek_k$ps <- paste0(ek_k$country, ek_k$sector)
  ek_dep_rate$ps <- paste0(ek_dep_rate$country, ek_dep_rate$sector)
  
  # disaggregation factor: disaggregates EUKLEMS capitals data by value
  # added from WIOD.
  # aggregates -> sum of WIOD VA representing a single sector in EUKLEMS
  aggregates <- tapply(as.numeric(sea_sectors[year,"gdp.s.us", ,]), 
                      rows$pwiod_sek, sum, na.rm = FALSE)
  disaggregation_ratio <-
    as.numeric(sea_sectors[year, "gdp.s.us", , ]) /
    aggregates[rows$pwiod_sek]
  disaggregation_ratio <- wlv_wiodr16_sanitize_va_ratios(
    disaggregation_ratio,
    year,
    lists$input
  )
  k_composition[,1:nums$input] <- 
    rep(disaggregation_ratio, each = nums$input)
  
  # disaggregate the ratio of types of k by sectors according 
  # to value added
  for (x in 1:nums$input) {
    k_composition[x,] <- 
      k_composition[x,] * 
      ek_k[match(rows$ps_ek, ek_k$ps),as.character(rows$k_ek[x])]
    
    dep_ratio[x,] <- 
      ek_dep_rate[
        match(rows$ps_ek, ek_dep_rate$ps),
        as.character(rows$k_ek[x])
      ]
  }
  
  
  ## Apply
  # Create an NxN matrix with GFCF for each country. In WIOD16, c60 is
  # the fourth final-demand category (gross fixed capital formation).
  gfcf_columns <- wlv_wiodr16_gfcf_columns(
    columns$country_sector,
    lists$countries
  )
  gfcf_by_country <- m_io_source[
    year,
    seq_len(nums$input),
    gfcf_columns,
    drop = FALSE
  ]
  dim(gfcf_by_country) <- c(nums$input, nums$countries)
  gfcf <- gfcf_by_country[
    , rep(seq_len(nums$countries), each = nums$sectors), drop = FALSE
  ]
  gfcf[gfcf<0] <- 0
  
  # First, we distribute the gfcf of each country according to 
  # the composition of capital in the euklems 
  k_composition <- k_composition * gfcf 
  
  # then we distribute the capital stock by the proportions of
  # the distributed gfcf
  k_composition <- wlv_wiodr16_allocate_capital(
    weights = k_composition,
    capital_stock = as.numeric(sea_sectors[year, "capital_stock.s.us", , ]),
    fallback_weights = gfcf,
    year = year,
    input_labels = lists$input
  )
  fallback_columns <- attr(k_composition, "wlv.gfcf_fallbacks")
  if (nrow(fallback_columns)) {
    message(sprintf(
      paste0(
        "Used the explicit national-GFCF fallback for %s positive-stock ",
        "sector(s) without EU KLEMS weights in %s: %s"
      ),
      nrow(fallback_columns),
      year,
      paste(utils::head(fallback_columns$input, 6L), collapse = ", ")
    ))
  }
  attr(k_composition, "wlv.gfcf_fallbacks") <- NULL
  
  m_io[year,"k_composition",
       1:nums$input,1:nums$input] <- 
    k_composition
  
  #Applying depreciation rates to total capital
  m_io[year,"k_depreciation",
       1:nums$input,1:nums$input] <- 
    k_composition * dep_ratio
}

# clear temporary variables
rm(
  dep_ratio, k_composition, ek_k, ek_dep_rate, aggregates,
  disaggregation_ratio, fallback_columns, gfcf, gfcf_by_country, gfcf_columns
)
