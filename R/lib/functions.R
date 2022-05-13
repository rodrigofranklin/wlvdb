newDim <- function(x, dimensions) {
  # return a variable with changed dimensions
  dim(x) <- dimensions
  return(x)
}

clean <- function(x) {
  # eliminates NaN, NA and Inf of a variable
  x[is.nan(x)] <- 0
  x[is.na(x)] <- 0
  x[is.infinite(x)] <- 0
  return(x)
}

cnames <- function(a,b) {
  #match column named "names"  from a and b
  match(a$names,b$names)
}

read_fst_array <- function(file_name) {
  
  ft <- fst::read_fst(file_name)  # single column data.frame
  meta_data <- readRDS(paste0(file_name, ".meta"))  # retrieve dim
  
  m <- ft[[1]]  
  attr(m, "dim") <- meta_data$dim
  dimensiones <- length(meta_data$dim)
  meta_data <- meta_data[2:(dimensiones+1)]
  # lapply(1:dimensiones,function(d,f) {
  #   dimnames(f)[[d]] <- meta_data[[d]]
  # })
  dimnames(m) <- meta_data
  
  m
}

write_fst_array <- function(m, file_name) {
  
  # store and remove dims attribute
  dim <- attr(m, "dim")
  
  meta_data <- list(
    dim = dim
  )
  for (i in 1:length(dim)){
    meta_data[[i+1]] <- dimnames(m)[[i]]
  }
  
  # serialize tale and meta data
  attr(m, "dim") <- NULL
  fst::write_fst(data.frame(Data = m), file_name)
  saveRDS(meta_data, paste0(file_name, ".meta"))
}