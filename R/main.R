###############################################################################.
#                                                                              #
#       World Labour Values Database  - studies on the reduction problem       #
#                                                                              #
###############################################################################.


# Versions computations ----

method_list <- c(
  "ochoa_1",
  "ochoa_2",
  "petrovic",
  "alternative_1",
  "alternative_2"
  )

gomarx <- function(methods = method_list, repeat_pp = F,
                   papern = 0, prepaper = F) {
  #Load functions
  source("R/lib/functions.R")
  
  if (repeat_pp == T ) {
    
    # Prepare WIOD ----
    
    source("R/utils/prepare_wiod_data.R")
    
    # Prepare EUKLEMS ----
    source("R/utils/prepare_euklems_data.R")
    
  }
  #Control for avoiding repeated intro message on cluster
  #creation
  cf <- "started"
  write(c("started","clusters"),cf,sep=",")

  assign("my.cluster",parallel::makeCluster(
    parallel::detectCores() - 1, 
    type = "PSOCK"), envir=globalenv())
  
  file.remove(cf)
  
  for (method_version in methods) {
    print(paste0("Calculating ", method_version,"..."))
    assign("method_version", method_version, envir=globalenv())
    assign("methods", methods, envir=globalenv())
    source("R/lib/computations.R")
  }
  
  stopCluster(cl = my.cluster)
  closeAllConnections()
  
  if(prepaper == T) {
    # Select and save ----
    
    source(paste0("R/papers/paper_",papern,"_selection.R"))
  }

  gc()
  
}
