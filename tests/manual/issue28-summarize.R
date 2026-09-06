# Read-only consolidation of the 18 scientific scenarios. Each original report
# remains immutable; this audit binds it to its run manifest and verifies the
# lineage, declared requests and inherited artifact hashes for the entire chain.
# Run from the main repository with campaign TEMP/TMP/TMPDIR already configured:
# Rscript --vanilla tests/manual/issue28-summarize.R <campaign> <new-report.json>
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L, !file.exists(args[[2L]]))
campaign <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
repo <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
stopifnot(startsWith(tolower(campaign), paste0(tolower(repo), "/temp/")))
source(file.path(repo, "renv", "activate.R"))
root <- file.path(campaign, "worktrees", "candidate")
boot <- new.env(parent = baseenv())
sys.source(file.path(root, "scripts", "runtime_bootstrap.R"), envir = boot)
runtime <- boot$wlv_load_runtime(root)
hash <- runtime$wlv_publication_file_sha256
read_json <- function(path) jsonlite::read_json(path, simplifyVector = FALSE)
lock <- read_json(file.path(root, "renv.lock"))
scenarios <- list(
  full1 = list(mode = "calculate", stage = NULL, workers = 1L, vars = NULL),
  `stage1-full1` = list(mode = "recalculate", stage = 1L, workers = 1L, vars = NULL),
  `stage4-full1` = list(mode = "recalculate", stage = 4L, workers = 1L, vars = NULL),
  `stage4-full2` = list(mode = "recalculate", stage = 4L, workers = 2L, vars = NULL),
  `stage5-full1` = list(mode = "recalculate", stage = 5L, workers = 1L, vars = NULL),
  `stage4-baskets1` = list(mode = "recalculate", stage = 4L, workers = 1L,
    vars = c("basket_price.r.pc", "basket_value.r.pc")),
  `stage4-baskets2` = list(mode = "recalculate", stage = 4L, workers = 2L,
    vars = c("basket_price.r.pc", "basket_value.r.pc")),
  `stage5-select1` = list(mode = "recalculate", stage = 5L, workers = 1L,
    vars = "gross_output.s.du"),
  `stage5-select2` = list(mode = "recalculate", stage = 5L, workers = 2L,
    vars = "gross_output.s.du")
)
artifact_map <- function(manifest) setNames(
  vapply(manifest$artifacts, `[[`, "", "sha256"),
  vapply(manifest$artifacts, `[[`, "", "path"))
