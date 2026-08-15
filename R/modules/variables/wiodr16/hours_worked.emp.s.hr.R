# Hours worked by employed persons
code <- "hours_worked.emp.s.hr"

meta_indicators[code,"name"] <- "Total hours worked by persons engaged"
meta_indicators[code,"description"] <- 
  paste0("Total hours worked by persons engaged represents the sum of hours ",
         "worker in a year by persons engaged.")
meta_indicators[code,"observation"] <- 
  paste0("Estimated from the average hours worked by employees.")
meta_indicators[code,"type"] <- "hours"
meta_indicators[code,"group"] <- "Labour and employment"
meta_indicators[code,"reverted"] <- FALSE

employee_hours <- sea_source[, "H_EMPE", lists$sectors, ]
employees <- sea_source[, "EMPE", lists$sectors, ]
persons_engaged <- sea_source[, "EMP", lists$sectors, ]
if (exists("wlv_contract_runtime", inherits = FALSE)) {
  sea_sectors[, code, , ] <- wlv_wiodr16_hours_worked_runtime(
    wlv_contract_runtime,
    employee_hours,
    employees,
    persons_engaged
  )
} else {
  sea_sectors[, code, , ] <-
    employee_hours / employees * persons_engaged * 1000000
}
rm(employee_hours, employees, persons_engaged)

