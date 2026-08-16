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

all_sea_variables <- sea_variables
if (!is.null(sea_vars)) {
  sea_variables <- sea_variables[sea_variables$names %in% sea_vars,]
}

# preliminary variables computations
if (at_stage == 1) {
  stage <- 1
  source("R/modules/variables/sea_sectors.R")
  # Reloading stage 1 also restores structural NA values from the source.
  # Reapply the deterministic assumptions before later-stage values are reused.
  for (assumption in assumptions$computation) {
    print(paste0("sourcing: ", assumption))
    source(paste0("R/modules/assumptions/", assumption))
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

if (identical(source_version, "wiodr13")) {
  source("R/modules/variables/wiodr13/normalize_price_indices.R")
}

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
}
write_fst_array(sea_sectors, file.path(wlv_result_dir, "sea_sectors.fst"))
write_fst_array(sea_countries, file.path(wlv_result_dir, "sea_countries.fst"))

# `sea_variables` may be narrowed for a selective recalculation, but the
# published method sidecar must always describe the complete result arrays.
sea_variables <- all_sea_variables

# Matrix modules are intentionally not rerun during a variable recalculation.
# Load and revalidate their calculation-specific scientific diagnostics so a
# missing, stale, or altered sidecar cannot be copied through staging silently.
recalculation_scientific_diagnostics <- list()
if (source_version %in% c("wiodr13", "wiodr16")) {
  if (!exists("wlv_wiodr_assert_negative_gfcf_profile", mode = "function")) {
    source("R/lib/gfcf_contracts.R")
  }
  if (!exists("wlv_load_gfcf_diagnostic_artifacts", mode = "function")) {
    source("R/lib/gfcf_diagnostics.R")
  }
  recalculation_scientific_diagnostics <- wlv_load_gfcf_diagnostic_artifacts(
    wlv_existing_result_dir,
    method = source_version
  )
}
if (!exists("wlv_load_leontief_diagnostic_artifact", mode = "function")) {
  source("R/lib/leontief_diagnostics.R")
}
recalculation_scientific_diagnostics[["_leontief_diagnostics.csv"]] <-
  wlv_load_leontief_diagnostic_artifact(
    wlv_existing_result_dir,
    method = method_version,
    expected_years = lists$years
  )
wlv_scientific_diagnostics <- recalculation_scientific_diagnostics

# Later-stage recalculations intentionally do not rerun assumptions. Preserve
# the method description those assumptions produced in the published snapshot;
# stage 1 recalculations rebuild it by executing the assumptions above.
if (at_stage > 1L) {
  persisted_parameters_path <- file.path(
    wlv_existing_result_dir,
    "_parameters.csv"
  )
  if (!file.exists(persisted_parameters_path)) {
    stop(
      "Cannot preserve method parameters: `_parameters.csv` is missing.",
      call. = FALSE
    )
  }
  persisted_parameters <- utils::read.csv2(
    persisted_parameters_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    fileEncoding = "UTF-8"
  )
  comparable_columns <- setdiff(names(parameters), "description")
  same_configuration <- identical(names(persisted_parameters), names(parameters)) &&
    identical(nrow(persisted_parameters), nrow(parameters)) &&
    identical(
      persisted_parameters[comparable_columns],
      parameters[comparable_columns]
    )
  current_descriptions <- as.character(parameters$description)
  persisted_descriptions <- as.character(persisted_parameters$description)
  description_is_preserved_base <- same_configuration && all(
    endsWith(persisted_descriptions, current_descriptions)
  )
  if (!description_is_preserved_base) {
    stop(
      paste0(
        "Current method parameters differ from the published snapshot; ",
        "rerun from stage 1 or perform a full calculation."
      ),
      call. = FALSE
    )
  }
  parameters$description <- persisted_descriptions
}
source("R/lib/write_labels.R")

rm(list = intersect(
  c(
    "basket_zero", "basket_value_zero", "all_sea_variables",
    "persisted_parameters_path", "persisted_parameters",
    "comparable_columns", "same_configuration", "current_descriptions",
    "persisted_descriptions", "description_is_preserved_base",
    "recalculation_scientific_diagnostics"
  ),
  ls(envir = environment(), all.names = TRUE)
), envir = environment())
