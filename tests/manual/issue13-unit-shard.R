# Run one deterministic shard of the existing unit/integration suite.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) stop("Expected shard-index shard-count result-json.")
index <- as.integer(args[[1L]])
count <- as.integer(args[[2L]])
if (anyNA(c(index, count)) || index < 1L || count < index) {
  stop("Invalid shard index/count.")
}
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]])
root <- normalizePath(file.path(dirname(script), "..", ".."), winslash = "/")
directory <- file.path(root, "tests", "testthat")
files <- sort(list.files(directory, pattern = "^test-.*[.]R$"), method = "radix")
selected <- files[(seq_along(files) - 1L) %% count + 1L == index]
names <- sub("[.]R$", "", sub("^test-", "", selected))
pattern <- paste0("^(", paste(names, collapse = "|"), ")$")
started <- Sys.time()
message("Shard ", index, "/", count, ": ", length(selected), " files")
failure <- NULL
tryCatch(
  testthat::test_dir(
    directory, filter = pattern, reporter = "summary",
    stop_on_failure = TRUE, stop_on_warning = TRUE
  ),
  error = function(error) failure <<- conditionMessage(error)
)
result <- list(
  schema = "wlv-issue13-unit-shard/1", index = index, count = count,
  files = selected, started_at = format(started, tz = "UTC", usetz = TRUE),
  elapsed_seconds = as.numeric(difftime(Sys.time(), started, units = "secs")),
  passed = is.null(failure), error = failure
)
jsonlite::write_json(result, args[[3L]], auto_unbox = TRUE, pretty = TRUE, null = "null")
if (!is.null(failure)) quit(status = 1L)
