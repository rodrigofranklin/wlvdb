# calculates sea_sectors data
#
# there are 6 moments of variables computations:
#
# 0 - variables directly obtained from raw data
# 1 - variables obtained by computation over raw data
# 2 - assumption variables
# 3 - assumption matrices # there are no assumption matrices
# 4 - variables obtained from transformed m_io
# 5 - variables obtained by computation over SEA results

if (stage == 1) { # Stage 0 is computed only before computing stage 1 variables
  # Stage 0 variables, adjusting scale as specified in parameters
  
  # Copy variables from sea_source to sea_sectors (indicated in parameters)
  raw_solutions <- !grepl("\\.[Rr]$", sea_variables$sector_solution)
  for (loop in which(raw_solutions)) {
    if (exists("wlv_contract_runtime", inherits = FALSE)) {
      wlv_contract_clear_states(
        wlv_contract_runtime,
        "sea_sectors",
        sea_variables$names[[loop]]
      )
    }
    temp <- unlist(strsplit(sea_variables$sector_solution[loop], "[*]"))
    sea_sectors[, sea_variables$names[loop], lists$sectors, lists$countries] <- 
      sea_source[, temp[1], lists$sectors, lists$countries]
    meta_indicators[sea_variables$names[loop],"observation"] <- paste("Source:", source_version)
  }
  
  # Changes scale of variables when indicated in parameters
  for (loop in grep("[*]", sea_variables$sector_solution)) {
    temp <- unlist(strsplit(sea_variables$sector_solution[loop], "[*]"))
    sea_sectors[,sea_variables$names[loop],lists$sectors,lists$countries] <- 
      sea_sectors[,sea_variables$names[loop],lists$sectors,lists$countries] *
      as.numeric(temp[2])
  }
  
  rm(list = intersect("temp", ls(envir = environment(), all.names = TRUE)))
  rm(raw_solutions)
}

# Computing stages 1 to 5, as define by "stage" variable
for (loop in sea_variables$sector_solution[which(sea_variables$stage==stage)]) {
  print(paste("Sourcing from stage",stage,"script",gsub(".*/","",loop)))
  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    wlv_contract_clear_states(
      wlv_contract_runtime,
      "sea_sectors",
      sea_variables$names[
        sea_variables$stage == stage & sea_variables$sector_solution == loop
      ]
    )
  }
  source(paste0("R/modules/variables/",loop))
  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    checkpoint <- paste0("after_stage_", stage)
    module_indicators <- sea_variables$names[
      sea_variables$stage == stage & sea_variables$sector_solution == loop
    ]
    for (module_indicator in module_indicators) {
      wlv_validate_sea_indicator(
        wlv_contract_runtime,
        sea_sectors,
        module_indicator,
        checkpoint = checkpoint,
        stage = stage,
        module = loop,
        years = lists$years
      )
    }
    wlv_assert_sea_no_special_values(
      wlv_contract_runtime,
      sea_sectors,
      checkpoint = checkpoint,
      stage = stage,
      module = loop
    )
  }
  print(paste("Finished sourcing script",gsub(".*/","",loop),"from stage",stage))
}

if (exists("wlv_contract_runtime", inherits = FALSE)) {
  checkpoint <- paste0("after_stage_", stage)
  wlv_validate_sea_stage(
    wlv_contract_runtime,
    sea_sectors,
    sea_variables,
    stage = stage,
    checkpoint = checkpoint,
    years = lists$years
  )
}

print(paste("Finished stage",stage))
rm(list = intersect(
  c("loop", "checkpoint", "module_indicators", "module_indicator"),
  ls(envir = environment(), all.names = TRUE)
))
