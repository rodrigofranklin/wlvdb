# Import one authenticated baseline full run into an isolated validation
# worktree. Interface: <import-spec.json> <evidence-directory>.

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE),
  value = TRUE
)
if (!length(script_argument)) stop("Run with Rscript.", call. = FALSE)
script_path <- normalizePath(
  sub("^--file=", "", script_argument[[1L]]),
  winslash = "/",
  mustWork = TRUE
)
script_dir <- dirname(script_path)
sys.source(file.path(script_dir, "issue13-lib.R"), envir = environment())
sys.source(file.path(script_dir, "issue13-import-baseline-lib.R"),
  envir = environment()
)

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L || any(startsWith(arguments, "--"))) {
  stop(paste0(
    "Usage: Rscript issue13-import-baseline-run.R ",
    "<import-spec.json> <evidence-directory>"
  ), call. = FALSE)
}

spec_path <- wlv13_import_normalize_file(arguments[[1L]],
  "import specification"
)
evidence_directory <- wlv13_scalar_text(arguments[[2L]],
  "evidence directory"
)
spec <- wlv13_json_read(spec_path, simplify = FALSE)

result <- tryCatch(
  wlv13_import_baseline_run(spec, evidence_directory),
  error = function(error) {
    message("Authenticated baseline import failed: ", conditionMessage(error))
    NULL
  }
)

if (is.null(result)) {
  quit(save = "no", status = 1L, runLast = FALSE)
}
message("Authenticated baseline import passed: ", result$scenario_path)
quit(save = "no", status = 0L, runLast = FALSE)
