## prea - define some basepaths
com_path <- "parameters/common_ground/" 
method_path <- paste0("methods/", method_version)
#method parameters basepath
met_p_pth <- paste0(method_path,"/parameters/")

## load all parameters of the choosed method
#Read method parameters
parameters <- 
  read.csv2(paste0(met_p_pth,"_parameters.csv"))

source_version <- parameters$version

#Def source basepath
src_path <- paste0("parameters/",source_version,"/")

##Helper function for loading most specific parameters for matrices,
##reduced matrices and solutions
load_parameters <- function(pg,paths = c(met_p_pth,src_path,com_path)) {
  files <- 
    unlist(lapply(paths,dir,pattern = pg, full.names = T))
  print(files)
  param <- bind_rows(lapply(files,read.csv2))
  param <- param[!duplicated(param$names),]
}

#Def param groups and unambiguous patterns 
param_groups <- 
  data.frame(group_pattern = c("[^e]._matrices","reduced","solutions"),
             object = c("matrices","reduced_matrices","sea_variables"))

for(i in 1:nrow(param_groups)){
  a <- load_parameters(param_groups$group_pattern[i])
  assign(param_groups$object[i],a)
  print(paste0("Loaded ",param_groups$object[i]," parameters"))
}

print(matrices$computation)
# sectors definitions ----
# according to the method
sectors <-
  read.csv2(paste0(met_p_pth,"_sectors.csv"))