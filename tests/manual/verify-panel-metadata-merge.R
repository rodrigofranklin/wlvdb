# Read-only real-run gate for issue #31. Only the report and merged CSV copies
# are written, inside a campaign; source runs and their manifests are untouched.
# Usage: Rscript --vanilla tests/manual/verify-panel-metadata-merge.R
#   <wiodr13-run> <wiodr16-run> <campaign-report.json>
args <- commandArgs(TRUE)
stopifnot(length(args) == 3L)
repo <- normalizePath(".", winslash = "/", mustWork = TRUE)
report_path <- normalizePath(args[[3L]], winslash = "/", mustWork = FALSE)
stopifnot(startsWith(tolower(report_path), paste0(tolower(repo), "/temp/")),
  dir.exists(dirname(report_path)), !file.exists(report_path))
source(file.path(repo, "renv/activate.R"))
bootstrap <- new.env(parent = baseenv())
sys.source(file.path(repo, "scripts/runtime_bootstrap.R"), bootstrap)
runtime <- bootstrap$wlv_load_runtime(repo)
roots <- normalizePath(args[1:2], winslash = "/", mustWork = TRUE)
manifest_paths <- file.path(roots, "run_manifest.json")
manifests <- lapply(manifest_paths, runtime$wlv_read_run_manifest)
stopifnot(identical(vapply(manifests, `[[`, character(1L), "method"),
  c("wiodr13", "wiodr16")))
artifacts <- c("_panel_indicators.csv", "_panel_meta_indicators.csv")
records <- lapply(manifests, runtime$wlv_run_manifest_artifact_subset,
  artifact_paths = artifacts, label = "issue31 panel metadata")
input_paths <- c(manifest_paths, as.vector(outer(roots, artifacts, file.path)))
hash <- function(path) paste0(runtime$wlv_publication_file_sha256(path))
before <- vapply(input_paths, hash, character(1L))
stopifnot(!any(vapply(input_paths, function(path) {
  any(grepl("<U\\+[0-9A-Fa-f]{4,8}>", readLines(path, encoding = "UTF-8")))
}, logical(1L))))
checks <- list()
for (index in seq_along(artifacts)) {
  artifact <- artifacts[[index]]
  paths <- file.path(roots, artifact)
  hashes <- vapply(records, function(items) items[[index]]$sha256, character(1L))
  key <- if (index == 1L) "cod_label" else "value"
  columns <- if (index == 1L) c(key, "label") else c(key, "groups", "type", "reverted")
  tables <- lapply(seq_along(paths), function(i) runtime$wlv_read_panel_result_csv(
    paths[[i]], columns, expected_sha256 = hashes[[i]]
  ))
  merged <- runtime$wlv_merge_panel_result_tables(paths, key, columns, hashes)
  reverse <- runtime$wlv_merge_panel_result_tables(rev(paths), key, columns, rev(hashes))
  stopifnot(identical(merged, reverse), !anyDuplicated(merged[[key]]),
    setequal(merged[[key]], unlist(lapply(tables, `[[`, key))))
  for (table in tables) {
    for (column in setdiff(columns, key)) {
      present <- !is.na(table[[column]])
      observed <- merged[[column]][match(table[[key]][present], merged[[key]])]
      stopifnot(identical(observed, table[[column]][present]))
    }
  }
  # Reconstruct the old missing-value interpretation from these same bytes.
  old <- do.call(rbind, lapply(paths, utils::read.csv2,
    stringsAsFactors = FALSE, check.names = FALSE, na.strings = "NA"))
  conflicts <- list()
  for (value in unique(old[[key]])) {
    group <- old[old[[key]] == value, , drop = FALSE]
    for (column in setdiff(columns, key)) {
      candidates <- unique(group[[column]][!is.na(group[[column]])])
      if (length(candidates) > 1L) {
        stopifnot("" %in% candidates, sum(nzchar(candidates)) == 1L)
        conflicts[[length(conflicts) + 1L]] <- list(key = value, field = column)
      }
    }
  }
  output <- paste0(report_path, ".", artifact)
  stopifnot(!file.exists(output))
  runtime$wlv_write_result_csv(merged, output)
  stopifnot(identical(runtime$wlv_read_panel_result_csv(output, columns), merged))
  checks[[artifact]] <- list(rows = nrow(merged),
    reverse_order_identical = TRUE, present_values_preserved = TRUE,
    old_empty_value_conflicts = conflicts, output_sha256 = hash(output))
}
stopifnot(identical(vapply(input_paths, hash, character(1L)), before))
report <- list(schema = "wlv-issue31-panel-metadata/1", passed = TRUE,
  verified_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  runtime_compatibility = paste0(runtime$.wlv_runtime_compatibility_generation()),
  runs = lapply(seq_along(roots), function(i) list(method = manifests[[i]]$method,
    run_id = manifests[[i]]$run_id, path = roots[[i]], manifest_sha256 = before[[i]])),
  publication_code_sha256 = hash(file.path(repo, "scripts/lib/publication.R")),
  verifier_sha256 = hash(file.path(repo, "tests/manual/verify-panel-metadata-merge.R")),
  input_bytes_unchanged = TRUE, unicode_escape_sequences_absent = TRUE,
  checks = checks)
jsonlite::write_json(report, report_path, pretty = TRUE, auto_unbox = TRUE, null = "null")
cat("Real WIOD13/WIOD16 panel metadata merge passed without changing either run.\n")
