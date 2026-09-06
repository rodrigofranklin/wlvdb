# control variables

lists <- NULL
nums <- NULL

# Source labels must come from the same normalized generation as SEA and m_io.
if (
  is.null(wlv_data$source_sea) ||
    !is.character(wlv_data$source_sea) ||
    length(wlv_data$source_sea) != 1L ||
    is.na(wlv_data$source_sea) ||
    !file.exists(wlv_data$source_sea)
) {
  stop("The validated normalized source generation is unavailable.", call. = FALSE)
}
srcdata_path <- dirname(normalizePath(
  wlv_data$source_sea,
  winslash = "/",
  mustWork = TRUE
))

# load country list
countries <- 
  read.csv2(file = 
              file.path(srcdata_path, "countries.csv"),
            row.names = NULL, check.names = F)

lists$countries <-  countries$country.source
nums$countries <- length(lists$countries)
# append sectors
lists$sectors <- sectors$sector.source
nums$sectors <- length(lists$sectors)

# identify rows
rows <- data.frame(country = rep(lists$countries, each = nums$sectors))
rows$sector <- lists$sectors

rows$productive <- sectors$productive
rows$num_country <- match(rows$country, countries$country.source)
rows$num_sector <- match(rows$sector, sectors$sector.source)
rows$country_sector <- paste0(rows$country,".",rows$sector)

nums$countries_sectors <- nums$countries*nums$sectors

# load demands list
demands <-
  read.csv2(file.path(srcdata_path, "demand.csv"))
nums$demands <- dim(demands)[1]

# identify columns
columns <- data.frame(country = c(rows$country, 
                               rep(lists$countries, each = nums$demands)))
columns$sector <- c(rows$sector, rep(demands$demand, times = nums$countries))
columns$num_country <- match(columns$country, countries$country.source)
columns$country_sector <- paste0(columns$country,".",columns$sector)

# Define parameters lists
lists$years <- names(sea_source[,1,1,1])
lists$input <- rows$country_sector
lists$output <- columns$country_sector
nums$years <- length(lists$years)
nums$input <- length(lists$input)
nums$output <- length(lists$output)

