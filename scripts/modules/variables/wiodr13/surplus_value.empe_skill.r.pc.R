ratio_numerator <-
  sea_sectors[, "abstract_labour.empe.s.mv", , ] *
  sea_sectors[, paste0("hours_worked.empe_", skill_code, ".r.pc"), , ]
ratio_denominator <-
  sea_sectors[, "labour_force_value.s.mv", , ] *
  sea_sectors[, paste0("compensation.empe_", skill_code, ".r.pc"), , ]
ratio_value <- if (exists("wlv_contract_runtime", inherits = FALSE)) {
  wlv_ratio_runtime(
    wlv_contract_runtime,
    ratio_numerator,
    ratio_denominator,
    zero = "not_applicable",
    artifact = "sea_sectors",
    indicator = code,
    checkpoint = "after_stage_5",
    stage = 5L,
    module = paste0("wiodr13/", code, ".R"),
    axes = c(year = 1L, sector = 2L, country = 3L)
  )
} else ratio_numerator / ratio_denominator
sea_sectors[, code, , ] <- ratio_value - 1
rm(ratio_numerator, ratio_denominator, ratio_value, skill_code)
