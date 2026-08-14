###############################################################################.
#                                                                              #
#                       World Labour Values Database                           #
#                                                                              #
###############################################################################.


# Versions computations ----

source("R/lib/dependencies.R", local = TRUE)

method_list <- gsub("methods/","",list.dirs("methods",recursive = F))

get_wlv <- function (methods = "wiodr13", repeat_pp = F,
                   papern = 0, prepaper = F) {
  wlv_assert_dependencies(
    include_preparation = repeat_pp,
    include_papers = prepaper
  )

  #Load functions
  source("R/lib/functions.R")
  
  #Starts parallel computation
  source("R/lib/parallelization_start.R")
  
  for (method_version in methods) {
    if (repeat_pp == T ) {
      a <-
        read.csv2(
          paste0("methods/",method_version,"/_parameters.csv"))
      
      a <- a$source
      # Prepare corresponding version ----
      print(paste("Preparing",
                  a,
                  "data collection and primary organization..."))
      source(paste0("R/utils/prepare_",a,"_data.R"))
      
    }
    
    print(paste0("Calculating ", method_version,"..."))
    assign("method_version", method_version, envir=globalenv())
    assign("methods", methods, envir=globalenv())
    source("R/lib/computations.R")
  }
  
  if(prepaper == T) {
    # Select and save ----
    source(paste0("R/utils/papers/paper_",papern,"_selection.R"))
  }

  #Stops parallel computation
  source("R/lib/parallelization_stop.R")

  gc()
  
}

# Function to recalculate just data from sea_variables and sea_countries
# Can also be used to include new variables
recalc_wlv <- function (methods = "wiodr13", at_stage = 1,
                    sea_vars = NULL, papern = 0, prepaper = F) {
  wlv_assert_dependencies(include_papers = prepaper)

  #Load functions
  source("R/lib/functions.R")
  
  #Starts parallel computation
  source("R/lib/parallelization_start.R")
  
  assign("methods", methods, envir=globalenv())
  assign("at_stage", at_stage, envir=globalenv())
  assign("sea_vars", sea_vars, envir=globalenv())
  
  for (method_version in methods) {

    print(paste0("Calculating ", method_version,"..."))
    assign("method_version", method_version, envir=globalenv())
    source("R/lib/re_computations.R")
  }
  
  if(prepaper == T) {
    # Select and save ----
    
    source(paste0("papers/paper_",papern,"_selection.R"))
  }
  
  #Stops parallel computation
  source("R/lib/parallelization_stop.R")

  gc()
  
}
