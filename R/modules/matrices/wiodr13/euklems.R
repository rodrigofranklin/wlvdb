####
#
# Calculates the capital depreciation matrix.
# - Distributes the capital stock
# - Apply depreciation rates
#
####

if (!exists("wlv_wiodr_sanitize_negative_gfcf", mode = "function")) {
  source("R/lib/gfcf_contracts.R")
}
if (!exists("wlv_gfcf_diagnostic_artifacts", mode = "function")) {
  source("R/lib/gfcf_diagnostics.R")
}

## Distribute capital stock from EUKLEMS data

# temporary matrices for depreciation rate and capital composition
dep_ratio = k_composition <- matrix(1, nrow = nums$input, 
                                    ncol = nums$input)

gfcf_columns <- which(columns$sector == "c41")
gfcf_by_country <- wlv_wiodr_sanitize_negative_gfcf(
  m_io_source[
    lists$years,
    seq_len(nums$input),
    gfcf_columns,
    drop = FALSE
  ],
  method = "wiodr13"
)
truncated_gfcf <- attr(gfcf_by_country, "wlv.truncated_negative_gfcf")
wlv_scientific_diagnostics <- wlv_gfcf_diagnostic_artifacts(
  truncated_gfcf,
  method = "wiodr13",
  input_unit = "usd"
)
if (
  nrow(truncated_gfcf) &&
  exists("wlv_contract_runtime", inherits = FALSE)
) {
  wlv_record_observed_transformations(
    wlv_contract_runtime,
    truncated_gfcf,
    artifact = "m_io",
    indicator = "gross_fixed_capital_formation",
    checkpoint = "after_matrices",
    stage = 3L,
    module = "wiodr13/euklems.R",
    coordinate_columns = c(
      year = "year", country = "country", sector = "input", output = "output"
    )
  )
}

for (year in lists$years) {
  print(paste0("Distributing capital stock. Year: ", year, "..."))
  
  # Create control variables for WIOD and EUKLEMS compatibility
  # Information obtained from the _sectors.csv file
  rows$s_ek <- sectors$euklems.sector
  rows$k_ek <- sectors$euklems.capital
  rows$p_ek <-
    rep(
      wlv_wiodr13_euklems_country_codes(lists$countries),
      each = nums$sectors
    )
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
  disaggregation_numerator <- as.numeric(
    sea_sectors[year, "gdp.s.us", , ]
  )
  disaggregation_denominator <- as.numeric(aggregates[rows$pwiod_sek])
  numerator_array <- array(
    disaggregation_numerator,
    dim = c(1L, nums$input),
    dimnames = list(year, lists$input)
  )
  denominator_array <- array(
    disaggregation_denominator,
    dim = c(1L, nums$input),
    dimnames = list(year, lists$input)
  )
  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    disaggregation_ratio <- as.numeric(wlv_safe_divide_runtime(
      wlv_contract_runtime,
      numerator_array,
      denominator_array,
      zero = "zero_if_both_zero",
      artifact = "m_io",
      indicator = "value_added_disaggregation_ratio",
      checkpoint = "after_matrices",
      stage = 3L,
      module = "wiodr13/euklems.R",
      axes = c(year = 1L, sector = 2L)
    ))
  } else {
    invalid_zero <- disaggregation_denominator == 0 &
      disaggregation_numerator != 0
    if (any(invalid_zero)) {
      stop("WIOD13 value-added disaggregation has nonzero over zero.", call. = FALSE)
    }
    both_zero <- disaggregation_denominator == 0 &
      disaggregation_numerator == 0
    disaggregation_ratio <-
      disaggregation_numerator / disaggregation_denominator
    disaggregation_ratio[both_zero] <- 0
  }
  k_composition[,1:nums$input] <- 
    rep(disaggregation_ratio, each = nums$input)
  
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
  gfcf_year <- gfcf_by_country[year, , , drop = FALSE]
  dim(gfcf_year) <- c(nums$input, nums$countries)
  gfcf <- gfcf_year[
    , rep(seq_len(nums$countries), each = nums$sectors), drop = FALSE
  ]
  
  # First, it distributes the gfcf of each country according to 
  # the composition of capital in the euklems 
  k_composition <- k_composition * gfcf 
  
  # then distributes the capital stock by the proportions of 
  # the distributed gfcf
  k_composition <- wlv_distribute_capital_stock(
    k_composition,
    as.numeric(sea_sectors[year, "capital_stock.s.us", , ]),
    fallback_weights = gfcf
  )
  fallback_columns <- attr(k_composition, "wlv.fallback_columns")
  if (length(fallback_columns)) {
    message(sprintf(
      paste0(
        "Used the explicit national-GFCF fallback for %s capital-stock ",
        "sector(s) without primary weights in %s: %s"
      ),
      length(fallback_columns),
      year,
      paste(utils::head(lists$input[fallback_columns], 5L), collapse = ", ")
    ))
    if (exists("wlv_contract_runtime", inherits = FALSE)) {
      fallback_totals <- array(
        colSums(gfcf),
        dim = c(1L, ncol(gfcf)),
        dimnames = list(year, lists$input)
      )
      fallback_mask <- array(
        FALSE,
        dim = dim(fallback_totals),
        dimnames = dimnames(fallback_totals)
      )
      fallback_mask[1L, fallback_columns] <- TRUE
      fallback_context <- wlv_contract_context_for(
        wlv_contract_runtime,
        artifact = "m_io",
        indicator = "capital_stock_allocation",
        checkpoint = "after_matrices",
        stage = 3L,
        module = "wiodr13/euklems.R",
        axes = c(year = 1L, sector = 2L),
        policy_id = "wiodr13_gfcf_fallback_v1"
      )
      wlv_contract_record(
        wlv_contract_runtime,
        wlv_contract_table(
          fallback_totals,
          fallback_mask,
          fallback_context,
          "use_national_gfcf_fallback"
        )
      )
    }
  }
  attr(k_composition, "wlv.fallback_columns") <- NULL
  
  m_io[year,"k_composition",
       1:nums$input,1:nums$input] <- 
    k_composition
  
  # Apply depreciation rate to stock of capital
  m_io[year,"k_depreciation",
       1:nums$input,1:nums$input] <- 
    k_composition * dep_ratio
}

# clear temporary variables
rm(
  dep_ratio, k_composition, ek_k, ek_dep_rate, aggregates, gfcf,
  disaggregation_numerator, disaggregation_denominator,
  disaggregation_ratio, numerator_array, denominator_array,
  gfcf_year, gfcf_by_country, gfcf_columns, truncated_gfcf
)
rm(list = intersect(
  c(
    "fallback_columns", "fallback_totals", "fallback_mask", "fallback_context",
    "invalid_zero", "both_zero"
  ),
  ls(envir = environment(), all.names = TRUE)
), envir = environment())
