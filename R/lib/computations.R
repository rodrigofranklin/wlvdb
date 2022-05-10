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

# # China
# if (!is.null(parameters$china)) {
#   source(paste0("R/modules/assumptions/",parameters$china))
# } 
# 
# # RoW
# if (!is.null(parameters$row)) {
#   source(paste0("R/modules/assumptions/",parameters$row))
# }

# Other assumptions
# (eg, reduction problem) 
stage <- 2
source("R/modules/variables/sea_sectors.R")

#######################.
# computations  ----
#######################.

# obtain list of m_io files
lists$m_io_files <- 
  dir(path = paste0("source_data/",source_version),
      pattern = "m_io", full.names = T )

# compute each file
for (current_m_io in lists$m_io_files) {
  
  # prepare m_io computation
  source("R/lib/prepare_computation.R")
  

  # matricial computations
  for (matrix_script in matrices$computation) {
    source(paste0("R/modules/matrices/",matrix_script))
  }

  # reduces input-output matrices to country matrices.
  # filter to eliminate internal trade
  filter <- rep(1-diag(nums$countries), each = nums$years)
  
  print("Start of reduction of IxO matrices:")
  for (matrix_script in reduced_matrices$computation) {
    source(paste0("R/modules/reduced_matrices/",matrix_script))
  }
  print("End of matrix reduction.")
  
  # compute variables from matrices
  stage <- 4
  source("R/modules/variables/sea_sectors.R")
  
  # write
  print("Writing...")
  saveRDS(m_io,paste0(method_path,"/results/m_io",lists$years[1],".rds"))

  # just in case of blackout
  print("Temporary writing...")
  saveRDS(m_countries,paste0(method_path,"/results/m_countries.rds"))
  saveRDS(sea_sectors,paste0(method_path,"/results/sea_sectors.rds"))
  saveRDS(sea_countries,paste0(method_path,"/results/sea_countries.rds"))

  # clear environment
  rm(lambda, m_io_source, m_io, balance_factor, filter, matrix_script)
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
saveRDS(m_io_filters,paste0("resultados/",method_version,"/m_io_filters.rds"))
saveRDS(m_countries,paste0("resultados/",method_version,"/m_countries.rds"))
saveRDS(sea_sectors,paste0("resultados/",method_version,"/sea_sectors.rds"))
saveRDS(sea_countries,paste0("resultados/",method_version,"/sea_countries.rds"))
