# make filters to read IO matrix

## parameters definitions ----
lists$filters <- c("countries",
                   "productive_sectors",
                   "trade",
                   "imports")
nums$filters <- length(lists$filters)


## assign variables ----
m_io_filters <- array(0,
                      dim = c(nums$filters,
                              nums$input,
                              nums$output),
                      dimnames = list(lists$filters,
                                      lists$input,
                                      lists$output))

## country filters ----
# This matrix is to be used as an index of tapply functions. 
# Create a matrix where each cell is a number in X.Y format, where
# the integer part (X) is the number of the country of the column, and 
# the decimal part (Y) is the number of the country of the row.
country_cols_matrix <- t(rep(columns$num_country, each = nums$input))
dim(country_cols_matrix) <- c(nums$input, nums$output)

country_rows_matrix <- rep(rows$num_country, times = nums$output)
dim(country_rows_matrix) <- c(nums$input, nums$output)

m_io_filters["countries",1:nums$input,1:nums$output] <- 
  country_cols_matrix+(country_rows_matrix/1000)

## productive sectors filters ----
# Multiplication filter: when multiplying this filter by an matrix
# containing data from all sectors, a matrix containing only the 
# data from the productive sectors is generated.
m_io_filters["productive_sectors",rows$productive==1,] <- 1

## International trade filter ----
# Multiplication filter to eliminate national trade
m_io_filters["trade",
             1:nums$input,
             1:nums$output
             ][(country_cols_matrix - country_rows_matrix)!=0] <- 1

## Import filters ----
# This matrix is to be used as an index of tapply functions. 
# Create a matrix where each cell is a number in X.Y format, where
# the integer part (X) is the number of the country of the column, and 
# the decimal part (Y) is the number of the sector of the row.
sector_rows_matrix <- rep(rows$num_sector, times = nums$output)
dim(sector_rows_matrix) <- c(nums$input, nums$output)

m_io_filters["imports",1:nums$input,1:nums$output] <- 
  country_cols_matrix+(sector_rows_matrix/1000)

rm(country_cols_matrix, country_rows_matrix, sector_rows_matrix)
