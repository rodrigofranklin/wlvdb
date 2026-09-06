# labour values per unit of output
# (i.e., per $ 1.00 of each sector)
code <- "value.m.mv"

meta_indicators[code,"name"] <- "Average value per unit of output"
meta_indicators[code,"description"] <- 
  paste0("Average value per unit of output represents the abstract productive ",
         "labour embodied per $1.00 of each sector.")
meta_indicators[code,"observation"] <- NA
meta_indicators[code,"type"] <- "value"
meta_indicators[code,"group"] <- "Product"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[lists$years,code,,] <- lambda
