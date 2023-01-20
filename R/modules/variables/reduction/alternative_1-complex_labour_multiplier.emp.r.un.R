## Solution to the reduction problem.
## Alternative 1: all labour is considered simple
code <- "complex_labour_multiplier.emp.r.un"

meta_indicators[code,"name"] <- "Complex labour multiplier"
meta_indicators[code,"description"] <- 
  paste0("Multiplier of labour accordingly it's complexty and intensity.")
meta_indicators[code,"observation"] <- 
  paste0("Reduction Problem: Alternative 1: all labour are treated as equal.")
meta_indicators[code,"type"] <- "index"
meta_indicators[code,"group"] <- "Others"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[,code,,] <- 1
