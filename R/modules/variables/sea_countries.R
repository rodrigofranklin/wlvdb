# calculates national values for SEA variables with sum and mean
for (loop in grep(".R", sea_variables$country_solution, invert = TRUE)) {
  sea_countries[, loop, lists$countries] <- 
    aperm(
      apply(sea_sectors[,loop,,], 1,
            tapply, rows$num_country, sea_variables$country_solution[loop], 
            na.rm = TRUE),
      c(2,1)
    )
  
  sea_countries[, loop, "WWW"] <- 
    sea_countries[, loop, lists$countries] %>%
    apply(1, sea_variables$country_solution[loop], na.rm = TRUE)
}

# calculates the others SEA variables
for (loop in grep(".R", sea_variables$country_solution)) {
  source(paste0("R/modules/variables/",sea_variables$country_solution[loop]))
  sea_countries[is.nan(sea_countries)] <- 0
  sea_countries[is.infinite(sea_countries)] <- 0
}
