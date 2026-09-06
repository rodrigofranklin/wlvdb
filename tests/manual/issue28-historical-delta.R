# Read-only diagnosis of the preserved issue-13 WIOD13 stage-4 divergence.
# Usage: Rscript tests/manual/issue28-historical-delta.R <full-run> <recalc-run>
#   <report.json>. Historical paths are supplied after applying the archive map.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L, !file.exists(args[[3L]]))
bootstrap <- new.env(parent = baseenv())
sys.source(file.path(getwd(), "R", "bootstrap.R"), envir = bootstrap)
runtime <- bootstrap$wlv_load_runtime(getwd())
hash <- runtime$wlv_publication_file_sha256
roots <- args[1:2]
manifests <- lapply(roots, function(root) {
  runtime$wlv_read_run_manifest(file.path(root, "run_manifest.json"))
})
authenticate <- function(index, filename) {
  matches <- Filter(function(record) identical(record$path, filename),
    manifests[[index]]$artifacts)
  stopifnot(length(matches) == 1L,
    identical(hash(file.path(roots[[index]], filename)), matches[[1L]]$sha256))
}
groups <- list()
for (artifact in c("sea_sectors", "sea_countries")) {
  for (i in 1:2) for (suffix in c(".fst", ".fst.meta")) {
    authenticate(i, paste0(artifact, suffix))
  }
  values <- lapply(roots, function(root) {
    runtime$read_fst_array(file.path(root, paste0(artifact, ".fst")))
  })
  stopifnot(identical(dimnames(values[[1L]]), dimnames(values[[2L]])),
    identical(is.na(values[[1L]]), is.na(values[[2L]])),
    identical(is.nan(values[[1L]]), is.nan(values[[2L]])))
  for (indicator in dimnames(values[[1L]])[[2L]]) {
    take <- function(value) if (length(dim(value)) == 4L) {
      value[, indicator, , , drop = FALSE]
    } else value[, indicator, , drop = FALSE]
    full <- take(values[[1L]])
    recalculated <- take(values[[2L]])
    delta <- recalculated - full
    changed <- is.finite(delta) & delta != 0
    if (!any(changed)) next
    coords <- which(changed, arr.ind = TRUE)
    max_index <- which.max(replace(abs(delta), !is.finite(delta), -Inf))
    max_coordinate <- arrayInd(max_index, dim(delta))
    coordinate <- vapply(seq_len(ncol(max_coordinate)), function(axis) {
      dimnames(full)[[axis]][max_coordinate[1L, axis]]
    }, character(1L))
    eligible <- changed & full != 0
    groups[[length(groups) + 1L]] <- list(artifact = artifact, indicator = indicator,
      mismatch_count = sum(changed),
      years = sort(unique(dimnames(full)[[1L]][coords[, 1L]])),
      countries = sort(unique(dimnames(full)[[length(dim(full))]][coords[, length(dim(full))]])),
      max_absolute_difference = abs(delta[max_index]), maximum_coordinate = coordinate,
      full_at_maximum = full[max_index], recalc_at_maximum = recalculated[max_index],
      max_relative_difference = max(abs(delta[eligible] / full[eligible])),
      increases = sum(delta[changed] > 0), decreases = sum(delta[changed] < 0))
  }
}
authenticate(1L, "_unit_contract.csv")
authenticate(2L, "_unit_contract.csv")
authenticate(1L, "_source_provenance.csv")
authenticate(2L, "_source_provenance.csv")
preserved_names <- c("_unit_contract.csv", "_source_provenance.csv",
  list.files(roots[[1L]], "^m_(io|countries).*[.]fst([.]meta)?$"))
preserved <- lapply(preserved_names, function(name) {
  for (i in 1:2) authenticate(i, name)
  list(artifact = name, bytes_identical = identical(
    hash(file.path(roots[[1L]], name)), hash(file.path(roots[[2L]], name))),
    decoded_identical = if (endsWith(name, ".meta")) identical(
      readRDS(file.path(roots[[1L]], name)), readRDS(file.path(roots[[2L]], name))) else NULL)
})
for (i in 1:2) authenticate(i, "_runtime_resources.rds")
snapshots <- lapply(roots, function(root) readRDS(file.path(root, "_runtime_resources.rds")))
semantic_states_identical <- identical(snapshots[[1L]]$panel_states, snapshots[[2L]]$panel_states)
units <- read.csv2(file.path(roots[[1L]], "_unit_contract.csv"), stringsAsFactors = FALSE)
report <- list(schema = "wlv-issue28-historical-delta/1",
  full = list(path = roots[[1L]], manifest_sha256 = hash(file.path(roots[[1L]], "run_manifest.json"))),
  recalculated = list(path = roots[[2L]], manifest_sha256 = hash(file.path(roots[[2L]], "run_manifest.json"))),
  semantic_na_nan_unchanged = TRUE, semantic_states_identical = semantic_states_identical,
  preserved_artifacts = preserved, groups = groups,
  units = units[units$indicator %in% unique(vapply(groups, `[[`, character(1L), "indicator")), ])
jsonlite::write_json(report, args[[3L]], auto_unbox = TRUE, pretty = TRUE, digits = 17)
message("Authenticated historical divergence: ", sum(vapply(groups, `[[`, numeric(1L), "mismatch_count")), " cells")
