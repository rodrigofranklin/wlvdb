###############################################################################.
#                                                                              #
#                       World Labour Values Database                           #
#                                                                              #
###############################################################################.


# Versions computations ----

method_list <- gsub("methods/","",list.dirs("methods",recursive = F))

get_wlv <- function (methods = "wiodr13", repeat_pp = F,
                   papern = 0, prepaper = F) {
  #Load functions
  source("R/lib/functions.R")
  
  #Control for avoiding repeated intro message on cluster
  #creation
  cf <- "started"
  write(c("started","clusters"),cf,sep=",")

  if(.Platform$OS.type == "unix") {
    my.cluster <-  makeForkCluster(detectCores() - 1,outfile="results/logs/parallelworkers.log",
           envir=globalenv())
  } else {
    assign("my.cluster",parallel::makeCluster(
      parallel::detectCores() - 1, 
      type = "PSOCK"), envir=globalenv())
  }
  
  file.remove(cf)
  
  for (method_version in methods) {
    if (repeat_pp == T ) {
      a <-
        read.csv2(
          paste0("methods/",method_version,"/parameters/_parameters.csv"))
      
      a <- a$version
      # Prepare corresponding version ----
      print(paste("Preparing",
                  method_version,
                  "data collection and primary organization..."))
      source(paste0("R/utils/prepare_",method_version,"_data.R"))
      
    }
    
    print(paste0("Calculating ", method_version,"..."))
    assign("method_version", method_version, envir=globalenv())
    assign("methods", methods, envir=globalenv())
    source("R/lib/computations.R")
  }
  
  stopCluster(cl = my.cluster)
  closeAllConnections()
  
  if(prepaper == T) {
    # Select and save ----
    
    source(paste0("R/utils/papers/paper_",papern,"_selection.R"))
  }

  gc()
  
}

# Function to recalculate just data from sea_variables and sea_countries
# Can also be used to include new variables
recalc_wlv <- function (methods = "wiodr13", at_stage = 1,
                    sea_vars = NULL, papern = 0, prepaper = F) {
  #Load functions
  source("R/lib/functions.R")
  
  #Control for avoiding repeated intro message on cluster
  #creation
  cf <- "started"
  write(c("started","clusters"),cf,sep=",")
  
  if(.Platform$OS.type == "unix") {
    my.cluster <-  makeForkCluster(detectCores() - 1,outfile="results/logs/parallelworkers.log",
                                   envir=globalenv())
  } else {
    assign("my.cluster",parallel::makeCluster(
      parallel::detectCores() - 1, 
      type = "PSOCK"), envir=globalenv())
  }
  
  file.remove(cf)
  
  assign("methods", methods, envir=globalenv())
  assign("at_stage", at_stage, envir=globalenv())
  assign("sea_vars", sea_vars, envir=globalenv())
  
  for (method_version in methods) {

    print(paste0("Calculating ", method_version,"..."))
    assign("method_version", method_version, envir=globalenv())
    source("R/lib/re_computations.R")
  }
  
  stopCluster(cl = my.cluster)
  closeAllConnections()
  
  if(prepaper == T) {
    # Select and save ----
    
    source(paste0("papers/paper_",papern,"_selection.R"))
  }
  
  gc()
  
}
