# Metadata-only tests for the 054-v2 array-proof cache.  No FST payload rows are
# opened: descriptors read only run manifests, sidecars, and FST headers.

raw <- commandArgs(trailingOnly = TRUE)
if (length(raw) %% 2L != 0L) stop("Arguments must be --name value pairs.")
keys <- gsub("-", "_", sub("^--", "", raw[seq.int(1L, length(raw), 2L)]),
  fixed = TRUE)
args <- as.list(raw[seq.int(2L, length(raw), 2L)])
names(args) <- keys
required <- c("comparison_root", "comparison_binding", "config",
  "science_binding", "proof_lib", "cache", "cache_sha256",
  "wiodr13_origin", "wiodr16_origin")
if (length(setdiff(required, names(args)))) stop("Missing selftest argument.")

root <- normalizePath(args$comparison_root, winslash = "/", mustWork = TRUE)
harness <- file.path(root, "issue13-evidence-harness")
sys.source(file.path(harness, "issue13-lib.R"), envir = environment())
sys.source(file.path(harness, "issue13-compare-lib.R"), envir = environment())
sys.source(normalizePath(args$proof_lib, winslash = "/", mustWork = TRUE),
  envir = environment())
binding <- wlv13_json_read(args$comparison_binding, simplify = FALSE)
algorithm_paths <- c(
  "issue13-evidence-harness/issue13-lib.R",
  "issue13-prep-paper-lib.R",
  "issue13-evidence-harness/issue13-compare-lib.R",
  "issue13-evidence-harness/issue13-v5-difference-fingerprint.R",
  "issue13-evidence-harness/issue13-v5-compare-override.R",
  "issue13-evidence-harness/issue13-v5-diagnostics-override.R",
  "issue13-evidence-harness/issue13-compare-results.R"
)
binding_paths <- vapply(binding$records, `[[`, character(1L), "relative_path")
algorithms <- lapply(algorithm_paths, function(path) {
  index <- which(binding_paths == path)
  stopifnot(length(index) == 1L)
  list(path = path, sha256 = binding$records[[index]]$sha256)
})
context <- list(
  config_sha256 = wlv13_sha256_file(args$config),
  science_tooling_binding_sha256 = wlv13_sha256_file(args$science_binding),
  comparison_binding_sha256 = wlv13_sha256_file(args$comparison_binding),
  algorithms = algorithms
)
cache <- wlv13_ap_load(args$cache, args$cache_sha256, context)

manifest_inventory <- function(side) {
  manifest <- wlv13_json_read(side$manifest_path, simplify = FALSE)
  rows <- lapply(manifest$artifacts, function(record) data.frame(
    path = record$path, role = record$role,
    size_bytes = as.numeric(record$size_bytes), sha256 = record$sha256,
    stringsAsFactors = FALSE
  ))
  records <- do.call(rbind, rows)
  row.names(records) <- NULL
  list(root = normalizePath(side$root, winslash = "/", mustWork = TRUE),
    records = records)
}

expected_result <- function(report, summary) {
  raw_summary <- summary[setdiff(names(summary), c("meta_role_match", "key",
    "type", "candidate_path", "baseline_path", "role_match"))]
  rows <- Filter(function(row) identical(row$artifact, summary$key),
    report$transitions)
  states <- vapply(rows, `[[`, character(1L), "candidate_state")
  indices <- match(states, wlv13_state_names)
  transitions <- data.frame(
    candidate_state = states,
    baseline_state = vapply(rows, `[[`, character(1L), "baseline_state"),
    count = vapply(rows, function(row) as.numeric(row$count), numeric(1L)),
    stringsAsFactors = FALSE,
    row.names = as.character(indices + (indices - 1L) *
      length(wlv13_state_names))
  )
  list(summary = raw_summary, transitions = transitions,
    indicators = data.frame())
}

expect_error <- function(expression, pattern) {
  message <- tryCatch({ force(expression); "" },
    error = function(error) conditionMessage(error))
  if (!grepl(pattern, message, fixed = TRUE)) {
    stop(sprintf("Expected error containing `%s`; got `%s`.", pattern, message),
      call. = FALSE)
  }
}

origins <- c(args$wiodr13_origin, args$wiodr16_origin)
checked <- 0L
example <- NULL
for (origin in origins) {
  job <- wlv13_json_read(file.path(origin, "job.json"), simplify = FALSE)
  contract_for <- function(side) {
    contracts <- Filter(function(value) identical(value$side, side),
      job$input_contracts)
    stopifnot(length(contracts) == 1L)
    record <- contracts[[1L]]
    list(arm = record$arm, method = record$method,
      expected_commit = record$commit, observed_commit = record$commit)
  }
  engine_pair <- list(candidate = contract_for("candidate"),
    baseline = contract_for("baseline"))
  report <- wlv13_json_read(file.path(origin, "comparison", "comparison.json"),
    simplify = FALSE)
  left <- wlv13_artifact_descriptors(manifest_inventory(report$candidate))
  right <- wlv13_artifact_descriptors(manifest_inventory(report$baseline))
  summaries <- Filter(function(value) identical(value$type, "fst_array"),
    report$artifacts)
  for (summary in summaries) {
    actual <- wlv13_ap_lookup(left[[summary$key]], right[[summary$key]],
      1000000L, "cross_engine_run_v3", cache, engine_pair)
    expected <- expected_result(report, summary)
    if (!identical(actual, expected)) {
      stop(sprintf("Cached/full return is not exact for %s.", summary$key),
        call. = FALSE)
    }
    checked <- checked + 1L
    if (is.null(example)) example <- list(left = left[[summary$key]],
      right = right[[summary$key]], engine_pair = engine_pair)
  }
}
stopifnot(checked == 8L)

