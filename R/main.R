###############################################################################.
#                                                                              #
#       World Labour Values Database  - studies on the reduction problem       #
#                                                                              #
###############################################################################.

# installing and loading required packages
packages <- c("dplyr",
              "magrittr",
              "R.matlab",
              "writexl",
              "readxl",
              "doParallel",
              "abind")

.libPaths(c(.libPaths(),"./library"))

install.packages(setdiff(packages, rownames(installed.packages())),
                 repos = "https://cloud.r-project.org/",
                 lib = "./library")  

library(dplyr)
library(magrittr)
library(R.matlab)
library(writexl)
library(readxl)
library(doParallel)
library(abind)
source("R/lib/functions.R")
# Prepare WIOD ----

# source("R/utils/prepare_wiod_data.R")

# Prepare EUKLEMS ----
source("R/utils/prepare_euklems_data.R")

# Versions computations ----

method_list <- c(
  "ochoa_1",
  "ochoa_2",
  "petrovic",
  "alternative_1",
  "alternative_2"
  )

my.cluster <- parallel::makeCluster(
  parallel::detectCores() - 1, 
  type = "PSOCK"
)

for (method_version in method_list) {
  print(paste0("Calculating ", method_version,"..."))
  source("R/lib/computations.R")
}

stopCluster(cl = my.cluster)
closeAllConnections()

# Select and save ----

source("R/utils/paper_selection.R")

rm(consumption_basket)

gc()
