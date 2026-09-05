# Narrow correction for the checkpoint-bearing scenario envelope. The frozen
# authentication logic is retained; checkpoint evidence is added, not discarded.
wlv13_main_preparation_checkpoint <- function(report, plan_record) {
  require <- wlv_gate_prep_require
  same <- wlv_gate_prep_same_path
  proof <- report$execution_checkpoint
  fields <- c("scenario_spec_path", "scenario_spec_sha256",
    "started_marker_path", "started_marker_sha256", "checkpoint_path",
    "checkpoint_sha256")
  require(is.list(proof) && setequal(names(proof), fields),
    "Preparation checkpoint envelope is invalid.")
  checkpoint_path <- plan_record$checkpoint_path
  started_path <- sub("[.]json$", ".started.json", checkpoint_path)
  paths <- c(scenario_spec = plan_record$scenario_spec_path,
    started_marker = started_path, checkpoint = checkpoint_path)
  for (name in names(paths)) {
    require(same(proof[[paste0(name, "_path")]], paths[[name]]) &&
        identical(wlv13_sha256_file(paths[[name]]), proof[[paste0(name, "_sha256")]]),
      paste("Preparation checkpoint path/hash mismatch:", name))
  }
  require(identical(proof$scenario_spec_sha256, plan_record$scenario_spec_sha256),
    "Preparation checkpoint does not match the audited scenario.")
  checkpoint <- wlv13_json_read(checkpoint_path, simplify = FALSE)
  started <- wlv13_json_read(started_path, simplify = FALSE)
  require(identical(checkpoint$schema, "wlv-issue13-execution-checkpoint/2") &&
      identical(checkpoint$status, "finished") &&
      identical(started$schema, "wlv-issue13-execution-started/1") &&
      identical(started$status, "started") && is.null(checkpoint$error),
    "Preparation checkpoint is not a completed successful execution.")
  expected_request <- c(list(scenario_spec_path = proof$scenario_spec_path,
      scenario_spec_sha256 = proof$scenario_spec_sha256, kind = report$kind),
    report$request, list(seed = report$seed))
  for (record in list(started, checkpoint)) {
    require(identical(record$scenario_id, report$scenario_id) &&
        same(record$project_root, report$project_root) &&
        identical(record$expected_commit, report$expected_commit) &&
        same(record$scenario_spec_path, proof$scenario_spec_path) &&
        identical(record$scenario_spec_sha256, proof$scenario_spec_sha256) &&
        identical(record$request, expected_request) &&
        identical(record$started_at, report$started_at) &&
        identical(record$publication_before, report$publication_before) &&
        identical(record$source_before, report$source_before),
      "Preparation checkpoint identity/request/initial state mismatch.")
  }
  require(same(checkpoint$started_marker_path, started_path) &&
      identical(checkpoint$started_marker_sha256, proof$started_marker_sha256) &&
      identical(checkpoint$outputs, report$outputs) &&
      identical(checkpoint$source_after, report$source_after) &&
      identical(checkpoint$publication_after, report$publication_after) &&
      identical(checkpoint$elapsed_seconds, report$elapsed_seconds),
    "Preparation checkpoint outcome differs from its scenario report.")
  invisible(TRUE)
}

wlv13_main_install_preparation_auth <- function(namespace) {
  fun <- namespace$wlv_gate_prep_authenticate_execution
  statements <- as.list(body(fun))
  assignment <- which(vapply(statements, function(value) {
    is.call(value) && identical(value[[1L]], as.name("<-")) &&
      identical(value[[2L]], as.name("required_report"))
  }, logical(1L)))
  stopifnot(length(assignment) == 1L)
  index <- assignment[[1L]]
  expected <- c("schema", "scenario_id", "status", "passed", "kind", "project_root",
    "expected_commit", "observed_commit", "started_at", "finished_at",
    "elapsed_seconds", "request", "outputs", "seed", "publication_before",
    "publication_after", "source_before", "source_after", "error")
  stopifnot(identical(eval(statements[[index]][[3L]], baseenv()), expected))
  statements[[index]][[3L]] <- substitute(c(FIELDS, "execution_checkpoint"),
    list(FIELDS = expected))
  statements <- append(statements,
    list(quote(wlv13_main_preparation_checkpoint(report, plan_record))), after = index)
  body(fun) <- as.call(statements)
  environment(fun) <- namespace
  checker <- wlv13_main_preparation_checkpoint
  environment(checker) <- namespace
  namespace$wlv13_main_preparation_checkpoint <- checker
  namespace$wlv_gate_prep_authenticate_execution <- fun
  invisible(TRUE)
}