negative <- unserialize(serialize(example, NULL, version = 3L))
negative$left$sha256 <- paste0("0", substring(negative$left$sha256, 2L))
if (!is.null(negative$left$sidecar$embedded_sha256)) {
  negative$left$sidecar$embedded_sha256 <- negative$left$sha256
}
stopifnot(is.null(wlv13_ap_lookup(negative$left, negative$right, 1000000L,
  "cross_engine_run_v3", cache, example$engine_pair)))

negative <- unserialize(serialize(example, NULL, version = 3L))
order <- rev(seq_along(negative$left$sidecar$dimensions))
negative$left$sidecar$dimensions <- negative$left$sidecar$dimensions[order]
negative$left$sidecar$dimnames <- negative$left$sidecar$dimnames[order]
stopifnot(is.null(wlv13_ap_lookup(negative$left, negative$right, 1000000L,
  "cross_engine_run_v3", cache, example$engine_pair)))

negative <- unserialize(serialize(example, NULL, version = 3L))
axis <- which(vapply(negative$left$sidecar$dimnames, length, integer(1L)) > 0L)[[1L]]
negative$left$sidecar$dimnames[[axis]][[1L]] <- "__array_proof_negative__"
stopifnot(is.null(wlv13_ap_lookup(negative$left, negative$right, 1000000L,
  "cross_engine_run_v3", cache, example$engine_pair)))

negative <- unserialize(serialize(example, NULL, version = 3L))
negative$left$fst_metadata$columnTypes[[1L]] <- "array-proof-negative"
stopifnot(is.null(wlv13_ap_lookup(negative$left, negative$right, 1000000L,
  "cross_engine_run_v3", cache, example$engine_pair)))

negative <- unserialize(serialize(example, NULL, version = 3L))
attr(negative$left$sidecar$dimnames, "array_proof_negative") <- TRUE
stopifnot(is.null(wlv13_ap_lookup(negative$left, negative$right, 1000000L,
  "cross_engine_run_v3", cache, example$engine_pair)))

negative <- unserialize(serialize(example, NULL, version = 3L))
negative$left$sidecar$dimnames[[axis]][[1L]] <- NA_character_
expect_error(wlv13_ap_lookup(negative$left, negative$right, 1000000L,
  "cross_engine_run_v3", cache, example$engine_pair), "sidecar axis")

stopifnot(is.null(wlv13_ap_lookup(example$left, example$right, 999999L,
  "cross_engine_run_v3", cache, example$engine_pair)))
stopifnot(is.null(wlv13_ap_lookup(example$left, example$right, 1000000L,
  "strict", cache, example$engine_pair)))
stopifnot(is.null(wlv13_ap_lookup(example$left, example$right, 1000000L,
  "strict", cache, NULL)))
stopifnot(is.null(wlv13_ap_lookup(example$left, example$right, 1000000L,
  "cross_engine_source_v1", cache, NULL)))
swapped_engine_pair <- list(candidate = example$engine_pair$baseline,
  baseline = example$engine_pair$candidate)
stopifnot(is.null(wlv13_ap_lookup(example$right, example$left, 1000000L,
  "cross_engine_run_v3", cache, swapped_engine_pair)))

mutate_cache <- function(mutator) {
  value <- wlv13_json_read(args$cache, simplify = FALSE)
  value <- mutator(value)
  path <- tempfile("issue13-array-proof-negative-", fileext = ".json")
  jsonlite::write_json(value, path, auto_unbox = TRUE, pretty = TRUE,
    digits = NA, null = "null", na = "string")
  path
}
altered_proof <- mutate_cache(function(value) {
  value$records[[1L]]$proof$summary$maximum_absolute_difference <- "1e+00"
  value
})
on.exit(unlink(altered_proof, force = TRUE), add = TRUE)
altered_sha <- wlv13_sha256_file(altered_proof)
expect_error(wlv13_ap_load(altered_proof, altered_sha, context),
  "cache SHA-256")
approved <- wlv13_ap_approved_cache_sha256
wlv13_ap_approved_cache_sha256 <- altered_sha
expect_error(wlv13_ap_load(altered_proof, altered_sha, context),
  "record hashes")
wlv13_ap_approved_cache_sha256 <- approved

duplicate <- mutate_cache(function(value) {
  value$records[[2L]] <- value$records[[1L]]
  value
})
on.exit(unlink(duplicate, force = TRUE), add = TRUE)
duplicate_sha <- wlv13_sha256_file(duplicate)
wlv13_ap_approved_cache_sha256 <- duplicate_sha
expect_error(wlv13_ap_load(duplicate, duplicate_sha, context), "duplicate pair")
wlv13_ap_approved_cache_sha256 <- approved

altered_context <- context
altered_context$algorithms[[1L]]$sha256 <- paste0("0",
  substring(altered_context$algorithms[[1L]]$sha256, 2L))
expect_error(wlv13_ap_load(args$cache, args$cache_sha256, altered_context),
  "different tooling")

cat(sprintf("array-proof-selftest=passed\nexact-real-arrays=%d\nnegative-cases=%d\n",
  checked, 14L))
