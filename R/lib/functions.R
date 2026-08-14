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

wlv_wiodr13_euklems_country_codes <- function(countries) {
  countrycode::countrycode(
    countries,
    origin = "iso3c",
    destination = "iso2c",
    custom_match = c(
      GBR = "UK",
      GRC = "EL",
      ROW = NA_character_
    )
  )
}

wlv_distribute_capital_stock <- function(weights, capital_stock) {
  if (!is.matrix(weights) || !is.numeric(weights)) {
    stop("`weights` must be a numeric matrix.", call. = FALSE)
  }
  if (
    !is.numeric(capital_stock) ||
    length(capital_stock) != ncol(weights) ||
    anyNA(capital_stock) ||
    any(!is.finite(capital_stock))
  ) {
    stop(
      "`capital_stock` must contain one finite number per weight column.",
      call. = FALSE
    )
  }

  totals <- colSums(weights)
  invalid_columns <- !is.finite(totals) | totals == 0
  distribution <- sweep(weights, 2L, totals, "/")
  distribution[, invalid_columns] <- 0
  distribution[!is.finite(distribution)] <- 0
  result <- sweep(distribution, 2L, capital_stock, "*")
  attr(result, "wlv.unallocated_columns") <- which(
    invalid_columns & capital_stock != 0
  )
  result
}

wlv_sum_input_flows <- function(intermediate_consumption, depreciation) {
  clean(intermediate_consumption) + clean(depreciation)
}

cnames <- function(a,b) {
  #match column named "names"  from a and b
  match(a$names,b$names)
}

read_fst_array <- function(file_name) {
  
  ft <- fst::read_fst(file_name)  # single column data.frame
  metaf <- paste0(file_name, ".meta")
  if(file.exists(metaf)) {
  meta_data <- readRDS(metaf)  # retrieve dim
  
  m <- ft[[1]]  
  attr(m, "dim") <- meta_data$dim
  dimensiones <- length(meta_data$dim)
  meta_data <- meta_data[2:(dimensiones+1)]
  # lapply(1:dimensiones,function(d,f) {
  #   dimnames(f)[[d]] <- meta_data[[d]]
  # })
  dimnames(m) <- meta_data
  
  m} else {
    ft
  }
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

convert_array_RDS <- function(nomebase) {
  nrds <- paste0(nomebase,".rds")
  print(paste("Converting",nrds))
  t <- readRDS(nrds)
  if(class(t) == "array"){
    print("This is an array object")
  write_fst_array(t,paste0(nomebase,".fst"))
  } else {
    write_fst(t,paste0(nomebase,".fst"))
  }
  rm(t)
  gc()
}
