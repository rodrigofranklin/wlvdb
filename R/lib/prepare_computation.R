# load raw m_io data
m_io_source <- 
  readRDS(file = current_m_io)

# Adjusts lists$years and nums$years to the years in m_io_source
lists$years <- unlist(dimnames(m_io_source)[1])
nums$years <- length(lists$years)

# assign m_io result variable
# m_io -> input-output matrix of results
m_io <- array(NA,
              dim = c(nums$years,
                      nums$m_io_variables,
                      nums$countries_sectors,
                      nums$output),
              dimnames = list(lists$years,
                              lists$m_io_variables,
                              rows$country_sector,
                              lists$output))
