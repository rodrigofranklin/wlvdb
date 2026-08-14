# Exploitation rate of employees in productive sectors, by country and for the
# world. The world value is a ratio of totals, not a mean of rates.
empe_p_numerator <- aperm(
  apply(
    sea_sectors[, "abstract_labour.empe.s.mv", , ] *
      rep(rows$productive, each = nums$years),
    1,
    tapply,
    rows$num_country,
    sum,
    na.rm = TRUE
  ),
  c(2, 1)
)
empe_p_denominator <- aperm(
  apply(
    sea_sectors[, "labour_force_value.s.mv", , ] *
      rep(rows$productive, each = nums$years),
    1,
    tapply,
    rows$num_country,
    sum,
    na.rm = TRUE
  ),
  c(2, 1)
)
sea_countries[, "surplus_value.empe_p.r.pc", lists$countries] <-
  empe_p_numerator / empe_p_denominator - 1
sea_countries[, "surplus_value.empe_p.r.pc", "WWW"] <-
  rowSums(empe_p_numerator) / rowSums(empe_p_denominator) - 1

rm(empe_p_numerator, empe_p_denominator)
