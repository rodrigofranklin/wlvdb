# Exploitation rate of employed persons in productive sectors, by country and
# for the world. The world value is a ratio of totals, not a mean of rates.
emp_p_numerator <- aperm(
  apply(
    sea_sectors[, "abstract_labour.emp.s.mv", , ] *
      rep(rows$productive, each = nums$years),
    1,
    tapply,
    rows$num_country,
    sum,
    na.rm = TRUE
  ),
  c(2, 1)
)
emp_p_denominator <- aperm(
  apply(
    sea_sectors[, "labour_force_value.emp.s.mv", , ] *
      rep(rows$productive, each = nums$years),
    1,
    tapply,
    rows$num_country,
    sum,
    na.rm = TRUE
  ),
  c(2, 1)
)
sea_countries[, "surplus_value.emp_p.r.pc", lists$countries] <-
  emp_p_numerator / emp_p_denominator - 1
sea_countries[, "surplus_value.emp_p.r.pc", "WWW"] <-
  rowSums(emp_p_numerator) / rowSums(emp_p_denominator) - 1

rm(emp_p_numerator, emp_p_denominator)
