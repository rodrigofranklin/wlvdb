# Reproducible consolidation gate. All generated files belong in temp/<id>/.
# Rscript --vanilla tests/manual/issue15-verify.R suite <report.json>
# Rscript --vanilla tests/manual/issue15-verify.R panel <report.json> \
#   <wlvpanel-checkout> <results-root> <channel>
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 2L, args[[1L]] %in% c("suite", "panel"))
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]])
root <- normalizePath(file.path(dirname(script), "../.."), winslash = "/")
Sys.setenv(RENV_PROJECT = root)
source(file.path(root, "renv/activate.R"))
report_path <- file.path(
  normalizePath(dirname(args[[2L]]), winslash = "/", mustWork = TRUE),
  basename(args[[2L]])
)
stopifnot(startsWith(tolower(report_path), paste0(tolower(root), "/temp/")))
dir.create(dirname(report_path), recursive = TRUE, showWarnings = FALSE)
sha <- function(path) {
  connection <- file(path, "rb")
  on.exit(close(connection))
  unname(unclass(as.character(openssl::sha256(connection))))
}
git <- function(path, ...) {
  paste(system2("git", c("-C", shQuote(path), ...), stdout = TRUE), collapse = "\n")
}
bootstrap <- new.env(parent = baseenv())
sys.source(file.path(root, "R/bootstrap.R"), envir = bootstrap)
runtime <- bootstrap$wlv_load_runtime(root)
definition_files <- bootstrap$wlv_runtime_definition_files(root)
before <- vapply(definition_files, sha, character(1L))
started <- Sys.time()
report <- list(
  schema = "wlv-issue15-verification/1", mode = args[[1L]],
  started_at_utc = format(started, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  commit = git(root, "rev-parse", "HEAD"),
  command = commandArgs(), R = R.version.string, platform = R.version$platform,
  runtime_files = as.list(stats::setNames(before, substring(definition_files, nchar(root) + 2L))),
  passed = FALSE
)
failure <- NULL
tryCatch({
  if (args[[1L]] == "suite") {
    catalog <- runtime$wlv_runtime_catalog()
    methods <- runtime$wlv_catalog_method_table(catalog)
    supported <- c("wiodr13", "wiodr16")
    stopifnot(setequal(methods$method[methods$can_calculate], supported),
              setequal(methods$method[methods$can_recalculate], supported))
    runtime$wlv_assert_dependencies(include_preparation = TRUE, attach = FALSE)
    invisible(lapply(list.files(file.path(root, "R"), "[.][Rr]$",
                               recursive = TRUE, full.names = TRUE), parse))
    tests <- testthat::test_dir(file.path(root, "tests/testthat"),
      reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)
    counts <- as.data.frame(tests)
    report$tests <- list(files = length(unique(counts$file)), cases = nrow(counts),
      passed = sum(counts$passed), failed = sum(counts$failed),
      errors = sum(counts$error), warnings = sum(counts$warning),
      skipped = sum(counts$skipped))
    report$supported_methods <- supported
  } else {
    stopifnot(length(args) == 5L)
    panel_root <- normalizePath(args[[3L]], winslash = "/", mustWork = TRUE)
    results_root <- normalizePath(args[[4L]], winslash = "/", mustWork = TRUE)
    panel <- new.env(parent = baseenv())
    panel_paths <- file.path(panel_root, "utils",
      c("result_contracts.R", "display_contracts.R", "prepare_data.R"))
    panel_hashes <- vapply(panel_paths, sha, character(1L))
    sys.source(panel_paths[[1L]], envir = panel)
    sys.source(panel_paths[[2L]], envir = panel)
    # Execute the panel's actual array reader without running its UI, writing
    # application caches or downloading geospatial data.
    definitions <- parse(panel_paths[[3L]], encoding = "UTF-8")
    reader <- Filter(function(node) is.call(node) && identical(node[[1L]], as.name("<-")) &&
      identical(node[[2L]], as.name("read_fst_array")), as.list(definitions))
    stopifnot(length(reader) == 1L)
    eval(reader[[1L]], envir = panel)
    runs <- panel$wlv_resolve_result_run_dirs(results_root, channel = args[[5L]],
      required_artifacts = c("sea_countries.fst", "sea_sectors.fst", "m_countries.fst",
                             "meta_indicators.RDS", "_parameters.csv"))
    stopifnot(identical(attr(runs, "publication_mode"), "immutable_release"),
              length(runs) > 0L, all(names(runs) %in% c("wiodr13", "wiodr16")))
    release_root <- attr(runs, "release_root")
    labels <- utils::read.csv2(file.path(release_root, "indicators_en.csv"),
      stringsAsFactors = FALSE, fileEncoding = "UTF-8")
    legacy <- utils::read.csv2(file.path(release_root, "meta_indicators.csv"),
      stringsAsFactors = FALSE, fileEncoding = "UTF-8")
    report$panel <- list(commit = git(panel_root, "rev-parse", "HEAD"),
      files = as.list(stats::setNames(panel_hashes, basename(panel_paths))),
      release_id = attr(runs, "release_id"), channel = attr(runs, "channel"))
    report$methods <- lapply(names(runs), function(method) {
      run <- runs[[method]]
      metadata <- readRDS(file.path(run, "meta_indicators.RDS"))
      parameters <- utils::read.csv2(file.path(run, "_parameters.csv"))
      contract <- panel$wlv_read_supported_method_display_contract(
        file.path(run, "meta_indicators.RDS"), method,
        as.character(parameters$code[[1L]]), as.character(metadata$code), legacy)
      stopifnot(!is.null(contract), nrow(contract) == nrow(metadata))
      stopifnot(identical(contract$canonical_unit, metadata$canonical_unit),
                identical(contract$display_unit, metadata$display_unit),
                identical(contract$display_multiplier, metadata$display_multiplier))
      method_code <- as.character(parameters$code[[1L]])
      for (i in seq_len(nrow(metadata))) {
        displayed <- panel$wlv_display_values(c(0, 0.25, 1, NA_real_), method_code,
          metadata$code[[i]], contract)
        stopifnot(identical(displayed,
          c(0, 0.25, 1, NA_real_) * metadata$display_multiplier[[i]]))
      }
      stopifnot(identical(panel$wlv_display_format_type(contract, method_code,
        "gross_output.s.mv"), "value"))
      arrays <- lapply(c("sea_countries", "sea_sectors", "m_countries"), function(name) {
        path <- file.path(run, paste0(name, ".fst"))
        value <- panel$read_fst_array(path)
        canonical <- runtime$read_fst_array(path)
        # The panel's legacy-compatible reader retains empty names on the
        # dimnames list. They name no axes; coordinates and every value must
        # still match exactly, including NA/NaN and signed infinities.
        axis_names <- names(dimnames(value))
        stopifnot(is.array(value), identical(dim(value), dim(canonical)),
          is.null(axis_names) || all(axis_names == "") ||
            identical(axis_names, names(dimnames(canonical))),
          identical(unname(dimnames(value)), unname(dimnames(canonical))),
          identical(as.vector(value), as.vector(canonical)))
        if (startsWith(name, "sea_")) {
          stopifnot(identical(dimnames(value)[[2L]], as.character(metadata$code)),
                    all(as.character(metadata$code) %in% labels$cod_label))
        }
        list(artifact = name, dimensions = dim(value), values_identical = TRUE,
             coordinate_labels_identical = TRUE,
             axis_hash = runtime$wlv_runtime_snapshot_value_sha256(dimnames(value)))
      })
      list(method = method, run_id = basename(run),
           indicators = nrow(contract), units_and_display_verified = TRUE,
           arrays = arrays,
           metadata_sha256 = sha(file.path(run, "meta_indicators.RDS")))
    })
    stopifnot(identical(panel_hashes, vapply(panel_paths, sha, character(1L))))
  }
  stopifnot(identical(before, vapply(definition_files, sha, character(1L))))
  report$passed <- TRUE
}, error = function(error) failure <<- conditionMessage(error))
report$error <- failure
report$elapsed_seconds <- as.numeric(difftime(Sys.time(), started, units = "secs"))
jsonlite::write_json(report, report_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
if (!is.null(failure)) stop(failure, call. = FALSE)
message("Verification passed: ", report_path)
