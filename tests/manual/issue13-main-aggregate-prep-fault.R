# Preserve two authenticated seed fields omitted by the frozen aggregate.
# CLI: Rscript this-file.R [--selftest] <frozen-aggregate.R> [original arguments]
arguments <- commandArgs(trailingOnly = TRUE)
selftest <- length(arguments) && identical(arguments[[1L]], "--selftest")
if (selftest) arguments <- arguments[-1L]
if (!length(arguments)) stop("Expected the frozen aggregate path.")
upstream <- normalizePath(arguments[[1L]], winslash = "/", mustWork = TRUE)
wrapper <- normalizePath(sub("^--file=", "", grep("^--file=",
  commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/", mustWork = TRUE)
hash <- function(path) {
  connection <- file(path, "rb")
  on.exit(close(connection))
  paste0(tolower(as.character(openssl::sha256(connection))), collapse = "")
}
upstream_hash <- "e8e4aa307a8d33e3252ea3a26a5e86832810fb5dc5cc477acc4d64fa5cea5ef2"
stopifnot(identical(hash(upstream), upstream_hash))
producer <- list(path = wrapper, sha256 = hash(wrapper),
  upstream_path = upstream, upstream_sha256 = upstream_hash)
unique_index <- function(values, predicate, label) {
  index <- which(vapply(as.list(values), predicate, logical(1L)))
  if (length(index) != 1L) stop(paste("Expected one AST match:", label))
  index[[1L]]
}
assignment <- function(value, name) is.call(value) &&
  identical(value[[1L]], as.name("<-")) &&
  identical(value[[2L]], as.name(name))
expected_projection <- quote(list(
  scenario_id = id,
  fault_id = wlv13_fault_names[[index]],
  channel = record$channel,
  seed_result_path = seed_result_path,
  seed_result_sha256 = wlv13_sha256_file(seed_result_path),
  run_id = seed$run_id,
  result_id = seed$result_id,
  release_id = seed$release_id,
  release_manifest_sha256 = seed$release_manifest_sha256,
  marker_sha256 = seed$marker_sha256,
  process = process
))
patch <- function(expressions) {
  main_index <- unique_index(expressions,
    function(value) assignment(value, "main"), "main definition")
  block <- expressions[[main_index]][[3L]][[3L]]
  seeds_index <- unique_index(block,
    function(value) assignment(value, "seeds"), "seed collection")
  seed_block <- block[[seeds_index]][[3L]][[3L]][[3L]]
  projection_index <- unique_index(seed_block,
    function(value) identical(value, expected_projection), "seed projection")
  stopifnot(projection_index == length(seed_block))
  projected <- as.list(expected_projection)
  projected$method <- quote(seed$method)
  projected$run_manifest_sha256 <- quote(seed$run_manifest_sha256)
  seed_block[[projection_index]] <- as.call(projected)
  block[[seeds_index]][[3L]][[3L]][[3L]] <- seed_block
  write_index <- unique_index(block, function(value) identical(value,
    quote(wlv13_json_write(report, report_path))), "final report write")
  block <- as.call(append(as.list(block),
    list(quote(report$producer <<- .wlv13_aggregate_producer)),
    after = write_index - 1L))
  expressions[[main_index]][[3L]][[3L]] <- block
  list(expressions = expressions, main_index = main_index,
    seeds_index = seeds_index, projection_index = projection_index,
    write_index = write_index, projection = as.call(projected))
}
original <- parse(upstream, keep.source = FALSE)
patched <- patch(original)
if (selftest) {
  checks <- character()
  check <- function(condition, name) {
    if (!isTRUE(condition)) stop(paste("Selftest failed:", name))
    checks <<- c(checks, name)
  }
  fails <- function(code) inherits(tryCatch({force(code); NULL},
    error = identity), "error")
  restored <- patched$expressions
  block <- restored[[patched$main_index]][[3L]][[3L]]
  block <- as.call(as.list(block)[-(patched$write_index)])
  block[[patched$seeds_index]][[3L]][[3L]][[3L]][[
    patched$projection_index]] <- expected_projection
  restored[[patched$main_index]][[3L]][[3L]] <- block
  check(identical(restored, original), "only two fields and provenance changed")
  duplicate <- c(original, original[patched$main_index])
  check(fails(patch(duplicate)), "duplicate main rejected")
  check(fails(patch(original[-patched$main_index])), "missing main rejected")
  mutated <- original
  mutated[[patched$main_index]][[3L]][[3L]][[patched$seeds_index]][[3L]][[
    3L]][[3L]][[patched$projection_index]] <- quote(list(method = seed$method))
  check(fails(patch(mutated)), "mutated projection rejected")
  fixture <- new.env(parent = baseenv())
  fixture$id <- "candidate/seed/fault/module-execution"
  fixture$index <- 1L
  fixture$wlv13_fault_names <- "module-execution"
  fixture$record <- list(channel = "test")
  fixture$seed_result_path <- "test.json"
  fixture$wlv13_sha256_file <- function(path) strrep("a", 64L)
  fixture$process <- list(passed = TRUE)
  fixture$seed <- list(method = "wiodr13", run_manifest_sha256 = strrep("b", 64L),
    run_id = "run", result_id = "result", release_id = "release",
    release_manifest_sha256 = strrep("c", 64L), marker_sha256 = strrep("d", 64L))
  fields <- c("method", "run_manifest_sha256")
  expected <- fixture$seed[fields]
  preserved <- eval(expected_projection, fixture)
  corrected <- eval(patched$projection, fixture)
  check(identical(corrected[fields], expected), "authenticated fields preserved")
  check(identical(corrected[setdiff(names(corrected), fields)], preserved),
    "all original projected values preserved")
  # These are the unchanged downstream identity checks at lines 412-419.
  same_identity <- function(value) identical(value$method, expected$method) &&
    identical(value$run_manifest_sha256, expected$run_manifest_sha256)
  check(!same_identity(preserved), "original omission reproduced")
  for (field in fields) {
    saved <- fixture$seed[[field]]
    fixture$seed[[field]] <- NULL
    check(!same_identity(eval(patched$projection, fixture)),
      paste("missing source field rejected:", field))
    fixture$seed[[field]] <- "mutated"
    check(!same_identity(eval(patched$projection, fixture)),
      paste("mutated source field rejected:", field))
    fixture$seed[[field]] <- saved
  }
  check(identical(hash(upstream), upstream_hash), "frozen aggregate unchanged")
  cat(jsonlite::toJSON(list(status = "passed", checks = as.list(checks),
    check_count = length(checks), producer = producer),
    auto_unbox = TRUE, pretty = TRUE), "\n")
} else {
  namespace <- new.env(parent = globalenv())
  namespace$.wlv13_aggregate_producer <- producer
  namespace$commandArgs <- local({
    cli <- arguments[-1L]
    file_arg <- paste0("--file=", upstream)
    function(trailingOnly = FALSE) if (trailingOnly) cli else file_arg
  })
  for (expression in patched$expressions) eval(expression, envir = namespace)
}
