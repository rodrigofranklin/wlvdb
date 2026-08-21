wlv_dependency_groups <- list(
  runtime = c(
    "abind", "countrycode", "dplyr", "fst", "jsonlite", "lubridate",
    "magrittr", "Matrix", "openssl", "readr", "rvest", "tidyr", "xml2"
  ),
  preparation = c("R.matlab", "readODS", "readxl", "WDI"),
  papers = c(
    "forcats", "ggplot2", "ggthemes", "hrbrthemes", "MLmetrics", "REdaS",
    "scales", "tibble", "writexl"
  )
)

wlv_require_packages <- function(
    packages,
    attach = TRUE,
    checker = function(package) requireNamespace(package, quietly = TRUE)) {
  packages <- unique(packages)
  available <- vapply(packages, checker, logical(1))
  missing <- packages[!available]

  if (length(missing)) {
    stop(
      paste0(
        "Missing R packages: ", paste(missing, collapse = ", "), ".\n",
        "Run `Rscript --vanilla scripts/bootstrap.R` from the repository root."
      ),
      call. = FALSE
    )
  }

  if (isTRUE(attach)) {
    invisible(lapply(packages, function(package) {
      suppressPackageStartupMessages(
        library(package, character.only = TRUE)
      )
    }))
  }

  invisible(packages)
}

wlv_assert_dependencies <- function(
    include_preparation = FALSE,
    include_papers = FALSE,
    attach = TRUE,
    checker = function(package) requireNamespace(package, quietly = TRUE)) {
  groups <- "runtime"
  if (isTRUE(include_preparation)) {
    groups <- c(groups, "preparation")
  }
  if (isTRUE(include_papers)) {
    groups <- c(groups, "papers")
  }

  packages <- unique(unlist(wlv_dependency_groups[groups], use.names = FALSE))
  wlv_require_packages(packages, attach = attach, checker = checker)
}
