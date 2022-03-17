# calculates sea_sectors data
#
# there are 6 moments of variables computations:
#
# 0 - variables directly obtained from raw data
# 1 - variables obtained by computation over raw data
# 2 - assumption variables
# 3 - assumption matrices
# 4 - variables obtained from transformed m_io
# 5 - variables obtained by computation over SEA results

if (stage == 1) {
  # Copy  order 0 variables , adjusting scale as specified in parameters
  # Copy variables from sea_source to sea_sectors (indicated in parameters)
  for (loop in grep(".R", sea_variables$sector_solution, invert = TRUE)) {
    temp <- unlist(strsplit(sea_variables$sector_solution[loop], "[*]"))
    sea_sectors[, loop, lists$sectors, lists$countries] <- 
      sea_source[, temp[1], lists$sectors, lists$countries]
  }
  
  # Changes scale of variables when indicated in parameters
  for (loop in grep("[*]", sea_variables$sector_solution)) {
    temp <- unlist(strsplit(sea_variables$sector_solution[loop], "[*]"))
    sea_sectors[,loop,lists$sectors,lists$countries] <- 
      sea_sectors[,loop,lists$sectors,lists$countries] *
      as.numeric(temp[2])
  }
  
  rm(temp)
}

# preliminary computation of order 1
for (loop in sea_variables$sector_solution[which(sea_variables$order==stage)]) {
  print(paste0("Sourcing from stage ",stage," script ",gsub(".*/","",loop)))
  source(paste0("R/modules/variables/",loop))
  sea_sectors <- clean(sea_sectors)
}

rm(loop)
