# Read-only verification of the exact bilingual guide data-reading example.
# Run from the WLVDB root with: <published-project-root> <channel> <report.json>
# The package library is activated from this checkout before selecting the
# campaign root/channel. No source or run is written.
arguments <- commandArgs(TRUE)
if (length(arguments) != 3L) stop("Expected published-project-root channel report.json")
documentation_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
published_root <- normalizePath(arguments[[1L]], winslash = "/", mustWork = TRUE)
output <- normalizePath(dirname(arguments[[3L]]), winslash = "/", mustWork = TRUE)
output <- file.path(output, basename(arguments[[3L]]))
guide_path <- file.path(documentation_root, "docs", "guide-en.md")
guide <- readLines(guide_path, encoding = "UTF-8")
starts <- grep("^```r$", guide)
start <- starts[[2L]]
end <- which(seq_along(guide) > start & guide == "```")[[1L]]
expressions <- parse(text = guide[seq.int(start + 1L, end - 1L)])
# Locate the documented run resolver and replace its explicit channel only.
resolver <- which(vapply(expressions, function(call) {
  is.call(call) && identical(call[[1L]], as.name("<-")) &&
    identical(call[[2L]], as.name("run_dir"))
}, logical(1L)))
stopifnot(length(resolver) == 1L)
expressions[[resolver]][[3L]]$channel <- arguments[[2L]]
environment <- new.env(parent = globalenv())
output_text <- capture.output({
  # Campaign snapshots may intentionally omit renv/; activate the same pinned
  # library from the documentation checkout before switching calculation roots.
  eval(expressions[[1L]], environment)
  setwd(published_root)
  eval(expressions[-1L], environment)
})
stopifnot(identical(dim(environment$gdp), c(15L, 1L, 1L)),
  all(is.finite(environment$gdp)),
  all(c("indicator", "canonical_unit") %in% names(environment$units)))
manifest <- jsonlite::read_json(file.path(environment$run_dir, "run_manifest.json"))
hash <- function(path) {
  connection <- file(path, "rb")
  on.exit(close(connection))
  paste0(as.character(openssl::sha256(connection)))
}
jsonlite::write_json(list(
  schema = "wlv-guide-reading-check/1", passed = TRUE,
  method = "wiodr13", channel = arguments[[2L]],
  guide_sha256 = hash(guide_path),
  run_id = manifest$run_id, result_id = manifest$result_id,
  manifest_sha256 = hash(file.path(environment$run_dir, "run_manifest.json")),
  selected_indicator = "gdp.s.us", selected_country = "BRA",
  dimensions = dim(environment$gdp),
  first_value = as.numeric(environment$gdp[[1L]]),
  verified = c("marker-release-run-artifact chain", "FST bundle and axes",
    "guide data selection", "unit contract", "semantic states"),
  adaptation = paste("Package activation from documentation checkout; calculation root",
    "and channel select the campaign publication. Guide expressions otherwise unchanged.")
), output, auto_unbox = TRUE, pretty = TRUE)
cat("Guide reading example passed; report: ", output, "\n", sep = "")