summary <- list()
models <- list()
for (method in c("wiodr13", "wiodr16")) {
  previous <- NULL
  full_manifest <- NULL
  full_artifacts <- NULL
  for (scenario in names(scenarios)) {
    expected <- scenarios[[scenario]]
    report_path <- file.path(campaign, "results", paste0(method, "-", scenario, ".json"))
    report <- read_json(report_path)
    manifest_path <- file.path(report$run_path, "run_manifest.json")
    manifest <- read_json(manifest_path)
    stopifnot(isTRUE(report$passed), isTRUE(manifest$result$provenance$complete),
      identical(hash(manifest_path), report$manifest_sha256),
      identical(manifest$run_id, report$run_id),
      identical(manifest$parent_run_id, previous),
      identical(manifest$result$request$mode, expected$mode),
      identical(manifest$result$request$method, method),
      identical(manifest$result$request$at_stage, expected$stage),
      identical(manifest$result$request$workers, expected$workers),
      identical(unlist(manifest$result$request$sea_vars), expected$vars),
      all(vapply(report$checks, isTRUE, logical(1L))))
    artifacts <- artifact_map(manifest)
    if (is.null(full_manifest)) {
      full_manifest <- manifest
      full_artifacts <- artifacts
      panels <- lapply(c("sea_sectors", "sea_countries"), function(name) {
        value <- runtime$read_fst_array(file.path(report$run_path, paste0(name, ".fst")))
        list(panel = name, dimensions = dim(value), cells = length(value),
          na_cells_including_nan = sum(is.na(value)), nan_cells = sum(is.nan(value)))
      })
      package_checks <- lapply(manifest$result$provenance$packages, function(package) {
        pinned <- lock$Packages[[package$name]]
        matches <- if (is.null(pinned)) NULL else {
          package_version(package$version) == package_version(pinned$Version)
        }
        stopifnot(is.null(matches) || isTRUE(matches))
        list(name = package$name, version = package$version,
          lock_version = if (is.null(pinned)) NULL else pinned$Version,
          matches_lock_version = matches)
      })
      historical_path <- file.path(campaign, "results", if (method == "wiodr13") {
        "wiodr13-full-to-054-v3.json"
      } else "wiodr16-full-to-054.json")
      historical <- read_json(historical_path)
      archive_path <- file.path(repo, historical$full$path, "run_manifest.json")
      archive <- read_json(archive_path)
      stopifnot(identical(hash(archive_path), historical$full$manifest_sha256),
        identical(historical$recalculated$manifest_sha256, report$manifest_sha256),
        length(historical$groups) == 0L, isTRUE(historical$semantic_na_nan_unchanged),
        isTRUE(historical$semantic_states_identical),
        all(vapply(historical$preserved_artifacts, function(x) {
          isTRUE(x$bytes_identical) || isTRUE(x$decoded_identical)
        }, logical(1L))),
        identical(manifest$result$provenance$packages, archive$result$provenance$packages))
      models[[method]] <- list(panels = panels, packages = package_checks,
        packages_identical_to_054 = TRUE,
        historical_comparison = basename(historical_path),
        historical_comparison_sha256 = hash(historical_path),
        historical_full_manifest_sha256 = historical$full$manifest_sha256,
        renv_lock_sha256 = hash(file.path(root, "renv.lock")),
        runtime_compatibility = manifest$result$provenance$runtime_compatibility)
    } else {
      for (name in c("sea_sectors", "sea_countries")) {
        comparison <- report$comparison[[name]]
        stopifnot(isTRUE(comparison$identical), isTRUE(comparison$labels_identical),
          isTRUE(comparison$na_identical), isTRUE(comparison$nan_identical),
          comparison$finite_mismatches == 0L)
        if (!is.null(expected$vars)) stopifnot(isTRUE(comparison$unselected_identical))
      }
      preserved <- c("meta_indicators.RDS", "_unit_contract.csv", "_source_provenance.csv",
        "_parameters.csv", "_leontief_diagnostics.csv", "_gfcf_negative_cells.csv",
        "_gfcf_negative_summary.csv", grep("^m_(io|countries).*[.]fst([.]meta)?$",
          names(full_artifacts), value = TRUE))
      stopifnot(all(preserved %in% names(artifacts)),
        identical(artifacts[preserved], full_artifacts[preserved]),
        identical(manifest$result$provenance$runtime_compatibility,
          full_manifest$result$provenance$runtime_compatibility),
        identical(manifest$result$provenance$packages, full_manifest$result$provenance$packages))
    }
    summary[[paste(method, scenario, sep = "/")]] <- list(
      report = basename(report_path), report_sha256 = hash(report_path),
      run_id = report$run_id, manifest_sha256 = report$manifest_sha256,
      parent_run_id = previous, elapsed_seconds = report$elapsed_seconds,
      mode = expected$mode, stage = expected$stage, workers = expected$workers,
      selection = expected$vars, passed = TRUE,
      original_api_attempt_exit = if (is.null(report$original_api_attempt_exit)) 0L else report$original_api_attempt_exit)
    previous <- manifest$run_id
  }
}
recovery_path <- file.path(campaign, "results", "wiodr16-publication-recovery.json")
recovery <- read_json(recovery_path)
stopifnot(isTRUE(recovery$passed), identical(recovery$original_api_attempt_exit, 1L),
  identical(recovery$recalculated, FALSE), identical(recovery$run_changed, FALSE),
  identical(recovery$manifest_sha256, summary[["wiodr16/full1"]]$manifest_sha256),
  identical(recovery$run_id, summary[["wiodr16/full1"]]$run_id),
  all(vapply(recovery$checks, isTRUE, logical(1L))))
delta_path <- file.path(campaign, "results", "historical-delta-v2.json")
out <- list(schema = "wlv-issue28-summary/1", passed = TRUE,
  scientific_scenarios = length(summary), full_calculations = 2L, recalculations = 16L,
  evidence_scope = "Reports and run manifests authenticated; original per-run comparisons retained.",
  recovery_report = basename(recovery_path), recovery_report_sha256 = hash(recovery_path),
  historical_delta_report = basename(delta_path), historical_delta_report_sha256 = hash(delta_path),
  models = models, scenarios = summary)
jsonlite::write_json(out, args[[2L]], pretty = TRUE, auto_unbox = TRUE, null = "null")
message("PASS 18 scientific scenarios, 16 exact recalculations; original WIOD16 API exit 1 retained")
