# Calculates national values using explicit aggregation contracts. Missing
# source components are propagated to an all-missing country and are excluded
# only under the declared `available` policy for partial/world aggregates.
for (loop in grep(".R", sea_variables$country_solution, invert = TRUE)) {
  indicator <- sea_variables$names[loop]
  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    wlv_contract_clear_states(wlv_contract_runtime, "sea_countries", indicator)
  }
  operation <- sea_variables$country_solution[loop]
  cat("Aggregating by ", operation, " variable ", indicator, "... \n", sep = "")

  sector_value <- sea_sectors[, indicator, , , drop = FALSE]
  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    sector_states <- wlv_contract_declared_states(
      wlv_contract_runtime,
      "sea_sectors",
      indicator,
      sector_value,
      "after_country_aggregation"
    )
    country_value <- wlv_contract_aggregate_runtime(
      wlv_contract_runtime,
      sector_value,
      margin = c(1L, 4L),
      operation = operation,
      missing = "available",
      artifact = "sea_countries",
      indicator = indicator,
      checkpoint = "after_country_aggregation",
      stage = 5L,
      module = "sea_countries.R",
      axes = c(year = 1L, sector = 3L, country = 4L),
      allowed_missing = sector_states
    )
  } else {
    country_value <- aperm(
      apply(
        sea_sectors[, indicator, , ],
        1,
        tapply,
        rows$num_country,
        operation,
        na.rm = TRUE
      ),
      c(2, 1)
    )
  }
  sea_countries[, indicator, lists$countries] <- country_value

  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    country_states <- attr(country_value, "wlv_state", exact = TRUE)
    world_value <- wlv_contract_aggregate_runtime(
      wlv_contract_runtime,
      country_value,
      margin = 1L,
      operation = operation,
      missing = "available",
      artifact = "sea_countries",
      indicator = indicator,
      checkpoint = "after_world_aggregation",
      stage = 5L,
      module = "sea_countries.R",
      axes = c(year = 1L, country = 2L),
      allowed_missing = country_states
    )
    sea_countries[, indicator, "WWW"] <- world_value

    complete_states <- array(
      "finite",
      dim = dim(sea_countries[, indicator, , drop = FALSE]),
      dimnames = dimnames(sea_countries[, indicator, , drop = FALSE])
    )
    complete_states[, 1L, lists$countries] <- country_states
    complete_states[, 1L, "WWW"] <- attr(world_value, "wlv_state", exact = TRUE)
    wlv_contract_register_states(
      wlv_contract_runtime,
      "sea_countries",
      indicator,
      complete_states
    )
  } else {
    sea_countries[, indicator, "WWW"] <- apply(
      sea_countries[, indicator, lists$countries, drop = FALSE],
      1,
      operation,
      na.rm = TRUE
    )
  }
}

# Calculates indicators with dedicated country formulas.
for (loop in grep(".R", sea_variables$country_solution)) {
  indicator <- sea_variables$names[loop]
  module <- sea_variables$country_solution[loop]
  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    wlv_contract_clear_states(wlv_contract_runtime, "sea_countries", indicator)
  }
  source(paste0("R/modules/variables/", module))
  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    value <- sea_countries[, indicator, , drop = FALSE]
    wlv_assert_no_special_values(
      wlv_contract_runtime,
      value,
      artifact = "sea_countries",
      indicator = indicator,
      checkpoint = "after_country_module",
      stage = 5L,
      module = module,
      axes = c(year = 1L, country = 3L)
    )
  }
}

if (exists("wlv_contract_runtime", inherits = FALSE)) {
  wlv_validate_sea_countries_contract(
    wlv_contract_runtime,
    sea_countries,
    checkpoint = "after_country_aggregation"
  )
}

rm(list = intersect(
  c(
    "loop", "indicator", "operation", "sector_value", "sector_states",
    "country_value", "country_states", "world_value", "complete_states",
    "module", "value"
  ),
  ls(envir = environment(), all.names = TRUE)
), envir = environment())
