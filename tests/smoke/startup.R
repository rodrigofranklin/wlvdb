`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- if (length(script_arg)) {
  sub("^--file=", "", script_arg[[1]])
} else {
  sys.frame(1)$ofile %||% "tests/smoke/startup.R"
}
repo_root <- normalizePath(file.path(dirname(script_path), "../.."), mustWork = TRUE)

Sys.setenv(RENV_PROJECT = repo_root)
source(file.path(repo_root, "renv", "activate.R"), local = TRUE)

profile_path <- file.path(repo_root, ".Rprofile")
project_path <- file.path(repo_root, "worldlabourvalues.Rproj")

profile <- readLines(profile_path, warn = FALSE, encoding = "UTF-8")
project <- readLines(project_path, warn = FALSE, encoding = "UTF-8")

forbidden <- c(
  "install\\.packages\\s*\\(",
  "update\\.packages\\s*\\(",
  "download\\.file\\s*\\(",
  "system2?\\s*\\(",
  "Sys\\.umask\\s*\\(",
  "makeCluster\\s*\\(",
  "git[[:space:]]+pull",
  "started"
)

stopifnot(
  !any(vapply(forbidden, grepl, logical(1), x = paste(profile, collapse = "\n"),
              perl = TRUE, ignore.case = TRUE)),
  "RestoreWorkspace: No" %in% project,
  "SaveWorkspace: No" %in% project,
  "AlwaysSaveHistory: No" %in% project
)

invisible(parse(profile_path, encoding = "UTF-8"))
bootstrap_path <- file.path(repo_root, "R", "bootstrap.R")
invisible(parse(bootstrap_path, encoding = "UTF-8"))
bootstrap_environment <- new.env(parent = baseenv())
sys.source(bootstrap_path, envir = bootstrap_environment)
definition_files <- bootstrap_environment$wlv_runtime_definition_files(repo_root)
invisible(lapply(definition_files, parse, encoding = "UTF-8"))

status_before_runtime <- system2(
  "git",
  c("-C", shQuote(repo_root), "status", "--porcelain=v1"),
  stdout = TRUE,
  stderr = TRUE
)
search_before_runtime <- search()
working_directory_before_runtime <- getwd()
runtime <- bootstrap_environment$wlv_load_runtime(repo_root)
status_after_runtime <- system2(
  "git",
  c("-C", shQuote(repo_root), "status", "--porcelain=v1"),
  stdout = TRUE,
  stderr = TRUE
)
stopifnot(
  identical(status_before_runtime, status_after_runtime),
  identical(search(), search_before_runtime),
  identical(getwd(), working_directory_before_runtime),
  identical(parent.env(runtime), baseenv()),
  environmentIsLocked(runtime),
  is.function(runtime$prepare_wlv),
  is.function(runtime$get_wlv),
  is.function(runtime$recalc_wlv)
)

status_before <- status_after_runtime
source(profile_path, local = new.env(parent = baseenv()), encoding = "UTF-8")
status_after <- system2("git", c("-C", shQuote(repo_root), "status", "--porcelain=v1"),
                        stdout = TRUE, stderr = TRUE)

stopifnot(identical(status_before, status_after))

sandbox <- tempfile("wlvdb-startup-")
dir.create(sandbox)
on.exit(unlink(sandbox, recursive = TRUE, force = TRUE), add = TRUE)
invisible(file.copy(profile_path, file.path(sandbox, ".Rprofile")))
child_script <- file.path(sandbox, "child.R")
writeLines("cat('Real startup passed.\\n')", child_script)

snapshot_files <- function(path) {
  files <- list.files(path, all.files = TRUE, recursive = TRUE,
                      include.dirs = TRUE, no.. = TRUE)
  info <- file.info(file.path(path, files))
  data.frame(path = files, size = info$size, mtime = info$mtime,
             row.names = NULL, check.names = FALSE)
}

sandbox_before <- snapshot_files(sandbox)
old_wd <- setwd(sandbox)
old_profile <- Sys.getenv("R_PROFILE_USER", unset = NA_character_)
on.exit(setwd(old_wd), add = TRUE)
on.exit({
  if (is.na(old_profile)) {
    Sys.unsetenv("R_PROFILE_USER")
  } else {
    Sys.setenv(R_PROFILE_USER = old_profile)
  }
}, add = TRUE)
Sys.setenv(
  R_PROFILE_USER = normalizePath(
    file.path(sandbox, ".Rprofile"),
    winslash = "/"
  )
)
rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
child_output <- system2(
  rscript,
  c("--no-environ", "--no-site-file", "--no-restore", "--no-save",
    shQuote(child_script)),
  stdout = TRUE,
  stderr = TRUE
)
child_status <- attr(child_output, "status") %||% 0L
setwd(old_wd)
if (is.na(old_profile)) {
  Sys.unsetenv("R_PROFILE_USER")
} else {
  Sys.setenv(R_PROFILE_USER = old_profile)
}
sandbox_after <- snapshot_files(sandbox)

if (child_status != 0L) {
  stop(
    paste(
      "The isolated R startup subprocess failed:",
      paste(child_output, collapse = "\n"),
      sep = "\n"
    ),
    call. = FALSE
  )
}
stopifnot(identical(sandbox_before, sandbox_after))

cat("Safe startup smoke test passed.\n")
