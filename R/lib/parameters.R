## load all parameters of the choosed method

parameters <- 
  read.csv2(paste0("models/",method_version,"/parameters/_parameters.csv"))

source_version <- parameters$version

# matrices computations ----
# load common matrices
matrices <- 
  read.csv2(paste0("parameters/common_ground/_common_matrices.csv"))

# overwrite with source specifics computations
source_matrices <- 
  paste0("parameters/",source_version,"/_source_matrices.csv")
if (file.exists(source_matrices)) {
  #load
  source_matrices <-
    read.csv2(source_matrices)
  
  #overwrite
  matrices[match(source_matrices$names, matrices$names),] <- 
    source_matrices
}

# overwrite with method specifics computations
method_matrices <- 
  paste0("parameters/",source_version,"/_method_matrices.csv")
if (file.exists(method_matrices)) {
  #load
  method_matrices <-
    read.csv2(method_matrices)
  
  #overwrite
  matrices[match(method_matrices$names, matrices$names),] <- 
    method_matrices
}


# reduced matrices computations ----
# load common reduced matrices
reduced_matrices <- 
  read.csv2(paste0("parameters/common_ground/_common_reduced_matrices.csv"))

# overwrite with source specifics computations
source_reduced <- 
  paste0("parameters/",source_version,"/_source_reduced.csv")
if (file.exists(source_reduced)) {
  #load
  source_reduced <-
    read.csv2(source_reduced)
  
  #overwrite
  matrices[match(source_reduced$names, matrices$names),] <- 
    source_reduced
}

# overwrite with method specifics computations
method_reduced <- 
  paste0("parameters/",source_version,"/_method_reduced.csv")
if (file.exists(method_reduced)) {
  #load
  method_reduced <-
    read.csv2(method_reduced)
  
  #overwrite
  matrices[match(matrices$names, method_reduced$names),] <- 
    method_reduced
}

# variables solutions ----
# load common solutions. Can be overwritten by method and 
# source specifics solutions
common_solutions <-
  read.csv2(paste0("parameters/common_ground/_common_solutions.csv"))

# source_code solutions
source_solutions <- 
  paste0("parameters/",source_version,"/_source_solutions.csv")
if (file.exists(source_solutions)) {
  source_solutions <-
    read.csv2(source_solutions)
} else {
  source_solutions <- NULL
}

# method specifics solutions
method_solutions <-
  paste0("models/",method_version,"/parameters/_method_solutions.csv")
if (file.exists(method_solutions)) {
  method_solutions <-
    read.csv2(method_solutions)
} else {
  method_solutions <- NULL
}

# sea_variables
# concatenate all solutions
sea_variables <-  data.frame("names" = unique(c(common_solutions$names,
                                                source_solutions$names,
                                                method_solutions$names)))

sea_variables$sector_solution <- NULL
sea_variables$country_solution <- NULL
sea_variables$order <- NULL

sea_variables[match(common_solutions$names, sea_variables$names),2:4] <- 
  common_solutions[,2:4]

sea_variables[match(source_solutions$names, sea_variables$names),2:4] <- 
  source_solutions[,2:4]

sea_variables[match(method_solutions$names, sea_variables$names),2:4] <- 
  method_solutions[,2:4]

# sectors definitions ----
# according to the method
sectors <-
  read.csv2(paste0("models/",method_version,"/parameters/_sectors.csv"))

# clear environment
rm(source_reduced, source_matrices, method_reduced, method_matrices, 
   common_solutions, source_solutions, method_solutions)
