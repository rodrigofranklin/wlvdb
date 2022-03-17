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
