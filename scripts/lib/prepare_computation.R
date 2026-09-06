# load raw m_io data
print("loading m_io file...")
print(current_m_io)
print(ls(1,pattern="rows"))
m_io_source <- read_fst_array(current_m_io)
wlv_canonical_gfcf_observations <- NULL
if (!is.null(wlv_data$gfcf_observations)) {
  wlv_canonical_gfcf_observations <- if (
    is.character(wlv_data$gfcf_observations) &&
      length(wlv_data$gfcf_observations) == 1L &&
      !is.na(wlv_data$gfcf_observations)
  ) {
    if (!file.exists(wlv_data$gfcf_observations)) {
      stop("Canonical GFCF diagnostic observations are missing.", call. = FALSE)
    }
    readRDS(wlv_data$gfcf_observations)
  } else {
    wlv_data$gfcf_observations
  }
  if (!is.data.frame(wlv_canonical_gfcf_observations)) {
    stop(
      "Canonical GFCF diagnostic observations must be a data frame.",
      call. = FALSE
    )
  }
}
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
