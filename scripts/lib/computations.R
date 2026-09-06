##########################################################.
#                                                         #
# Calculate the labour values.                            #
#                                                         #
##########################################################.


source("scripts/lib/parameters.R")

# load raw sea data
source("scripts/lib/raw_sea_data.R")

# load control variables
source("scripts/lib/control_variables.R")

# assign results variables
source("scripts/lib/results_variables.R")

# make filters to read IO matrix
source("scripts/lib/filters_io.R")

# preliminary variables computations
stage <- 1
source("scripts/modules/variables/sea_sectors.R")

#######################.
# assumptions ----
#######################.

for (assumption in assumptions$computation) {
  print(paste0("sourcing: ",assumption))
  source(paste0("scripts/modules/assumptions/",assumption))
}
if (exists("wlv_contract_runtime", inherits = FALSE)) {
  wlv_contract_clear_states(
    wlv_contract_runtime,
    "sea_sectors",
    sea_variables$names[sea_variables$stage <= 1L]
  )
  wlv_validate_sea_stage(
    wlv_contract_runtime,
    sea_sectors,
    sea_variables,
    stage = 1L,
    checkpoint = "after_assumptions",
    years = lists$years
  )
}

# Other assumptions
# (eg, reduction problem) 
stage <- 2
source("scripts/modules/variables/sea_sectors.R")

#######################.
# computations  ----
#######################.

# Use the exact files that passed preflight validation.
lists$m_io_files <- wlv_data$source_io

for(current_m_io in lists$m_io_files) {
  print("lets prepare the computation")
  source("scripts/lib/prepare_computation.R")
  # stage <- 3
  # print("Starting stage 3")
  # matricial computations
  for (matrix_script in matrices$computation) {
    print(paste("Sourcing from ",paste0("scripts/modules/matrices/",matrix_script)))
    source(paste0("scripts/modules/matrices/",matrix_script))
  }
  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    wlv_validate_m_io_contract(
      wlv_contract_runtime,
      m_io,
      checkpoint = "after_matrices"
    )
  }

  # reduces input-output matrices to country matrices.
  # filter to eliminate internal trade
  print("Start of reduction of IxO matrices:")
  filter <- rep(1-diag(nums$countries), each = nums$years)
  for (matrix_script in reduced_matrices$computation) {
    source(paste0("scripts/modules/reduced_matrices/",matrix_script))
  }
  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    wlv_validate_m_countries_contract(
      wlv_contract_runtime,
      m_countries[lists$years, , , , drop = FALSE],
      checkpoint = "after_reduced_matrices"
    )
  }
  print("End of matrix reduction.")
  
  # compute variables from matrices
  stage <- 4
  source("scripts/modules/variables/sea_sectors.R")
  
  # write
  print("Writing...")
  if (nums$years == 1) {
    current_result_io <- file.path(
      wlv_result_dir,
      paste0("m_io", lists$years[1], ".fst")
    )
  } else {
    current_result_io <- file.path(
      wlv_result_dir,
      paste0("m_io", lists$years[1], "-", lists$years[nums$years], ".fst")
    )
  }
  write_fst_array(m_io, current_result_io)

  # just in case of blackout
  print("Temporary writing...")
  write_fst_array(m_countries, file.path(wlv_result_dir, "m_countries.fst"))
  write_fst_array(sea_sectors, file.path(wlv_result_dir, "sea_sectors.fst"))

  # clear environment
  rm(lambda, m_io_source, m_io, balance_factor, filter)
  rm(list = intersect(
    c("matrix_script", "wlv_canonical_gfcf_observations"),
    ls(envir = environment(), all.names = TRUE)
  ), envir = environment())
  gc()
}



# clear environment
gc()

# all years
lists$years <- names(sea_source[,1,1,1])
nums$years <- length(lists$years)

if (source_version %in% c("wiodr13", "wiodr16")) {
  source("scripts/modules/variables/wiodr13/normalize_price_indices.R")
}

#######################.
# results variables
#######################.

# sectorial results
stage <- 5
source("scripts/modules/variables/sea_sectors.R")

# national results
source("scripts/modules/variables/sea_countries.R")

#######################.
# Writing ----
#######################.

print("Writing...")
if (exists("wlv_contract_runtime", inherits = FALSE)) {
  wlv_validate_sea_stage(
    wlv_contract_runtime,
    sea_sectors,
    sea_variables,
    stage = 5L,
    checkpoint = "pre_publish"
  )
  wlv_validate_sea_countries_contract(
    wlv_contract_runtime,
    sea_countries,
    checkpoint = "pre_publish"
  )
  wlv_validate_m_countries_contract(
    wlv_contract_runtime,
    m_countries,
    checkpoint = "pre_publish"
  )
}
write_fst_array(m_countries, file.path(wlv_result_dir, "m_countries.fst"))
write_fst_array(sea_sectors, file.path(wlv_result_dir, "sea_sectors.fst"))
write_fst_array(sea_countries, file.path(wlv_result_dir, "sea_countries.fst"))

source("scripts/lib/write_labels.R")

rm(list = intersect(
  c("basket_zero", "basket_value_zero"),
  ls(envir = environment(), all.names = TRUE)
), envir = environment())
