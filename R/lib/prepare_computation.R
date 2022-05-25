# load raw m_io data
print("loading m_io file...")
print(current_m_io)
print(ls(1,pattern="rows"))
m_io_source <- 
  read_fst_array(current_m_io)
print("loaded source m_io")
# Adjusts lists$years and nums$years to the years in m_io_source
lists$years <- unlist(dimnames(m_io_source)[1])
nums$years <- length(lists$years)

# Define função paralelizada se houver + de 1 ano.
if (nums$years == 1) {
  myApply <- function (...) {
    apply(...)
  }
} else {
  myApply <- function (...) {
    parApply(cl = my.cluster,...)
  }
}

# assign m_io result variable
# m_io -> input-output matrix of results

m_io <-  array(NA,
                     dim = c(nums$years,
                             nums$m_io_variables,
                             nums$countries_sectors,
                             nums$output),
                     dimnames = list(lists$years,
                                     lists$m_io_variables,
                                     rows$country_sector,
                                     lists$output))
#, envir = 1) 
