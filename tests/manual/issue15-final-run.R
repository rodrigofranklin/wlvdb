# Final-runtime, real-data integration through the public API.
# Rscript --vanilla tests/manual/issue15-final-run.R <frozen-campaign-root>
#   <wiodr13-reference-run> <wiodr16-reference-run> <new-report.json>
# Set TEMP/TMP/TMPDIR to the registered campaign scratch before starting R.
args <- commandArgs(TRUE)
stopifnot(length(args) == 4L, !file.exists(args[[4L]]))
repo <- normalizePath(getwd(), winslash = "/")
root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
stopifnot(startsWith(tolower(root), paste0(tolower(repo), "/temp/")))
report_directory <- normalizePath(dirname(args[[4L]]), winslash = "/", mustWork = TRUE)
stopifnot(startsWith(tolower(report_directory), paste0(tolower(repo), "/temp/")))
args[[4L]] <- file.path(report_directory, basename(args[[4L]]))
Sys.setenv(RENV_PROJECT = repo)
source(file.path(repo, "renv/activate.R"))
bootstrap <- new.env(parent = baseenv())
sys.source(file.path(root, "scripts/runtime_bootstrap.R"), envir = bootstrap)
runtime <- bootstrap$wlv_load_runtime(root)
methods <- c("wiodr13", "wiodr16")
references <- stats::setNames(args[2:3], methods)
hash <- function(path) unname(unclass(as.character(runtime$wlv_publication_file_sha256(path))))
channel <- "validation/issue15-final"
stopifnot(is.null(runtime$wlv_read_current_release(root, channel, required = FALSE)))
report <- list(schema = "wlv-issue15-final-api/1", passed = FALSE,
  root = root, command = commandArgs(), R = R.version.string,
  platform = R.version$platform, channel = channel,
  started_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3%z"), phases = list())
authenticate <- function(path) {
  manifest <- runtime$wlv_read_run_manifest(file.path(path, "run_manifest.json"))
  runtime$wlv_verify_run_manifest(manifest, path, reject_unlisted = TRUE)
  list(run_id = manifest$run_id, run_path = path,
    manifest_sha256 = hash(file.path(path, "run_manifest.json")),
    compatibility = manifest$result$provenance$runtime_compatibility)
}
compare <- function(observed, expected) {
  summary <- list()
  for (name in c("sea_sectors", "sea_countries", "m_countries")) {
    actual <- runtime$read_fst_array(file.path(observed, paste0(name, ".fst")))
    reference <- runtime$read_fst_array(file.path(expected, paste0(name, ".fst")))
    stopifnot(identical(actual, reference))
    summary[[name]] <- list(identical = TRUE, dimensions = dim(actual),
      labels_identical = identical(dimnames(actual), dimnames(reference)),
      na_identical = identical(is.na(actual), is.na(reference)),
      nan_identical = identical(is.nan(actual), is.nan(reference)))
  }
  for (name in c("meta_indicators.RDS", "_unit_contract.csv", "_source_provenance.csv",
      "_parameters.csv", "_leontief_diagnostics.csv", "_gfcf_negative_cells.csv",
      "_gfcf_negative_summary.csv")) {
    stopifnot(identical(hash(file.path(observed, name)), hash(file.path(expected, name))))
    summary[[name]] <- TRUE
  }
  matrices <- list.files(expected, "^m_(io|countries).*[.]fst$", full.names = FALSE)
  stopifnot(length(matrices) >= 2L,
    identical(matrices, list.files(observed, "^m_(io|countries).*[.]fst$", full.names = FALSE)))
  summary$matrices <- lapply(matrices, function(name) {
    actual_path <- file.path(observed, name)
    expected_path <- file.path(expected, name)
    stopifnot(identical(hash(actual_path), hash(expected_path)),
      identical(readRDS(paste0(actual_path, ".meta")), readRDS(paste0(expected_path, ".meta"))))
    list(file = name, payload_sha256 = hash(actual_path), payload_identical = TRUE,
      sidecar_values_identical = TRUE,
      sidecar_bytes_identical = identical(hash(paste0(actual_path, ".meta")),
        hash(paste0(expected_path, ".meta"))))
  })
  actual_states <- readRDS(file.path(observed, "_runtime_resources.rds"))$panel_states
  expected_states <- readRDS(file.path(expected, "_runtime_resources.rds"))$panel_states
  stopifnot(identical(actual_states, expected_states))
  summary$semantic_states_identical <- TRUE
  summary
}
failure <- NULL
tryCatch({
  report$references <- lapply(references, authenticate)
  for (method in methods) {
    reference_manifest <- runtime$wlv_read_run_manifest(
      file.path(references[[method]], "run_manifest.json"))
    stopifnot(identical(reference_manifest$method, method),
      identical(reference_manifest$result$request$mode, "calculate"))
  }
  parents <- NULL
  for (mode in c("calculate", "recalculate")) {
    elapsed <- system.time({
      if (mode == "calculate") {
        runtime$get_wlv(methods, workers = 1L, channel = channel)
      } else {
        runtime$recalc_wlv(methods, at_stage = 4L, workers = 1L,
          sea_vars = c("basket_price.r.pc", "basket_value.r.pc", "gross_output.s.du"),
          channel = channel)
      }
    })[["elapsed"]]
    release <- runtime$wlv_read_current_release(root, channel, required = TRUE)
    runs <- lapply(methods, function(method) {
      run <- runtime$wlv_resolve_method_run_reference(root, method, release)
      stopifnot(identical(run$manifest$result$request$mode, mode))
      if (!is.null(parents)) {
        stopifnot(identical(run$manifest$parent_run_id, parents[[method]]$run_id))
      }
      list(run = authenticate(run$path),
        parent_run_id = run$manifest$parent_run_id,
        comparison = compare(run$path, references[[method]]))
    })
    names(runs) <- methods
    report$phases[[mode]] <- list(elapsed_seconds = unname(elapsed),
      release_id = release$manifest$release_id,
      marker_sha256 = hash(release$marker_path), runs = runs)
    parents <- lapply(runs, function(x) x$run)
    jsonlite::write_json(report, args[[4L]], auto_unbox = TRUE, pretty = TRUE, null = "null")
    message("PASS combined public API ", mode, " elapsed=", elapsed)
  }
  report$passed <- TRUE
}, error = function(e) { failure <<- conditionMessage(e) })
report$error <- failure
report$finished_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3%z")
jsonlite::write_json(report, args[[4L]], auto_unbox = TRUE, pretty = TRUE, null = "null")
if (!is.null(failure)) stop(failure, call. = FALSE)
