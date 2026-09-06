print(paste0("loading raw data from ",source_version,"..."))

if (
  is.null(wlv_data$source_sea) ||
    !is.character(wlv_data$source_sea) ||
    length(wlv_data$source_sea) != 1L ||
    is.na(wlv_data$source_sea) ||
    !file.exists(wlv_data$source_sea)
) {
  stop("The validated source SEA artifact is missing.", call. = FALSE)
}
sea_source <- read_fst_array(wlv_data$source_sea)
