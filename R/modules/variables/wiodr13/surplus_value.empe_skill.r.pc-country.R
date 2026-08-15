ratio_numerator <-
  sea_sectors[, "abstract_labour.empe.s.mv", , ] *
  sea_sectors[, paste0("hours_worked.empe_", skill_code, ".r.pc"), , ]
ratio_denominator <-
  sea_sectors[, "labour_force_value.s.mv", , ] *
  sea_sectors[, paste0("compensation.empe_", skill_code, ".r.pc"), , ]

if (exists("wlv_contract_runtime", inherits = FALSE)) {
  ratio_result <- wlv_country_and_world_ratio_runtime(
    wlv_contract_runtime,
    ratio_numerator,
    ratio_denominator,
    indicator = country_indicator,
    numerator_indicator = "abstract_labour.empe.s.mv",
    denominator_indicator = "labour_force_value.s.mv",
    checkpoint = "after_country_module",
    module = paste0("wiodr13/", country_indicator, "-country.R"),
    zero = "not_applicable"
  )
  sea_countries[, country_indicator, lists$countries] <- ratio_result$country - 1
  sea_countries[, country_indicator, "WWW"] <- ratio_result$world - 1

  complete_states <- array(
    "finite",
    dim = dim(sea_countries[, country_indicator, , drop = FALSE]),
    dimnames = dimnames(sea_countries[, country_indicator, , drop = FALSE])
  )
  complete_states[, 1L, lists$countries] <- attr(ratio_result$country, "wlv_state")
  complete_states[, 1L, "WWW"] <- attr(ratio_result$world, "wlv_state")
  wlv_contract_register_states(
    wlv_contract_runtime, "sea_countries", country_indicator, complete_states
  )
} else {
  sea_countries[, country_indicator, lists$countries] <- aperm(
    apply(ratio_numerator, 1L, tapply, rows$num_country, sum, na.rm = TRUE),
    c(2L, 1L)
  ) / aperm(
    apply(ratio_denominator, 1L, tapply, rows$num_country, sum, na.rm = TRUE),
    c(2L, 1L)
  ) - 1
  sea_countries[, country_indicator, "WWW"] <-
    apply(ratio_numerator, 1L, sum, na.rm = TRUE) /
    apply(ratio_denominator, 1L, sum, na.rm = TRUE) - 1
}

rm(list = intersect(
  c(
    "ratio_numerator", "ratio_denominator", "ratio_result",
    "complete_states", "skill_code", "country_indicator"
  ),
  ls(envir = environment(), all.names = TRUE)
), envir = environment())
