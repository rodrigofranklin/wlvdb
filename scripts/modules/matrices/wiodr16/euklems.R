####
#
# Calculates the capital depreciation matrix.
# - Distributes the capital stock
# - Apply depreciation rates
#
####

if (!exists("wlv_wiodr16_allocate_capital", mode = "function")) {
  source("scripts/lib/wiodr16_allocation.R")
}
if (!exists("wlv_wiodr_sanitize_negative_gfcf", mode = "function")) {
  source("scripts/lib/gfcf_contracts.R")
}
if (!exists("wlv_gfcf_diagnostic_artifacts", mode = "function")) {
  source("scripts/lib/gfcf_diagnostics.R")
}

## Distribute capital stock from EUKLEMS data

# temporary matrices for depreciation rate and capital composition
dep_ratio = k_composition <- matrix(1, nrow = nums$input, 
                                        ncol = nums$input)

gfcf_columns <- wlv_wiodr16_gfcf_columns(
  columns$country_sector,
  lists$countries
)
gfcf_by_country <- wlv_wiodr_sanitize_negative_gfcf(
  m_io_source[
    lists$years,
    seq_len(nums$input),
    gfcf_columns,
    drop = FALSE
  ],
  method = "wiodr16"
)
truncated_gfcf <- attr(gfcf_by_country, "wlv.truncated_negative_gfcf")
gfcf_diagnostic_observations <- if (
  exists("wlv_canonical_gfcf_observations", inherits = FALSE) &&
  !is.null(wlv_canonical_gfcf_observations)
) {
  wlv_canonical_gfcf_observations
} else {
  truncated_gfcf
}
gfcf_diagnostic_input_unit <- if (
  identical(gfcf_diagnostic_observations, truncated_gfcf)
) {
  "usd"
} else {
  "million_usd"
}
wlv_scientific_diagnostics <- wlv_gfcf_diagnostic_artifacts(
  gfcf_diagnostic_observations,
  method = "wiodr16",
  input_unit = gfcf_diagnostic_input_unit
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
    module = "wiodr16/euklems.R",
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
      wlv_wiodr16_euklems_country_codes(lists$countries),
      each = nums$sectors
    )
  rows$pwiod_sek <- paste0(rows$country, rows$s_ek)

  # Load data ----
  # ek_k -> distribution ratio of each type of capital across all sectors
  # ek_dep_rate -> depreciation ratio of each type of capital in each sector
  ek_k <- fst::read_fst(paste0("source_data/euklems/ekk_", year, ".fst"))
  ek_dep_rate <- fst::read_fst(paste0(
    "source_data/euklems/ekdeprate_",
    as.character(as.numeric(year) + 1),
    ".fst"
  ))
  ek_k <- wlv_wiodr16_sanitize_euklems_weights(ek_k, year)
  truncated_euklems_weights <-
    attr(ek_k, "wlv.truncated_negative_weights")
  if (
    nrow(truncated_euklems_weights) &&
    exists("wlv_contract_runtime", inherits = FALSE)
  ) {
    wlv_record_observed_transformations(
      wlv_contract_runtime,
      truncated_euklems_weights,
      artifact = "m_io",
      indicator = "euklems_capital_weight",
      checkpoint = "after_matrices",
      stage = 3L,
      module = "wiodr16/euklems.R",
      coordinate_columns = c(
        year = "year", country = "country", sector = "sector",
        output = "variable"
      )
    )
  }

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
  disaggregation_numerator <- as.numeric(sea_sectors[year, "gdp.s.us", , ])
  disaggregation_denominator <- aggregates[rows$pwiod_sek]
  raw_disaggregation_ratio <-
    disaggregation_numerator / disaggregation_denominator
  disaggregation_ratio <- wlv_wiodr16_sanitize_va_ratios(
    raw_disaggregation_ratio,
    year,
    lists$input,
    numerator = disaggregation_numerator,
    denominator = disaggregation_denominator
  )
  absolute_va_ratios <- attr(disaggregation_ratio, "wlv.absolute_va_ratios")
  if (
    nrow(absolute_va_ratios) &&
    exists("wlv_contract_runtime", inherits = FALSE)
  ) {
    wlv_record_observed_transformations(
      wlv_contract_runtime,
      absolute_va_ratios,
      artifact = "m_io",
      indicator = "value_added_disaggregation_ratio",
      checkpoint = "after_matrices",
      stage = 3L,
      module = "wiodr16/euklems.R",
      coordinate_columns = c(
        year = "year", country = "country", sector = "sector"
      )
    )
  }
  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    zero_positions <- attr(disaggregation_ratio, "wlv.zero_va_ratios")
    if (length(zero_positions)) {
      ratio_array <- array(
        raw_disaggregation_ratio,
        dim = c(1L, length(raw_disaggregation_ratio)),
        dimnames = list(year, lists$input)
      )
      failed <- array(FALSE, dim = dim(ratio_array), dimnames = dimnames(ratio_array))
      failed[1L, zero_positions] <- TRUE
      ratio_context <- wlv_contract_context_for(
        wlv_contract_runtime,
        artifact = "m_io",
        indicator = "value_added_disaggregation_ratio",
        checkpoint = "after_matrices",
        stage = 3L,
        module = "wiodr16/euklems.R",
        axes = c(year = 1L, sector = 2L),
        policy_id = "wiodr16_va_zero_aggregate_v1"
      )
      wlv_contract_record(
        wlv_contract_runtime,
        wlv_contract_table(
          ratio_array,
          failed,
          ratio_context,
          "replace_both_zero_with_zero"
        )
      )
    }
  }
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
  gfcf_year <- gfcf_by_country[year, , , drop = FALSE]
  dim(gfcf_year) <- c(nums$input, nums$countries)
  gfcf <- gfcf_year[
    , rep(seq_len(nums$countries), each = nums$sectors), drop = FALSE
  ]
  
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
    if (exists("wlv_contract_runtime", inherits = FALSE)) {
      stock_values <- array(
        as.numeric(sea_sectors[year, "capital_stock.s.us", , ]),
        dim = c(1L, nums$input),
        dimnames = list(year, lists$input)
      )
      fallback_mask <- array(
        lists$input %in% fallback_columns$input,
        dim = dim(stock_values),
        dimnames = dimnames(stock_values)
      )
      fallback_context <- wlv_contract_context_for(
        wlv_contract_runtime,
        artifact = "m_io",
        indicator = "k_composition",
        checkpoint = "after_matrices",
        stage = 3L,
        module = "wiodr16/euklems.R",
        axes = c(year = 1L, output = 2L),
        policy_id = "wiodr16_national_gfcf_fallback_v1"
      )
      wlv_contract_record(
        wlv_contract_runtime,
        wlv_contract_table(
          stock_values,
          fallback_mask,
          fallback_context,
          "fallback_to_national_gfcf_weights"
        )
      )
    }
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
  disaggregation_ratio, disaggregation_numerator, disaggregation_denominator,
  raw_disaggregation_ratio, fallback_columns, gfcf, gfcf_year,
  gfcf_by_country, gfcf_columns, truncated_gfcf,
  gfcf_diagnostic_observations, gfcf_diagnostic_input_unit
)
rm(list = intersect(
  c(
    "zero_positions", "ratio_array", "failed", "ratio_context",
    "stock_values", "fallback_mask", "fallback_context",
    "truncated_euklems_weights", "absolute_va_ratios"
  ),
  ls(envir = environment(), all.names = TRUE)
), envir = environment())
