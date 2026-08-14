script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_arg)) {
  stop("Run this file with Rscript.", call. = FALSE)
}

script_path <- normalizePath(sub("^--file=", "", script_arg[[1]]), mustWork = TRUE)
project_root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
setwd(project_root)

options(repos = c(CRAN = "https://cloud.r-project.org"))

message("Activating the renv version pinned by the project...")
source(file.path("renv", "activate.R"), local = TRUE)
message("Restoring the project library from renv.lock...")
renv::consent(provided = TRUE)
renv::restore(project = project_root, prompt = FALSE)
message("The project library is synchronized.")
