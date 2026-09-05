# Authenticated entrypoint that installs the array-proof hook into the original
# comparator in memory.  The comparison runtime itself remains byte-for-byte
# identical to its existing binding.

raw <- commandArgs(trailingOnly = TRUE)
if (length(raw) %% 2L != 0L ||
    any(!startsWith(raw[seq.int(1L, length(raw), 2L)], "--"))) {
  stop("Arguments must be --name value pairs.", call. = FALSE)
}
keys <- gsub("-", "_", sub("^--", "",
  raw[seq.int(1L, length(raw), 2L)]), fixed = TRUE)
if (anyDuplicated(keys)) stop("Duplicate CLI argument.", call. = FALSE)
args <- as.list(raw[seq.int(2L, length(raw), 2L)])
names(args) <- keys
required <- c(
  "comparison_root", "comparison_results_sha256", "proof_lib",
  "proof_lib_sha256", "array_proof", "array_proof_sha256", "config",
  "config_sha256", "science_binding", "science_binding_sha256",
  "comparison_binding", "comparison_binding_sha256", "comparison_mode"
)
missing <- setdiff(required, names(args))
if (length(missing)) {
  stop(sprintf("Missing array-proof argument(s): %s.",
    paste(missing, collapse = ", ")), call. = FALSE)
}

suppressPackageStartupMessages(library(openssl))
suppressPackageStartupMessages(library(jsonlite))
sha_file <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  connection <- file(path, open = "rb")
  on.exit(close(connection), add = TRUE)
  paste0(tolower(as.character(openssl::sha256(connection))), collapse = "")
}
assert_hash <- function(path, expected, name) {
  if (!is.character(expected) || length(expected) != 1L ||
      !grepl("^[0-9a-f]{64}$", expected) ||
      !identical(sha_file(path), expected)) {
    stop(sprintf("Array-proof %s binding changed.", name), call. = FALSE)
  }
  invisible(normalizePath(path, winslash = "/", mustWork = TRUE))
}

comparison_root <- normalizePath(args$comparison_root,
  winslash = "/", mustWork = TRUE)
comparison_script <- file.path(comparison_root,
  "issue13-evidence-harness", "issue13-compare-results.R")
proof_lib <- normalizePath(args$proof_lib, winslash = "/", mustWork = TRUE)
assert_hash(comparison_script, args$comparison_results_sha256,
  "comparison entrypoint")
assert_hash(proof_lib, args$proof_lib_sha256, "hook library")
assert_hash(args$array_proof, args$array_proof_sha256, "cache")
assert_hash(args$config, args$config_sha256, "config")
assert_hash(args$science_binding, args$science_binding_sha256,
  "science tooling")
assert_hash(args$comparison_binding, args$comparison_binding_sha256,
  "comparison tooling")

binding <- jsonlite::read_json(args$comparison_binding, simplifyVector = FALSE)
if (!is.list(binding) ||
    !identical(binding$schema, "wlv-issue13-main-comparison-binding/1") ||
    !identical(normalizePath(binding$runtime_root,
      winslash = "/", mustWork = TRUE), comparison_root)) {
  stop("Array-proof comparison binding has an invalid runtime root.",
    call. = FALSE)
}
algorithm_paths <- c(
  "issue13-evidence-harness/issue13-lib.R",
  "issue13-prep-paper-lib.R",
  "issue13-evidence-harness/issue13-compare-lib.R",
  "issue13-evidence-harness/issue13-v5-difference-fingerprint.R",
  "issue13-evidence-harness/issue13-v5-compare-override.R",
  "issue13-evidence-harness/issue13-v5-diagnostics-override.R",
  "issue13-evidence-harness/issue13-compare-results.R"
)
record_paths <- vapply(binding$records, `[[`, character(1L), "relative_path")
algorithms <- lapply(algorithm_paths, function(relative) {
  matches <- which(record_paths == relative)
  if (length(matches) != 1L) {
    stop(sprintf("Array-proof binding lacks algorithm: %s.", relative),
      call. = FALSE)
  }
  expected <- binding$records[[matches]]$sha256
  assert_hash(file.path(comparison_root, relative), expected,
    paste("algorithm", relative))
  list(path = relative, sha256 = expected)
})
context <- list(
  config_sha256 = args$config_sha256,
  science_tooling_binding_sha256 = args$science_binding_sha256,
  comparison_binding_sha256 = args$comparison_binding_sha256,
  algorithms = algorithms
)
required_hits <- if ("array_proof_required_hits" %in% names(args)) {
  suppressWarnings(as.integer(args$array_proof_required_hits))
} else {
  0L
}
if (length(required_hits) != 1L || is.na(required_hits) || required_hits < 0L) {
  stop("Invalid --array-proof-required-hits value.", call. = FALSE)
}

