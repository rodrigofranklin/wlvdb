script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_argument)) {
  stop("Run issue13-snapshot.R with Rscript.", call. = FALSE)
}
script_path <- normalizePath(sub("^--file=", "", script_argument[[1L]]),
  winslash = "/", mustWork = TRUE
)
script_dir <- dirname(script_path)
sys.source(file.path(script_dir, "issue13-lib.R"), envir = environment())

options <- wlv13_parse_cli(commandArgs(trailingOnly = TRUE))
wlv13_cli_required(options, c("root", "snapshot_id", "output"))
root <- wlv13_normalize_existing_dir(options$root, "snapshot root")

paths <- if ("paths_file" %in% names(options)) {
  enc2utf8(readLines(options$paths_file, encoding = "UTF-8", warn = FALSE))
} else {
  wlv13_list_files(root)
}
paths <- paths[nzchar(paths)]
if ("include_regex" %in% names(options)) {
  paths <- paths[grepl(options$include_regex, paths, perl = TRUE)]
}
if ("exclude_regex" %in% names(options)) {
  paths <- paths[!grepl(options$exclude_regex, paths, perl = TRUE)]
}
if (!length(paths)) {
  stop("Snapshot selection is empty.", call. = FALSE)
}
role <- if ("role" %in% names(options)) options$role else "evidence_artifact"
roles <- rep(role, length(paths))
wlv13_create_snapshot(
  root = root,
  paths = paths,
  roles = roles,
  snapshot_id = options$snapshot_id,
  output = options$output
)
cat(normalizePath(options$output, winslash = "/", mustWork = TRUE), "\n")
