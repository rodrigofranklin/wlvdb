## assign results variables

## Define parameters ----
lists$m_io_variables <- matrices$names
lists$m_countries_variables <- reduced_matrices$names
lists$sea_variables <- sea_variables$names

nums$m_io_variables <- length(lists$m_io_variables)
nums$m_countries_variables <- length(lists$m_countries_variables)
nums$sea_variables <- length(lists$sea_variables)

## assign variables  ----

# m_countries -> country x country matrix
m_countries <- array(NA,
                  dim = c(nums$years,
                          nums$m_countries_variables,
                          nums$countries,
                          nums$countries),
                  dimnames = list(lists$years,
                                  lists$m_countries_variables,
                                  lists$countries,
                                  lists$countries))
# sea_sectors -> vectors of results per sector
sea_sectors <- array(NA,
                     dim = c(nums$years,
                             nums$sea_variables,
                             nums$sectors,
                             nums$countries),
                     dimnames = list(lists$years,
                                     lists$sea_variables,
                                     lists$sectors,
                                     lists$countries))
# sea_countries -> vectors of results per country
# Obs: a 'Whole Wide World' (WWW) is added
sea_countries <- array(NA,
                    dim = c(nums$years,
                            nums$sea_variables,
                            nums$countries+1),
                    dimnames = list(lists$years,
                                    lists$sea_variables,
                                    c(lists$countries,"WWW")))

# Creates folder in "results"
dir.create(paste0("results/",method_version), showWarnings = FALSE)

# Save infos
write.csv2(parameters,paste0("results/",method_version,"/_parameters.csv"),
           row.names = FALSE)
