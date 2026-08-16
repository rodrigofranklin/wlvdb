# load raw m_io data
print("loading m_io file...")
print(current_m_io)
print(ls(1,pattern="rows"))
m_io_source <- read_fst_array(current_m_io)
wlv_canonical_gfcf_observations <- NULL
if (
  exists("source_version", inherits = TRUE) &&
  source_version %in% c("wiodr13", "wiodr16")
) {
  if (!exists(
    "wlv_wiodr_canonical_gfcf_diagnostic_observations",
    mode = "function"
  )) {
    source("R/lib/gfcf_contracts.R")
  }
  # Preserve the reviewed million-USD doubles before the accounting array is
  # scaled to USD. Multiplying and dividing by 1e6 changes some WIOD16 values
  # by one ULP, which must not redefine the source-level scientific pin.
  wlv_canonical_gfcf_observations <-
    wlv_wiodr_canonical_gfcf_diagnostic_observations(
      m_io_source,
      method = source_version
    )
}
m_io_source <- m_io_source * 1000000
print("loaded source m_io")
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
