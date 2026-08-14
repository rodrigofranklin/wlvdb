##########################################################.
#                                                         #
# Recalculate Variables from labour values.               #
#                                                         #
##########################################################.


source("R/lib/parameters.R")

# load raw sea data
source("R/lib/raw_sea_data.R")

# load control variables
source("R/lib/control_variables.R")

# assign results variables
source("R/lib/re_results_variables.R")

# make filters to read IO matrix
source("R/lib/filters_io.R")

if (!is.null(sea_vars)) {
  sea_variables <- sea_variables[sea_variables$names %in% sea_vars,]
}

# preliminary variables computations
if (at_stage == 1) {
  stage <- 1
  source("R/modules/variables/sea_sectors.R")
}

# Other assumptions
# Variáveis de pressupostos não devem ser recalculadas! Pois modificam os
# resultados. Ao invés disso, todos os cálculos devem ser feitos novamente
# if (at_stage <=2) {
#   stage <- 2
#   source("R/modules/variables/sea_sectors.R")
# }

#######################.
# computations  ----
#######################.

if (at_stage <= 4) {
  lists$m_io_results_files <- wlv_data$result_io
  lists$m_io_source_files <- wlv_data$source_io
  
  for(current_m_io in seq_along(lists$m_io_results_files)) {
    print("lets prepare the computation")
    source("R/lib/re_prepare_computation.R")
    
    # stage <- 3
    # There are no stage 3 variables

    # compute variables from matrices
    stage <- 4
    source("R/modules/variables/sea_sectors.R")
    
    # clear environment
    rm(lambda, m_io_source, m_io, balance_factor)
    gc()
  }
}
# obtain list of m_io files

# clear environment
gc()

# all years
lists$years <- names(sea_source[,1,1,1])
nums$years <- length(lists$years)

#######################.
# results variables
#######################.

# sectorial results
stage <- 5
source("R/modules/variables/sea_sectors.R")

# national results
source("R/modules/variables/sea_countries.R")

#######################.
# Writing ----
#######################.

print("Writing...")
write_fst_array(sea_sectors,paste0("results/",method_version,"/sea_sectors.fst"))
write_fst_array(sea_countries,paste0("results/",method_version,"/sea_countries.fst"))

rm(basket_zero, basket_value_zero)
