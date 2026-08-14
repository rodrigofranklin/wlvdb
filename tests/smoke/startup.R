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
invisible(parse(file.path(repo_root, "R/main.R"), encoding = "UTF-8"))

status_before <- system2("git", c("-C", shQuote(repo_root), "status", "--porcelain=v1"),
                         stdout = TRUE, stderr = TRUE)
source(profile_path, local = new.env(parent = baseenv()), encoding = "UTF-8")
status_after <- system2("git", c("-C", shQuote(repo_root), "status", "--porcelain=v1"),
                        stdout = TRUE, stderr = TRUE)

stopifnot(identical(status_before, status_after))

sandbox <- tempfile("wlvdb-startup-")
dir.create(sandbox)
on.exit(unlink(sandbox, recursive = TRUE, force = TRUE), add = TRUE)
invisible(file.copy(profile_path, file.path(sandbox, ".Rprofile")))

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
    "-e", shQuote("cat('Real startup passed.\\n')")),
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

stopifnot(child_status == 0L, identical(sandbox_before, sandbox_after))

cat("Safe startup smoke test passed.\n")
