arguments <- commandArgs(trailingOnly = TRUE)
stopifnot(length(arguments) == 4L)
support <- normalizePath(arguments[[1L]], winslash = "/", mustWork = TRUE)
plan <- jsonlite::read_json(arguments[[2L]], simplifyVector = FALSE)
library_path <- arguments[[3L]]
output <- arguments[[4L]]
stopifnot(!file.exists(output))
script_path <- file.path(support, "issue13-preparation-compare.R")
for (path in c("issue13-prep-paper-lib.R", "issue13-evidence-harness/issue13-lib.R",
    "issue13-preparation-auth-lib.R")) {
  sys.source(file.path(support, path), envir = environment())
}
self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])
sys.source(file.path(dirname(self), "issue13-main-preparation-auth.R"),
  envir = environment())
checks <- list()
reject <- function(label, expression) {
  failed <- tryCatch({force(expression); FALSE}, error = function(e) TRUE)
  stopifnot(failed)
  checks[[label]] <<- TRUE
}
records <- plan$records[1:2]
for (record in records) {
  arm <- sub("/.*", "", record$scenario_id)
  path <- file.path(record$evidence_directory, "scenario-result.json")
  reject(paste0(arm, "/old-envelope-reproduced"),
    wlv_gate_prep_authenticate_execution(path, arm, record$project_root,
      record$expected_commit, record))
}
wlv13_main_install_preparation_auth(environment())
for (record in records) {
  arm <- sub("/.*", "", record$scenario_id)
  path <- file.path(record$evidence_directory, "scenario-result.json")
  result <- wlv13_json_read(path, simplify = FALSE)
  proof <- wlv_gate_prep_authenticate_execution(path, arm, record$project_root,
    record$expected_commit, record)
  stopifnot(isTRUE(proof$passed))
  checks[[paste0(arm, "/execution")]] <- TRUE
  metrics <- wlv_gate_prep_authenticate_metrics(
    file.path(record$evidence_directory, "process-metrics.json"), arm,
    record$project_root, record$expected_commit, library_path, record)
  stopifnot(isTRUE(metrics$passed))
  checks[[paste0(arm, "/metrics")]] <- TRUE
  for (field in c("scenario_spec_sha256", "started_marker_sha256", "checkpoint_sha256")) {
    bad <- result
    bad$execution_checkpoint[[field]] <- paste(rep("0", 64L), collapse = "")
    reject(paste(arm, field, sep = "/"), wlv13_main_preparation_checkpoint(bad, record))
  }
  bad <- result
  bad$execution_checkpoint <- NULL
  reject(paste0(arm, "/missing-proof"), wlv13_main_preparation_checkpoint(bad, record))
  bad <- result
  bad$request$workers <- 2L
  reject(paste0(arm, "/misbound-request"), wlv13_main_preparation_checkpoint(bad, record))
  bad <- result
  bad$outputs[[1L]]$manifest_sha256 <- paste(rep("0", 64L), collapse = "")
  reject(paste0(arm, "/changed-output"), wlv13_main_preparation_checkpoint(bad, record))
  bad <- result
  bad$execution_checkpoint$extra <- TRUE
  reject(paste0(arm, "/extra-proof-field"), wlv13_main_preparation_checkpoint(bad, record))
}
wlv_gate_write_json(list(passed = TRUE, checks = checks, count = length(checks)), output)
cat("Preparation authentication regression passed:", length(checks), "checks\n")
