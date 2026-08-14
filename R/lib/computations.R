##########################################################.
#                                                         #
# Calculate the labour values.                            #
#                                                         #
##########################################################.


source("R/lib/parameters.R")

# load raw sea data
source("R/lib/raw_sea_data.R")

# load control variables
source("R/lib/control_variables.R")

# assign results variables
source("R/lib/results_variables.R")

# make filters to read IO matrix
source("R/lib/filters_io.R")

# preliminary variables computations
stage <- 1
source("R/modules/variables/sea_sectors.R")

#######################.
# assumptions ----
#######################.

for (assumption in assumptions$computation) {
  print(paste0("sourcing: ",assumption))
  source(paste0("R/modules/assumptions/",assumption))
}

# Other assumptions
# (eg, reduction problem) 
stage <- 2
source("R/modules/variables/sea_sectors.R")

#######################.
# computations  ----
#######################.

# Use the exact files that passed preflight validation.
lists$m_io_files <- wlv_data$source_io

for(current_m_io in lists$m_io_files) {
  print("lets prepare the computation")
  source("R/lib/prepare_computation.R")
  # stage <- 3
  # print("Starting stage 3")
  # matricial computations
  for (matrix_script in matrices$computation) {
    print(paste("Sourcing from ",paste0("R/modules/matrices/",matrix_script)))
    source(paste0("R/modules/matrices/",matrix_script))
  }

  # reduces input-output matrices to country matrices.
  # filter to eliminate internal trade
  print("Start of reduction of IxO matrices:")
  filter <- rep(1-diag(nums$countries), each = nums$years)
  for (matrix_script in reduced_matrices$computation) {
    source(paste0("R/modules/reduced_matrices/",matrix_script))
  }
  print("End of matrix reduction.")
  
  # compute variables from matrices
  stage <- 4
  source("R/modules/variables/sea_sectors.R")
  
  # write
  print("Writing...")
  if (nums$years == 1) {
    write_fst_array(m_io,paste0("results/",method_version,"/m_io",lists$years[1],".fst"))
  } else {
    write_fst_array(m_io,paste0("results/",method_version,"/m_io",lists$years[1],"-",
                        lists$years[nums$years],".fst"))
  }

  # just in case of blackout
  print("Temporary writing...")
  write_fst_array(m_countries,paste0("results/",method_version,"/m_countries.fst"))
  write_fst_array(sea_sectors,paste0("results/",method_version,"/sea_sectors.fst"))

  # clear environment
  #rm(lambda, m_io_source, m_io, balance_factor, filter, matrix_script)
  gc()
}



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
write_fst_array(m_countries,paste0("results/",method_version,"/m_countries.fst"))
write_fst_array(sea_sectors,paste0("results/",method_version,"/sea_sectors.fst"))
write_fst_array(sea_countries,paste0("results/",method_version,"/sea_countries.fst"))

source("R/lib/write_labels.R")

rm(basket_zero, basket_value_zero)
