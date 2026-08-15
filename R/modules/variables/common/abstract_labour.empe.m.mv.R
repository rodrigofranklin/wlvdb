# Jornada de trabalho média - trabalhadores assalariados - em magnitude de valor
code <- "abstract_labour.empe.m.mv"

meta_indicators[code,"name"] <-
  "Working day of employee per year (magnitude of value)"
meta_indicators[code,"description"] <- paste0(
  'Average magnitude of value "created" by employee per year. Includes ',
  "productive and unproductive workers.")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "value"
meta_indicators[code,"group"] <- "Labour and employment"
meta_indicators[code,"reverted"] <- FALSE

ratio_numerator <- sea_sectors[lists$years, "abstract_labour.empe.s.mv", , ]
ratio_denominator <- sea_sectors[lists$years, "empe.s.un", , ]
sea_sectors[lists$years, code, , ] <- if (exists("wlv_contract_runtime", inherits = FALSE)) {
  wlv_ratio_runtime(
    wlv_contract_runtime, ratio_numerator, ratio_denominator,
    zero = "not_applicable", artifact = "sea_sectors",
    indicator = code, checkpoint = "after_stage_5", stage = 5L,
    module = "common/abstract_labour.empe.m.mv.R",
    axes = c(year = 1L, sector = 2L, country = 3L)
  )
} else ratio_numerator / ratio_denominator
rm(ratio_numerator, ratio_denominator)
