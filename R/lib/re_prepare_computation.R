# load raw m_io data
print("loading m_io files...")

m_io <- 
  read_fst_array(lists$m_io_results_files[current_m_io])

m_io_source <- 
  read_fst_array(lists$m_io_source_files[current_m_io])

print("loaded m_io files")

# Adjusts lists$years and nums$years to the years in m_io_source
lists$years <- unlist(dimnames(m_io_source)[1])
nums$years <- length(lists$years)

# Define função paralelizada se houver + de 1 ano.
if (is.null(my.cluster) || nums$years == 1) {
  myApply <- function (...) {
    base::apply(...)
  }
} else {
  myApply <- function (...) {
    parallel::parApply(cl = my.cluster, ...)
  }
}

# Assign intermediate variables
lambda <- 
  sea_sectors[lists$years,"value.m.mv",,] %>% 
  newDim(c(nums$years, nums$input))

a <- nums$years
d1 <- nums$input
d2 <- nums$output
x <- 1:d1
y <- 1:d2
balance_factor <- 
  (m_io[,"values",x,y] * 
     (m_io_filters["trade",x,y] %>% rep(each = nums$years))) %>%
  newDim(c(a, d1, d2)) %>%
  apply (1, sum, na.rm = TRUE) /
  (m_io_source[,x,y] *
     ((m_io_filters["trade",x,y] * 
         m_io_filters["productive_sectors",x,y]) %>% rep(each = nums$years))) %>%
  newDim(c(a, d1, d2)) %>%
  apply (1, sum, na.rm = TRUE)

rm(a,d1,d2,x,y)