source_lines <- readLines(comparison_script, warn = FALSE, encoding = "UTF-8")
marker <- paste0(
  'sys.source(file.path(script_dir, "issue13-v5-diagnostics-override.R"), ',
  'envir = environment())'
)
locations <- which(source_lines == marker)
if (length(locations) != 1L) {
  stop("Cannot locate the exact comparator hook boundary.", call. = FALSE)
}
injection <- c(
  "sys.source(wlv13_ap_bootstrap$proof_lib, envir = environment())",
  "options(wlv13.array_proof.comparison_mode = wlv13_ap_bootstrap$comparison_mode)",
  paste0("wlv13_ap_install(wlv13_ap_load(wlv13_ap_bootstrap$proof_path, ",
    "wlv13_ap_bootstrap$proof_sha256, wlv13_ap_bootstrap$context), ",
    "fail_on_miss = wlv13_ap_bootstrap$required_hits > 0L)")
)
source_lines <- append(source_lines, injection, after = locations)
write_line <- "wlv13_write_comparison_outputs(report, output)"
write_locations <- which(source_lines == write_line)
if (length(write_locations) != 1L) {
  stop("Cannot locate the exact comparator output boundary.", call. = FALSE)
}
hit_assertion <- paste0(
  "if (wlv13_ap_bootstrap$required_hits > 0L && ",
  "!identical(wlv13_ap_hits, wlv13_ap_bootstrap$required_hits)) ",
  "stop('Required array-proof hit count differs.', call. = FALSE)"
)
source_lines <- append(source_lines, hit_assertion,
  after = write_locations - 1L)
quit_line <- "quit(save = \"no\", status = if (report$passed) 0L else 1L, runLast = FALSE)"
quit_locations <- which(source_lines == quit_line)
if (length(quit_locations) != 1L) {
  stop("Cannot locate the exact comparator exit boundary.", call. = FALSE)
}
source_lines <- append(source_lines,
  'cat(sprintf("array-proof-hits=%d\\n", wlv13_ap_hits))',
  after = quit_locations - 1L)

runner <- new.env(parent = globalenv())
runner$wlv13_ap_bootstrap <- list(
  proof_lib = proof_lib,
  proof_path = normalizePath(args$array_proof, winslash = "/", mustWork = TRUE),
  proof_sha256 = args$array_proof_sha256,
  comparison_mode = args$comparison_mode,
  required_hits = required_hits,
  context = context
)
original_command_args <- base::commandArgs
runner$commandArgs <- function(trailingOnly = FALSE) {
  value <- original_command_args(trailingOnly = trailingOnly)
  if (!trailingOnly) {
    file_index <- grep("^--file=", value)
    if (length(file_index) != 1L) stop("Rscript file identity is ambiguous.")
    value[[file_index]] <- paste0("--file=", comparison_script)
  }
  value
}
expression <- parse(text = source_lines, keep.source = FALSE,
  srcfile = comparison_script)
eval(expression, envir = runner)
