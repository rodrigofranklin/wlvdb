# Exploitation rate of employees in productive sectors, with aligned coverage.
country_indicator <- "surplus_value.empe_p.r.pc"
productive_filter <- rep(rows$productive, each = nums$years)
ratio_numerator <-
  sea_sectors[, "abstract_labour.empe.s.mv", , ] * productive_filter
ratio_denominator <-
  sea_sectors[, "labour_force_value.s.mv", , ] * productive_filter

if (exists("wlv_contract_runtime", inherits = FALSE)) {
  country_ratio <- wlv_ratio_of_aggregates_runtime(
    wlv_contract_runtime,
    ratio_numerator,
    ratio_denominator,
    margin = c(1L, 3L),
    indicator = country_indicator,
    numerator_indicator = "abstract_labour.empe.s.mv",
    denominator_indicator = "labour_force_value.s.mv",
    checkpoint = "after_country_module",
    module = "common/surplus_value.empe_p.r.pc-country.R",
    input_axes = c(year = 1L, sector = 2L, country = 3L),
    output_axes = c(year = 1L, country = 2L)
  )
  world_ratio <- wlv_ratio_of_aggregates_runtime(
    wlv_contract_runtime,
    ratio_numerator,
    ratio_denominator,
    margin = 1L,
    indicator = country_indicator,
    numerator_indicator = "abstract_labour.empe.s.mv",
    denominator_indicator = "labour_force_value.s.mv",
    checkpoint = "after_country_module",
    module = "common/surplus_value.empe_p.r.pc-country.R",
    input_axes = c(year = 1L, sector = 2L, country = 3L),
    output_axes = c(year = 1L)
  )
} else {
  country_ratio <- aperm(
    apply(ratio_numerator, 1L, tapply, rows$num_country, sum, na.rm = TRUE),
    c(2L, 1L)
  ) / aperm(
    apply(ratio_denominator, 1L, tapply, rows$num_country, sum, na.rm = TRUE),
    c(2L, 1L)
  )
  world_ratio <- apply(ratio_numerator, 1L, sum, na.rm = TRUE) /
    apply(ratio_denominator, 1L, sum, na.rm = TRUE)
}
sea_countries[, country_indicator, lists$countries] <- country_ratio - 1
sea_countries[, country_indicator, "WWW"] <- world_ratio - 1

if (exists("wlv_contract_runtime", inherits = FALSE)) {
  complete_states <- array(
    "finite",
    dim = dim(sea_countries[, country_indicator, , drop = FALSE]),
    dimnames = dimnames(sea_countries[, country_indicator, , drop = FALSE])
  )
  complete_states[, 1L, lists$countries] <- attr(country_ratio, "wlv_state")
  complete_states[, 1L, "WWW"] <- attr(world_ratio, "wlv_state")
  wlv_contract_register_states(
    wlv_contract_runtime, "sea_countries", country_indicator, complete_states
  )
}
rm(
  country_indicator, productive_filter, ratio_numerator, ratio_denominator,
  country_ratio, world_ratio
)
rm(list = intersect(
  "complete_states",
  ls(envir = environment(), all.names = TRUE)
), envir = environment())
