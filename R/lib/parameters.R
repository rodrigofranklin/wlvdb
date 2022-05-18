## prea - define some basepaths
com_path <- "parameters/common_ground/" 
method_path <- paste0("methods/", method_version,"/")

## load all parameters of the choosed method
#Read method parameters
parameters <- 
  read.csv2(paste0(method_path,"_parameters.csv"))

#Def source basepath
source_version <- parameters$version
src_path <- paste0("parameters/",source_version,"/")

##Helper function for loading most specific parameters for matrices,
##reduced matrices and solutions
load_parameters <- function(pg,paths = c(method_path,src_path,com_path)) {
  files <- unlist(lapply(paths,dir,pattern = pg, full.names = T))
  param <- bind_rows(lapply(files,read.csv2))
  param <- param[!duplicated(param$names),]
}

#Def param groups and unambiguous patterns 
param_groups <- 
  data.frame(group_pattern = c("[^e]._matrices","reduced","solutions","assumptions"),
             object = c("matrices","reduced_matrices","sea_variables","assumptions"))

for(i in 1:nrow(param_groups)){
  a <- load_parameters(param_groups$group_pattern[i])
  assign(param_groups$object[i],a)
  print(paste0("Loaded ",param_groups$object[i]," parameters"))
}


# sectors definitions ----
# according to the method
sectors <- 
  read.csv2(paste0(method_path,"_sectors.csv"))